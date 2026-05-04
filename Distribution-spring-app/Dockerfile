FROM eclipse-temurin:17-jre-jammy

RUN groupadd -r water && useradd -r -g water water

WORKDIR /app

# Directory for runtime extension JARs (mounted at deploy time via EXTRA_CLASSPATH_DIR)
RUN mkdir -p /extlib && chown water:water /extlib

COPY build/libs/Distribution-spring-app-*.jar app.jar
RUN chown water:water app.jar

USER water

EXPOSE 8080

ENV SERVER_PORT=8080 \
    SERVER_SERVLET_CONTEXT_PATH=/water \
    EXTRA_CLASSPATH_DIR=/extlib \
    EXTRA_SCAN_PACKAGES="" \
    WATER_TEST_MODE=false \
    WATER_KEYSTORE_TYPE=jks \
    WATER_KEYSTORE_PASSWORD=water. \
    WATER_KEYSTORE_ALIAS=server-cert \
    WATER_KEYSTORE_FILE=classpath:certs \
    WATER_PRIVATE_KEY_PASSWORD=water. \
    DB_DRIVER_CLASS_NAME=org.hsqldb.jdbcDriver \
    DB_HOST=jdbc:hsqldb:mem:waterdb \
    DB_USERNAME=sa \
    DB_PASSWORD="" \
    DB_POOL_SIZE=10

VOLUME ["/extlib"]

HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD bash -c 'exec 6<>/dev/tcp/localhost/${SERVER_PORT} && echo -e "GET ${SERVER_SERVLET_CONTEXT_PATH}/ HTTP/1.0\r\n\r\n" >&6 && cat <&6 | grep -qE "HTTP/1\.[01] [1-5][0-9]{2}"' || exit 1

ENTRYPOINT ["java", "-jar", "/app/app.jar"]