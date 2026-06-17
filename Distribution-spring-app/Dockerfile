FROM eclipse-temurin:17-jre-jammy

RUN groupadd -r water && useradd -r -g water water

# curl/ca-certificates: needed by entrypoint.sh to download runtime modules from Maven repos
RUN apt-get update \
    && apt-get install -y --no-install-recommends curl ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Directory for runtime extension JARs (mounted at deploy time via EXTRA_CLASSPATH_DIR)
RUN mkdir -p /extlib && chown water:water /extlib

COPY build/libs/Distribution-spring-app-*.jar app.jar
RUN chown water:water app.jar

# Bootstrap script: downloads WATER_MODULES from Maven repos into /extlib, then launches the app
COPY entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh && chown water:water /app/entrypoint.sh

# Demo keystore generated at build time (container-level property, NOT shipped from sources).
# Used by entrypoint.sh as fallback only when WATER_KEYSTORE_FILE is unset, so a bare
# `docker run` works out-of-the-box for testing. The jar itself stays fail-fast (#1):
# a real deployment MUST provide its own keystore via WATER_KEYSTORE_FILE.
RUN mkdir -p /app/default-certs \
    && keytool -genkeypair -alias server-cert -keyalg RSA -keysize 2048 -validity 3650 \
       -keystore /app/default-certs/server.keystore -storetype JKS \
       -storepass water. -keypass water. \
       -dname "CN=water-default, OU=dev, O=WaterFramework, L=NA, ST=NA, C=IT" \
    && chown -R water:water /app/default-certs

USER water

EXPOSE 8080

# Dynamic module provisioning (handled by entrypoint.sh):
#   WATER_MODULES         = comma-separated Maven coordinates (groupId:artifactId:version) downloaded into /extlib
#   WATER_MAVEN_REPO_<n>_URL / _USER / _PASSWORD = repositories tried in order (failover, first HTTP 200 wins)
#                                                   USER/PASSWORD optional per repo
ENV SERVER_PORT=8080 \
    SERVER_SERVLET_CONTEXT_PATH=/water \
    EXTRA_CLASSPATH_DIR=/extlib \
    EXTRA_SCAN_PACKAGES="" \
    WATER_MODULES="" \
    WATER_MAVEN_REPO_1_URL="" \
    WATER_TEST_MODE=false \
    WATER_KEYSTORE_TYPE=jks \
    WATER_KEYSTORE_PASSWORD=water. \
    WATER_KEYSTORE_ALIAS=server-cert \
    WATER_PRIVATE_KEY_PASSWORD=water. \
    DB_DRIVER_CLASS_NAME=org.hsqldb.jdbcDriver \
    DB_HOST=jdbc:hsqldb:mem:waterdb \
    DB_USERNAME=sa \
    DB_PASSWORD="" \
    DB_POOL_SIZE=10

VOLUME ["/extlib"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD bash -c 'exec 6<>/dev/tcp/localhost/${SERVER_PORT} && echo -e "GET ${SERVER_SERVLET_CONTEXT_PATH}/ HTTP/1.0\r\n\r\n" >&6 && cat <&6 | grep -qE "HTTP/1\.[01] [1-5][0-9]{2}"' || exit 1

ENTRYPOINT ["/app/entrypoint.sh"]