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
    && rm -rf /var/lib/apt/lists/*

# Create Camunda user and group
RUN groupadd -r camunda && useradd -r -g camunda camunda

# Create directories
RUN mkdir -p /camunda /opt/camunda

# Copy and extract Camunda Tomcat distribution
COPY distro/tomcat/assembly/target/camunda-tomcat-*.tar.gz /tmp/camunda-tomcat.tar.gz
RUN tar -xzf /tmp/camunda-tomcat.tar.gz -C /opt/camunda --strip-components=1 \
    && rm /tmp/camunda-tomcat.tar.gz \
    && ln -s /opt/camunda /camunda

# Set environment variables for Tomcat and Java
ENV CATALINA_HOME=/opt/camunda
ENV CATALINA_BASE=/opt/camunda
ENV JAVA_OPTS="-Djava.security.egd=file:/dev/./urandom -Djava.awt.headless=true"
ENV CATALINA_OPTS="-Xms1g -Xmx2g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+UseStringDeduplication"

# Set environment variables for Database connection
ENV DB_DRIVER=org.postgresql.Driver
ENV DB_URL=jdbc:postgresql://camunda-postgres-postgresql.database.svc.cluster.local:5432/camunda
ENV DB_USERNAME=camunda
ENV DB_PASSWORD=camunda
ENV DB_VALIDATE_ON_MIGRATE=true
ENV DB_CONN_MAXACTIVE=20
ENV DB_CONN_MINIDLE=5

# Set environment variables for Camunda Webapp configuration
ENV CAMUNDA_BPM_RUN_CORS_ENABLED=false
ENV CAMUNDA_BPM_AUTHORIZATION_ENABLED=true
ENV CAMUNDA_BPM_DATABASE_SCHEMA_UPDATE=true

# Copy application WAR files
COPY distro/tomcat/webapp/target/camunda-webapp*.war /tmp/
COPY engine-rest/assembly/target/camunda-engine-rest-*-tomcat.war /tmp/
RUN ${TOMCAT_DIR:-/opt/camunda}/bin/shutdown.sh 60 -force || true
RUN mkdir -p ${TOMCAT_DIR:-/opt/camunda}/webapps \
    && cp /tmp/camunda-webapp*.war ${TOMCAT_DIR:-/opt/camunda}/webapps/camunda.war \
    && cp /tmp/camunda-engine-rest-*-tomcat.war ${TOMCAT_DIR:-/opt/camunda}/webapps/engine-rest.war \
    && rm /tmp/camunda-webapp*.war /tmp/camunda-engine-rest-*-tomcat.war

# Copy and process configuration templates
COPY distro/tomcat/assembly/src/conf/bpm-platform.xml /tmp/bpm-platform.xml.template
COPY distro/tomcat/assembly/src/conf/server.xml /tmp/server.xml.template

# Create start script
RUN echo '#!/bin/bash' > /opt/camunda/start-camunda.sh && \
    echo 'set -e' >> /opt/camunda/start-camunda.sh && \
    echo '' >> /opt/camunda/start-camunda.sh && \
    echo '# Set Tomcat directory directly as /opt/camunda' >> /opt/camunda/start-camunda.sh && \
    echo 'TOMCAT_DIR="/opt/camunda"' >> /opt/camunda/start-camunda.sh && \
    echo 'echo "Using Tomcat directory: $TOMCAT_DIR"' >> /opt/camunda/start-camunda.sh && \
    echo '' >> /opt/camunda/start-camunda.sh && \
    echo '# Process configuration templates with envsubst' >> /opt/camunda/start-camunda.sh && \
    echo 'envsubst < /tmp/bpm-platform.xml.template > "$TOMCAT_DIR/conf/bpm-platform.xml"' >> /opt/camunda/start-camunda.sh && \
    echo 'envsubst < /tmp/server.xml.template > "$TOMCAT_DIR/conf/server.xml"' >> /opt/camunda/start-camunda.sh && \
    echo '' >> /opt/camunda/start-camunda.sh && \
    echo '# Start Tomcat' >> /opt/camunda/start-camunda.sh && \
    echo 'exec "$TOMCAT_DIR/bin/catalina.sh" run' >> /opt/camunda/start-camunda.sh

# Set permissions and ownership
RUN chmod -R 755 /opt/camunda /camunda && \
    chmod +x /opt/camunda/start-camunda.sh && \
    chmod +x /opt/camunda/bin/catalina.sh && \
    mkdir -p /opt/camunda/work/Catalina/localhost && \
    mkdir -p /opt/camunda/conf/Catalina/localhost && \
    chmod 777 /opt/camunda/conf && \
    chmod 777 /opt/camunda/conf/Catalina && \
    chmod 777 /opt/camunda/conf/Catalina/localhost && \
    chmod 777 /opt/camunda/webapps && \
    chmod 777 /opt/camunda/work && \
    chmod 777 /opt/camunda/work/Catalina && \
    chmod 777 /opt/camunda/work/Catalina/localhost && \
    chmod 777 /opt/camunda/logs && \
    chmod 777 /opt/camunda/temp && \
    chown -R camunda:camunda /camunda /opt/camunda

# Set user
USER camunda

# Expose HTTP port
EXPOSE 8080

# Define entrypoint
ENTRYPOINT ["/opt/camunda/start-camunda.sh"]
