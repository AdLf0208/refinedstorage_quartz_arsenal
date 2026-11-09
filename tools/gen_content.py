#!/usr/bin/env python3
"""Write `content/` from the pack's Quartz Arsenal jar, deterministically.

The jar is the source of truth (AGENTS.md: the jar wins over every catalogue).
Four things are copied byte for byte (the two textures, the two `active`/
`inactive` variant models and all locale files); the rest is the 1.21.1 → 26.3
upgrade the pin needs:

* `assets/<ns>/items/<name>.json` — 26.3's item definition, which names the
  model; 1.21.1 has no such file (the model was bound in code).
* `assets/<ns>/models/item/<name>.json` — 1.21.1's `overrides` block on the
  `refinedstorage:network_bound` predicate is **not** a 26.3 item model
  (`docs/mods.md`, `horizon-assets/src/item_model.rs`: 26.3 uses
  `minecraft:condition`/`select`/`range_dispatch`), and the property needs the
  pending `item_model_property` hook, so both base models draw the carried
  `inactive` variant.
* `data/<ns>/horizon/item/<name>.json` — the template declaration every Horizon
  content item needs (`docs/mods.md`).
* `data/<ns>/recipe/wireless_crafting_grid.json` — 1.21.1's
  `{"item": X}` / `{"tag": T}` ingredients become 26.3's `"X"` / `"#T"`.

Run from anywhere: `python3 tools/gen_content.py [--jar PATH] [--check]`.
`--check` writes nothing and returns 1 if `content/` is not exactly what the jar
and this script produce (so a hand edit cannot drift silently).
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CAMPAIGN = ROOT.parents[1]
DEFAULT_JAR = (
    CAMPAIGN / "ports/_shared/licence-cache/refinedstorage-quartz-arsenal-neoforge-1.0.8.jar"
)
JAR_SHA1 = "510c20c2b4531ceaa99f19ba6bc4671650df7a81"
NS = "refinedstorage_quartz_arsenal"
CONTENT = ROOT / "content"

# The jar's two items, in its lang's order.
ITEMS = ("wireless_crafting_grid", "creative_wireless_crafting_grid")
# 1.21.1 model -> the 26.3 layer0 it keeps. Both base models drew the same
# variant pair upstream; the switch is recorded, not carried (see module doc).
BASE_MODEL_LAYER = "refinedstorage_quartz_arsenal:item/wireless_crafting_grid/inactive"

MANIFEST = f"""\
# Carried from {DEFAULT_JAR.name} (MIT) for local use only.
# Provenance, hashes and the licence string: ports/_shared/carry-work/{NS}/SOURCE.md
id = "{NS}"
name = "Refined Storage - Quartz Arsenal"
version = "1.0.8"
api = "0.2"
side = "both"
capabilities = ["registries"]
"""

RECIPE = {
    "type": "minecraft:crafting_shaped",
    "category": "misc",
    "pattern": ["EPE", "EGE", "EAE"],
    "key": {
        "E": "refinedstorage:quartz_enriched_iron",
        "P": "#c:ender_pearls",
        "G": "#refinedstorage:crafting_grids",
        "A": "refinedstorage:advanced_processor",
    },
    "result": {"id": f"{NS}:wireless_crafting_grid", "count": 1},
    "show_notification": False,
}


def sha1(data: bytes) -> str:
    return hashlib.sha1(data).hexdigest()


def json_bytes(value) -> bytes:
    return (json.dumps(value, indent=2, sort_keys=True) + "\n").encode()


def build(jar: Path) -> dict[str, bytes]:
    """Every file `content/` must hold, keyed by path under `content/`."""
    if sha1(jar.read_bytes()) != JAR_SHA1:
        raise SystemExit(f"{jar}: not the pack's 1.0.8 jar (SHA-1 mismatch)")
    files: dict[str, bytes] = {}
    with zipfile.ZipFile(jar) as archive:
        names = archive.namelist()

        def read(name: str) -> bytes:
            if name not in names:
                raise SystemExit(f"the jar has no {name}")
            return archive.read(name)

        # 1. Byte-for-byte carried: textures, variant models, every locale.
        for name in names:
            if name.startswith(f"assets/{NS}/textures/") and name.endswith(".png"):
                files[name] = read(name)
            elif name.startswith(f"assets/{NS}/lang/") and name.endswith(".json"):
                data = read(name)
                if data.startswith(b"\xef\xbb\xbf"):
                    raise SystemExit(f"{name}: a UTF-8 BOM breaks the JSON reader")
                json.loads(data)  # must parse
                files[name] = data
            elif name in (
                f"assets/{NS}/models/item/wireless_crafting_grid/active.json",
                f"assets/{NS}/models/item/wireless_crafting_grid/inactive.json",
            ):
                data = read(name)
                model = json.loads(data)
                if model.get("parent") not in ("item/generated", "minecraft:item/generated"):
                    raise SystemExit(f"{name}: unexpected parent {model.get('parent')}")
                files[name] = data

        # 2. The two base models, rewritten to 26.3 (no `overrides`).
        for item in ITEMS:
            files[f"assets/{NS}/models/item/{item}.json"] = json_bytes(
                {
                    "parent": "minecraft:item/generated",
                    "textures": {"layer0": BASE_MODEL_LAYER},
                }
            )
            # 3. The 26.3 item definition: the file that names the model.
            files[f"assets/{NS}/items/{item}.json"] = json_bytes(
                {"model": {"type": "minecraft:model", "model": f"{NS}:item/{item}"}}
            )
            # 4. The content declaration: a plain item, one per slot.
            files[f"data/{NS}/horizon/item/{item}.json"] = json_bytes(
                {"template": "minecraft:paper", "max_stack_size": 1}
            )

        # 5. The one recipe, in 26.3's ingredient shape.
        files[f"data/{NS}/recipe/wireless_crafting_grid.json"] = json_bytes(RECIPE)

    files["horizon-mod.toml"] = MANIFEST.encode()
    return files


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--jar", type=Path, default=DEFAULT_JAR)
    parser.add_argument("--check", action="store_true",
                        help="verify content/ matches, write nothing")
    args = parser.parse_args()
    files = build(args.jar)
    if args.check:
        stale = []
        for name, data in files.items():
            path = CONTENT / name
            if not path.exists() or path.read_bytes() != data:
                stale.append(name)
        present = {str(p.relative_to(CONTENT)) for p in CONTENT.rglob("*") if p.is_file()}
        extra = sorted(present - set(files))
        for name in sorted(stale):
            print(f"stale: {name}")
        for name in extra:
            print(f"extra: {name}")
        print(f"{len(files)} files, {len(stale)} stale, {len(extra)} extra")
        return 0 if not stale and not extra else 1
    for name, data in sorted(files.items()):
        path = CONTENT / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    counts = {
        "lang": sum(1 for n in files if "/lang/" in n),
        "models": sum(1 for n in files if "/models/" in n),
        "textures": sum(1 for n in files if "/textures/" in n),
        "item_defs": sum(1 for n in files if "/items/" in n),
        "item_decls": sum(1 for n in files if "/horizon/item/" in n),
        "recipes": sum(1 for n in files if "/recipe/" in n),
    }
    print(json.dumps({"files": len(files), **counts}, sort_keys=True))
    return 0


if __name__ == "__main__":
    sys.exit(main())
