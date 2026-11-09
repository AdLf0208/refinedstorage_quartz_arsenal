#!/usr/bin/env python3
"""Check the carried `content/` tree is internally consistent.

`cargo-horizon-mod check` validates the package envelope (manifest, paths,
capabilities) but not that an item definition names a model that exists, that a
model's texture exists, or that the recipe's ingredients are the ones we recorded
as unresolved. `tools/e2e.sh` cannot see any of that either: a slot's display
name is not exposed through `horizon-ctl`, and a broken item model draws the
missing-model cube without logging.

So this is the tree's real check: every reference resolves, the census numbers
are the jar's, and the two deliberately-unresolved recipe tags are still the two
documented ones (a new tag, or a "fix" that invents one, fails here).

    python3 tools/check_content.py [--content PATH]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
NS = "refinedstorage_quartz_arsenal"
ITEMS = ("wireless_crafting_grid", "creative_wireless_crafting_grid")
# The recorded gaps (notes.md): two ingredient tags the pack cannot resolve.
UNRESOLVED_TAGS = ("#c:ender_pearls", "#refinedstorage:crafting_grids")
# A vanilla item the declaration copies; a mod item could never be a template.
TEMPLATE_PREFIX = "minecraft:"


class Failures(list):
    def check(self, condition: bool, message: str) -> None:
        if not condition:
            self.append(message)


def load(path: Path, failures: Failures):
    data = path.read_bytes()
    failures.check(not data.startswith(b"\xef\xbb\xbf"), f"{path}: UTF-8 BOM")
    try:
        return json.loads(data)
    except json.JSONDecodeError as error:
        failures.append(f"{path}: {error}")
        return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--content", type=Path, default=ROOT / "content")
    args = parser.parse_args()
    content = args.content
    failures = Failures()

    assets = content / "assets" / NS
    data = content / "data" / NS
    models = {p.stem if p.parent.name == "item" else f"{p.parent.name}/{p.stem}": p
              for p in (assets / "models/item").rglob("*.json")}
    definitions = {p.stem: p for p in (assets / "items").glob("*.json")}
    textures = {f"{p.parent.name}/{p.stem}" for p in (assets / "textures/item").rglob("*.png")}
    declarations = {p.stem: p for p in (data / "horizon/item").glob("*.json")}
    recipes = {p.stem: p for p in (data / "recipe").glob("*.json")}
    locales = {p.stem: p for p in (assets / "lang").glob("*.json")}

    # The census: these counts are the jar's, pinned in notes.md and in
    # mixins/<ns>/runtime.rs.
    failures.check(len(definitions) == 2, f"{len(definitions)} item definitions, want 2")
    failures.check(len(declarations) == 2, f"{len(declarations)} item declarations, want 2")
    failures.check(len(models) == 4, f"{len(models)} item models, want 4")
    failures.check(len(textures) == 2, f"{len(textures)} item textures, want 2")
    failures.check(len(locales) == 18, f"{len(locales)} locales, want 18")
    failures.check(len(recipes) == 1, f"{len(recipes)} recipes, want 1")
    failures.check(set(definitions) == set(ITEMS), f"items {sorted(definitions)} != {ITEMS}")
    failures.check(set(declarations) == set(ITEMS), f"declarations {sorted(declarations)} != {ITEMS}")

    # Every item definition names a model that exists.
    for item, path in sorted(definitions.items()):
        value = load(path, failures) or {}
        model = (value.get("model") or {})
        failures.check(model.get("type") == "minecraft:model", f"{path}: model.type")
        target = model.get("model", "")
        failures.check(target.startswith(f"{NS}:item/"), f"{path}: model.model {target!r}")
        key = target.split(f"{NS}:item/", 1)[-1]
        failures.check(key in models, f"{path}: names model {key!r}, which is not carried")

    # Every model's texture exists, and its parent is a 26.3 one.
    for key, path in sorted(models.items()):
        value = load(path, failures) or {}
        failures.check(
            value.get("parent") in ("item/generated", "minecraft:item/generated"),
            f"{path}: parent {value.get('parent')!r}",
        )
        layer = (value.get("textures") or {}).get("layer0", "")
        failures.check(layer.startswith(f"{NS}:item/"), f"{path}: layer0 {layer!r}")
        failures.check(
            layer.split(f"{NS}:item/", 1)[-1] in textures,
            f"{path}: texture {layer!r} is not carried",
        )
        failures.check("overrides" not in value, f"{path}: 1.21.1 `overrides` in a 26.3 model")

    # The declaration: a vanilla template, one per slot, no unknown keys.
    allowed = {"template", "max_stack_size", "rarity", "components",
               "crafting_remainder", "place_block"}
    for item, path in sorted(declarations.items()):
        value = load(path, failures) or {}
        failures.check(set(value) <= allowed, f"{path}: unknown keys {set(value) - allowed}")
        failures.check(str(value.get("template", "")).startswith(TEMPLATE_PREFIX),
                       f"{path}: template {value.get('template')!r} is not vanilla")
        failures.check(value.get("max_stack_size") == 1, f"{path}: max_stack_size is not 1")

    # The recipe: a shaped pattern whose keys all resolve, and the two tags
    # that must stay unresolved until the parent supplies them.
    recipe = load(next(iter(recipes.values())), failures) or {}
    failures.check(recipe.get("type") == "minecraft:crafting_shaped", "recipe type")
    key = recipe.get("key") or {}
    for row in recipe.get("pattern") or []:
        for char in row:
            failures.check(char in key, f"recipe: pattern character {char!r} has no key")
    for name, ingredient in sorted(key.items()):
        if ingredient.startswith("#"):
            failures.check(ingredient in UNRESOLVED_TAGS,
                           f"recipe: unexpected tag {ingredient!r} for {name}")
        else:
            failures.check(ingredient.startswith("refinedstorage:"),
                           f"recipe: {ingredient!r} for {name} is not the parent's")
    failures.check(tuple(sorted(i for i in key.values() if i.startswith("#")))
                   == UNRESOLVED_TAGS, "recipe: the recorded unresolved tags changed")
    result = recipe.get("result") or {}
    failures.check(result.get("id") == f"{NS}:wireless_crafting_grid", f"recipe result {result}")
    failures.check(result.get("count") == 1, "recipe result count")

    # Lang: every locale carries the same key set, and both item names.
    key_sets = {}
    for code, path in sorted(locales.items()):
        value = load(path, failures) or {}
        key_sets[code] = frozenset(value)
        for item in ITEMS:
            failures.check(f"item.{NS}.{item}" in value, f"{path}: no item name for {item}")
    if key_sets:
        reference = key_sets["en_us"]
        for code, keys in key_sets.items():
            failures.check(keys == reference, f"lang/{code}.json: key set differs from en_us")

    # The manifest declares the carried mod.
    manifest = (content / "horizon-mod.toml").read_text()
    for line in ('api = "0.2"', 'side = "both"', f'id = "{NS}"', 'version = "1.0.8"'):
        failures.check(line in manifest, f"horizon-mod.toml: missing {line}")

    for message in failures:
        print(f"FAIL: {message}")
    print(f"{'FAIL' if failures else 'PASS'}: content census {len(definitions)} items, "
          f"{len(models)} models, {len(textures)} textures, {len(locales)} locales, "
          f"{len(recipes)} recipe; {len(failures)} failures")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
