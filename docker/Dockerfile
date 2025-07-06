FROM eclipse-temurin:17-jre-alpine

# Gerekli araçları yükle
RUN apk add --no-cache curl tar gzip bash tzdata tini xmlstarlet

# Build-time argümanları olarak Nexus ve Camunda versiyon bilgilerini al
ARG CAMUNDA_VERSION=7.23.0
ARG NEXUS_URL=http://nexus.pia.local:8081/repository/maven-releases
ARG NEXUS_USERNAME
ARG NEXUS_PASSWORD

# Çevresel değişkenleri ayarla
ENV CAMUNDA_VERSION=${CAMUNDA_VERSION}
ENV DB_DRIVER=
ENV DB_URL=
ENV DB_USERNAME=
ENV DB_PASSWORD=
ENV DB_CONN_MAXACTIVE=20
ENV DB_CONN_MINIDLE=5
ENV DB_CONN_MAXIDLE=20
ENV DB_VALIDATE_ON_BORROW=false
ENV DB_VALIDATION_QUERY="SELECT 1"
ENV SKIP_DB_CONFIG=
ENV WAIT_FOR=
ENV WAIT_FOR_TIMEOUT=30
ENV TZ=UTC
ENV DEBUG=false
ENV JAVA_OPTS=""
ENV JMX_PROMETHEUS=false
ENV JMX_PROMETHEUS_CONF=/camunda/javaagent/prometheus-jmx.yml
ENV JMX_PROMETHEUS_PORT=9404

# Kullanıcı oluştur
RUN addgroup -g 1000 -S camunda && \
    adduser -u 1000 -S camunda -G camunda -h /camunda -s /bin/bash -D camunda

# Camunda Tomcat Assembly'yi Nexus'tan indir
RUN mkdir -p /opt/camunda \
    && curl -f -L -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" -o /tmp/camunda-tomcat.tar.gz \
       "${NEXUS_URL}/org/camunda/bpm/camunda-bpm-platform-tomcat-assembly/${CAMUNDA_VERSION}/camunda-bpm-platform-tomcat-assembly-${CAMUNDA_VERSION}.tar.gz" \
    && tar -xzf /tmp/camunda-tomcat.tar.gz -C /opt/camunda --strip-components=1 \
    && rm /tmp/camunda-tomcat.tar.gz

# Camunda Webapp WAR'ı Nexus'tan indir ve doğru yere taşı
RUN curl -f -L -u "${NEXUS_USERNAME}:${NEXUS_PASSWORD}" -o /tmp/camunda-webapp.war \
       "${NEXUS_URL}/org/camunda/bpm/camunda-webapp/${CAMUNDA_VERSION}/camunda-webapp-${CAMUNDA_VERSION}.war" \
    && mv /tmp/camunda-webapp.war /opt/camunda/webapps/camunda.war

# Çalışma dizini ve kullanıcıyı ayarla
WORKDIR /camunda
USER root

# Yardımcı scriptleri kopyala ve izinleri ayarla
COPY camunda-lib.sh /camunda/
COPY camunda-tomcat.sh /camunda/camunda.sh
COPY prometheus-jmx.yml /camunda/javaagent/prometheus-jmx.yml

# İzinleri ayarla ve kullanıcıyı değiştir
RUN chmod +x /camunda/*.sh \
    && mkdir -p /camunda/javaagent \
    && chown -R camunda:camunda /camunda /opt/camunda

USER camunda

# Portu aç
EXPOSE 8080 9404

# Başlangıç komutu
ENTRYPOINT ["/sbin/tini", "--"]
CMD ["./camunda.sh"]
