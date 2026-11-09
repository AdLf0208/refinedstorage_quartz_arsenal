#!/usr/bin/env bash
# Prove the *packaged* content (content/refinedstorage_quartz_arsenal.hmod) loads
# on a real game: the shared, unmodded 1d63e0a5 game with `--dev-mod <the .hmod>`
# must register both items and give them. A second launch of a fresh world
# WITHOUT the package is the negative control: the same ids are refused there,
# so the check cannot pass vacuously. Every leg prints `EXIT:<status>`.
set -euo pipefail
export LC_ALL=C

CLONE=${CAMPAIGN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
ID=refinedstorage_quartz_arsenal
PIN_BIN=$CLONE/ports/_shared/bin/horizon-1d63e0a5
CTL=${CTL:-$PIN_BIN/horizon-ctl}
GAME=${GAME:-$PIN_BIN/horizon-client}
HMOD=${HMOD:-$CLONE/ports/$ID/content/$ID.hmod}
RES=${RES:-${HORIZON_RES:-$HOME/Desktop/horizon/.local/horizon-client/26.3}}
SOCK=${SOCK:-/tmp/opencode/$ID-hmod-load.sock}

GRID=$ID:wireless_crafting_grid
CREATIVE=$ID:creative_wireless_crafting_grid

[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL" >&2; exit 1; }
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -f "$HMOD" ] || { echo "missing package: $HMOD" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }

SCRATCH=$(mktemp -d /tmp/opencode/$ID-hmod-home.XXXXXX)
export HORIZON_HOME=$SCRATCH/game
export HORIZON_LAUNCHER_HOME=$SCRATCH/launcher
export XDG_DATA_HOME=$SCRATCH/data
export XDG_CONFIG_HOME=$SCRATCH/config
export HORIZON_NO_AUDIO=1
mkdir -p "$(dirname "$SOCK")"
rm -f "$SOCK"
cd "$SCRATCH"

ctl() { "$CTL" --socket "$SOCK" "$@"; }
fail() { echo "FAIL: $*" >&2; exit 1; }

cleanup() {
    local status=$?
    echo "EXIT:$status"
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    rm -rf "$SCRATCH" 2>/dev/null || true
}
trap cleanup EXIT

launch() { # world [extra args...]
    local world=$1; shift
    rm -f "$SOCK"
    "$CTL" --socket "$SOCK" launch \
        --game "$GAME" --world "$world" --seed 20261109 --creative --headless --wait \
        --game-dir "$SCRATCH/game" --resources "$RES" "$@" >/dev/null
    ctl wait-ready 240 >/dev/null
    ctl wait 5 >/dev/null
}

echo "== launch WITH the package (--dev-mod $HMOD) =="
launch QuartzArsenalHmod --dev-mod "$HMOD"
for id in "$GRID" "$CREATIVE"; do
    ctl give "$id" 1 >/dev/null || fail "the package did not register $id"
    ctl wait 1 >/dev/null
    got=$(ctl inventory | jq -r --arg i "$id" '.counts[$i] // 0')
    echo "packaged give $id -> inventory count $got"
    [ "$got" = 1 ] || fail "the packaged $id did not land (count $got)"
done
ctl quit >/dev/null 2>&1 || true
sleep 2

echo "== control launch WITHOUT the package =="
launch QuartzArsenalNoHmod
ctl give minecraft:stick 1 >/dev/null || fail "minecraft:stick refused in the control world"
ctl wait 1 >/dev/null
ctl inventory | jq -e '.counts["minecraft:stick"] >= 1' >/dev/null \
    || fail "the control world's give path is broken"
for id in "$GRID" "$CREATIVE"; do
    if ctl give "$id" 1 >/dev/null 2>&1; then
        fail "without the package $id still gives"
    fi
    ctl wait 1 >/dev/null
    got=$(ctl inventory | jq -r --arg i "$id" '.counts[$i] // 0')
    echo "control give $id -> refused, inventory count $got"
    [ "$got" = 0 ] || fail "without the package $id is still in the inventory"
done
echo "control: both ids are unknown without the package, a vanilla stick still gives"
echo "PASS: the .hmod registers the wireless crafting grid and its creative variant and both give; without it the same ids are refused"
