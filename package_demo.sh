#!/usr/bin/env bash
# ============================================================================
# package_demo.sh
# Creates a clean distributable ZIP of the Oracle 26ai Fleet Optimization Demo
# Usage:  bash package_demo.sh
# Output: oracle-26ai-fleet-demo.zip   (in parent directory)
# ============================================================================

set -e

DEMO_DIR="$(cd "$(dirname "$0")" && pwd)"
DEMO_NAME="oracle-26ai-fleet-demo"
OUTPUT_ZIP="${DEMO_DIR}/../${DEMO_NAME}.zip"

echo ""
echo "========================================================="
echo " Oracle 26ai Fleet Spatial VRP Demo – Package Builder"
echo "========================================================="
echo " Source : $DEMO_DIR"
echo " Output : $OUTPUT_ZIP"
echo ""

# ── Check dependencies ────────────────────────────────────────────────────
command -v zip  >/dev/null 2>&1 || { echo "Error: 'zip' not found. Install it first."; exit 1; }

# ── Remove old output ─────────────────────────────────────────────────────
[ -f "$OUTPUT_ZIP" ] && rm "$OUTPUT_ZIP" && echo "  Removed previous ZIP"

# ── Create ZIP, excluding sensitive and generated files ───────────────────
cd "$DEMO_DIR/.."

zip -r "$OUTPUT_ZIP" "$DEMO_NAME/" \
    --exclude "*/wallet/*.zip"           \
    --exclude "*/wallet/*.sso"           \
    --exclude "*/wallet/*.p12"           \
    --exclude "*/wallet/*.jks"           \
    --exclude "*/wallet/ojdbc.properties"\
    --exclude "*/wallet/sqlnet.ora"      \
    --exclude "*/wallet/tnsnames.ora"    \
    --exclude "*/wallet/cwallet.sso"     \
    --exclude "*/config/connection.properties" \
    --exclude "*/.git/*"                 \
    --exclude "*/.DS_Store"              \
    --exclude "*/Thumbs.db"              \
    --exclude "*/__pycache__/*"          \
    --exclude "*/package_demo.sh"        \
    -q

echo "  ZIP created: $OUTPUT_ZIP"
echo ""

# ── Show contents ─────────────────────────────────────────────────────────
echo "  Contents:"
zip -sf "$OUTPUT_ZIP" | grep -v "^Archive" | sort | sed 's/^/    /'

echo ""
SIZE=$(du -sh "$OUTPUT_ZIP" | cut -f1)
echo "  Total size: $SIZE"
echo ""
echo "========================================================="
echo " Distribution package ready!"
echo ""
echo " To unzip and get started:"
echo "   unzip oracle-26ai-fleet-demo.zip"
echo "   cd oracle-26ai-fleet-demo"
echo "   # Place your wallet zip in wallet/"
echo "   # Then open in VSCode:  code ."
echo "   # Or run via SQLcl:  sql /nolog"
echo "   # See README.md for full instructions"
echo "========================================================="
echo ""
