class_name Elements
extends RefCounted
## The twelve "essences" that define the whole combinatorial layer.
## Every tower, skill, relic and synergy interacts through these tags.

const FIRE = "fire"
const FROST = "frost"
const LIGHTNING = "lightning"
const SHADOW = "shadow"
const HOLY = "holy"
const NATURE = "nature"
const ARCANE = "arcane"
const POISON = "poison"
const BLOOD = "blood"
const CHRONO = "chrono"
const STEEL = "steel"
const VOID = "void"

const ALL = [
	FIRE, FROST, LIGHTNING, SHADOW, HOLY, NATURE,
	ARCANE, POISON, BLOOD, CHRONO, STEEL, VOID,
]

const NAME = {
	FIRE: "Fire", FROST: "Frost", LIGHTNING: "Lightning",
	SHADOW: "Shadow", HOLY: "Holy", NATURE: "Nature",
	ARCANE: "Arcane", POISON: "Poison", BLOOD: "Blood",
	CHRONO: "Chrono", STEEL: "Steel", VOID: "Void",
}

const COLOR = {
	FIRE: Color("ff5a3c"), FROST: Color("59b8ff"), LIGHTNING: Color("efe94a"),
	SHADOW: Color("9a5df0"), HOLY: Color("fff0a8"), NATURE: Color("66c266"),
	ARCANE: Color("bf7eff"), POISON: Color("8ed64a"), BLOOD: Color("c23a5e"),
	CHRONO: Color("41e0c0"), STEEL: Color("b8b8cc"), VOID: Color("6d6f9e"),
}

static func name_of(e: String) -> String:
	return NAME.get(e, e.capitalize())

static func color_of(e: String) -> Color:
	return COLOR.get(e, Color.GRAY)

static func all_tags(elements: Array) -> Array:
	return elements
