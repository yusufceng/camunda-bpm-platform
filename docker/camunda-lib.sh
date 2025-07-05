#!/bin/bash

# Common functions for Camunda scripts

# Database configuration
function set_database_environment_variables() {
  : ${DB_DRIVER:=org.postgresql.Driver}
  : ${DB_URL:=jdbc:postgresql://localhost:5432/camunda}
  : ${DB_USERNAME:=camunda}
  : ${DB_PASSWORD:=camunda}
  : ${DB_CONN_MAXACTIVE:=20}
  : ${DB_CONN_MINIDLE:=5}
  : ${DB_CONN_MAXIDLE:=20}
  : ${DB_VALIDATE_ON_BORROW:=true}
  : ${DB_VALIDATION_QUERY:="SELECT 1"}
}

# XML configuration
function xmlstarlet_command() {
  local file=$1
  local command=$2
  xmlstarlet ed -L -N c=http://www.camunda.org/schema/1.0/BpmPlatform -N w=http://java.sun.com/xml/ns/javaee "$command" "$file"
} 