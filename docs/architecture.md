# Sapling architecture and data flow

This is a code map for the intentionally single-file game. Exact formulas and UI behavior live in `index.html`; use the identifiers below to navigate rather than relying on this summary as a specification.

## Runtime shape

`index.html` contains the game document, styles, and one inline strict-mode JavaScript script. `admin.html` is the separate Supabase-authenticated player support dashboard and live challenge publisher; `leaderboard-config.js` holds the browser-safe project URL/public key. `supabase/leaderboard.sql` defines leaderboard/admin storage and RPCs, while `supabase/live_challenges.sql` defines the challenge catalog, completion records, and challenge RPCs; `supabase/live_challenge_leaf_sap.sql` adds leaf-production goals, `supabase/live_challenge_server_clock.sql` returns database time for countdown alignment, and `supabase/live_challenge_goals.sql` adds the other goal types and rewards. The game script initializes progression, loads local run/meta state, installs handlers, then starts `requestAnimationFrame(frame)`.

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

The Critter Hub and expedition slots also live in `META`, so stored critters, offers, and active trip progress survive cuts and reloads. Starting an expedition removes its critters from the hub immediately. Older active trips are migrated once on load. Foreground progress advances in `frame`; offline elapsed time advances at `offlineRateNow()` in `creditOffline`. Resource rewards use buff-free production rates captured when a trip begins and count as earned resources, not tree production.

The Spellbook appears beside the Pantheon and expeditions in the minigame dock once acorns unlock. `unlockSpellbook` spends one banked acorn to set `META.spellbook.opened` permanently. Existing saves with the former `META.up.spellbook` Grove purchase migrate to the opened state without a second payment. Spell Study, Mana Well, and Mana Spring remain ring upgrades beneath Vitality in the Grove and become available once the book is open. `spellstudy` levels unlock additional spells without replacing the earlier versions; `manawell` and `manaspring` improve mana capacity and refill speed. `META.spellbook` stores its unlock, mana, a wall-clock refill timestamp, and total casts. Mana survives cuts and refills at full speed offline, with a 100 base cap and a 20-minute base refill. Freeze pauses regeneration and casting. `S.spells` stores temporary spell timers and the pending Amber Echo multiplier, so these survive reloads and save-code export but reset with a new tree. Old saves receive defaults through `ensureSpellbook` and `hydrateSpells`.

Spell timers expire offline unless frozen. `creditOffline` splits income at those expiration times so short production spells cannot boost an entire offline interval. Sap and resin spell windfalls count as earned resources rather than tree production. Spell surges share a ×2 leaf multiplier; they can combine with existing blooms but do not multiply one another. Bark Ward prevents critter penalties, spawning, and Blight damage across the tree; its backfire removes one terminal node and never the Core. Amber Echo affects the prune preview and is consumed by the next actual prune. Expedition reward estimates temporarily remove spell effects along with other transient boosts.

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
| Critter Hub and expeditions | `renderCritterHub`, `EXPEDITION_TYPES`, `renderExpeditions`, `startExpedition`, `advanceExpeditions` |
| Grove and prestige | `buyGrove`, Grove layout/render/popover functions, `cutDown`, `finalizeCut` |
| Spellbook and mana | `SPELLS`, `unlockSpellbook`, `castSpell`, `renderSpellbook`, `tickSpellMana`, `advanceSpellTimers`, `hydrateSpells` |
| Acorns/Pantheon/achievement/stat drawers | `tickAcorns`, `renderPantheon`, `renderAchievements`, `renderStats` |
| Persistence/offline recovery | `save`, `load`, `creditOffline`, `loadMeta`, `saveMeta` |
| Save-code and settings actions | `makeSaveCode`, `applySaveCode`, settings event handlers |
| Release notes and update popup | `UPDATE_LOG`, `newMeta().seenUpdateId`, `openUpdates`, `showUnseenUpdates` |
| Optional online leaderboard | Top-bar leaderboard drawer and `submitLeaderboardScore` / `loadLeaderboard`; SQL setup in `supabase/leaderboard.sql` |
| Live challenges | Top-bar Challenges drawer and draggable event HUD, `loadLiveChallenges`, `challengeGoals`, `accrueChallengeWindow`, `recordChallengeEvent`, `checkLiveChallengeClaims`, `claimLiveChallenge`; admin publishing in `admin.html`; SQL setup in `supabase/live_challenges.sql`, `supabase/live_challenge_leaf_sap.sql`, `supabase/live_challenge_server_clock.sql`, and `supabase/live_challenge_goals.sql` |
| Main runtime and boot | `frame`, listeners near the end, final load/intro/bootstrap calls |

## Persistence and compatibility

The game stores two JSON records in browser `localStorage`:

| Key | Contents | Recovery |
|---|---|---|
| `sapling-save-v1` | Current tree/run state, currently written with `v: 2` | `-bak`, slower `-snap`, plus `-prereset` used by restore/import flows |
| `sapling-meta-v1` | Grove/lifetime progression and long-term systems | `-bak` and `-snap` |
| `sapling-vol` | Audio volume preference | No parallel backup |

`load()` accepts run save versions 1 and 2 and fills defaults for fields introduced after older saves. `loadMeta()` tries the primary meta value and backup slots before creating defaults. The game autosaves the run every six seconds, before unload, and when the document becomes hidden; meta is saved at relevant progression changes. Offline production is credited on reload and when returning from a hidden/suspended tab, with a calculated cap and rate.

The optional leaderboard, admin tools, and live challenges use Supabase when `leaderboard-config.js` is configured. Public rankings retain personal bests; private player profiles and the admin action queue power `admin.html`. Admins are authenticated and allowlisted in the database. A player ID identifies one browser profile, not a cloud account. Challenge achievements are recorded in local meta state; the completion and first-finisher records are kept in Supabase. Challenge eligibility is reported by the browser, so the database orders claims but cannot verify gameplay. Setup and limitations are in `docs/leaderboard.md`.

The in-game changelog is `UPDATE_LOG` in `index.html`. Its first entry is the latest release, and `META.seenUpdateId` records what the player has dismissed. New players begin with no seen ID. The popup waits for the first-run intro or Welcome Back dialog to close, then shows the latest release; Settings → Update log shows the full history. When shipping player-facing changes, add a new entry that covers every important feature and fix so the popup reaches both new and returning players.

When changing state fields, inspect both serialization and hydration, existing defaults, legacy version branches, save-code export/import, and reset/restore behavior. Do not assume a field is only transient because it is not visible in the save object: determine whether it should survive reload, cuts, or both.

## Browser and deployment assumptions

The separate `calculator/` folder contains a graphical TI-84 Plus CE TI-BASIC edition.
`SAPLING.txt` is its source, `SAPLING.8xp` is the transferable program, and
`build.py` optionally regenerates that file using Python's standard library. It
draws a fixed tree with up to 13 nodes and computes leaf-to-Core sap/resin flow
through amplifiers and refineries. Individual upgrades, pruning, and Roots are
stored in the calculator's named list `SAPCE`; version-1 calculator saves migrate
to version 2 with a `SABAK` backup. Its saves are independent of browser saves.
Production advances
using `startTmr`/`checkTmr` only while the calculator program runs. See
[`calculator/README.md`](../calculator/README.md) for installation, controls,
limits, calculator settings, and device verification status.

- Modern browser APIs include canvas, `requestAnimationFrame`, pointer events, `localStorage`, visibility events, and Web Audio (with prefixed AudioContext fallback).
- The local game can be opened directly as a file; the static site also loads from GitHub Pages.
- `sethatubby.png` is referenced by a relative path in the HTML. Preserve that path relationship or update the reference if the asset moves.
- `.github/workflows/pages.yml` uploads the repository root as the Pages artifact. There is no build/transpile stage.
