# Refined Storage - Quartz Arsenal — Horizon port

A port of [Refined Storage - Quartz Arsenal](https://github.com/refinedmods/refinedstorage-quartz-arsenal) by Refined Mods for
Horizon. A content carry with a test-only Rust census module (no injection).

**Status:** the slice below is what works today; the second list is what is
missing. Nothing here claims parity with the original.

## What works

- The mod's two items: `wireless_crafting_grid` and `creative_wireless_crafting_grid`,
  with the inactive/active model pair, their two textures and 18 language files.
- Both items register and give (one per inventory slot); the two are separate ids, and
  an absent id is refused.
- The mod's shaped recipe is carried in the 26.3 recipe format.

## Not yet ported

- The grid itself is not ported: using the item does not open a crafting menu, no energy
  is stored or spent, and nothing binds to a Refined Storage network. The
  `network_bound_active` model condition needs the pending `item_model_property` hook at
  this pin.
- The recipe cannot match yet: its `refinedstorage:quartz_enriched_iron`,
  `refinedstorage:advanced_processor`, `#refinedstorage:crafting_grids` and
  `#c:ender_pearls` ingredients are not provided by this port.
- This is an add-on: it expects the Refined Storage parent mod in the same game.
- There is no `notes.md` in the port yet; the scope was settled by the campaign's slice
  record.

## Install

1. Take `refinedstorage_quartz_arsenal.hmod` from this repository (or build it below).
2. Put it in the game folder's `horizon-mods` folder — the game folder is the
   one holding `options.txt`.
3. Mods are off by default: enable this one in the game's mod list.

To try it without installing, start the game with
`--dev-mod refinedstorage_quartz_arsenal.hmod`.

## Build from source

This is a content-only mod: `content/horizon-mod.toml` plus `assets/` and
`data/`.

```sh
cd content && cargo horizon-mod build    # packs content/ into the .hmod and checks it
python3 tools/gen_content.py          # regenerates content/ from the pack jar
```

`cargo-horizon-mod` comes from the Horizon repository
(`cargo install --git https://github.com/horizon-rust/horizon cargo-horizon-mod`).
`tools/` holds the content generator and the in-game harness. The harness
expects a campaign checkout (`$CAMPAIGN_ROOT`) with the prepared 26.3 resources
(`$HORIZON_RES`, default `~/Desktop/horizon/.local/horizon-client/26.3`).

## Compatibility

- Horizon `1d63e0a` (see `compatibility.json` for the exact revision this
  artifact was built against).
- horizon-mixins `5a64af93`, schema 6.
- Minecraft: Java Edition 26.3.

## Credits

Refined Storage - Quartz Arsenal 1.0.8 by Refined Mods — <https://github.com/refinedmods/refinedstorage-quartz-arsenal>.
The original copyright and licence notices are kept in
[LICENSE](LICENSE); [LICENSE-NOTICE.md](LICENSE-NOTICE.md) records where each
was read from.

This is an unofficial port: Horizon is not affiliated with the original author.

## Licence

MIT — see [LICENSE](LICENSE).

## Contributing

The "Not yet ported" list is the gap list; an issue or a pull request that
closes one item is welcome. Please keep the original notices and say which
slice you are working on.
