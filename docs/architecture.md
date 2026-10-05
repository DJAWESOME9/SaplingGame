# Sapling architecture and data flow

This is a code map for the intentionally single-file game. Exact formulas and UI behavior live in `index.html`; use the identifiers below to navigate rather than relying on this summary as a specification.

## Runtime shape

`index.html` contains the game document, styles, and one inline strict-mode JavaScript script. `admin.html` is the separate Supabase-authenticated player support dashboard; `leaderboard-config.js` holds the browser-safe project URL/public key, and `supabase/leaderboard.sql` defines the online schema and RPCs. The game script initializes progression, loads local run/meta state, installs handlers, then starts `requestAnimationFrame(frame)`.

The main frame loop advances the simulation, updates production, time-based systems, and node positions, prepares branch geometry, updates critters/withering/particles, draws the canvas, and refreshes the HUD and selected-node panel. A frame-level catch logs errors and the loop schedules its next frame after the catch, so one exception should not permanently stop animation.

## Game-state flow

```text
user input ──> action handlers ──> run state S / persistent meta META
                                      │
frame(dt) ──> computeFlow(dt) ──> income at Core ──> resource banks
    │                                 │
    ├── tick boosts, acorns, critters, wither
    ├── layout/camera + canvas render
    └── HUD/panel refresh

periodic save + visibility/page exit ──> localStorage
reload ──> loadMeta() + load() ──> offline credit ──> first frame
```

`S` is the current tree/run: nodes, resources, Roots upgrades, per-tree stats, temporary effects, and UI-relevant gameplay flags. Nodes are indexed by ID in `S.nodes`; each node has a parent and children. Flow is evaluated recursively from leaves toward the root/Core. The root receives combined sap/resin income. Edge capacity, critter slowdowns, Blight withering, amplifiers, refineries, and capacitors all affect that path.

`META` holds cross-tree progression such as rings, species, Grove upgrades, achievements, Pantheon/acorns, and lifetime statistics. A cut credits meta progression and then starts a new run tree.

## Subsystem landmarks

| Subsystem | Main code landmarks |
|---|---|
| Tuning and persistent progression definitions | `CFG`, `SPECIES`, `GROVE`, `PANTHEON`, `ACHIEVEMENTS`, Roots data |
| Run initialization and node graph | `newGame`, `mkNode`, `N`, `layout`, `relaxNodes` |
| Production and branch capacity | `computeFlow`, rate/capacity helpers, `frame` |
| Player actions | `grow`, `harvestLeaf`, `beginChannel`, `upgrade`, `thicken`, `graft`, `polish`, `doPrune`, `buyRoot` |
| Canvas rendering and hit testing | `draw`, `pickRoot`, `pickBranch`, `pickCore`, `pickTarget` |
| Pointer interactions | canvas `pointerdown/move/up/cancel` and `wheel` listeners around the hit-testing code |
| HTML action panel and HUD | `buildPanel`, `refreshPanel`, `refreshHud`, `hintText` |
| Temporary effects, critters, Blight | `BLOOMS`, `tickBlooms`, `spawnCritter`, `updateCritters`, `updateWither` |
| Grove and prestige | `buyGrove`, Grove layout/render/popover functions, `cutDown`, `finalizeCut` |
| Acorns/Pantheon/achievement/stat drawers | `tickAcorns`, `renderPantheon`, `renderAchievements`, `renderStats` |
| Persistence/offline recovery | `save`, `load`, `creditOffline`, `loadMeta`, `saveMeta` |
| Save-code and settings actions | `makeSaveCode`, `applySaveCode`, settings event handlers |
| Optional online leaderboard | Settings panel and `submitLeaderboardScore` / `loadLeaderboard`; SQL setup in `supabase/leaderboard.sql` |
| Main runtime and boot | `frame`, listeners near the end, final load/intro/bootstrap calls |

## Persistence and compatibility

The game stores two JSON records in browser `localStorage`:

| Key | Contents | Recovery |
|---|---|---|
| `sapling-save-v1` | Current tree/run state, currently written with `v: 2` | `-bak`, slower `-snap`, plus `-prereset` used by restore/import flows |
| `sapling-meta-v1` | Grove/lifetime progression and long-term systems | `-bak` and `-snap` |
| `sapling-vol` | Audio volume preference | No parallel backup |

`load()` accepts run save versions 1 and 2 and fills defaults for fields introduced after older saves. `loadMeta()` tries the primary meta value and backup slots before creating defaults. The game autosaves the run every six seconds, before unload, and when the document becomes hidden; meta is saved at relevant progression changes. Offline production is credited on reload and when returning from a hidden/suspended tab, with a calculated cap and rate.

The optional leaderboard and admin tools use Supabase when `leaderboard-config.js` is configured. Public rankings retain personal bests; private player profiles and the admin action queue power `admin.html`. Admins are authenticated and allowlisted in the database. A player ID identifies one browser profile, not a cloud account; setup and limitations are in `docs/leaderboard.md`.

When changing state fields, inspect both serialization and hydration, existing defaults, legacy version branches, save-code export/import, and reset/restore behavior. Do not assume a field is only transient because it is not visible in the save object: determine whether it should survive reload, cuts, or both.

## Browser and deployment assumptions

- Modern browser APIs include canvas, `requestAnimationFrame`, pointer events, `localStorage`, visibility events, and Web Audio (with prefixed AudioContext fallback).
- The local game can be opened directly as a file; the static site also loads from GitHub Pages.
- `sethatubby.png` is referenced by a relative path in the HTML. Preserve that path relationship or update the reference if the asset moves.
- `.github/workflows/pages.yml` uploads the repository root as the Pages artifact. There is no build/transpile stage.
