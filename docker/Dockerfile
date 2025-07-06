FROM alpine:3.18 as builder

ARG VERSION=7.23.0
ARG POSTGRESQL_VERSION=42.7.2
ARG MYSQL_VERSION=8.0.33
ARG JMX_PROMETHEUS_VERSION=0.19.0

# Install build dependencies
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    tar \
    xmlstarlet \
    openjdk17

# Create camunda directory structure
RUN mkdir -p /camunda/lib /camunda/webapps /camunda/conf /camunda/docker /camunda/javaagent

# Copy Tomcat assembly from Maven build
COPY source/distro/tomcat/assembly/target/camunda-tomcat-assembly*.tar.gz /tmp/
RUN tar xf /tmp/camunda-tomcat-assembly*.tar.gz -C /camunda --strip-components=2 && \
    rm -rf /tmp/camunda-tomcat-assembly*.tar.gz

# Copy Camunda webapp
COPY source/distro/tomcat/webapp/target/camunda-webapp.war /camunda/webapps/camunda.war

# Download database drivers
RUN curl -o /camunda/lib/postgresql.jar https://jdbc.postgresql.org/download/postgresql-${POSTGRESQL_VERSION}.jar && \
    curl -o /camunda/lib/mysql.jar https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/${MYSQL_VERSION}/mysql-connector-j-${MYSQL_VERSION}.jar

# Download JMX Prometheus Java Agent
RUN curl -L -o /camunda/javaagent/jmx_prometheus_javaagent.jar \
    https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${JMX_PROMETHEUS_VERSION}/jmx_prometheus_javaagent-${JMX_PROMETHEUS_VERSION}.jar

# Copy configuration scripts and files
COPY docker/camunda-lib.sh /camunda/docker/
COPY docker/camunda-tomcat.sh /camunda/docker/
COPY docker/prometheus-jmx.yml /camunda/javaagent/

# Final stage
FROM alpine:3.18

ARG VERSION
ENV CAMUNDA_VERSION=${VERSION}

# Install runtime dependencies
RUN apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    openjdk17-jre-headless \
    tzdata \
    tini \
    xmlstarlet \
    ttf-dejavu && \
    curl -o /usr/local/bin/wait-for-it.sh \
    "https://raw.githubusercontent.com/vishnubob/wait-for-it/a454892f3c2ebbc22bd15e446415b8fcb7c1cfa4/wait-for-it.sh" && \
    chmod +x /usr/local/bin/wait-for-it.sh

# Create camunda user
RUN addgroup -g 1000 -S camunda && \
    adduser -u 1000 -S camunda -G camunda -h /camunda -s /bin/bash -D camunda

# Copy Camunda from builder
COPY --from=builder --chown=camunda:camunda /camunda /camunda

# Set permissions
RUN chmod +x /camunda/docker/camunda-tomcat.sh /camunda/docker/camunda-lib.sh

# Environment variables
ENV PATH=/camunda/bin:$PATH \
    CATALINA_HOME=/camunda \
    CATALINA_BASE=/camunda \
    DB_DRIVER="" \
    DB_URL="" \
    DB_USERNAME="" \
    DB_PASSWORD="" \
    DB_CONN_MAXACTIVE=20 \
    DB_CONN_MINIDLE=5 \
    DB_CONN_MAXIDLE=20 \
    DB_VALIDATE_ON_BORROW=false \
    DB_VALIDATION_QUERY="SELECT 1" \
    SKIP_DB_CONFIG="" \
    WAIT_FOR="" \
    WAIT_FOR_TIMEOUT=30 \
    TZ=UTC \
    DEBUG=false \
    JAVA_OPTS="" \
    JMX_PROMETHEUS=false \
    JMX_PROMETHEUS_CONF=/camunda/javaagent/prometheus-jmx.yml \
    JMX_PROMETHEUS_PORT=9404

# Expose ports (Tomcat, Debug, JMX Prometheus)
EXPOSE 8080 8000 9404

# Switch to camunda user
WORKDIR /camunda
USER camunda

# Use tini as init
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["/camunda/docker/camunda-tomcat.sh"] 