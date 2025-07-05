#!/bin/bash

# Environment variable'ları export et (varsayılan değerler olmadan)
# Bu 'export' komutları, zaten ENV ile ayarlanmış değişkenler için gerekli değildir,
# ancak hata yaratmadıkları için bu haliyle bırakılabilir.
export DB_DRIVER
export DB_URL
export DB_USERNAME
export DB_PASSWORD
export DB_SCHEMA_UPDATE
export AUTH_ENABLED
export DB_CONN_MAXACTIVE
export DB_CONN_MINIDLE

# --- HATA AYIKLAMA BAŞLANGICI ---
echo "--- Ortam Değişkenleri Hata Ayıklama İçin ---"
echo "DB_URL: $DB_URL"
echo "DB_USERNAME: $DB_USERNAME"
echo "DB_PASSWORD: $DB_PASSWORD"
echo "DB_DRIVER: $DB_DRIVER"
echo "DB_SCHEMA_UPDATE: $DB_SCHEMA_UPDATE"
echo "AUTH_ENABLED: $AUTH_ENABLED"
echo "DB_CONN_MAXACTIVE: $DB_CONN_MAXACTIVE"
echo "DB_CONN_MINIDLE: $DB_CONN_MINIDLE"
echo "--- Ortam Değişkenleri Hata Ayıklama Sonu ---"
echo ""

echo "--- /tmp/bpm-platform.xml.template İçeriği ---"
cat /tmp/bpm-platform.xml.template
echo "--- /tmp/bpm-platform.xml.template İçeriği Sonu ---"
echo ""
# --- HATA AYIKLAMA SONU ---

# bpm-platform.xml dosyasını güncelle
# CATALINA_HOME, Dockerfile'daki ENV değişkeniyle ayarlanmıştır.
envsubst < /tmp/bpm-platform.xml.template > "$CATALINA_HOME/conf/bpm-platform.xml"

# --- HATA AYIKLAMA BAŞLANGICI ---
echo ""
echo "=== İşlenmiş bpm-platform.xml jdbcUrl ==="
# Grep komutunda $CATALINA_HOME değişkenini kullanın
grep "jdbcUrl" "$CATALINA_HOME/conf/bpm-platform.xml"
echo "=== Tam bpm-platform.xml içeriği ==="
# Cat komutunda $CATALINA_HOME değişkenini kullanın
cat "$CATALINA_HOME/conf/bpm-platform.xml"
echo ""
# --- HATA AYIKLAMA SONU ---

# Tomcat'i başlat
exec "$CATALINA_HOME/bin/catalina.sh" run
