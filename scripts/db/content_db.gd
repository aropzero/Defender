extends Node
## ---------------------------------------------------------------------------
## Content database: everything that exists in the game. Static data only.
## The *logic* that consumes this lives in synergy_engine.gd / game.gd.
## ---------------------------------------------------------------------------

# ---- Player attributes (spendable stat points) -----------------------------
const ATTR := {
	"might":     {"name": "Might",     "desc": "+8% tower damage per point."},
	"swiftness": {"name": "Swiftness", "desc": "+7% attack speed per point."},
	"wits":      {"name": "Wits",      "desc": "+1.5% crit chance, +4% crit damage per point."},
	"bastion":   {"name": "Bastion",   "desc": "+10 castle max HP & +1 HP/s regen per point."},
	"mastery":   {"name": "Mastery",   "desc": "+4% cooldown reduction & +6% spell damage per point."},
}

# XP required to go from level L to L+1.
func xp_for_level(level: int) -> int:
	return 60 + level * 40 + level * level * 6

# ---- Towers ---------------------------------------------------------------
# base fields: damage, range (px), rate (shots/sec), crit (base chance)
# behavior.kind: single | chain | splash | lane | bomb
# status: dict of status id -> potency per hit
var towers := {
	"ember": {
		"name": "Ember Turret", "element": "fire", "tags": ["fire"],
		"cost": 50, "shape": "turret", "color": Elements.color_of("fire"),
		"base": {"damage": 14, "range": 190, "rate": 0.9, "crit": 0.05},
		"behavior": {"kind": "single"},
		"status": {"burn": 1.0},
		"desc": "Hurls cinders that scorch enemies, leaving them burning.",
	},
	"cryo": {
		"name": "Cryo Cannon", "element": "frost", "tags": ["frost"],
		"cost": 60, "shape": "turret", "color": Elements.color_of("frost"),
		"base": {"damage": 10, "range": 200, "rate": 1.0, "crit": 0.05},
		"behavior": {"kind": "single"},
		"status": {"slow": 1.0},
		"desc": "Shards of rime that chill flesh, slowing movement.",
	},
	"storm": {
		"name": "Storm Spire", "element": "lightning", "tags": ["lightning"],
		"cost": 85, "shape": "spire", "color": Elements.color_of("lightning"),
		"base": {"damage": 12, "range": 220, "rate": 0.8, "crit": 0.08},
		"behavior": {"kind": "chain", "chain": 2},
		"status": {"shock": 1.0},
		"desc": "Arcs of fury that leap between nearby enemies.",
	},
	"bone": {
		"name": "Bone Ward", "element": "shadow", "tags": ["shadow"],
		"cost": 120, "shape": "ward", "color": Elements.color_of("shadow"),
		"base": {"damage": 20, "range": 200, "rate": 0.55, "crit": 0.05},
		"behavior": {"kind": "lane", "pierce": 4},
		"status": {"bleed": 0.6},
		"desc": "A spear of grave-bone that impales the whole lane. Kills feed the castle.",
		"on_kill": "heal_castle_small",
	},
	"sanctum": {
		"name": "Sanctum Bolt", "element": "holy", "tags": ["holy"],
		"cost": 110, "shape": "spire", "color": Elements.color_of("holy"),
		"base": {"damage": 16, "range": 250, "rate": 1.1, "crit": 0.05},
		"behavior": {"kind": "single"},
		"status": {"mark": 1.0},
		"desc": "Bolt of righteousness. Deals +50% vs Shadow/Void. Kills restore castle health.",
		"vs_tags": ["shadow", "void"],
		"on_kill": "heal_castle_small",
	},
	"thorn": {
		"name": "Thorn Burrow", "element": "nature", "tags": ["nature"],
		"cost": 70, "shape": "ward", "color": Elements.color_of("nature"),
		"base": {"damage": 8, "range": 170, "rate": 0.7, "crit": 0.05},
		"behavior": {"kind": "single"},
		"status": {"root": 0.2, "slow": 0.5},
		"desc": "Verdant snares that entangle and slow. Some shots root.",
	},
	"monolith": {
		"name": "Mana Monolith", "element": "arcane", "tags": ["arcane"],
		"cost": 150, "shape": "monolith", "color": Elements.color_of("arcane"),
		"base": {"damage": 28, "range": 160, "rate": 0.35, "crit": 0.1},
		"behavior": {"kind": "bomb"},
		"desc": "A dense source of raw mana. Adjacent towers gain +18% attack speed.",
		"aura": {"atk_rate_mult": 0.18},
	},
	"plague": {
		"name": "Plague Vat", "element": "poison", "tags": ["poison"],
		"cost": 90, "shape": "vat", "color": Elements.color_of("poison"),
		"base": {"damage": 10, "range": 180, "rate": 0.8, "crit": 0.05},
		"behavior": {"kind": "splash", "radius": 46},
		"status": {"poison": 1.0},
		"desc": "Lobs disease that coats a small area in creeping venom.",
	},
	"hemo": {
		"name": "Hemomancy Font", "element": "blood", "tags": ["blood"],
		"cost": 130, "shape": "font", "color": Elements.color_of("blood"),
		"base": {"damage": 34, "range": 230, "rate": 0.45, "crit": 0.08},
		"behavior": {"kind": "single"},
		"status": {"bleed": 1.2},
		"desc": "Bloody magic. Each shot costs 1 castle HP but hits like a curse. Lifesteals a portion.",
		"hp_cost": 1.0, "lifesteal": 0.08,
	},
	"chrono": {
		"name": "Chrono Loop", "element": "chrono", "tags": ["chrono"],
		"cost": 140, "shape": "loop", "color": Elements.color_of("chrono"),
		"base": {"damage": 12, "range": 210, "rate": 1.0, "crit": 0.05},
		"behavior": {"kind": "single"},
		"status": {"slow": 1.4, "rewind": 0.15},
		"desc": "Bends time; slows heavily and occasionally rewinds an enemy a short step.",
	},
	"ballista": {
		"name": "Ballista Line", "element": "steel", "tags": ["steel"],
		"cost": 160, "shape": "ballista", "color": Elements.color_of("steel"),
		"base": {"damage": 58, "range": 260, "rate": 0.30, "crit": 0.08},
		"behavior": {"kind": "single"},
		"desc": "A monstrous crossbow for piercing armor. Ignores mitigation partly.",
		"pierce_armor": 0.5,
	},
	"nullgate": {
		"name": "Null Gate", "element": "void", "tags": ["void"],
		"cost": 150, "shape": "gate", "color": Elements.color_of("void"),
		"base": {"damage": 22, "range": 240, "rate": 0.6, "crit": 0.05},
		"behavior": {"kind": "single"},
		"status": {"shred": 1.0},
		"desc": "Rends space; shots shred enemy armor and hit from an impossible angle.",
	},
}

# ---- Skills ----------------------------------------------------------------
# type: active | passive. active.cast is a function name on game.gd.
var skills := {
	"meteor": {
		"name": "Meteor Swarm", "element": "fire", "tags": ["fire"],
		"type": "active", "cooldown": 16.0, "buy": 80,
		"cast": "cast_meteor",
		"desc": "Rain of meteors over a zone. Power scales with your Fire towers.",
	},
	"blizzard": {
		"name": "Blizzard", "element": "frost", "tags": ["frost"],
		"type": "active", "cooldown": 20.0, "buy": 80,
		"cast": "cast_blizzard",
		"desc": "Freezes and slows a large area for several seconds.",
	},
	"chaincall": {
		"name": "Chain Call", "element": "lightning", "tags": ["lightning"],
		"type": "active", "cooldown": 13.0, "buy": 75,
		"cast": "cast_chaincall",
		"desc": "A lightning bolt that arcs across up to 6 enemies.",
	},
	"soulreap": {
		"name": "Soul Reap", "element": "shadow", "tags": ["shadow"],
		"type": "active", "cooldown": 18.0, "buy": 90,
		"cast": "cast_soulreap",
		"desc": "Executes weakened enemies across all lanes and heals you.",
	},
	"consecrate": {
		"name": "Consecrate", "element": "holy", "tags": ["holy"],
		"type": "active", "cooldown": 22.0, "buy": 85,
		"cast": "cast_consecrate",
		"desc": "A holy nova that heals the castle and scorches Shadow/Void.",
	},
	"gale": {
		"name": "Gale of Thorns", "element": "nature", "tags": ["nature"],
		"type": "active", "cooldown": 15.0, "buy": 70,
		"cast": "cast_gale",
		"desc": "A gust that pushes every enemy back and momentarily roots them.",
	},
	"arcoverload": {
		"name": "Arc Overload", "element": "arcane", "tags": ["arcane"],
		"type": "active", "cooldown": 18.0, "buy": 95,
		"cast": "cast_arcoverload",
		"desc": "Overcharges all towers: +100% attack speed for 6 seconds.",
	},
	"miasma": {
		"name": "Miasma", "element": "poison", "tags": ["poison"],
		"type": "active", "cooldown": 16.0, "buy": 80,
		"cast": "cast_miasma",
		"desc": "Conjures a sickly cloud that poisons everything within for a while.",
	},
	"bloodpact": {
		"name": "Blood Pact", "element": "blood", "tags": ["blood"],
		"type": "active", "cooldown": 24.0, "buy": 100,
		"cast": "cast_bloodpact",
		"desc": "Sacrifice 5% castle HP for a massive blast; gain temporary lifesteal.",
	},
	"timelock": {
		"name": "Timelock", "element": "chrono", "tags": ["chrono"],
		"type": "active", "cooldown": 28.0, "buy": 110,
		"cast": "cast_timelock",
		"desc": "Freezes every enemy on the field for 3 seconds.",
	},
	"ironresolve": {
		"name": "Iron Resolve", "element": "steel", "tags": ["steel"],
		"type": "passive", "buy": 90,
		"passive": "ironresolve",
		"desc": "The castle's armor is increased by 20% (stacking).",
	},
	"voidecho": {
		"name": "Void Echo", "element": "void", "tags": ["void"],
		"type": "passive", "buy": 90,
		"passive": "voidecho",
		"desc": "When you kill an enemy, its debuffs spread to a nearby enemy.",
	},
}

# ---- Resonance (global aura from essence pool) ------------------------------
# req: dict element -> minimum count of that element in the pool.
# give: mod -> value (mul_* are multiplicative; others additive).
var resonances := [
	{ "id": "superheating", "req": {"fire": 2}, "give": {"mul_dmg": 0.10, "burn_str": 0.35}, "name": "Superheating", "desc": "2 Fire: +10% damage, +35% burn potency." },
	{ "id": "deepfreeze", "req": {"frost": 2}, "give": {"slow_str": 0.30}, "name": "Deep Freeze", "desc": "2 Frost: +30% slow strength." },
	{ "id": "arc_circuit", "req": {"lightning": 2}, "give": {"chain_bonus": 1, "crit_chance": 0.04}, "name": "Arc Circuit", "desc": "2 Lightning: +1 chain jump, +4% crit." },
	{ "id": "grim_harvest", "req": {"shadow": 2}, "give": {"lifesteal": 0.04}, "name": "Grim Harvest", "desc": "2 Shadow: +4% lifesteal on all damage." },
	{ "id": "guarded_light", "req": {"holy": 2}, "give": {"castle_regen": 2.0, "holy_vs": 0.25}, "name": "Guarded Light", "desc": "2 Holy: castle regenerates +2 HP/s; Holy dmg +25%." },
	{ "id": "verdant_growth", "req": {"nature": 2}, "give": {"root_str": 0.30, "dot_mult": 0.10}, "name": "Verdant Growth", "desc": "2 Nature: +30% root chance, +10% damage-over-time." },
	{ "id": "overchannel", "req": {"arcane": 2}, "give": {"atk_rate": 0.15, "cdr": 0.10}, "name": "Overchannel", "desc": "2 Arcane: +15% attack speed, +10% CDR." },
	{ "id": "contagion", "req": {"poison": 2}, "give": {"poison_str": 0.50}, "name": "Contagion", "desc": "2 Poison: +50% poison potency." },
	{ "id": "hogwash", "req": {"blood": 2}, "give": {"lifesteal": 0.06, "blood_dmg": 0.15}, "name": "Bloodletting", "desc": "2 Blood: +6% lifesteal, +15% Blood damage." },
	{ "id": "paradox", "req": {"chrono": 2}, "give": {"cdr": 0.15, "freeze_periodic": 12.0}, "name": "Paradox", "desc": "2 Chrono: +15% CDR; every 12s freeze all for 0.8s." },
	{ "id": "fortress", "req": {"steel": 2}, "give": {"castle_armor": 0.25}, "name": "Fortress", "desc": "2 Steel: +25% castle armor." },
	{ "id": "nothingness", "req": {"void": 2}, "give": {"shred_str": 0.40}, "name": "Nothingness", "desc": "2 Void: +40% armor shred." },

	{ "id": "saltstorm", "req": {"fire": 1, "frost": 1}, "give": {"burn_slows": 1.0, "slow_burns": 0.5}, "name": "Saltstorm", "desc": "Fire+Frost: burning enemies are slowed; slowed enemies burn." },
	{ "id": "conduction", "req": {"fire": 1, "lightning": 1}, "give": {"lightning_ignites": 1.0}, "name": "Conduction", "desc": "Fire+Lightning: lightning strikes ignite enemies." },
	{ "id": "static_lock", "req": {"frost": 1, "lightning": 1}, "give": {"chilled_chaincrit": 0.30}, "name": "Static Lock", "desc": "Frost+Lightning: chilled enemies +30% chain crit." },
	{ "id": "ashfall", "req": {"fire": 1, "shadow": 1}, "give": {"burn_lifesteal": 0.03}, "name": "Ashfall", "desc": "Fire+Shadow: burns lifesteal 3%." },
	{ "id": "polar_ward", "req": {"frost": 1, "holy": 1}, "give": {"slow_vs_shadow": 0.40}, "name": "Polar Ward", "desc": "Frost+Holy: Shadow/Void enemies are slowed +40%." },
	{ "id": "thorn_volley", "req": {"nature": 1, "lightning": 1}, "give": {"root_shocks": 1.0}, "name": "Thorn Volley", "desc": "Nature+Lightning: rooted enemies get shocked." },
	{ "id": "hexflame", "req": {"arcane": 1, "fire": 1}, "give": {"mana_burn": 0.35}, "name": "Hexflame", "desc": "Arcane+Fire: +35% burn strength (arcane feeds it)." },
	{ "id": "blightblood", "req": {"poison": 1, "blood": 1}, "give": {"poison_lifesteal": 0.05}, "name": "Blightblood", "desc": "Poison+Blood: poison lifesteals 5%." },
	{ "id": "chronoplag", "req": {"chrono": 1, "poison": 1}, "give": {"dot_tickboost": 0.25}, "name": "Chronoplag", "desc": "Chrono+Poison: DoTs tick 25% faster." },
	{ "id": "siege_engine", "req": {"steel": 1, "arcane": 1}, "give": {"multi_hit": 0.35}, "name": "Siege Engine", "desc": "Steel+Arcane: +35% chance for shots to hit twice." },
	{ "id": "riftburn", "req": {"void": 1, "fire": 1}, "give": {"shred_ignites": 1.0}, "name": "Riftburn", "desc": "Void+Fire: shredded enemies ignite." },
	{ "id": "eclipse", "req": {"void": 1, "shadow": 1}, "give": {"shadow_void_mult": 0.30}, "name": "Eclipse", "desc": "Void+Shadow: Shadow dmg +30% vs Void, and vice versa." },
	{ "id": "grail", "req": {"holy": 1, "blood": 1}, "give": {"heal_on_kill": 1.5}, "name": "Grail", "desc": "Holy+Blood: every kill heals castle +1.5 HP." },
	{ "id": "timber", "req": {"nature": 1, "steel": 1}, "give": {"root_armor": 0.30}, "name": "Ironwood", "desc": "Nature+Steel: rooted enemies take +30% damage." },
	{ "id": "dreadwinter", "req": {"frost": 1, "shadow": 1}, "give": {"slow_bleed": 1.0}, "name": "Dreadwinter", "desc": "Frost+Shadow: slowed enemies also bleed." },

	# Triple meta-resonances (the deep end)
	{ "id": "infernal_void", "req": {"fire": 1, "void": 1, "shadow": 1}, "give": {"infernal_void": 1.0}, "name": "Infernal Void", "desc": "Fire+Void+Shadow: shredding also ignites and reaps." },
	{ "id": "chrono_storm", "req": {"chrono": 1, "lightning": 1, "arcane": 1}, "give": {"chrono_chain": 1.0}, "name": "Chrono Storm", "desc": "Chrono+Lightning+Arcane: chain jumps also freeze briefly." },
	{ "id": "verdant_grail", "req": {"nature": 1, "holy": 1, "blood": 1}, "give": {"heal_aura": 1.0}, "name": "Verdant Grail", "desc": "Nature+Holy+Blood: towers slowly heal the castle while firing." },
	{ "id": "steel_plague", "req": {"steel": 1, "poison": 1, "frost": 1}, "give": {"armored_toxin": 1.0}, "name": "Steel Plague", "desc": "Steel+Poison+Frost: poison sticks through armor (ignores mitigation)." },
]

# ---- Building fusions (adjacency) -------------------------------------------
# pair: two tower ids placed in adjacent grid slots.
# give: mods granted to BOTH towers.
var adjacencies := [
	{ "id": "quench", "pair": ["ember", "cryo"], "give": {"mul_dmg": 0.12}, "behavior": "vaporize",
	  "desc": "Ember + Cryo: freezing a burning enemy vaporizes it for a burst. Both +12% dmg." },
	{ "id": "staticlock", "pair": ["cryo", "storm"], "give": {"chilled_chaincrit": 0.30}, "behavior": "",
	  "desc": "Cryo + Storm: chilled enemies have +30% chain crit." },
	{ "id": "grimblight", "pair": ["bone", "plague"], "give": {"shadow_vs_poisoned": 0.25}, "behavior": "",
	  "desc": "Bone + Plague: poisoned enemies take +25% Shadow damage." },
	{ "id": "exorcism", "pair": ["sanctum", "nullgate"], "give": {"holy_vs": 0.45}, "behavior": "banish",
	  "desc": "Sanctum + Null Gate: Holy bursts banish weakened Shadow/Void." },
	{ "id": "conduction2", "pair": ["ember", "storm"], "give": {"lightning_ignites": 1.0}, "behavior": "",
	  "desc": "Ember + Storm: lightning strikes ignite." },
	{ "id": "frozenmoment", "pair": ["cryo", "chrono"], "give": {"slow_str": 0.30}, "behavior": "",
	  "desc": "Cryo + Chrono: +30% slow strength." },
	{ "id": "siegegolem", "pair": ["monolith", "ballista"], "give": {"atk_rate": 0.20, "mul_dmg": 0.10}, "behavior": "",
	  "desc": "Monolith + Ballista: tower +20% AS / +10% dmg; monolith's aura is stronger." },
	{ "id": "bloodtithe", "pair": ["hemo", "bone"], "give": {"lifesteal": 0.08, "blood_dmg": 0.20}, "behavior": "",
	  "desc": "Hemo + Bone: +8% lifesteal, +20% Blood damage." },
	{ "id": "bloodecho", "pair": ["hemo", "chrono"], "give": {"bloodecho": 1.0}, "behavior": "bloodecho",
	  "desc": "Hemo + Chrono: kills trigger a small rewind blast." },
	{ "id": "riftshot", "pair": ["nullgate", "ballista"], "give": {"pierce_armor": 0.25}, "behavior": "riftshot",
	  "desc": "Null Gate + Ballista: shots pierce and hit a second time." },
	{ "id": "virulent", "pair": ["thorn", "plague"], "give": {"root_poisons": 1.0}, "behavior": "",
	  "desc": "Thorn + Plague: rooted enemies are also poisoned." },
	{ "id": "naturegrace", "pair": ["sanctum", "thorn"], "give": {"heal_aura": 1.0}, "behavior": "",
	  "desc": "Sanctum + Thorn: towers gently heal the castle while firing." },
	{ "id": "phasechain", "pair": ["storm", "nullgate"], "give": {"chain_hop": 1.0}, "behavior": "",
	  "desc": "Storm + Null Gate: chain jumps can leap between lanes." },
	{ "id": "emberbones", "pair": ["ember", "bone"], "give": {"burn_bleed": 1.0}, "behavior": "",
	  "desc": "Ember + Bone: burning enemies also bleed." },
]

# ---- Trifecta ascensions ----------------------------------------------------
# req: the three tower ids you must have built (in any order).
# focal: which tower type ascends. g_* : global mods; l_*: shared to focal towers.
var ascensions := [
	{ "id": "infernal_ordinance", "req": ["ember", "ballista", "bone"], "focal": "ballista",
	  "name": "Infernal Ordinance", "desc": "Ballista rounds become seeking soulfire (hits 3 targets, ignites).",
	  "l_": {"kind": "asc_infernal"} },
	{ "id": "absolute_zero", "req": ["cryo", "chrono", "monolith"], "focal": "monolith",
	  "name": "Absolute Zero", "desc": "Monolith's bomb freezes a radius for 1.2s.",
	  "l_": {"kind": "asc_zero"} },
	{ "id": "tempest_refraction", "req": ["storm", "nullgate", "cryo"], "focal": "storm",
	  "name": "Tempest Refraction", "desc": "Storm bolts split into two arcs.",
	  "l_": {"kind": "asc_refraction"} },
	{ "id": "grail_aegis", "req": ["sanctum", "thorn", "hemo"], "focal": "sanctum",
	  "name": "Grail Aegis", "desc": "Sanctum radiates a healing aura to the castle.",
	  "l_": {"kind": "asc_aegis"} },
	{ "id": "choking_bloom", "req": ["plague", "thorn", "ember"], "focal": "thorn",
	  "name": "Choking Bloom", "desc": "Thorn roots detonate poison, and rooted enemies ignite.",
	  "l_": {"kind": "asc_bloom"} },
	{ "id": "nightmarish", "req": ["bone", "hemo", "nullgate"], "focal": "bone",
	  "name": "Nightmarish Pact", "desc": "Bone Ward's pierce also drains life from each enemy hit.",
	  "l_": {"kind": "asc_nightmare"} },
	{ "id": "arbelest_light", "req": ["ballista", "monolith", "sanctum"], "focal": "ballista",
	  "name": "Arbelest of Light", "desc": "Ballista bolts become holy and ignore all armor.",
	  "l_": {"kind": "asc_arbelest"} },
	{ "id": "ebon_tide", "req": ["ember", "cryo", "plague"], "focal": "plague",
	  "name": "Ebon Tide", "desc": "Plague Vat's cloud also burns and chills.",
	  "l_": {"kind": "asc_ebon"} },
]

# ---- Keystone perks (global picks every 3 player levels) --------------------
var keystones := [
	{ "id": "poly_ember", "name": "Twin Ember", "desc": "Fire elements count twice toward resonance.", "effect": "polyelement", "tag": "fire" },
	{ "id": "poly_chill", "name": "Twin Frost", "desc": "Frost elements count twice toward resonance.", "effect": "polyelement", "tag": "frost" },
	{ "id": "poly_bolt", "name": "Twin Lightning", "desc": "Lightning elements count twice toward resonance.", "effect": "polyelement", "tag": "lightning" },
	{ "id": "keystone_overcharge", "name": "Overcharge", "desc": "+20% attack speed on all towers.", "effect": "stat", "give": {"atk_rate": 0.20} },
	{ "id": "keystone_warlord", "name": "Warlord", "desc": "+25% tower damage.", "effect": "stat", "give": {"mul_dmg": 0.25} },
	{ "id": "keystone_attrition", "name": "Attrition", "desc": "Enemies take +12% damage from all sources.", "effect": "stat", "give": {"enemy_vuln": 0.12} },
	{ "id": "keystone_cata", "name": "Cataract", "desc": "+15% crit chance for all towers.", "effect": "stat", "give": {"crit_chance": 0.15} },
	{ "id": "keystone_indomitable", "name": "Indomitable", "desc": "+60 castle max HP and +3 HP/s regen.", "effect": "stat", "give": {"castle_maxhp": 60.0, "castle_regen": 3.0} },
	{ "id": "keystone_harvest", "name": "Bountiful Harvest", "desc": "+25% gold from kills.", "effect": "stat", "give": {"gold_mult": 0.25} },
]

# ---- Relic pool (chosen per tower on level 3/6/9) ----------------------------
var relics := [
	{ "id": "r_dmg", "name": "Serrated Head", "desc": "+35% damage.", "give": {"mul_dmg": 0.35} },
	{ "id": "r_as", "name": "Greased Gears", "desc": "+30% attack speed.", "give": {"atk_rate": 0.30} },
	{ "id": "r_range", "name": "Long Lens", "desc": "+20% range.", "give": {"range_mult": 0.20} },
	{ "id": "r_crit", "name": "Ace Barrel", "desc": "+12% crit chance, +40% crit damage.", "give": {"crit_chance": 0.12, "crit_mult": 0.40} },
	{ "id": "r_burn", "name": "Coating of Embers", "desc": "Shots apply Burn.", "give": {"add_status": "burn", "add_status_v": 0.8} },
	{ "id": "r_chill", "name": "Rime Chisel", "desc": "Shots apply Chill/Slow.", "give": {"add_status": "slow", "add_status_v": 0.8} },
	{ "id": "r_chain", "name": "Forked Conduit", "desc": "Chain shots get +1 jump.", "give": {"chain_bonus": 1} },
	{ "id": "r_lifesteal", "name": "Ghoul Reliquary", "desc": "Shots lifesteal 3% to the castle.", "give": {"lifesteal": 0.03} },
	{ "id": "r_splash", "name": "Scatter Charge", "desc": "Non-splash towers gain splash in a 40px radius.", "give": {"add_splash": 40.0} },
	{ "id": "r_shred", "name": "Void-Tipped", "desc": "Shots shred enemy armor.", "give": {"add_status": "shred", "add_status_v": 0.8} },
	{ "id": "r_dot", "name": "Slow Burn", "desc": "+45% damage-over-time potency.", "give": {"dot_mult": 0.45} },
	{ "id": "r_heal", "name": "Blessed Steadying", "desc": "Each shot heals the castle 0.3 HP.", "give": {"castle_heal_per_shot": 0.3} },
]

# ---- Wave Omens (battlefield conditions) ------------------------------------
# Every wave rolls one omen: a global condition that buffs a strategy for that
# wave. `give` values are injected into the synergy engine for the wave.
# `spd` optionally scales enemy movement speed.
const OMENS := [
	{ "id": "starfall", "name": "Starfall", "desc": "Fire burns hotter: +22% damage, +30% burn potency.",
	  "give": {"mul_dmg": 0.22, "burn_str": 0.30} },
	{ "id": "rimeveil", "name": "Rimeveil", "desc": "Chill deepens: +35% slow strength; enemies crawl 15% slower.",
	  "give": {"slow_str": 0.35}, "spd": 0.85 },
	{ "id": "stormfront", "name": "Stormfront", "desc": "Thunder sings: +1 chain jump, +5% crit.",
	  "give": {"chain_bonus": 1, "crit_chance": 0.05} },
	{ "id": "blackhunt", "name": "Black Hunt", "desc": "The dark hungers: every enemy takes +18% damage.",
	  "give": {"enemy_vuln": 0.18} },
	{ "id": "blessed", "name": "Blessed Ground", "desc": "Light abides: +4 HP/s castle regen; kills heal +2.",
	  "give": {"castle_regen": 4.0, "heal_on_kill": 2.0} },
	{ "id": "overgrowth", "name": "Verdant Overgrowth", "desc": "Nature flourishes: +25% DoT potency, +30% root chance.",
	  "give": {"dot_mult": 0.25, "root_str": 0.30} },
	{ "id": "mana_surge", "name": "Mana Surge", "desc": "Arcane overflows: +20% attack speed, +15% CDR.",
	  "give": {"atk_rate": 0.20, "cdr": 0.15} },
	{ "id": "blight_wind", "name": "Blight Wind", "desc": "Venom hangs thick: +45% poison potency.",
	  "give": {"poison_str": 0.45} },
	{ "id": "blood_moon", "name": "Blood Moon", "desc": "Life bleeds freely: +6% lifesteal on all damage.",
	  "give": {"lifesteal": 0.06} },
	{ "id": "time_drift", "name": "Temporal Drift", "desc": "Time stutters: the field periodically freezes.",
	  "give": {"freeze_periodic": 10.0} },
	{ "id": "iron_siege", "name": "Iron Siege", "desc": "The fortress endures: +30% castle armor, +20% armor pierce.",
	  "give": {"castle_armor": 0.30, "pierce_armor": 0.20} },
	{ "id": "void_eclipse", "name": "Void Eclipse", "desc": "Reality frays: +40% armor shred.",
	  "give": {"shred_str": 0.40} },
]

# ---- Elite affixes (enemy modifiers) ----------------------------------------
const AFFIXES := [
	{ "id": "swift", "name": "Swift", "color": Color("#ffe08a"), "speed_mult": 1.5 },
	{ "id": "warded", "name": "Warded", "color": Color("#8fdcff"), "armor_add": 8.0 },
	{ "id": "colossal", "name": "Colossal", "color": Color("#c98aff"), "hp_mult": 1.7, "radius": 16.0 },
	{ "id": "regen", "name": "Regenerating", "color": Color("#7ff58a"), "regen": 0.02 },
	{ "id": "adaptive", "name": "Adaptive", "color": Color("#ffb84a"), "adaptive": true },
	{ "id": "splitter", "name": "Splitter", "color": Color("#ff5a6e"), "splitter": true },
]

# ---- Pacts (cursed rewards) --------------------------------------------------
# Offered occasionally among wave rewards. `add` values fold into the permanent
# `give_bonus` stream (refresh applies them). Immediate effects are one-offs
# (gold_now / curse_hp / curse_attr). Taking a pact is a one-way commitment.
const PACTS := [
	{ "id": "ravager", "name": "Ravager's Pact", "desc": "+35% all damage forever — but the castle permanently loses 40 max HP.",
	  "add": {"mul_dmg": 0.35}, "curse_hp": 40 } ,
	{ "id": "gilded", "name": "Gilded Curse", "desc": "+120 gold now — but -20% gold income forever.",
	  "add": {"gold_mult": -0.20}, "gold_now": 120 },
	{ "id": "alchemist", "name": "Mad Alchemist", "desc": "+25% attack speed forever — but you lose 1 Might.",
	  "add": {"atk_rate": 0.25}, "curse_attr": "might" },
]

# ---- Waves ------------------------------------------------------------------
# Wave scaling helpers, called by game.gd.
const LANE_Y := 0.0  # filled at runtime

func wave_composition(wave: int, lanes: int) -> Dictionary:
	# returns {count, hp, speed, armor, gold, xp, boss}
	var hp := 32.0 * pow(1.22, wave) + wave * 14.0
	var speed := 46.0 + wave * 2.2
	var armor := 0.0 + wave * 0.6
	var gold := 8.0 + wave * 1.4
	var xp := 6 + wave * 2
	var count := 2 + wave * 2 + lanes
	var boss := (wave % 5 == 0)
	if boss:
		count = clamp(count / 3, 3, 8)
		hp *= 4.5
		speed *= 0.75
		armor += 6.0
		gold *= 3.0
		xp *= 4
	return {"count": count, "hp": hp, "speed": speed, "armor": armor,
		"gold": gold, "xp": xp, "boss": boss}

# ---- Meta progression store keys -------------------------------------------
const META_COST := 100

func get_tower(id: String) -> Dictionary:
	return towers.get(id, {})

func get_skill(id: String) -> Dictionary:
	return skills.get(id, {})

func attr_info(id: String) -> Dictionary:
	return ATTR.get(id, {})
