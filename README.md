# Sapling

An idle/incremental game where the tree is simultaneously the map, the production line, and the upgrade screen. Sap flows from the leaves through amplifiers and refineries to the Core. You spend what you produce to grow the tree wider and deeper, prune branches into permanent advancement, and eventually fell the whole tree for eternal upgrades that carry over into the next sapling.

A single HTML file. Open `index.html` in a browser — no build step, no server.

## Controls

- **Click a node** to open its action panel (grow, upgrade, polish, prune, etc.)
- **Drag** to pan, **scroll** or **pinch** to zoom
- **Click the core** to reveal the Roots advancement tree underground
- **Click a leaf with a glow** to harvest a gold leaf
- **Hold (press and hold) a leaf** to channel a **Verdant Touch** surge once that ability is unlocked
- **Click a bug or bird** sitting on a node to scare it off (it deals one damage per click)
- **🪓 Cut** button in the topbar → fells the tree and opens the Grove (prestige)
- **🧴 Pesticide** (after Grove unlock) → arms a sap-cost toggle that stops critters; −15% leaf production while on (removed by **Symbiosis**)
- **🌰 Acorns** (after 1M lifetime sap) → ripen on the canopy in real time; tap to bank, long-press or right-click for the Pantheon
- **🏆 Achievements** → progress tracker in the topbar
- **⚙ Settings** → volume, restore backup, save code, intro, hard reset, cheat codes
- **Click the hint banner** to dismiss tutorial nudges for the current tree

## Resources

| Resource | Source | Spent on |
|---|---|---|
| **Sap** 🟡 | Leaves; produced passively, flows through the tree | Growing branches, upgrading most node types, thickening edges |
| **Resin** 🟠 | Refined from sap by Refinery nodes | Capacitors, grafting, polishing |
| **Amber** 🟤 | Pruning branches | Permanent Roots-tree advancement (per-tree) |
| **Rings** 🍃 | Cutting down a grown tree | Eternal Grove upgrades and species unlocks (across all trees) |
| **Acorns** 🌰 | Ripen on the canopy (~1 per 2h of active play; offline counts at 10% rate) | Pantheon gods and eternal acorn-tempo upgrades |

Acorns unlock after **1M lifetime sap** produced. A hint appears at 50% progress. Bank ripe acorns with the topbar 🌰 button; bank **3** to wake the **Pantheon**.

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

**Pruning** a branch sacrifices it and everything below it for **amber**, based on the branch's lifetime flow. Amber buys advancement in the Roots tree under the core. Payout has **diminishing returns** as the whole tree's connected lifetime flow grows, so a sprawling tree pays less per cut than a young one. The amber for a cut is *marginal* — the drop it causes in that curve — so dismantling a tree branch-by-branch banks exactly the same total as one trunk cut (the parts always sum to the whole). Fractional amber carries over between cuts so nothing is lost to rounding.

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
| Squirrelry | T3 / Nest | Acorns ripen 10% faster per level |
| Pesticide | T4 / Bramble | Unlocks the 🧴 pesticide toggle |
| Canopy Charm | T5 / Worldtree | Acorns ripen 20% faster per level, +1 max ripe slot per level |
| Symbiosis | T5 / Pesticide | Pesticide no longer costs −15% production |
| Born Refined, Born Charged | T3 | New refineries / capacitors begin +1 level higher per level |
| Thick Bark | T4 / Heartgirth | New branches start +1 thickness level higher per level (capacity from birth) |
| Golden Bough | T3 / Sunray | Gold leaves pay +25% more sap per level |
| Amber Heart | T4 / Crescent | Pruning yields +25% more amber per level |
| Verdant Touch | T4 / Sunray | Unlocks the **Channel** active ability |
| Everbloom | T5 / Verdant Touch | Channel surges last +3s and hit +50% harder per level |
| **Verdant Tide** | T5 / Everbloom | Channel surge pours into **every leaf at once**, not just the held one |

### The Channel (Verdant Touch)

Once **Verdant Touch** is bought in the Grove, a charge meter fills over real time. Press and **hold a leaf** to drain it and pour a ×(2 + level) production surge into *that one leaf*. **Everbloom** makes each surge last longer and hit harder; **Verdant Tide** spreads the surge across **all** leaves at once instead of just the one you're holding.

Grove upgrade cards offer **×1**, **×10**, and **Max** bulk-buy buttons showing how many levels fit your rings and the total cost.

## The Pantheon

Once you've banked 3 acorns, long-press or right-click the 🌰 button to open the Pantheon. Slot up to **3 tree-gods** on pedestals — each has a blessing and a curse that apply globally:

| God | Blessing | Curse |
|---|---|---|
| ☀️ Helios | +60% leaf production | Gold leaves ripen 50% slower |
| 🌙 Selene | Gold leaves pay ×2 sap | Leaf production −15% |
| 🌬️ Boreas | Amplifier multiplier ×1.5 | Branch capacity −25% |
| 🌾 Demeter | Refineries yield +75% | Capacitor storage −30% |
| 🪨 Atlas | Branch capacity ×1.5 | Amplifier multiplier −15% |
| ⚰️ Charon | Pruning gives ×2 amber | Sap production −15% |

Gods cost 2–3 acorns to first unlock, then can be swapped freely. Effects stack multiplicatively across slots.

## Critters

Birds and bugs occasionally land on producer nodes and **slow their throughput to 35%**. They no longer leave on their own — click them to scare them off (one damage per click; Strong Swat doubles it).

**Pesticide** (Grove upgrade) adds a topbar toggle. Arming it costs ~30 seconds of current sap production, immediately routes all critters off the tree, and prevents new spawns while active. Leaf production is −15% while armed unless you own **Symbiosis**.

## Blight mode (hard mode)

An opt-in hard mode for veterans, chosen from a checkbox on the first-run intro (or after a hard reset). Once active:

- **Critters swarm harder** and a bug left sitting on a leaf too long will **devour** it outright.
- **Leaf output is taxed −15%** for the whole run.
- **Every cheat code is disabled**, and the **Pesticide** / **Symbiosis** roots are locked out.
- Its own challenge achievements: **Into the Blight**, **Thorn Forester**, **Bloom in Blight**, **Devoured**.

It's a **one-way door**: you can leave via **Exit Blight mode** in the gear menu, but only after your first cut — and once you leave, you can't re-enter.

## Save data and settings

The game autosaves on a timer plus on visibility change. Come back after time away and a **Welcome Back** popup tallies the sap, resin, and acorn progress you banked while offline (subject to the offline rate and cap below). In the gear menu:

- **Restore backup** — roll back to a stashed snapshot (10-min, prereset, etc.)
- **Save Code** — Export to copy a UTF-8 base64 string of your full state; Import to load one (your current save is stashed to `-prereset` before overwrite)
- **Show intro** — re-read the first-run intro
- **Exit Blight mode** — appears only during a Blight run after your first cut; leaving is permanent
- **Hard reset** — wipes everything (current tree, rings, all upgrades, all backups). Double-confirmed.
- **Cheat codes** — type in the settings box (e.g. founder names for one-shot ×3 Bloom buffs; summon all six founders for the 🌳 Founders achievement). Disabled in Blight mode.

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
- Tutorial hints appear under the topbar — **click to dismiss**; they return when the game advances to a new hint. Cutting the tree resets dismissals.
- Offline progress is capped at 4 hours, extended by Heartwood (Roots) and Endurance (Grove). Offline time counts toward acorn ripening at 10% rate (~20h offline ≈ 1 acorn).

## Building from source

There is no build. Edit `index.html`, refresh the browser. The codebase is one file, with comments marking each subsystem (state, flow, render, critters, grove, etc.).

## License

MIT. Fork it, mod it, sell it. Send a screenshot when your tree gets weird.
