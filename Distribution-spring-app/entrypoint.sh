#!/usr/bin/env bash
#
# Distribution-spring-app — container bootstrap
#
# Scarica a runtime i moduli Water indicati in WATER_MODULES dai repository Maven
# configurati (WATER_MAVEN_REPO_<n>_URL/USER/PASSWORD), li deposita in
# EXTRA_CLASSPATH_DIR (/extlib) e infine avvia il WaterLauncher.
#
# Le variabili d'ambiente del container sono ereditate automaticamente dal processo
# java (exec) -> forward automatico verso l'app Spring (application.properties usa ${VAR}).
#
set -euo pipefail

log() { echo "[bootstrap] $*"; }
err() { echo "[bootstrap][ERROR] $*" >&2; }

EXTRA_CLASSPATH_DIR="${EXTRA_CLASSPATH_DIR:-/extlib}"
WATER_MODULES="${WATER_MODULES:-}"
APP_JAR="${APP_JAR:-/app/app.jar}"

mkdir -p "$EXTRA_CLASSPATH_DIR"

# ---------------------------------------------------------------------------
# Avvio dell'applicazione (env già ereditate -> forward automatico)
# ---------------------------------------------------------------------------
# Keystore fallback (container-level, NOT baked into the jar):
# se WATER_KEYSTORE_FILE non è impostata, si usa il keystore demo generato nell'immagine
# (cartella default-certs). Il jar/sorgente resta fail-fast (#1): application.properties non
# definisce un default, è il container a fornirlo. MAI affidarsi a questo default in produzione.
DEFAULT_KEYSTORE_FILE="${DEFAULT_KEYSTORE_FILE:-/app/default-certs/server.keystore}"

apply_default_keystore() {
    if [ -z "${WATER_KEYSTORE_FILE:-}" ]; then
        if [ -f "$DEFAULT_KEYSTORE_FILE" ]; then
            export WATER_KEYSTORE_FILE="$DEFAULT_KEYSTORE_FILE"
            log "[keystore] WATER_KEYSTORE_FILE non impostata → uso i certificati demo del container (${WATER_KEYSTORE_FILE}). NON usare in produzione."
        else
            err "[keystore] WATER_KEYSTORE_FILE non impostata e nessun keystore demo in ${DEFAULT_KEYSTORE_FILE}."
        fi
    fi
}

start_app() {
    apply_default_keystore
    log "Avvio WaterLauncher: java ${JAVA_OPTS:-} -jar ${APP_JAR}"
    # shellcheck disable=SC2086
    exec java ${JAVA_OPTS:-} -jar "$APP_JAR" "$@"
}

# Nessun modulo da provisionare: si avvia direttamente.
# (extraLib baked / volume montato su /extlib continuano a funzionare)
if [ -z "${WATER_MODULES// /}" ]; then
    log "WATER_MODULES non impostata: nessun download. Uso eventuali jar già presenti in ${EXTRA_CLASSPATH_DIR}."
    start_app "$@"
fi

# ---------------------------------------------------------------------------
# Raccolta dei repository configurati: WATER_MAVEN_REPO_<n>_URL/USER/PASSWORD
# Iterazione finché l'URL indicizzato è valorizzato.
# ---------------------------------------------------------------------------
REPO_URLS=()
REPO_USERS=()
REPO_PASSWORDS=()

idx=1
while true; do
    url_var="WATER_MAVEN_REPO_${idx}_URL"
    url_val="${!url_var:-}"
    [ -z "$url_val" ] && break

    user_var="WATER_MAVEN_REPO_${idx}_USER"
    pass_var="WATER_MAVEN_REPO_${idx}_PASSWORD"

    # rimuove eventuale slash finale dalla base URL
    url_val="${url_val%/}"

    REPO_URLS+=("$url_val")
    REPO_USERS+=("${!user_var:-}")
    REPO_PASSWORDS+=("${!pass_var:-}")
    log "Repository #${idx}: ${url_val} (auth: $([ -n "${!user_var:-}" ] && echo sì || echo no))"
    idx=$((idx + 1))
done

if [ "${#REPO_URLS[@]}" -eq 0 ]; then
    err "WATER_MODULES è impostata ma nessun repository configurato (WATER_MAVEN_REPO_1_URL...)."
    exit 1
fi

# ---------------------------------------------------------------------------
# Download di un singolo modulo con failover sui repository (primo 200 vince)
# ---------------------------------------------------------------------------
download_module() {
    local coord="$1"

    # Validazione formato: groupId:artifactId:version (esattamente 3 segmenti)
    local segments
    IFS=':' read -r -a segments <<< "$coord"
    if [ "${#segments[@]}" -ne 3 ]; then
        err "Coordinata non valida '${coord}': atteso formato groupId:artifactId:version."
        exit 1
    fi

    local group_id="${segments[0]}"
    local artifact_id="${segments[1]}"
    local version="${segments[2]}"

    if [ -z "$group_id" ] || [ -z "$artifact_id" ] || [ -z "$version" ]; then
        err "Coordinata non valida '${coord}': segmenti vuoti."
        exit 1
    fi

    # Solo versioni release: SNAPSHOT non supportato (richiederebbe maven-metadata.xml)
    case "$version" in
        *-SNAPSHOT)
            err "Versione SNAPSHOT non supportata per '${coord}'. Usa una versione release."
            exit 1
            ;;
    esac

    local group_path="${group_id//.//}"
    local jar_name="${artifact_id}-${version}.jar"
    local rel_path="${group_path}/${artifact_id}/${version}/${jar_name}"
    local dest="${EXTRA_CLASSPATH_DIR}/${jar_name}"

    local i
    for i in "${!REPO_URLS[@]}"; do
        local base="${REPO_URLS[$i]}"
        local user="${REPO_USERS[$i]}"
        local pass="${REPO_PASSWORDS[$i]}"
        local full_url="${base}/${rel_path}"

        log "  → tentativo repo #$((i + 1)): ${full_url}"
        if [ -n "$user" ]; then
            if curl -fsSL -u "${user}:${pass}" -o "$dest" "$full_url"; then
                log "  ✓ '${coord}' scaricato da repo #$((i + 1)) (${base}) -> ${dest}"
                return 0
            fi
        else
            if curl -fsSL -o "$dest" "$full_url"; then
                log "  ✓ '${coord}' scaricato da repo #$((i + 1)) (${base}) -> ${dest}"
                return 0
            fi
        fi
    done

    err "Modulo '${coord}' non risolvibile in nessun repository configurato."
    exit 1
}

# ---------------------------------------------------------------------------
# Iterazione sui moduli richiesti (lista separata da virgola)
# ---------------------------------------------------------------------------
log "Provisioning moduli in ${EXTRA_CLASSPATH_DIR}..."
IFS=',' read -r -a modules <<< "$WATER_MODULES"
for raw in "${modules[@]}"; do
    # trim spazi attorno alla coordinata
    coord="$(echo "$raw" | xargs)"
    [ -z "$coord" ] && continue
    log "Modulo richiesto: ${coord}"
    download_module "$coord"
done

log "Provisioning completato: ${#modules[@]} modulo/i elaborati."
start_app "$@"
