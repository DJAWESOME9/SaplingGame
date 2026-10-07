# Agent guide

## Project identity and source of truth

Sapling is a single-page idle/incremental browser game. The full game implementation is in the inline HTML, CSS, and JavaScript of [`index.html`](index.html); there is no module tree, build step, dependency manifest, or test suite. Treat the code as the source of truth when behavior differs from docs. Read [`docs/architecture.md`](docs/architecture.md) for the feature map and persistence details.

## Find the implementation

| Change request | Start here in `index.html` |
|---|---|
| Economy, production rates, resource balance | `CFG`, formula helpers, `computeFlow`, `frame` |
| Nodes, growing/upgrading/grafting/pruning | `newGame`, `mkNode`, `grow`, `upgrade`, `graft`, `doPrune`, `buyRoot` |
| Tree geometry, canvas drawing, camera | `layout`, `relaxNodes`, `prepareEdgeCache`, `draw`, camera helpers |
| Pointer/touch interaction and node action panel | canvas pointer and wheel listeners near `pickTarget`; `buildPanel`, `refreshPanel` |
| Gold leaves and temporary boosts | `computeFlow`, `harvestLeaf`, `BLOOMS`, `tickBlooms` |
| Critters and Blight withering | `spawnCritter`, `updateCritters`, `updateWither`, `witherAway` |
| Grove, species, prestige/cut | `GROVE`, `SPECIES`, `buyGrove`, `renderGrove`, `cutDown`, `finalizeCut` |
| Acorns and Pantheon | `tickAcorns`, `PANTHEON`, `renderPantheon`, `unlockPantheon` |
| Achievements, stats, settings | `ACHIEVEMENTS`, `renderAchievements`, `renderStats`, settings event handlers |
| Save/load/offline progress/import-export | `save`, `load`, `creditOffline`, `saveMeta`, `makeSaveCode`, `applySaveCode` |
| Intro, animation loop, boot | `beginRun`, `frame`; final initialization block at end of script |
| Player update log and popup | `UPDATE_LOG`, `newMeta().seenUpdateId`, `openUpdates`, `showUnseenUpdates` |
| Visual asset for easter egg | `sethatubby.png` and the Sethatubby overlay markup/styles in `index.html` |

All subsystem boundaries are comments within the large inline script. Use `rg -n 'function NAME|const NAME|section comment' index.html` to jump to the relevant code. Most DOM references are cached near their subsystem; preserve the existing style of local helpers and event handlers.

## Run and verify

- Run locally by opening `index.html` in a browser. Refresh after edits.
- No build, package install, formatter, test command, or automated browser check is configured in this repository.
- For a documentation-only change, verify referenced paths and links exist and inspect the diff.
- For a gameplay change, manually exercise the affected flow in a browser when available. For UI changes, check a narrow/mobile viewport as well as desktop because the game supports touch and safe-area insets.
- GitHub Pages deploys the repository root when `main` is pushed or the workflow is manually dispatched; workflow: [`.github/workflows/pages.yml`](.github/workflows/pages.yml).

## GitHub push troubleshooting

- If an HTTPS push is rejected with a GitHub `Internal Server Error` during `git-receive-pack`, first confirm the local commit is intact and compare the remote branch with `git ls-remote origin refs/heads/main`. A successful dry-run does not confirm that GitHub can process the actual pack.
- In this repository, retrying with uncompressed Git objects succeeded after normal pushes returned HTTP 500. Use `git -c core.compression=0 -c pack.compression=0 push origin main` as a workaround; verify the remote ref afterward. This changes only that invocation and does not alter repository config.
- If that still fails, record the GitHub request ID and timestamp from the rejection and check [GitHub Status](https://www.githubstatus.com/) before diagnosing branch rules or local object corruption. Do not disable SSH host-key verification when trying another transport.

## Release notes for every change

- For every change that ships to players, including gameplay, UI, balance, online features, and bug fixes, add a plain-language note to the `UPDATE_LOG` array in `index.html`. Summarize all important player-facing changes; do not leave features or fixes out of the popup.
- Add a new entry at the front with a unique `id`, date, title, and `notes`. Group related changes in one entry, put the most important changes first, and keep older entries so Settings → Update log remains a history. `UPDATE_LOG` is the project's changelog; do not maintain a conflicting list elsewhere.
- The first entry's `id` controls the unseen-update popup. Keep `newMeta().seenUpdateId` unset for new players, and preserve `showUnseenUpdates()` after the intro and Welcome Back overlays so everyone sees new notes once. Closing the popup records the latest seen ID.
- For a documentation-only or internal maintenance change with no player-visible effect, update the relevant docs; do not interrupt players with an empty or misleading popup.

## Editing constraints and risks

- Keep the single-file architecture unless the requested change calls for a structural refactor. If moving code or assets, update every relative path and the Pages workflow assumptions.
- Treat save compatibility as a product requirement. `sapling-save-v1` and `sapling-meta-v1` contain different parts of player progress. Update serialization and hydration together, preserve defaults for old saves, and avoid changing/removing keys without a migration plan.
- Save code changes and hard reset/restore behavior can overwrite player progress. Keep backup/import/export behavior coherent; do not use a real personal save as a test fixture.
- Economy formulas interact across node flow, upgrades, species, Grove upgrades, Pantheon modifiers, boosts, offline credit, and achievements. Trace all callers and multipliers before tuning a formula.
- Production and timed effects run in `frame` using elapsed time. The loop clamps frame delta and separately credits wall-clock gaps; changes to timers must account for foreground play, idle, hidden tabs, reload/offline time, and freeze behavior as applicable.
- Keep UI behavior usable with pointer and touch input; controls use pointer events and the canvas owns drag/pan/zoom gestures.
- Do not add dependencies, build infrastructure, tests, or generated files unless the user requests them or the change requires them.

## Working tree caution

Before editing, inspect `git status`. Preserve pre-existing user changes. In particular, do not discard, reformat, or overwrite unrelated modifications in `index.html` or untracked files. Make focused changes and review `git diff` before finishing.
