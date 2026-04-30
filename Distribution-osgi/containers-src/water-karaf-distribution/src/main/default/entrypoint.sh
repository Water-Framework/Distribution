#!/bin/sh
set -e

MODULES_PATH="${MODULES_PATH:-/opt/modules}"
FEATURE_FILE="/opt/karaf/deploy/dynamic-modules-feature.xml"

generate_feature_file() {
    echo "==> Generazione feature file da MODULES env"

    cat > "$FEATURE_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<features name="dynamic-modules-repo" xmlns="http://karaf.apache.org/xmlns/features/v1.6.0">
    <feature name="dynamic-modules" version="1.0.0">
EOF

    echo "$MODULES" | tr ',' '\n' | while IFS= read -r module; do
        module=$(echo "$module" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        [ -z "$module" ] && continue
        echo "        <bundle>$module</bundle>" >> "$FEATURE_FILE"
        echo "    [+] $module"
    done

    cat >> "$FEATURE_FILE" <<EOF
    </feature>
</features>
EOF

    echo "==> Feature file generato:"
    cat "$FEATURE_FILE"
}

if [ -n "$MODULES" ]; then
    generate_feature_file
else
    echo "==> MODULES non impostata, skip"
fi

exec "$@"