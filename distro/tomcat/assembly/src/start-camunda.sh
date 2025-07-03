#!/bin/bash

# Veritabanı bağlantı bilgilerini environment variable'lardan al
export DB_DRIVER=${DB_DRIVER:-org.postgresql.Driver}
export DB_URL=${DB_URL:-jdbc:postgresql://localhost:5432/camunda}
export DB_USERNAME=${DB_USERNAME:-camunda}
export DB_PASSWORD=${DB_PASSWORD:-camunda}
export DB_SCHEMA_UPDATE=${DB_SCHEMA_UPDATE:-true}
export AUTH_ENABLED=${AUTH_ENABLED:-true}
export DB_CONN_MAXACTIVE=${DB_CONN_MAXACTIVE:-20}
export DB_CONN_MINIDLE=${DB_CONN_MINIDLE:-5}

# Tomcat dizinini bul
CATALINA_HOME="$(dirname "$0")/server/apache-tomcat-${version.tomcat}"

# bpm-platform.xml dosyasını güncelle
envsubst < /tmp/bpm-platform.xml.template > "$CATALINA_HOME/conf/bpm-platform.xml"

# Tomcat'i başlat
exec "$CATALINA_HOME/bin/catalina.sh" run
