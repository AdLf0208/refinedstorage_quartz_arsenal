#!/usr/bin/env bash
# In-game check for the Quartz Arsenal data carry: the two wireless grids.
#
# The mod's whole contents are `refinedstorage_quartz_arsenal:wireless_crafting_grid`
# and `:creative_wireless_crafting_grid` (plus lang, models, textures and one
# recipe); there is no behaviour in slice 1, so the scenario is registration and
# item semantics, not machinery.
#
# Default run (creative, headless, shared unmodded 1d63e0a5 game, `--dev-mod
# content/`):
#   1. both ids register: `ctl give` lands each one in the inventory;
#   2. the carried `max_stack_size: 1` holds: `/give 2` of the grid is two
#      stacks of one, not one stack of two (the one semantic the jar's data
#      leaves to the item class, so it is pinned here);
#   3. a plausible but absent sibling id (`quartz_pickaxe`) is refused, while
#      `minecraft:stick` in the same world still gives — so a refusal is the
#      id, not a broken command.
#
# COUNTERFACTUAL=1 launches the same run WITHOUT `--dev-mod content/`: both the
# ids are refused there while a vanilla stick still gives, so the differential is
# live. NEGATIVE=1 (implies the counterfactual) asserts the deliberately false
# "the content is registered without --dev-mod", so the run MUST exit 1.
# SELFTEST=1 asserts the deliberately wrong stack shape in the default run, so
# the inventory read-back MUST exit 1. Every leg prints `EXIT:<status>` from the
# cleanup trap as its last line.
set -euo pipefail

CLONE=${CAMPAIGN_ROOT:-$(cd "$(dirname "$0")/../../.." && pwd)}
PORT=$CLONE/ports/refinedstorage_quartz_arsenal
PIN_BIN=$CLONE/ports/_shared/bin/horizon-1d63e0a5
CTL=${CTL:-$PIN_BIN/horizon-ctl}
GAME=${GAME:-$PIN_BIN/horizon-client}
RES=${RES:-${HORIZON_RES:-$HOME/Desktop/horizon/.local/horizon-client/26.3}}
SOCK=${SOCK:-/tmp/opencode/refinedstorage_quartz_arsenal-e2e.sock}
COUNTERFACTUAL=${COUNTERFACTUAL:-0}
NEGATIVE=${NEGATIVE:-0}
SELFTEST=${SELFTEST:-0}

GRID=refinedstorage_quartz_arsenal:wireless_crafting_grid
CREATIVE=refinedstorage_quartz_arsenal:creative_wireless_crafting_grid
ABSENT=refinedstorage_quartz_arsenal:quartz_pickaxe

if [ "$NEGATIVE" = 1 ]; then
    COUNTERFACTUAL=1
fi

[ -x "$CTL" ] || { echo "missing horizon-ctl: $CTL" >&2; exit 1; }
[ -x "$GAME" ] || { echo "missing horizon-client: $GAME" >&2; exit 1; }
[ -d "$RES/assets" ] || { echo "missing prepared resources: $RES" >&2; exit 1; }
[ -f "$PORT/content/horizon-mod.toml" ] || { echo "missing content mod: $PORT/content" >&2; exit 1; }

SCRATCH=$(mktemp -d /tmp/opencode/refinedstorage_quartz_arsenal-home.XXXXXX)
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
say() { echo "+ $*"; }
count_item() { ctl inventory | jq -r --arg i "$1" '.counts[$i] // 0'; }
# How many inventory slots (hotbar + main; `ctl inventory`'s shape) hold
# exactly `n` of an item.
slots_of_count() { ctl inventory | jq -r --arg i "$1" --argjson n "$2" \
    '[.hotbar[], .main[]] | map(select(. != null and .item == $i and .count == $n)) | length'; }

cleanup() {
    local status=$?
    echo "EXIT:$status"
    ctl quit >/dev/null 2>&1 || true
    sleep 1
    rm -rf "$SCRATCH" || true
}
trap cleanup EXIT

launch() { # world [extra ctl args...]
    local world=$1; shift
    rm -f "$SOCK"
    "$CTL" --socket "$SOCK" launch \
        --game "$GAME" --world "$world" --seed 20261109 --creative --headless --wait \
        --game-dir "$SCRATCH/game" --resources "$RES" "$@" >/dev/null
    ctl wait-ready 240 >/dev/null
    ctl wait 5 >/dev/null
}

# --------------------------------------------------- counterfactual / negative
if [ "$COUNTERFACTUAL" = 1 ]; then
    say "counterfactual: the same run WITHOUT --dev-mod content/"
    launch QuartzArsenalControl
    # The command works in this very world: a vanilla id gives.
    ctl give minecraft:stick 1 >/dev/null
    ctl wait 1 >/dev/null
    stick=$(count_item minecraft:stick)
    echo "vanilla minecraft:stick = $stick"
    [ "$stick" -ge 1 ] || fail "minecraft:stick did not land; the give path itself is broken"
    for id in "$GRID" "$CREATIVE"; do
        if ctl give "$id" 1 >/dev/null 2>&1; then
            fail "give $id succeeded without the content mod"
        fi
        ctl wait 1 >/dev/null
        echo "give $id without --dev-mod: refused, inventory count $(count_item "$id")"
        [ "$(count_item "$id")" = 0 ] || fail "$id exists without the content mod"
    done
    if [ "$NEGATIVE" = 1 ]; then
        echo "FAIL: NEGATIVE: the deliberately false assertion (the content is registered without --dev-mod) tripped, as it must; the --dev-mod differential is live (this exit 1 is the proof)" >&2
        exit 1
    fi
    echo "both ids are refused without --dev-mod, and a vanilla stick still lands"
    echo "PASS: counterfactual (no --dev-mod: $GRID and $CREATIVE are unknown; minecraft:stick still gives)"
    exit 0
fi

say "launch (headless, creative, content --dev-mod content/)"
launch QuartzArsenalE2E --dev-mod "$PORT/content"

# ------------------------------------------------------- 1. both ids register
for id in "$GRID" "$CREATIVE"; do
    ctl give "$id" 1 >/dev/null || fail "give $id was refused"
    ctl wait 1 >/dev/null
    got=$(count_item "$id")
    echo "give $id -> inventory count $got"
    [ "$got" = 1 ] || fail "$id did not register (count $got)"
done

# --------------------------------------------- 2. one grid per slot (stack 1)
ctl give "$GRID" 2 >/dev/null || fail "give $GRID 2 was refused"
ctl wait 1 >/dev/null
total=$(count_item "$GRID")
singles=$(slots_of_count "$GRID" 1)
doubles=$(slots_of_count "$GRID" 2)
echo "three grids: total=$total slots-of-one=$singles slots-of-two=$doubles"
if [ "$SELFTEST" = 1 ]; then
    echo "SELFTEST: reading the deliberately wrong stack shape (one slot of 2)"
    if [ "$doubles" = 1 ]; then
        fail "SELFTEST: the deliberately wrong 'one slot of 2' assertion passed; the inventory read-back is vacuous"
    fi
    echo "FAIL: SELFTEST: read singles=$singles doubles=$doubles where the deliberately wrong assertion wanted one slot of 2; the stack read-back is live (this exit 1 is the proof)" >&2
    exit 1
fi
[ "$total" = 3 ] || fail "three grids expected, inventory holds $total"
[ "$singles" = 3 ] || fail "$singles slots of one, expected 3 (max_stack_size is not 1)"
[ "$doubles" = 0 ] || fail "$doubles slots of two: the stack limit is not 1"

# ------------------------------------- 3. an absent sibling id is refused
if ctl give "$ABSENT" 1 >/dev/null 2>&1; then
    fail "give $ABSENT succeeded; an id the mod does not define must be refused"
fi
ctl wait 1 >/dev/null
echo "give $ABSENT -> refused, inventory count $(count_item "$ABSENT")"
[ "$(count_item "$ABSENT")" = 0 ] || fail "$ABSENT landed in the inventory"
ctl give minecraft:stick 1 >/dev/null || fail "minecraft:stick was refused; the command path is broken"
ctl wait 1 >/dev/null
[ "$(count_item minecraft:stick)" -ge 1 ] || fail "minecraft:stick did not land"
echo "minecraft:stick still gives in the same world"

echo "PASS: both wireless grids register and give (1 per slot, 3 grids in 3 slots), a plausible absent sibling id is refused while a vanilla stick still gives"
