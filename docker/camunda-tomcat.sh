#!/bin/bash

set -e

# Source common functions
source /camunda/docker/camunda-lib.sh

# Set database environment variables
set_database_environment_variables

# Wait for dependent services
if [ -n "$WAIT_FOR" ]; then
  IFS=',' read -ra WAIT_FOR_ARRAY <<< "$WAIT_FOR"
  for host_port in "${WAIT_FOR_ARRAY[@]}"; do
    wait-for-it.sh -t ${WAIT_FOR_TIMEOUT} ${host_port}
  done
fi

# Configure server.xml for Tomcat
function configure_server() {
  # Configure HTTP port
  : ${HTTP_PORT:=8080}
  xmlstarlet_command /camunda/conf/server.xml \
    '-u "/Server/Service/Connector[@protocol=\"HTTP/1.1\"]/@port" -v "'${HTTP_PORT}'"'

  # Configure database connection
  xmlstarlet_command /camunda/conf/server.xml \
    '-d "/Server/GlobalNamingResources/Resource[@name=\"jdbc/ProcessEngine\"]" \
     -s "/Server/GlobalNamingResources" -t elem -n "Resource" \
     -i "/Server/GlobalNamingResources/Resource[not(@name)]" -t attr -n "name" -v "jdbc/ProcessEngine" \
     -i "/Server/GlobalNamingResources/Resource[@name=\"jdbc/ProcessEngine\"]" -t attr -n "auth" -v "Container" \
     -i "/Server/GlobalNamingResources/Resource[@name=\"jdbc/ProcessEngine\"]" -t attr -n "type" -v "javax.sql.DataSource" \
     -i "/Server/GlobalNamingResources/Resource[@name=\"jdbc/ProcessEngine\"]" -t attr -n "driverClassName" -v "'${DB_DRIVER}'" \
     -i "/Server/GlobalNamingResources/Resource[@name=\"jdbc/ProcessEngine\"]" -t attr -n "url" -v "'${DB_URL}'" \
     -i "/Server/GlobalNamingResources/Resource[@name=\"jdbc/ProcessEngine\"]" -t attr -n "username" -v "'${DB_USERNAME}'" \
     -i "/Server/GlobalNamingResources/Resource[@name=\"jdbc/ProcessEngine\"]" -t attr -n "password" -v "'${DB_PASSWORD}'" \
     -i "/Server/GlobalNamingResources/Resource[@name=\"jdbc/ProcessEngine\"]" -t attr -n "maxActive" -v "'${DB_CONN_MAXACTIVE}'" \
     -i "/Server/GlobalNamingResources/Resource[@name=\"jdbc/ProcessEngine\"]" -t attr -n "minIdle" -v "'${DB_CONN_MINIDLE}'" \
     -i "/Server/GlobalNamingResources/Resource[@name=\"jdbc/ProcessEngine\"]" -t attr -n "maxIdle" -v "'${DB_CONN_MAXIDLE}'" \
     -i "/Server/GlobalNamingResources/Resource[@name=\"jdbc/ProcessEngine\"]" -t attr -n "testOnBorrow" -v "'${DB_VALIDATE_ON_BORROW}'" \
     -i "/Server/GlobalNamingResources/Resource[@name=\"jdbc/ProcessEngine\"]" -t attr -n "validationQuery" -v "'${DB_VALIDATION_QUERY}'"'
}

# Configure bpm-platform.xml
function configure_bpm_platform() {
  : ${BPM_HISTORY_LEVEL:=full}
  : ${BPM_METRICS_FLAG:=true}

  xmlstarlet_command /camunda/conf/bpm-platform.xml \
    '-u "/c:bpm-platform/c:process-engine/c:properties/c:property[@name=\"history\"]/@value" -v "'${BPM_HISTORY_LEVEL}'" \
     -u "/c:bpm-platform/c:process-engine/c:properties/c:property[@name=\"metricsEnabled\"]/@value" -v "'${BPM_METRICS_FLAG}'"'
}

# Configure JMX Prometheus
if [ "${JMX_PROMETHEUS}" = "true" ]; then
  JAVA_OPTS="${JAVA_OPTS} -javaagent:/camunda/javaagent/jmx_prometheus_javaagent.jar=${JMX_PROMETHEUS_PORT}:${JMX_PROMETHEUS_CONF}"
fi

# Configure Debug Mode
if [ "${DEBUG}" = "true" ]; then
  JAVA_OPTS="${JAVA_OPTS} -agentlib:jdwp=transport=dt_socket,server=y,suspend=n,address=*:8000"
fi

# Main configuration
configure_server
configure_bpm_platform

# Start Tomcat
exec /camunda/bin/catalina.sh run 