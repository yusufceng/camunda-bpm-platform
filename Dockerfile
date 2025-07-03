# Camunda BPM Platform 7 - Production Ready Docker Image
# Base: Eclipse Temurin JRE 17
FROM eclipse-temurin:17-jre

# Metadata
LABEL maintainer="Cadenza Flow-Yusuf Coşkun"
LABEL version="7.23.0"
LABEL description="Camunda BPM Platform 7 - Production Ready Build for EKS"

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

# Download and extract Tomcat directly
RUN wget -O /tmp/apache-tomcat-9.0.85.tar.gz \
    "https://archive.apache.org/dist/tomcat/tomcat-9/v9.0.85/bin/apache-tomcat-9.0.85.tar.gz" \
    && tar -xzf /tmp/apache-tomcat-9.0.85.tar.gz -C /opt/camunda --strip-components=1 \
    && rm /tmp/apache-tomcat-9.0.85.tar.gz \
    && ln -s /opt/camunda /camunda \
    && echo "=== Tomcat Directory Structure Debug ===" \
    && find /opt/camunda -maxdepth 3 -type d | head -20

# Set up Tomcat environment
RUN echo "TOMCAT_DIR=/opt/camunda" \
    && ln -sf /opt/camunda/conf /opt/camunda/conf \
    && ln -sf /opt/camunda/bin /opt/camunda/bin \
    && ln -sf /opt/camunda/lib /opt/camunda/lib \
    && ln -sf /opt/camunda/webapps /opt/camunda/webapps \
    && ln -sf /opt/camunda/logs /opt/camunda/logs \
    && echo "=== Tomcat Directory Setup Complete ===" \
    && ls -la /opt/camunda/

# Download PostgreSQL driver to correct location
RUN echo "Downloading PostgreSQL driver to: /opt/camunda/lib/" \
    && wget -O /opt/camunda/lib/postgresql-42.7.3.jar \
    "https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.3/postgresql-42.7.3.jar" \
    && echo "=== PostgreSQL Driver Downloaded ===" \
    && ls -la /opt/camunda/lib/postgresql-42.7.3.jar

# Copy Classic Java EE WAR files to webapps directory  
COPY distro/tomcat/webapp/target/camunda-webapp*.war /tmp/
COPY engine-rest/assembly/target/camunda-engine-rest-*-tomcat.war /tmp/
RUN cp /tmp/camunda-webapp*.war /opt/camunda/webapps/camunda.war \
    && cp /tmp/camunda-engine-rest-*-tomcat.war /opt/camunda/webapps/engine-rest.war \
    && rm /tmp/camunda-webapp*.war /tmp/camunda-engine-rest-*-tomcat.war \
    && echo "=== Classic Java EE WAR Files Deployed ===" \
    && ls -la /opt/camunda/webapps/*.war

# Environment variables for production
ENV CATALINA_HOME=/opt/camunda
ENV CATALINA_BASE=/opt/camunda
ENV JAVA_OPTS="-Djava.security.egd=file:/dev/./urandom -Djava.awt.headless=true"
ENV CATALINA_OPTS="-Xms1g -Xmx2g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+UseStringDeduplication"

# Database configuration (will be overridden by envsubst)
ENV DB_DRIVER=org.postgresql.Driver
ENV DB_URL=jdbc:postgresql://localhost:5432/camunda
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
    echo '# Process configuration templates with envsubst' >> /opt/camunda/start-camunda.sh && \
    echo 'envsubst < /tmp/bpm-platform.xml.template > /opt/camunda/conf/bpm-platform.xml' >> /opt/camunda/start-camunda.sh && \
    echo 'envsubst < /tmp/server.xml.template > /opt/camunda/conf/server.xml' >> /opt/camunda/start-camunda.sh && \
    echo '' >> /opt/camunda/start-camunda.sh && \
    echo '# Start Tomcat' >> /opt/camunda/start-camunda.sh && \
    echo 'exec /opt/camunda/bin/catalina.sh run' >> /opt/camunda/start-camunda.sh

# Set proper permissions and make scripts executable
RUN chmod -R 755 /opt/camunda /camunda && \
    chmod +x /opt/camunda/start-camunda.sh && \
    chmod +x /opt/camunda/bin/*.sh && \
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
