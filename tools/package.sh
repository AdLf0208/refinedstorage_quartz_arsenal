#!/usr/bin/env bash
# Package both artifacts:
#  - the source-only .hnmod (tools/package.py, deterministic bytes)
#  - the .hmod via the pin's own cargo-horizon-mod (build + check), from content/
# Run inside a build slot (it compiles the packaging tool):
#   ports/tools/build-slot.sh run --job rqa-pack --port ports/refinedstorage_quartz_arsenal \
#       --step package -- env CARGO_INCREMENTAL=0 tools/package.sh
set -euo pipefail

PORT=$(cd "$(dirname "$0")/.." && pwd)
ID=refinedstorage_quartz_arsenal
HORIZON=${HORIZON:-$(cd "$PORT/../_shared/pins/horizon-1d63e0a" && pwd)}
LOGS=$PORT/target/ladder
mkdir -p "$LOGS"
cd "$PORT"

# The content tree must be exactly what the jar carries before it is packaged.
python3 tools/check_content.py | tee "$LOGS/content-check.log"

python3 tools/package.py | tee "$LOGS/package-hnmod.log"
cp "target/$ID-1.0.8.hnmod" "$PORT/$ID.hnmod"

CARGO_TARGET_DIR=$PORT/target/carry-tools
export CARGO_TARGET_DIR
(cd content && cargo run --locked --offline --quiet \
    --manifest-path "$HORIZON/crates/cargo-horizon-mod/Cargo.toml" -- horizon-mod build) \
    2>&1 | tee "$LOGS/package-hmod.log"
cp "content/target/horizon-mod/$ID.hmod" "content/$ID.hmod"
(cd content && cargo run --locked --offline --quiet \
    --manifest-path "$HORIZON/crates/cargo-horizon-mod/Cargo.toml" -- horizon-mod check "$ID.hmod") \
    2>&1 | tee -a "$LOGS/package-hmod.log"

echo "== artifacts =="
for f in "content/$ID.hmod" "$ID.hnmod"; do
    [ -f "$f" ] || { echo "missing $f"; exit 1; }
    size=$(stat -c %s "$f")
    sha=$(sha256sum "$f" | cut -d' ' -f1)
    entries=$(python3 -c "import zipfile,sys; print(len(zipfile.ZipFile(sys.argv[1]).namelist()))" "$f")
    echo "$f size=$size sha256=$sha entries=$entries"
done
