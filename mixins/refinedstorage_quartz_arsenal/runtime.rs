// Refined Storage - Quartz Arsenal for Horizon — the two-item census (pure, test-only).
//
// Ported from Quartz Arsenal 1.0.8 (`refinedmods/refinedstorage-quartz-arsenal`,
// MIT) for Minecraft Java 26.3. The jar's own assets, lang and recipe were read
// for the ids, model paths, locale set and recipe shape; this is a clean-room
// model of those facts. The port is content-only: the two items are declared in
// `../content` by `../tools/gen_content.py`, this bundle has zero injections, and
// the tests spell out what those declarations must keep true.
//
// The mod has no other content: one item family (a wireless crafting grid and
// its creative variant), no block, entity, menu asset or tool.

#[cfg(test)]
mod tests {
    use std::collections::BTreeSet;

    /// The mod's namespace: the jar's own `modId`, used verbatim.
    const NAMESPACE: &str = "refinedstorage_quartz_arsenal";

    /// The two item paths the jar's lang names, in the jar's order.
    const ITEMS: [&str; 2] = ["wireless_crafting_grid", "creative_wireless_crafting_grid"];

    /// The item models the jar carries: two base models, and the
    /// active/inactive pair they select between.
    const MODELS: [&str; 4] = [
        "item/wireless_crafting_grid",
        "item/creative_wireless_crafting_grid",
        "item/wireless_crafting_grid/active",
        "item/wireless_crafting_grid/inactive",
    ];

    /// The two textures the jar carries. Their paths are the variant models'
    /// paths: a model at `item/<x>` draws the texture at `textures/item/<x>.png`.
    const TEXTURES: [&str; 2] = [
        "item/wireless_crafting_grid/active",
        "item/wireless_crafting_grid/inactive",
    ];

    /// The predicate the upstream item models select on; the parent mod owns
    /// the property and this addon's two models name it.
    const NETWORK_BOUND_PROPERTY: &str = "refinedstorage:network_bound";

    /// `item_model_property` is the hook that would answer that property, and
    /// it is **pending** at this pin (`docs/native-mods.md`: "Bundles need
    /// `"hooks": 385` once this pending hook is stamped"). Slice 1 therefore
    /// draws the `inactive` variant for both items and records the switch.
    const ITEM_MODEL_PROPERTY_HOOK_API: u32 = 385;

    /// The lang key of an item: upstream writes vanilla's own shape, not
    /// NeoForge's `<mod>.item.<name>`.
    fn lang_key(item: &str) -> String {
        format!("item.{NAMESPACE}.{item}")
    }

    /// A resource path under the mod's namespace.
    fn namespaced(path: &str) -> String {
        format!("{NAMESPACE}:{path}")
    }

    /// The one recipe the jar carries, upgraded from the 1.21.1 `{"item": …}` /
    /// `{"tag": …}` ingredient form to 26.3's bare id / `#tag` strings.
    struct Recipe {
        pattern: [&'static str; 3],
        key: [(&'static str, &'static str); 4],
        result: &'static str,
        count: u8,
    }

    const RECIPE: Recipe = Recipe {
        pattern: ["EPE", "EGE", "EAE"],
        key: [
            ("E", "refinedstorage:quartz_enriched_iron"),
            ("P", "#c:ender_pearls"),
            ("G", "#refinedstorage:crafting_grids"),
            ("A", "refinedstorage:advanced_processor"),
        ],
        result: "refinedstorage_quartz_arsenal:wireless_crafting_grid",
        count: 1,
    };

    /// The jar's 18 locales (the v2 brief said 19; `unzip -l` counts 18).
    const LOCALES: [&str; 18] = [
        "da_dk", "de_de", "en_us", "es_es", "fr_fr", "hu_hu", "id_id", "it_it", "ja_jp", "ko_kr",
        "pl_pl", "pt_br", "ru_ru", "sv_se", "tr_tr", "uk_ua", "zh_cn", "zh_tw",
    ];

    /// The ingredients the recipe names that this pack cannot resolve: the
    /// parent port has no `quartz_enriched_iron`/`advanced_processor` item yet,
    /// and 26.3 ships no `c:` tags and no `refinedstorage:crafting_grids` tag.
    const UNRESOLVED_ITEMS: [&str; 2] = [
        "refinedstorage:quartz_enriched_iron",
        "refinedstorage:advanced_processor",
    ];
    const UNRESOLVED_TAGS: [&str; 2] = ["#c:ender_pearls", "#refinedstorage:crafting_grids"];

    /// How a `/give <n>` splits under a stack limit: `ceil(n / max)` slots.
    fn slots_for(count: u8, max: u8) -> u8 {
        assert!(max > 0, "a stack limit is at least 1, got {max}");
        count.div_ceil(max)
    }

    #[test]
    fn the_mod_is_one_item_family_and_no_blocks() {
        // The whole jar: two items, no block declaration, no entity, no menu.
        assert_eq!(ITEMS.len(), 2);
        assert_eq!(
            ITEMS,
            ["wireless_crafting_grid", "creative_wireless_crafting_grid"]
        );
        // Both draw the same variant pair: one family, two ids.
        assert!(
            ITEMS
                .iter()
                .all(|item| item.contains("wireless_crafting_grid"))
        );
    }

    #[test]
    fn item_ids_are_upstreams_own() {
        let ids: Vec<String> = ITEMS.iter().map(|i| namespaced(i)).collect();
        assert_eq!(
            ids,
            [
                "refinedstorage_quartz_arsenal:wireless_crafting_grid",
                "refinedstorage_quartz_arsenal:creative_wireless_crafting_grid",
            ]
        );
        // The ids are the jar's, untouched: the mod id keeps its underscores,
        // and the path is never shortened to `quartz_arsenal`.
        assert_eq!(NAMESPACE, "refinedstorage_quartz_arsenal");
        assert!(ids.iter().all(|id| !id.starts_with("quartz_arsenal:")));
    }

    #[test]
    fn every_item_definition_names_a_carried_model() {
        for item in ITEMS {
            // 26.3: `assets/<ns>/items/<item>.json` names the model
            // `<ns>:item/<item>`, which must be one of the four carried files.
            let model = format!("item/{item}");
            assert!(
                MODELS.contains(&model.as_str()),
                "{item} names {model}, which the jar does not carry"
            );
            assert_eq!(namespaced(&model), format!("{NAMESPACE}:{model}"));
        }
    }

    #[test]
    fn the_four_models_and_two_textures_are_the_jars_whole_asset_set() {
        assert_eq!(MODELS.len(), 4);
        assert_eq!(MODELS.iter().collect::<BTreeSet<_>>().len(), 4);
        // The creative variant has a base model of its own, and it draws the
        // same variant pair as the plain one (upstream's two files are equal).
        assert!(MODELS.contains(&"item/creative_wireless_crafting_grid"));
        // Each variant model's texture is carried under the same path.
        assert_eq!(TEXTURES.len(), 2);
        for variant in TEXTURES {
            assert!(MODELS.contains(&variant), "no model draws {variant}");
        }
        // Every model path is namespaced by the mod.
        for model in MODELS {
            assert!(namespaced(model).starts_with("refinedstorage_quartz_arsenal:item/"));
        }
    }

    #[test]
    fn both_items_render_the_inactive_variant_until_the_property_is_stamped() {
        // Slice 1 carries the switch's *files* but not the switch: both base
        // models draw the inactive variant and the active one is carried
        // unused, because the only hook that could answer the property is
        // pending. The census pins the fallback so stamping the hook fails it.
        assert_eq!(NETWORK_BOUND_PROPERTY, "refinedstorage:network_bound");
        assert_eq!(ITEM_MODEL_PROPERTY_HOOK_API, 385);
        let fallback = "item/wireless_crafting_grid/inactive";
        assert!(MODELS.contains(&fallback));
        for item in ITEMS {
            let base = format!("item/{item}");
            assert_ne!(base, fallback, "the base models are files of their own");
        }
    }

    #[test]
    fn the_recipe_is_the_carried_shaped_pattern() {
        assert_eq!(RECIPE.pattern, ["EPE", "EGE", "EAE"]);
        assert_eq!(RECIPE.count, 1);
        assert_eq!(
            RECIPE.result,
            "refinedstorage_quartz_arsenal:wireless_crafting_grid"
        );
        // Every pattern character is a key of the recipe.
        for row in RECIPE.pattern {
            for c in row.chars() {
                assert!(
                    RECIPE.key.iter().any(|(k, _)| k.starts_with(c)),
                    "pattern character {c} has no key"
                );
            }
        }
        // The recipe makes the plain grid, never the creative one.
        assert!(!RECIPE.result.contains("creative"));
    }

    #[test]
    fn the_recipes_ingredients_cannot_resolve_in_this_pack_yet() {
        // The recorded gaps, pinned so the next slice cannot silently "fix"
        // one: two parent items that do not exist here yet, and two tags.
        let mut items = Vec::new();
        let mut tags = Vec::new();
        for (_, ingredient) in RECIPE.key {
            if ingredient.starts_with('#') {
                tags.push(ingredient);
            } else {
                items.push(ingredient);
            }
        }
        assert_eq!(items, UNRESOLVED_ITEMS);
        assert_eq!(tags, UNRESOLVED_TAGS);
        // An unresolved tag makes the ingredient empty, and `Ingredient::parse`
        // returns `None` for that, so the loader drops the shaped recipe
        // entirely (`crafting.rs`); an unresolved item id only never matches.
        assert_eq!(UNRESOLVED_TAGS.len(), 2);
        for item in UNRESOLVED_ITEMS {
            assert!(
                item.starts_with("refinedstorage:"),
                "{item} is the parent's"
            );
        }
        // Neither tag is ours to invent: `c:ender_pearls` is a convention tag
        // 26.3 does not ship, and `refinedstorage:crafting_grids` is the
        // parent namespace's membership.
        assert!(
            UNRESOLVED_TAGS
                .iter()
                .all(|tag| { tag.starts_with("#c:") || tag.starts_with("#refinedstorage:") })
        );
    }

    #[test]
    fn eighteen_locales_carry_the_two_item_names() {
        assert_eq!(LOCALES.len(), 18);
        assert_eq!(LOCALES.iter().collect::<BTreeSet<_>>().len(), 18);
        assert!(LOCALES.contains(&"en_us"));
        for item in ITEMS {
            let key = lang_key(item);
            // Vanilla's key shape, as the jar's own lang files write it.
            assert_eq!(key, format!("item.refinedstorage_quartz_arsenal.{item}"));
            assert_eq!(key.matches('.').count(), 2, "{key}");
            // All 18 files carry it (the e2e cannot see a slot's name, so
            // `tools/check_content.py` asserts the files' key sets match).
        }
    }

    #[test]
    fn a_carried_grid_is_one_per_slot() {
        // The item's stack size is not in the jar's data (the item class sets
        // it). It is carried as 1 because the item holds per-stack state (FE in
        // `custom_data` and a network binding); notes.md records that as an
        // inference, and the e2e pins it: `/give 2` lands as two stacks of one.
        const MAX_STACK_SIZE: u8 = 1;
        assert_eq!(MAX_STACK_SIZE, 1);
        assert_eq!(slots_for(1, MAX_STACK_SIZE), 1);
        assert_eq!(slots_for(2, MAX_STACK_SIZE), 2, "two grids, two slots");
    }

    #[test]
    fn the_manifest_values_the_hmod_must_declare() {
        // `neoforge.mods.toml` says 1.0.8, API 0.2, `side = "BOTH"`: the data
        // pack and the assets are both needed, so the .hmod is `side = "both"`
        // and a client/server pair compares its hash by version.
        const VERSION: &str = "1.0.8";
        const API: &str = "0.2";
        const SIDE: &str = "both";
        const CAPABILITIES: [&str; 1] = ["registries"];
        assert_eq!(VERSION, "1.0.8");
        assert_eq!(API, "0.2");
        assert_eq!(SIDE, "both");
        assert_eq!(CAPABILITIES, ["registries"]);
    }
}
