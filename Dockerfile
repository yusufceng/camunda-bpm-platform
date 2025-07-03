# Camunda BPM Platform 7.23.0 - Production Ready Docker Image
# Single stage - Build artifacts from Tekton pipeline
FROM eclipse-temurin:17-jre

# Metadata
LABEL maintainer="Cadenza Flow-Yusuf Coşkun"
LABEL version="7.23.0"
LABEL description="Camunda BPM Platform 7.23.0 - Production Ready Build for EKS"

# Install required packages
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    unzip \
    xmlstarlet \
    gettext-base \
    && rm -rf /var/lib/apt/lists/*

# Create camunda user and directories
RUN groupadd -r camunda && useradd -r -g camunda camunda
RUN mkdir -p /camunda /opt/camunda

# Copy and extract Camunda Tomcat Assembly (pre-built in Tekton)
COPY distro/tomcat/assembly/target/camunda-tomcat-assembly-*.tar.gz /tmp/camunda-tomcat.tar.gz
RUN tar -xzf /tmp/camunda-tomcat.tar.gz -C /opt/camunda --strip-components=1 \
    && rm /tmp/camunda-tomcat.tar.gz \
    && ln -s /opt/camunda /camunda

# Find Tomcat directory and set up environment (assembly uses server/ directory)
RUN TOMCAT_DIR=$(find /opt/camunda/server -name "apache-tomcat-*" -type d | head -1) \
    && echo "TOMCAT_DIR=${TOMCAT_DIR}" \
    && ln -sf ${TOMCAT_DIR}/conf /opt/camunda/conf \
    && ln -sf ${TOMCAT_DIR}/bin /opt/camunda/bin \
    && ln -sf ${TOMCAT_DIR}/lib /opt/camunda/lib \
    && ln -sf ${TOMCAT_DIR}/webapps /opt/camunda/webapps \
    && ln -sf ${TOMCAT_DIR}/logs /opt/camunda/logs

# Download PostgreSQL driver to correct location
RUN TOMCAT_DIR=$(find /opt/camunda/server -name "apache-tomcat-*" -type d | head -1) \
    && wget -O ${TOMCAT_DIR}/lib/postgresql-42.7.3.jar \
    "https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.3/postgresql-42.7.3.jar"

# Copy WAR files (pre-built in Tekton) to webapps directory  
COPY distro/tomcat/webapp/target/camunda-webapp*.war /tmp/
COPY engine-rest/assembly/target/camunda-engine-rest-*-tomcat.war /tmp/
RUN TOMCAT_DIR=$(find /opt/camunda/server -name "apache-tomcat-*" -type d | head -1) \
    && cp /tmp/camunda-webapp*.war ${TOMCAT_DIR}/webapps/camunda.war \
    && cp /tmp/camunda-engine-rest-*-tomcat.war ${TOMCAT_DIR}/webapps/engine-rest.war \
    && rm /tmp/camunda-webapp*.war /tmp/camunda-engine-rest-*-tomcat.war

# Environment variables for production
ENV CATALINA_HOME=/opt/camunda
ENV CATALINA_BASE=/opt/camunda
ENV JAVA_OPTS="-Djava.security.egd=file:/dev/./urandom -Djava.awt.headless=true"
ENV CATALINA_OPTS="-Xms1g -Xmx2g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+UseStringDeduplication"

# Database configuration
ENV DB_DRIVER=org.postgresql.Driver
ENV DB_URL=jdbc:postgresql://camunda-postgres-postgresql.database.svc.cluster.local:5432/camunda
ENV DB_USERNAME=camunda
ENV DB_PASSWORD=camunda
ENV DB_VALIDATE_ON_MIGRATE=true
ENV DB_CONN_MAXACTIVE=20
ENV DB_CONN_MINIDLE=5

# Camunda specific configurations
ENV CAMUNDA_BPM_RUN_CORS_ENABLED=false
ENV CAMUNDA_BPM_AUTHORIZATION_ENABLED=true
ENV CAMUNDA_BPM_DATABASE_SCHEMA_UPDATE=true

# Copy configuration templates
COPY distro/tomcat/assembly/src/conf/bpm-platform.xml /tmp/bpm-platform.xml.template
COPY distro/tomcat/assembly/src/conf/server.xml /tmp/server.xml.template

# Create startup script with envsubst
RUN echo '#!/bin/bash' > /opt/camunda/start-camunda.sh && \
    echo 'set -e' >> /opt/camunda/start-camunda.sh && \
    echo '' >> /opt/camunda/start-camunda.sh && \
    echo '# Find Tomcat directory' >> /opt/camunda/start-camunda.sh && \
    echo 'TOMCAT_DIR=$(find /opt/camunda/server -name "apache-tomcat-*" -type d | head -1)' >> /opt/camunda/start-camunda.sh && \
    echo 'echo "Using Tomcat directory: $TOMCAT_DIR"' >> /opt/camunda/start-camunda.sh && \
    echo '' >> /opt/camunda/start-camunda.sh && \
    echo '# Process configuration templates with envsubst' >> /opt/camunda/start-camunda.sh && \
    echo 'envsubst < /tmp/bpm-platform.xml.template > "$TOMCAT_DIR/conf/bpm-platform.xml"' >> /opt/camunda/start-camunda.sh && \
    echo 'envsubst < /tmp/server.xml.template > "$TOMCAT_DIR/conf/server.xml"' >> /opt/camunda/start-camunda.sh && \
    echo '' >> /opt/camunda/start-camunda.sh && \
    echo '# Start Tomcat' >> /opt/camunda/start-camunda.sh && \
    echo 'exec "$TOMCAT_DIR/bin/catalina.sh" run' >> /opt/camunda/start-camunda.sh

# Set proper permissions and make scripts executable
RUN chmod -R 755 /opt/camunda /camunda && \
    chmod +x /opt/camunda/start-camunda.sh && \
    TOMCAT_DIR=$(find /opt/camunda/server -name "apache-tomcat-*" -type d | head -1) && \
    chmod +x ${TOMCAT_DIR}/bin/*.sh && \
    mkdir -p ${TOMCAT_DIR}/work/Catalina/localhost && \
    mkdir -p ${TOMCAT_DIR}/conf/Catalina/localhost && \
    chmod 777 ${TOMCAT_DIR}/conf && \
    chmod 777 ${TOMCAT_DIR}/conf/Catalina && \
    chmod 777 ${TOMCAT_DIR}/conf/Catalina/localhost && \
    chmod 777 ${TOMCAT_DIR}/webapps && \
    chmod 777 ${TOMCAT_DIR}/work && \
    chmod 777 ${TOMCAT_DIR}/work/Catalina && \
    chmod 777 ${TOMCAT_DIR}/work/Catalina/localhost && \
    chmod 777 ${TOMCAT_DIR}/logs && \
    chmod 777 ${TOMCAT_DIR}/temp && \
    chown -R camunda:camunda /camunda /opt/camunda

# Health check for Kubernetes
HEALTHCHECK --interval=30s --timeout=15s --start-period=120s --retries=3 \
  CMD curl -f http://localhost:8080/camunda/ || exit 1

# Switch to camunda user
USER camunda
WORKDIR /camunda

# Expose Tomcat port
EXPOSE 8080

# Start Camunda
CMD ["/opt/camunda/start-camunda.sh"]
