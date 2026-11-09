# Citadel of Echoes — Design Document

A **roguelite tower-defense** where every tower and every spell carries one or more
elemental *essences*. The real game is not clicking towers — it is *discovering how
your choices interact*. Nothing in this game exists in isolation.

---

## 1. The Essence System (the substrate)

There are **12 essences**. Every piece of content (tower, skill, relic, gizmo) is
tagged with one or more of them:

Fire, Frost, Lightning, Shadow, Holy, Nature, Arcane, Poison, Blood, Chrono, Steel, Void

Tags are the *vocabulary* that every synergy reads. The code never special-cases a
tower — it only ever reasons about tags and behaviours.

## 2. The four synergy layers

### Layer 1 — Elemental Resonance (global auras)
Each essence in your active pool (built towers + equipped skills) counts toward a
pool. Certain **sets of essences in the pool** unlock permanent global auras for the
whole defense. Sets are not exclusive — you can have many active at once, and the
more essences you stack the more auras you collect.

Examples (from `content_db.gd → resonances`):

| Set | Name | Effect |
|-----|------|--------|
| Fire×2 | Superheating | +10% damage, +35% burn potency |
| Fire+Frost | Saltstorm | burning enemies are slowed; slowed enemies burn |
| Lightning+Arcane+Chrono | Chrono Storm | chain jumps also freeze briefly |
| Steel+Poison+Frost | Steel Plague | poison ignores armor |
| Void+Shadow+Fire | Infernal Void | shredding ignites and reaps |

There are ~30 resonances, including **triple meta-resonances** that only appear when
you commit to three simultaneous essences.

### Layer 2 — Building Fusions (adjacency)
When two *specific* tower types occupy adjacent grid slots, they fuse: both towers
gain a bonus and a shared emergent behaviour activates.

Examples:
- **Ember Turret + Cryo Cannon** → *Quench*: freezing a burning enemy vaporizes it for burst.
- **Ballista + Null Gate** → *Rift Shot*: shots pierce and strike a second time.
- **Storm Spire + Null Gate** → *Phase Chain*: lightning arcs can leap between lanes.

The grid matters. Arrangement is a strategic axis.

### Layer 3 — Trifecta Ascensions
Collect three specific tower types anywhere in your defense and one of them
**ascends** into a legendary form, permanently changing its behaviour.

Examples:
- **Ember + Ballista + Bone** → *Infernal Ordinance*: ballista rounds become seeking soulfire that ignites.
- **Cryo + Chrono + Monolith** → *Absolute Zero*: the monolith's bomb freezes a radius.
- **Storm + Void + Cryo** → *Tempest Refraction*: bolts split into two arcs.

### Layer 4 — Skill × Tower affinity
Active spells scale not just with ranks but with the count of matching-essence towers
you have built: e.g. *Meteor Swarm* grows more powerful and leaves more smoldering
ground for every Fire tower in your line.

## 3. Leveling & progression

- **Player level** rises from XP (kills). Each level grants an attribute point to
  spend in a tree: *Might* (damage), *Swiftness* (attack speed), *Wits* (crit),
  *Bastion* (castle HP/regen), *Mastery* (CDR & spell damage).
- **Keystones** — every 3 levels pick one global perk (e.g. *Twin Ember* makes Fire
  count twice toward resonance; *Warlord* boosts all tower damage).
- **Towers** level up with gold. Level 3/6/9 lets you choose **1 of 3 relics**
  (e.g. crit chance, extra chain jump, splash, armour shred, DoT boost).
- **Skills** are recruited and ranked, and equipped into a hotbar (5 slots, +1 via meta unlock).

## 4. Cross-run meta progression

Performance (waves cleared) earns **Essence Shards**, spent permanently on small
boons: bonus starting gold, an extra skill slot, free attribute points, extra castle
HP, or a starting relic.

## 5. Combat model

- Enemies march along lanes left→right to the castle.
- Towers occupy a 4×6 grid of defense slots and auto-target within their range.
- Each hit computes: base damage → player/tower multipliers → critical chance →
  armour mitigation (optionally pierced/shredded) → damage applied; then the hit
  applies its statuses and any active behaviours (vaporize, ignite-on-shock, etc.).
- Debuffs (burn, poison, bleed, slow, root, freeze, shred, shock, mark) tick over
  time and interact with the synergy flags.

## 6. Code architecture

| File | Responsibility |
|------|----------------|
| `scripts/core/elements.gd` | The 12 essences, names, colors |
| `scripts/db/content_db.gd` | All static content: towers, skills, resonances, fusions, ascensions, relics, keystones, wave math |
| `scripts/db/synergy_engine.gd` | Computes every active modifier from the current build |
| `scripts/model/run_data.gd` | Mutable state of the current run |
| `scripts/meta/meta_store.gd` | Cross-run shards/unlocks, persisted to `user://` |
| `scripts/game/game.gd` | Master controller: waves, combat, economy, UI, leveling |
| `scripts/game/enemy.gd` | Enemy + debuff simulation |
| `scripts/game/tower.gd` | Tower rendering |
| `scripts/main.gd` | Entry point + headless self-test harness |

To add new content: define it in `content_db.gd` and, if it should interact with
other systems, describe it with essence tags + behaviours — the synergy engine picks
it up automatically.
