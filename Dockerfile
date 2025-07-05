FROM eclipse-temurin:17-jre

LABEL maintainer="Cadenza Flow-Yusuf Coşkun"
LABEL version="7.23.0"
LABEL description="Camunda BPM Platform 7.23.0 - Production Ready Build for EKS"

# Install necessary packages
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    unzip \
    xmlstarlet \
    gettext-base \
    file \
    && rm -rf /var/lib/apt/lists/*

# Create Camunda user and group
RUN groupadd -r camunda && useradd -r -g camunda camunda

# Create directories
RUN mkdir -p /camunda /opt/camunda

# Copy and extract Camunda Tomcat distribution
COPY distro/tomcat/assembly/target/camunda-tomcat-*.tar.gz /tmp/camunda-tomcat.tar.gz

# Debug: Check assembly file content
RUN ls -la /tmp/camunda-tomcat.tar.gz && \
    file /tmp/camunda-tomcat.tar.gz && \
    echo "=== Assembly file content ===" && \
    tar -tzf /tmp/camunda-tomcat.tar.gz | head -20

# Extract assembly
RUN tar -xzf /tmp/camunda-tomcat.tar.gz -C /opt/camunda --strip-components=1 \
    && rm /tmp/camunda-tomcat.tar.gz \
    && ln -s /opt/camunda /camunda

# Debug: Check extracted content
RUN echo "=== /opt/camunda content ===" && \
    ls -la /opt/camunda && \
    echo "=== /opt/camunda/bin content ===" && \
    ls -la /opt/camunda/bin 2>/dev/null || echo "bin directory not found" && \
    echo "=== /opt/camunda/conf content ===" && \
    ls -la /opt/camunda/conf 2>/dev/null || echo "conf directory not found"

# Find Tomcat directory and create symlinks
RUN TOMCAT_DIR=$(find /opt/camunda -name "apache-tomcat-*" -type d | head -1) \
    && echo "TOMCAT_DIR=${TOMCAT_DIR}" \
    && if [ -n "$TOMCAT_DIR" ]; then \
        ln -sf ${TOMCAT_DIR}/conf /opt/camunda/conf; \
        ln -sf ${TOMCAT_DIR}/bin /opt/camunda/bin; \
        ln -sf ${TOMCAT_DIR}/lib /opt/camunda/lib; \
        ln -sf ${TOMCAT_DIR}/webapps /opt/camunda/webapps; \
        ln -sf ${TOMCAT_DIR}/logs /opt/camunda/logs; \
    else \
        echo "Tomcat directory not found, checking assembly structure"; \
        find /opt/camunda -type d | head -10; \
    fi

# Download PostgreSQL driver (already included in assembly)
# We keep this as a fallback in case the assembly doesn't include it
RUN TOMCAT_DIR=$(find /opt/camunda -name "apache-tomcat-9.*" -type d | head -1) \
    && if [ -n "$TOMCAT_DIR" ]; then \
        if [ ! -f ${TOMCAT_DIR}/lib/postgresql-42.7.3.jar ]; then \
            wget -O ${TOMCAT_DIR}/lib/postgresql-42.7.3.jar \
            "https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.3/postgresql-42.7.3.jar"; \
        fi \
    else \
        echo "Tomcat directory not found, skipping PostgreSQL driver"; \
    fi

# Set environment variables for Tomcat and Java
ENV CATALINA_HOME=/opt/camunda
ENV CATALINA_BASE=/opt/camunda
ENV JAVA_OPTS="-Djava.security.egd=file:/dev/./urandom -Djava.awt.headless=true"
ENV CATALINA_OPTS="-Xms1g -Xmx2g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+UseStringDeduplication"

# Set environment variables for Camunda Webapp configuration
ENV CAMUNDA_BPM_RUN_CORS_ENABLED=false
ENV CAMUNDA_BPM_AUTHORIZATION_ENABLED=true
ENV CAMUNDA_BPM_DATABASE_SCHEMA_UPDATE=true

# Copy configuration files and scripts
COPY distro/tomcat/assembly/src/conf/bpm-platform.xml /tmp/bpm-platform.xml.template
COPY distro/tomcat/assembly/src/conf/server.xml /tmp/server.xml.template
COPY distro/tomcat/assembly/src/start-camunda.sh /opt/camunda/start-camunda.sh

# Copy application WAR files (using non-Jakarta WAR files for Tomcat 9)
COPY distro/tomcat/webapp/target/camunda-webapp.war /tmp/
COPY engine-rest/assembly/target/camunda-engine-rest-*-tomcat.war /tmp/

# Deploy WAR files and configuration
RUN TOMCAT_DIR=$(find /opt/camunda -name "apache-tomcat-*" -type d | head -1) \
    && if [ -n "$TOMCAT_DIR" ]; then \
        mkdir -p ${TOMCAT_DIR}/webapps; \
        cp /tmp/camunda-webapp.war ${TOMCAT_DIR}/webapps/camunda.war; \
        cp /tmp/camunda-engine-rest-*-tomcat.war ${TOMCAT_DIR}/webapps/engine-rest.war; \
        cp /tmp/bpm-platform.xml.template ${TOMCAT_DIR}/conf/bpm-platform.xml; \
        cp /tmp/server.xml.template ${TOMCAT_DIR}/conf/server.xml; \
        rm /tmp/camunda-webapp.war /tmp/camunda-engine-rest-*-tomcat.war; \
    else \
        echo "Tomcat directory not found, cannot deploy WAR files"; \
        exit 1; \
    fi

# Set permissions and ownership
RUN TOMCAT_DIR=$(find /opt/camunda -name "apache-tomcat-*" -type d | head -1) \
    && if [ -n "$TOMCAT_DIR" ]; then \
        chmod -R 755 /opt/camunda /camunda; \
        chmod +x /opt/camunda/start-camunda.sh; \
        chmod +x ${TOMCAT_DIR}/bin/*.sh; \
        mkdir -p ${TOMCAT_DIR}/work/Catalina/localhost; \
        mkdir -p ${TOMCAT_DIR}/conf/Catalina/localhost; \
        chmod 777 ${TOMCAT_DIR}/conf; \
        chmod 777 ${TOMCAT_DIR}/conf/Catalina; \
        chmod 777 ${TOMCAT_DIR}/conf/Catalina/localhost; \
        chmod 777 ${TOMCAT_DIR}/webapps; \
        chmod 777 ${TOMCAT_DIR}/work; \
        chmod 777 ${TOMCAT_DIR}/work/Catalina; \
        chmod 777 ${TOMCAT_DIR}/work/Catalina/localhost; \
        chmod 777 ${TOMCAT_DIR}/logs; \
        chmod 777 ${TOMCAT_DIR}/temp; \
        chown -R camunda:camunda /camunda /opt/camunda; \
    else \
        echo "Tomcat directory not found, cannot set permissions"; \
        exit 1; \
    fi

# Set user
USER camunda

# Expose HTTP port
EXPOSE 8080

# Define entrypoint
ENTRYPOINT ["/opt/camunda/start-camunda.sh"]
