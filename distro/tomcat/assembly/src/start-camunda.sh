#!/bin/bash

# Environment variable'ları export et (varsayılan değerler olmadan)
export DB_DRIVER
export DB_URL
export DB_USERNAME
export DB_PASSWORD
export DB_SCHEMA_UPDATE
export AUTH_ENABLED
export DB_CONN_MAXACTIVE
export DB_CONN_MINIDLE

# bpm-platform.xml dosyasını güncelle
envsubst < /tmp/bpm-platform.xml.template > "$CATALINA_HOME/conf/bpm-platform.xml"

# Tomcat'i başlat
exec "$CATALINA_HOME/bin/catalina.sh" run
