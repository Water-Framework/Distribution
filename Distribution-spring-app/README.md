# Distribution-spring-app

Applicazione Spring Boot minimale con Water Framework abilitato. Funge da punto di ingresso eseguibile per tutti i moduli Water in ambiente Spring/Spring Boot e supporta l'estensione dinamica a runtime tramite JAR esterni.

---

## Indice

1. [Panoramica architetturale](#1-panoramica-architetturale)
2. [Prerequisiti](#2-prerequisiti)
3. [Build del modulo](#3-build-del-modulo)
4. [Avvio come Java runner classico](#4-avvio-come-java-runner-classico)
5. [Creazione e avvio del container Docker](#5-creazione-e-avvio-del-container-docker)
6. [Riferimento variabili d'ambiente](#6-riferimento-variabili-dambiente)
7. [Sistema di estensione runtime (extlib)](#7-sistema-di-estensione-runtime-extlib)
8. [Configurazione database](#8-configurazione-database)
9. [Configurazione certificati e keystore](#9-configurazione-certificati-e-keystore)
10. [Health check](#10-health-check)
11. [Best practice per la produzione](#11-best-practice-per-la-produzione)

---

## 1. Panoramica architetturale

Il modulo è composto da due classi principali che lavorano in sequenza:

```
java -jar app.jar
       │
       ▼
  WaterLauncher.main()           ← entry point effettivo
       │
       ├─ 1. Legge water.extra.classpath.dir (application.properties / env)
       ├─ 2. Costruisce URLClassLoader con tutti i .jar in /extlib
       ├─ 3. Legge it.water.application.properties da ogni JAR esterno
       ├─ 4. Registra le proprietà esterne come WaterPropertiesPropertySource
       │
       ▼
  SpringApplication.run(WaterSpringApplication.class)
       │
       ├─ @EnableWaterFramework      → registra tutta l'infrastruttura Water
       ├─ @EnableJpaRepositories     → configura RepositoryFactory su it.water.*
       ├─ @EntityScan("it.water")    → scansione JPA entità su tutti i moduli
       └─ @ComponentScan("it.water") → scansione Spring bean su tutti i moduli
```

### Perché due classi?

`WaterLauncher` esegue il setup del classloader **prima** che Spring inizializzi il contesto applicativo. Questo permette ai JAR depositati in `/extlib` di essere visibili a Spring durante la fase di auto-configurazione, consentendo l'aggiunta di moduli Water a runtime senza ricompilare il JAR principale.

---

## 2. Prerequisiti

| Componente | Versione minima |
|---|---|
| Java JDK | 17 |
| Gradle | 7.x (gestito dal wrapper) |
| Node.js (per il generator) | 18.20.8 |
| Yeoman + yo water | vedi setup NVM |
| Docker (opzionale) | 20.x+ |

Verifica ambiente:

```bash
java -version          # deve mostrare openjdk 17+
gradle --version       # oppure ./gradlew --version
node --version         # v18.20.8
yo water:help          # deve rispondere con la lista dei comandi
```

---

## 3. Build del modulo

> **Regola**: usare sempre `yo water:build` — mai `./gradlew` direttamente.

### Build singolo modulo

```bash
# Attiva la versione Node corretta (se si usa NVM)
source /opt/homebrew/Cellar/nvm/0.39.0/nvm.sh && nvm use 18.20.8

yo water:build --projects Distribution-spring-app
```

### Build completa dalla radice (con tutte le dipendenze)

```bash
yo water:build --projects Core,Implementation,Repository,JpaRepository,Rest,Distribution-spring-app
```

L'artefatto prodotto si trova in:

```
Distribution-spring-app/build/libs/Distribution-spring-app-3.0.0.jar
```

---

## 4. Avvio come Java runner classico

### Avvio minimale (database in-memory, configurazione default)

```bash
java -jar Distribution-spring-app-3.0.0.jar
```

L'applicazione sarà raggiungibile su `http://localhost:8080/water`.

### Avvio con variabili d'ambiente personalizzate

```bash
java \
  -DSERVER_PORT=9090 \
  -DDB_HOST="jdbc:postgresql://localhost:5432/waterdb" \
  -DDB_DRIVER_CLASS_NAME="org.postgresql.Driver" \
  -DDB_USERNAME="water_user" \
  -DDB_PASSWORD="secret" \
  -DEXTRA_CLASSPATH_DIR="/opt/water/modules" \
  -jar Distribution-spring-app-3.0.0.jar
```

Le variabili possono essere passate indifferentemente come:
- **System property** (`-Dchiave=valore`)
- **Variabile d'ambiente** (`export CHIAVE=valore` prima del lancio)

### Avvio con moduli aggiuntivi in extlib

```bash
export EXTRA_CLASSPATH_DIR=/opt/water/modules
export EXTRA_SCAN_PACKAGES=it.water.mymodule,it.water.anothermodule

java -jar Distribution-spring-app-3.0.0.jar
```

I JAR presenti in `/opt/water/modules` vengono caricati automaticamente da `WaterLauncher` prima che Spring parta.

### Script di avvio consigliato (produzione)

```bash
#!/usr/bin/env bash
# start-water.sh

export SERVER_PORT=8080
export SERVER_SERVLET_CONTEXT_PATH=/water
export EXTRA_CLASSPATH_DIR=/opt/water/modules

# Database
export DB_DRIVER_CLASS_NAME=org.postgresql.Driver
export DB_HOST=jdbc:postgresql://db-host:5432/waterdb
export DB_USERNAME=water_user
export DB_PASSWORD=changeme

# Keystore
export WATER_KEYSTORE_FILE=file:/opt/water/certs/server.keystore
export WATER_KEYSTORE_PASSWORD=changeme
export WATER_PRIVATE_KEY_PASSWORD=changeme

# JVM tuning
exec java \
  -Xms512m -Xmx1024m \
  -XX:+UseG1GC \
  -Djava.security.egd=file:/dev/./urandom \
  -jar /opt/water/app.jar
```

---

## 5. Creazione e avvio del container Docker

### 5.1 Build dell'immagine

Prima di costruire l'immagine è necessario che il JAR sia già compilato:

```bash
# 1. Build del JAR
yo water:build --projects Distribution-spring-app

# 2. Build dell'immagine Docker (dalla directory del modulo)
cd Distribution/Distribution-spring-app

docker build \
  -t water-spring-app:3.0.0 \
  -t water-spring-app:latest \
  .
```

Il Dockerfile usa `eclipse-temurin:17-jre-jammy` come base e copia il JAR prodotto da Gradle:

```
build/libs/Distribution-spring-app-*.jar → /app/app.jar
```

L'immagine:
- Crea un utente non-root `water` (principio del minimo privilegio)
- Espone la porta `8080`
- Dichiara il volume `/extlib` per i moduli runtime

### 5.2 Avvio container — configurazione minimale

```bash
docker run -d \
  --name water-app \
  -p 8080:8080 \
  water-spring-app:latest
```

### 5.3 Avvio container — configurazione completa

```bash
docker run -d \
  --name water-app \
  -p 8080:8080 \
  -e SERVER_PORT=8080 \
  -e SERVER_SERVLET_CONTEXT_PATH=/water \
  -e DB_DRIVER_CLASS_NAME=org.postgresql.Driver \
  -e DB_HOST=jdbc:postgresql://postgres:5432/waterdb \
  -e DB_USERNAME=water_user \
  -e DB_PASSWORD=secret \
  -e DB_POOL_SIZE=20 \
  -e WATER_KEYSTORE_TYPE=jks \
  -e WATER_KEYSTORE_FILE=file:/certs/server.keystore \
  -e WATER_KEYSTORE_PASSWORD=changeme \
  -e WATER_KEYSTORE_ALIAS=server-cert \
  -e WATER_PRIVATE_KEY_PASSWORD=changeme \
  -e EXTRA_CLASSPATH_DIR=/extlib \
  -e EXTRA_SCAN_PACKAGES=it.water.mymodule \
  -v /host/path/modules:/extlib \
  -v /host/path/certs:/certs:ro \
  water-spring-app:latest
```

### 5.4 Docker Compose (stack completo con PostgreSQL)

```yaml
# docker-compose.yml
version: "3.9"

services:
  postgres:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: waterdb
      POSTGRES_USER: water_user
      POSTGRES_PASSWORD: secret
    volumes:
      - pg_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U water_user -d waterdb"]
      interval: 10s
      timeout: 5s
      retries: 5

  water-app:
    image: water-spring-app:latest
    depends_on:
      postgres:
        condition: service_healthy
    ports:
      - "8080:8080"
    environment:
      SERVER_PORT: 8080
      SERVER_SERVLET_CONTEXT_PATH: /water

      # Database
      DB_DRIVER_CLASS_NAME: org.postgresql.Driver
      DB_HOST: jdbc:postgresql://postgres:5432/waterdb
      DB_USERNAME: water_user
      DB_PASSWORD: secret
      DB_POOL_SIZE: 20

      # Keystore
      WATER_KEYSTORE_TYPE: jks
      WATER_KEYSTORE_FILE: file:/certs/server.keystore
      WATER_KEYSTORE_PASSWORD: changeme
      WATER_KEYSTORE_ALIAS: server-cert
      WATER_PRIVATE_KEY_PASSWORD: changeme

      # Moduli aggiuntivi
      EXTRA_CLASSPATH_DIR: /extlib
      EXTRA_SCAN_PACKAGES: ""

    volumes:
      - ./modules:/extlib          # JAR dei moduli Water aggiuntivi
      - ./certs:/certs:ro          # Certificati e keystore

volumes:
  pg_data:
```

```bash
# Avvio stack
docker compose up -d

# Log in tempo reale
docker compose logs -f water-app

# Stop
docker compose down
```

> **Nota**: il driver PostgreSQL (`org.postgresql:postgresql`) deve essere presente nel JAR principale o aggiunto come dipendenza nel `build.gradle` prima della build. Non può essere caricato tramite `/extlib` perché il datasource Spring viene inizializzato prima del classloader esteso.

---

## 6. Riferimento variabili d'ambiente

Tutte le variabili hanno un valore di default applicato sia in `application.properties` (via `${VAR:default}`) sia nel `Dockerfile`.

### Server

| Variabile | Default | Descrizione |
|---|---|---|
| `SERVER_PORT` | `8080` | Porta HTTP su cui ascolta Spring Boot |
| `SERVER_SERVLET_CONTEXT_PATH` | `/water` | Context path dell'applicazione. Tutti gli endpoint REST sono relativo a questo path |

### Classpath e scansione

| Variabile | Default | Descrizione |
|---|---|---|
| `EXTRA_CLASSPATH_DIR` | `/extlib` | Directory da cui `WaterLauncher` carica i JAR aggiuntivi prima dell'avvio di Spring |
| `EXTRA_SCAN_PACKAGES` | *(vuoto)* | Pacchetti aggiuntivi da passare a `@ComponentScan`. Separati da virgola. Necessari solo per moduli fuori da `it.water.*` |

### Modalità test

| Variabile | Default | Descrizione |
|---|---|---|
| `WATER_TEST_MODE` | `false` | Se `true`, disabilita la validazione JWT e alcune protezioni di sicurezza. **Mai `true` in produzione.** |

### Keystore e certificati

| Variabile | Default | Descrizione |
|---|---|---|
| `WATER_KEYSTORE_TYPE` | `jks` | Tipo di keystore: `jks` o `pkcs12` |
| `WATER_KEYSTORE_FILE` | `classpath:certs` | Percorso del keystore. Usa `classpath:` per risorse interne o `file:` per path assoluto esterno |
| `WATER_KEYSTORE_PASSWORD` | `water.` | Password del keystore |
| `WATER_KEYSTORE_ALIAS` | `server-cert` | Alias del certificato server nel keystore |
| `WATER_PRIVATE_KEY_PASSWORD` | `water.` | Password della chiave privata |

### Database

| Variabile | Default | Descrizione |
|---|---|---|
| `DB_DRIVER_CLASS_NAME` | `org.hsqldb.jdbcDriver` | Classe JDBC driver. Cambiare per PostgreSQL, MySQL, ecc. |
| `DB_HOST` | `jdbc:hsqldb:mem:waterdb` | URL di connessione JDBC |
| `DB_USERNAME` | `sa` | Username database |
| `DB_PASSWORD` | *(vuoto)* | Password database |
| `DB_POOL_SIZE` | `10` | Dimensione massima del pool HikariCP |

---

## 7. Sistema di estensione runtime (extlib)

`WaterLauncher` implementa un meccanismo di **plugin JAR** che consente di aggiungere moduli Water all'applicazione senza ricompilare il JAR principale.

### Come funziona

```
Avvio JVM
   │
   ▼
WaterLauncher legge EXTRA_CLASSPATH_DIR (default: /extlib)
   │
   ├─ Costruisce URLClassLoader con tutti i .jar trovati
   │   └─ Lo imposta come ContextClassLoader del thread principale
   │
   ├─ Per ogni JAR: cerca it.water.application.properties
   │   └─ Carica le properties e le registra come WaterPropertiesPropertySource
   │
   └─ Avvia SpringApplication con il ResourceLoader aggiornato
         └─ Spring vede tutte le classi nei JAR esterni
```

### Struttura di un modulo esterno compatibile

Un JAR da inserire in `/extlib` deve:

1. Contenere classi annotate con `@FrameworkComponent` (o `@Component` Spring)
2. Opzionalmente: includere `it.water.application.properties` nella root del JAR

```
mymodule.jar
├─ it/water/mymodule/
│   ├─ MyService.class          (@FrameworkComponent)
│   └─ MyEntity.class           (@Entity)
└─ it.water.application.properties   ← properties specifiche del modulo
```

### Esempio di it.water.application.properties

```properties
# it.water.application.properties (nella root del JAR esterno)
mymodule.feature.enabled=true
mymodule.timeout=5000
```

### Moduli precaricati (extraLib)

Il repository include già due moduli pronti all'uso in `extraLib/`:

| JAR | Funzione |
|---|---|
| `Authentication-service-spring-3.0.0.jar` | Servizio di autenticazione JWT |
| `User-service-spring-3.0.0.jar` | Gestione utenti, ruoli e permessi |

Per attivarli in un container:

```bash
docker run -d \
  -v $(pwd)/extraLib:/extlib \
  water-spring-app:latest
```

---

## 8. Configurazione database

### Default: HSQLDB in-memory (sviluppo / test)

Configurazione attiva per default, non richiede setup esterno. I dati vengono persi al riavvio (`create-drop`).

```properties
spring.datasource.driver-class-name=org.hsqldb.jdbcDriver
spring.datasource.url=jdbc:hsqldb:mem:waterdb
spring.datasource.username=sa
spring.datasource.password=
```

### PostgreSQL (produzione consigliata)

Aggiungere la dipendenza nel `build.gradle` prima della build:

```groovy
implementation 'org.postgresql:postgresql:42.7.3'
```

Poi configurare via variabili d'ambiente:

```bash
DB_DRIVER_CLASS_NAME=org.postgresql.Driver
DB_HOST=jdbc:postgresql://localhost:5432/waterdb
DB_USERNAME=water_user
DB_PASSWORD=secret
DB_POOL_SIZE=20
```

### MySQL / MariaDB

```groovy
implementation 'com.mysql:mysql-connector-j:8.3.0'
```

```bash
DB_DRIVER_CLASS_NAME=com.mysql.cj.jdbc.Driver
DB_HOST=jdbc:mysql://localhost:3306/waterdb?useSSL=false&serverTimezone=UTC
DB_USERNAME=water_user
DB_PASSWORD=secret
```

### Strategia DDL

La proprietà `spring.jpa.hibernate.ddl-auto=create-drop` è fissa nel `application.properties` e adatta a sviluppo. Per la produzione si raccomanda di sovrascriverla aggiungendo alla JVM:

```bash
-Dspring.jpa.hibernate.ddl-auto=validate
```

oppure gestendo le migrazioni con Flyway o Liquibase.

---

## 9. Configurazione certificati e keystore

### Certificati inclusi (solo sviluppo)

Il JAR include certificati autofirmati in `classpath:certs/`:

```
certs/
├─ server.keystore       ← JKS (alias: server-cert, password: water.)
├─ server.truststore     ← JKS
├─ serverkeystore.p12    ← PKCS12 alternativo
├─ diagserverCA.pem      ← CA certificate
└─ diagserverCA.key      ← CA private key
```

> **Attenzione**: i certificati embedded hanno password `water.` e sono validi solo per sviluppo locale. Non usarli in produzione.

### Keystore esterno (produzione)

Montare il keystore come volume e puntarvi tramite variabile d'ambiente:

```bash
# Keystore JKS esterno
docker run -d \
  -v /host/certs:/certs:ro \
  -e WATER_KEYSTORE_TYPE=jks \
  -e WATER_KEYSTORE_FILE=file:/certs/server.keystore \
  -e WATER_KEYSTORE_PASSWORD=strongpassword \
  -e WATER_KEYSTORE_ALIAS=server-cert \
  -e WATER_PRIVATE_KEY_PASSWORD=strongpassword \
  water-spring-app:latest
```

```bash
# Keystore PKCS12
docker run -d \
  -v /host/certs:/certs:ro \
  -e WATER_KEYSTORE_TYPE=pkcs12 \
  -e WATER_KEYSTORE_FILE=file:/certs/serverkeystore.p12 \
  -e WATER_KEYSTORE_PASSWORD=strongpassword \
  -e WATER_KEYSTORE_ALIAS=server-cert \
  -e WATER_PRIVATE_KEY_PASSWORD=strongpassword \
  water-spring-app:latest
```

### Generare un keystore JKS per produzione

```bash
keytool -genkeypair \
  -alias server-cert \
  -keyalg RSA \
  -keysize 2048 \
  -validity 365 \
  -keystore server.keystore \
  -storepass strongpassword \
  -keypass strongpassword \
  -dname "CN=myapp.example.com, OU=IT, O=MyOrg, L=City, ST=State, C=IT"
```

---

## 10. Health check

Il Dockerfile configura un health check TCP automatico:

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=60s --retries=3 \
    CMD bash -c 'exec 6<>/dev/tcp/localhost/${SERVER_PORT} && ...'
```

| Parametro | Valore | Significato |
|---|---|---|
| `--interval` | 30s | Frequenza dei check |
| `--timeout` | 5s | Timeout per singolo check |
| `--start-period` | 60s | Tempo di grazia all'avvio (Spring Boot impiega ~30s) |
| `--retries` | 3 | Tentativi falliti prima di dichiarare il container `unhealthy` |

Verifica stato health in Docker:

```bash
docker inspect --format='{{.State.Health.Status}}' water-app
# → starting | healthy | unhealthy
```

---

## 11. Best practice per la produzione

### Sicurezza

- Impostare `WATER_TEST_MODE=false` (è il default, verificare che non venga sovrascritto)
- Usare keystore esterni con certificati firmati da CA reale
- Cambiare tutte le password di default (`water.`, `sa`, ecc.)
- Il container gira già come utente non-root `water` — non eseguire mai come `root`

### Database

- Usare PostgreSQL o MySQL al posto di HSQLDB in-memory
- Configurare `spring.jpa.hibernate.ddl-auto=validate` o affidarsi a Flyway/Liquibase
- Dimensionare `DB_POOL_SIZE` in base al carico previsto (default 10)

### JVM

```bash
java \
  -Xms512m -Xmx1024m \
  -XX:+UseG1GC \
  -XX:MaxGCPauseMillis=200 \
  -Djava.security.egd=file:/dev/./urandom \
  -jar app.jar
```

### Logging

Spring Boot scrive su stdout per default. In ambiente container, reindirizzare i log verso un aggregatore (ELK, Loki, CloudWatch) via driver Docker:

```bash
docker run -d \
  --log-driver=json-file \
  --log-opt max-size=50m \
  --log-opt max-file=3 \
  water-spring-app:latest
```

### Secrets management

Non passare password come variabili d'ambiente in chiaro nei file `docker-compose.yml` versionati. Usare:
- **Docker Secrets** (`docker secret create`)
- **Kubernetes Secrets** (base64-encoded, con encryption at rest)
- **Vault** o sistemi di secrets management dedicati

```yaml
# docker-compose con secrets
services:
  water-app:
    image: water-spring-app:latest
    secrets:
      - db_password
      - keystore_password
    environment:
      DB_PASSWORD_FILE: /run/secrets/db_password

secrets:
  db_password:
    external: true
  keystore_password:
    external: true
```