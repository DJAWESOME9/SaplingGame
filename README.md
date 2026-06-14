# Sapling

An idle incremental game where you grow a tree, manage flowing resources, and unlock upgrades by pruning branches.

## How to Play

Open `index.html` in a browser — no build step or server needed.

Click nodes on the tree to open the action panel. From there you can grow new branches, upgrade existing nodes, and prune dead weight for amber.

## Resources

| Resource | Color | Source |
|----------|-------|--------|
| **Sap** | Yellow | Produced by leaf nodes; flows through the tree |
| **Resin** | Orange | Converted from sap by refinery nodes |
| **Amber** | Amber | Earned by pruning branches; spent on root upgrades |

## Node Types

- **Leaf** — produces sap passively; level up to increase output
- **Amplifier** — multiplies all sap flowing through it
- **Refinery** — converts sap into resin (more efficient at higher levels)
- **Capacitor** — stores flow and bursts it out with a bonus multiplier

## Root Upgrades

Unlocked by spending amber. Click the core node to see the roots panel. Upgrades are organized in tiers:

- **Tier 1** — Amplification, Rich Soil, Keen Shears
- **Tier 2** — Refining, Strong Wood, Grove, Taproot, Crown, Thrift, Heartwood
- **Tier 3** — Capacitance, Grafting, Stills, Vigor, Verdance, Canopy
- **Tier 4** — Wells, Surge, Distill, Fineness, Purity

## Tips

- Branch capacity limits flow; upgrade edges to widen throughput.
- Pruning a large branch yields more amber than pruning many small ones.
- The game saves automatically and credits offline progress (up to 4 hours, extendable with Heartwood).
- Use **Restore backup** in settings if you want to roll back, or **Cut down the tree** to start fresh.
