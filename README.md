# Sapling

An idle/incremental game where the tree is simultaneously the map, the production line, and the upgrade screen. Sap flows from the leaves through amplifiers and refineries to the Core. You spend what you produce to grow the tree wider and deeper, prune branches into permanent advancement, and eventually fell the whole tree for eternal upgrades that carry over into the next sapling.

A single HTML file. Open `index.html` in a browser — no build step, no server.

## Controls

- **Click a node** to open its action panel (grow, upgrade, polish, prune, etc.)
- **Drag** to pan, **scroll** or **pinch** to zoom
- **Click the core** to reveal the Roots advancement tree underground
- **Click a leaf with a glow** to harvest a gold leaf
- **Click a bug or bird** sitting on a node to scare it off (it deals one damage per click)
- **🪓 Cut** button in the topbar → fells the tree and opens the Grove (prestige)
- **⚙ Settings** → volume, restore backup, save code, intro, hard reset

## Resources

| Resource | Source | Spent on |
|---|---|---|
| **Sap** 🟡 | Leaves; produced passively, flows through the tree | Growing branches, upgrading most node types, thickening edges |
| **Resin** 🟠 | Refined from sap by Refinery nodes | Capacitors, grafting, polishing |
| **Amber** 🟤 | Pruning branches | Permanent Roots-tree advancement (per-tree) |
| **Rings** 🍃 | Cutting down a grown tree | Eternal Grove upgrades and species unlocks (across all trees) |

## Node types

- **Leaf** — produces sap; periodically grows a **gold leaf** for a sap windfall
- **Amplifier** — multiplies any flow passing through it (deep vs. wide tension)
- **Refinery** — converts sap into resin; cannot be placed on another refinery
- **Capacitor** — buffers flow and bursts it out boosted; can overflow thin edges

### Polish ✨

Spend resin to **polish** a leaf, amplifier, or capacitor for a permanent +6% boost to its primary stat (stacking). Each polish on the same node is more expensive than the last. Cap is 3 per node by default, raised by the **Lacquer** eternal upgrade.

### Lock 🔒

Every node panel has a small lock toggle. Locking a node hides every spend button (upgrade, polish, edges, growth, grafting) and disables pruning — handy for protecting your best branches from accidental clicks.

## Branches and pruning

Every connection between nodes is a **branch** with throughput capacity. Flow that exceeds capacity leaks (red drips) — thicken the edge to widen capacity, or it's wasted.

**Pruning** a branch sacrifices it and everything below it for **amber**, based on the branch's lifetime flow. Amber buys advancement in the Roots tree under the core. Each parent tracks its own amber-earned total, and future prunes from the same parent yield diminishing returns — spread your prunes around to keep the rate up.

## Roots tree

Click the core to reveal a downward-growing skill tree. Costs are paid in amber and scale by depth (×1.4 per tier). Sample paths:

- **Amplify → Refine → Capacitance → Grafting** (the production-tech spine)
- **Soil → Verdance → Sunlight** (leaf production multipliers and caps)
- **Soil → Crown** (more branch slots on the core)
- **Shears → Thrift / Heartwood** (cheaper growth, more offline time)
- Tier-5 deep roots like Cascade, Reservoir, Resonance, Sunlight reward focused investment in one specialty

## The Grove (prestige)

Click the 🪓 Cut button to fell your tree. A short animation plays, then you bank **rings** based on the tree's lifetime flow.

- **Rings produced scales sub-linearly** with tree size, then is further damped by your cumulative lifetime rings — early prestiges pay more than late ones.
- Rings buy **eternal upgrades** in the Grove (persist across cuts) and **species unlocks**.
- **Species** are tree types with their own perks and banes — Oak (balanced), Apple (gold-leaf bonus), Peach (lush production / fragile branches), Grape (extra slots), Maple (sap-rich), Pine (hardy / no gold). Producers visually take on the species' color.

### Grove (eternal) upgrades

Organized into a small tree of their own, gated by tiers. Higher tiers cost more rings (×1.5 per tier). Highlights:

| Upgrade | Tier | Effect |
|---|---|---|
| Vitality, Heartgirth, Endurance | T1 | Production %, edge capacity %, offline hours |
| Seasoned Leaves, Nest Egg, Windfall | T2 | Leaf start level, starting sap, +ring % |
| Sunray, Omen | T2 / Vitality | Faster gold-leaf cadence / reveals next-gold timer on leaves |
| Strong Swat | T2 / Endurance | Critter clicks deal **2** damage instead of 1 |
| Bramble, Patience | T3 | Critters appear less often / offline production % |
| Resin Glaze, Lacquer | T3 / Seasoned | Polish gives extra %, +1 max polish per node |
| Born Resonant, Verdure | T3 / Resonant | Amp start level / max leaf level |
| **Birthright** | T3 / Resonant | Every new branch starts +1 level higher per level (max 10) |
| Deep Roots | T3 / Windfall | New trees start with key Roots pre-unlocked |
| Graft Apple/Peach/Grape/Maple/Pine | T2-T3 | Unlock species |

## Critters

Birds and bugs occasionally land on producer nodes and **slow their throughput to 35%**. They no longer leave on their own — click them to scare them off (one damage per click; Strong Swat doubles it).

## Save data and settings

The game autosaves on a timer plus on visibility change. In the gear menu:

- **Restore backup** — roll back to a stashed snapshot (10-min, prereset, etc.)
- **Save Code** — Export to copy a UTF-8 base64 string of your full state; Import to load one (your current save is stashed to `-prereset` before overwrite)
- **Show intro** — re-read the first-run intro
- **Hard reset** — wipes everything (current tree, rings, all upgrades, all backups). Double-confirmed.

Saves live in `localStorage`:
- `sapling-save-v1` — current tree
- `sapling-save-v1-bak`, `-snap`, `-prereset` — backup slots
- `sapling-meta-v1` — eternal/Grove state

## Tips

- Sap from leaves flows **down** branches. Place amps where many leaves converge for the biggest multiplier effect.
- Refineries care about resin yield, not just throughput. Polish them for more resin per sap.
- Capacitors buffer surges but their burst can overflow thin downstream branches — thicken first.
- A locked node is immune to mistakes (and accidental pruning).
- Gold leaves fade after a few seconds. Big gold leaves (rarer, larger, orange) trigger a 30-second ×3 **Bloom** on all leaf production.
- Offline progress is capped at 4 hours, extended by Heartwood (Roots) and Endurance (Grove).

## Building from source

There is no build. Edit `index.html`, refresh the browser. The codebase is one file, with comments marking each subsystem (state, flow, render, critters, grove, etc.).

## License

MIT. Fork it, mod it, sell it. Send a screenshot when your tree gets weird.
