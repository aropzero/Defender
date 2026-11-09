# 🏰 Citadel of Echoes

A **roguelite tower-defense** built in **Godot 4.7** where the true weapon is
*combination*. Every tower and spell carries elemental essence; the interplay of
those essences — resonances, fusions and ascensions — creates your defense.

> "Make a AAA tower/castle defense with a leveling system, synergy, and all the
> building+skill combinations — with real complexity." — that's this game.

## Why Godot

Godot 4 is fully authorable as text (GDScript + scenes), runs headless for
validation, exports to desktop/mobile/web, and is the only one of the two requested
engines that can be built and verified inside this environment. Unity requires the
proprietary editor, which cannot run here. The entire project is open and readable.

## Engine decision

- **Engine:** Godot 4.7.2 (Godot 4.x required)
- **Language:** GDScript (no external plugins, no assets required — all visuals are
  procedural vector drawing, so the project is fully self-contained)

## How to play

```
godot --path .          # run from the project root
godot —editor --path .   # open the editor
```

1. **Start a New Run** from the main menu.
2. In the **Build** phase, click any defense slot on the right side of the field
   to buy a tower (12 tower types).
3. Press **Start Wave**. Enemies march from the left toward your castle; your towers
   auto-fire.
4. Kill enemies → gold + XP. Spend gold on towers/upgrades. Level up to spend
   attribute points and pick **Keystone** perks every 3 levels.
5. Build towers sharing **essences** to unlock **Resonances** (global auras),
   place specific towers **adjacent** for **Fusions**, and collect tower
   **trifectas** for **Ascensions**.
6. Use **skills** with keys `1–5`. Every skill has elemental affinity that scales
   with your matching towers.
7. Between waves pick one of three **rewards**. Survive as many waves as you can —
   waves cleared earn Essence Shards for the permanent meta store.

## Controls

| Input | Action |
|-------|--------|
| Mouse click on slot | Open build menu |
| Mouse click on built tower | Upgrade / sell / choose relic |
| Keys `1`–`5` | Cast equipped active skills |
| Buttons in UI | Start wave, meta store, abandon run |

## The synergy layer (the heart)

See **[docs/DESIGN.md](docs/DESIGN.md)** for the full system. In short:

- **12 essences** tag every tower and skill.
- ~30 Elemental **Resonances** (pool-based global auras), including triple meta-combos.
- 14 **Building Fusions** (adjacency recipes with emergent behaviours).
- 8 **Trifecta Ascensions** (three tower types → a legendary upgrade).
- **Skill × tower** affinity scaling, per-tower **relics**, and a **Keystone**
  perk tree on top of the attribute point system — so builds are combinatorial.

## Project layout

```
project.godot              # Godot project (autoloads, input, display)
scenes/main.tscn           # minimal scene; all UI built in code
scripts/
  core/elements.gd         # the 12 essences
  db/content_db.gd         # ALL content (towers, skills, synergies, relics...)
  db/synergy_engine.gd     # computes active modifiers from your build
  model/run_data.gd        # current-run state
  meta/meta_store.gd       # cross-run meta progression (saved)
  game/game.gd             # master controller (waves/combat/UI)
  game/enemy.gd            # enemies + debuffs
  game/tower.gd            # tower rendering
  main.gd                  # entry point + self-test
docs/DESIGN.md             # full design documentation
```

## Headless self-test

The project includes a scripted stress test that plays itself (builds towers,
casts skills, clears waves, picks rewards, levels up):

```bash
CITADEL_SELFTEST=1 godot --headless --path .
# -> [SELFTEST OK] waves_ran=6 hp=... kills=... gold=... syn_active=... asc=...
```

This is how the project is validated here, and it doubles as a regression harness.

## Android APK (autobuild via GitHub Actions)

A CI workflow (`.github/workflows/build-apk.yml`) builds and signs the Android APK
on every push to `main` (and on pull requests / manual dispatch). It:

1. Installs Godot 4.7.2 + export templates, JDK 17, and the Android SDK.
2. Runs the headless self-test — the build **fails** if the game doesn't play
   correctly.
3. Exports a signed debug APK (`.apk`) and a release APK (`-release.apk`).
4. Uploads both as workflow artifacts.

Build locally from the project root:

```bash
godot --headless --path . --export-debug "Android" build/CitadelOfEchoes.apk
godot --headless --path . --export-release "Android" build/CitadelOfEchoes-release.apk
```

The export preset is `export_presets.cfg` (package `com.ecod.citadellecthoes`,
arm64). Debug/release signing uses a keystore configured in the Godot editor
settings — CI generates its own keystore; locally, either configure your own in
`Editor Settings → Export → Android`, or install the default `debug.keystore`.

## Adding content

Everything content lives in `scripts/db/content_db.gd`. Add a tower, skill,
resonance, fusion, ascension, relic or keystone as one dictionary entry and the
synergy engine and combat loop pick it up automatically — no wiring required.
