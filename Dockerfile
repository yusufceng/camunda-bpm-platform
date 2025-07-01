# Camunda BPM Platform 7 - Production Ready Docker Image
# Base: Eclipse Temurin JRE 17
FROM eclipse-temurin:17-jre

# Metadata
LABEL maintainer="Your Organization"
LABEL version="7.x-custom"
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

# Install Tomcat 9
ENV TOMCAT_VERSION=9.0.93
ENV CATALINA_HOME=/camunda
ENV CATALINA_BASE=/camunda

RUN wget -O /tmp/tomcat.tar.gz \
    "https://archive.apache.org/dist/tomcat/tomcat-9/v${TOMCAT_VERSION}/bin/apache-tomcat-${TOMCAT_VERSION}.tar.gz" \
    && tar -xzf /tmp/tomcat.tar.gz -C /opt/camunda --strip-components=1 \
    && rm /tmp/tomcat.tar.gz \
    && rm -rf /opt/camunda/webapps/ROOT \
           /opt/camunda/webapps/docs \
           /opt/camunda/webapps/examples \
           /opt/camunda/webapps/host-manager \
           /opt/camunda/webapps/manager \
    && ln -s /opt/camunda /camunda

# Download database drivers at BUILD TIME (not runtime)
# Ensure lib directory exists first
RUN mkdir -p /camunda/lib && \
    wget -O /camunda/lib/postgresql-42.7.3.jar \
    "https://repo1.maven.org/maven2/org/postgresql/postgresql/42.7.3/postgresql-42.7.3.jar" && \
    wget -O /camunda/lib/mysql-connector-j-8.4.0.jar \
    "https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.4.0/mysql-connector-j-8.4.0.jar"

# Copy built artifacts (will be available after Maven build in pipeline)
# Engine core libraries
COPY engine/target/*.jar /camunda/lib/
COPY engine-dmn/*/target/*.jar /camunda/lib/
COPY engine-spring/target/*.jar /camunda/lib/

# Web applications - WAR files from assembly modules
COPY engine-rest/assembly/target/camunda-engine-rest-*-tomcat.war /camunda/webapps/engine-rest.war
COPY webapps/assembly/target/camunda-webapp.war /camunda/webapps/camunda.war

# Environment variables for production
ENV JAVA_OPTS="-Djava.security.egd=file:/dev/./urandom -Djava.awt.headless=true"
ENV CATALINA_OPTS="-Xms1g -Xmx2g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+UseStringDeduplication"

# Database configuration (override with K8s ConfigMap/Secrets)
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

# Create configuration directory and files at BUILD TIME
RUN mkdir -p /camunda/conf

# Create bpm-platform.xml at BUILD TIME
RUN cat > /camunda/conf/bpm-platform.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<bpm-platform xmlns="http://www.camunda.org/schema/1.0/BpmPlatform"
              xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
              xsi:schemaLocation="http://www.camunda.org/schema/1.0/BpmPlatform http://www.camunda.org/schema/1.0/BpmPlatform.xsd">

  <job-executor>
    <job-acquisition name="default">
      <max-jobs-per-acquisition>3</max-jobs-per-acquisition>
      <wait-time-in-millis>5000</wait-time-in-millis>
    </job-acquisition>
  </job-executor>

  <process-engine name="default">
    <job-acquisition>default</job-acquisition>
    <configuration>org.camunda.bpm.engine.impl.cfg.StandaloneProcessEngineConfiguration</configuration>
    <datasource>jdbc/ProcessEngine</datasource>
    
    <properties>
      <property name="history">full</property>
      <property name="databaseSchemaUpdate">true</property>
      <property name="authorizationEnabled">true</property>
      <property name="jobExecutorDeploymentAware">true</property>
    </properties>
  </process-engine>

</bpm-platform>
EOF

# Create context.xml with hardcoded PostgreSQL configuration
RUN cat > /camunda/conf/context.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<Context>
    <Resource name="jdbc/ProcessEngine"
              auth="Container"
              type="javax.sql.DataSource"
              factory="org.apache.tomcat.jdbc.pool.DataSourceFactory"
              uniqueResourceName="process-engine"
              driverClassName="org.postgresql.Driver"
              url="jdbc:postgresql://camunda-postgres-postgresql.database.svc.cluster.local:5432/postgres"
              username="postgres"
              password="postgres"
              maxActive="20"
              minIdle="5"
              maxIdle="20"
              testOnBorrow="true"
              testWhileIdle="true"
              testOnReturn="false"
              validationQuery="SELECT 1"
              timeBetweenEvictionRunsMillis="30000"
              minEvictableIdleTimeMillis="30000" />
</Context>
EOF

# Copy and setup startup script
COPY startup.sh /camunda/bin/camunda-start.sh
RUN chmod +x /camunda/bin/camunda-start.sh

# Health check for Kubernetes
HEALTHCHECK --interval=30s --timeout=15s --start-period=120s --retries=3 \
  CMD curl -f http://localhost:8080/camunda/app/welcome/default/#!/welcome || exit 1

# Set proper permissions and make scripts executable
RUN chmod +x /opt/camunda/bin/*.sh && \
    chown -R camunda:camunda /camunda /opt/camunda

# Switch to camunda user
USER camunda
WORKDIR /camunda

# Expose Tomcat port
EXPOSE 8080

# Start Camunda
CMD ["/camunda/bin/camunda-start.sh"] 
