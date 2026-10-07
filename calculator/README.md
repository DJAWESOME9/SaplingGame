# Sapling for TI-84 Plus CE

A graphical TI-BASIC edition: a colored tree with a Core, individually selected
leaves, amplifiers, and refineries. Sap flows through branches into your bank;
pruning earns amber for Roots upgrades. Runs from the normal PRGM menu.

## Install and play

1. Install [TI Connect CE](https://education.ti.com/en/products/computer-software/ti-connect-ce-sw).
2. Connect your TI-84 Plus CE by USB and open `SAPLING.8xp` in the Program Editor.
3. Send it to the calculator's **RAM**, named **SAPLING**. When updating the old
   edition, replace the existing SAPLING program; keep the SAPCE save list.
4. Press **PRGM**, select **SAPLING** in **EXEC**, and press **ENTER** twice.
5. If prompted to turn on the clock, execute **ClockOn** from **2nd → 0
   (CATALOG)** on the home screen and run the program again.

| Key | Action |
| --- | --- |
| **Left / Right** | Cycle through existing nodes |
| **Up** | Select the parent |
| **Down** | Select the first child |
| **1** | Grow a leaf under the selected Core, amplifier, or refinery |
| **2** | Grow an amplifier from the selected Core |
| **3** | Grow a refinery from the selected Core |
| **4** | Upgrade the selected node with sap |
| **5, then 5 again** | Prune the selected node and its children into amber |
| **6** | Buy a Roots upgrade with amber |
| **7** | Polish the selected refinery with resin |
| **0** | Harvest 1 sap manually |
| **CLEAR** | Save and quit |

The blue ring marks your selection. **C** is the yellow Core, **L** is a green
leaf, **A** is a magenta amplifier, and **R** is an orange refinery. The upper
HUD shows sap, resin, income per second, amber, and Roots level. The lower panel
shows the selected node, purchase prices, and messages.

Start by selecting the Core with Up and growing another leaf. Later, grow an
amplifier from the Core, then select it and grow leaves beneath it. A new empty
amplifier produces nothing until leaves feed it. A refinery needs leaves in the
same way. If all three Core slots are occupied by leaves, prune one to make room
for an amplifier or refinery.

## Economy and tree limits

A new game starts with 12 sap and one level-1 leaf. The Core has three child
slots. Amplifiers and refineries directly under the Core each have three leaf
slots, for up to 13 visible nodes including the Core. Terminal nodes cannot grow
another tier. Left/Right selection includes only existing nodes.

- Each leaf makes `1.4^(level − 1)` sap per second, multiplied by Roots bonuses.
- An amplifier multiplies the combined incoming **sap** by
  `2 + 0.5 × (level − 1)`. It passes resin through unchanged. These are the
  browser game's base amplifier values.
- A refinery converts incoming sap to resin at
  `max(6, 18 − 0.9 × (level − 1))` sap per resin. It passes incoming resin through.
- Leaves and amplifiers use the browser game's base upgrade curves: leaf sap
  cost `20 × 1.8^(level − 1) × 1.25^(leaf count − 1)`; amplifier sap cost
  `80 × 2.8^(level − 1) × 1.5^(amplifier count − 1)`. Prices are rounded.
- New leaf, amplifier, and refinery prices start at 8, 80, and 150 sap and rise
  with existing counts by ×1.35, ×1.5, and ×1.5 respectively.
- A refinery upgrade costs `150 × 2.2^(level − 1)` sap, or you can polish it for
  `5 × 1.8^(level − 1)` resin. Both raise its level by one.
- Pruning pays at least 1 amber, otherwise the floor of total removed levels / 3.
  This is a simplified calculator rule; the browser uses branch lifetime flow.
- Roots cost `5 + 3 × current Roots level` amber and add 15% leaf output per level.

Leaves cap at level 20, amplifiers/refineries at 10, and Roots at 10. Resource
banks cap at 1 billion. Production runs while the program is open, using whole
seconds from the calculator clock. Drawing delays are credited on the next
iteration. The tree redraws when selection or structure changes; the resource
HUD updates as time advances.

This edition currently omits edge capacity, capacitors, critters, gold leaves,
Grove/prestige, online features, and offline production. It uses a fixed tree
layout sized for the calculator display.

## Saves and migration

**ʟSAPCE** is the persistent save. Version 2 stores:
`{2, sap, resin, amber, Roots level, selected node, legacy canopy multiplier,
13 node types, 13 node levels}` (33 elements). Node types are 0=empty, 1=leaf,
2=amplifier, 3=refinery, 4=Core. Nodes 2–4 attach to the Core; nodes 5–13 attach
to those three branches in groups of three.

The first launch upgrades a valid version-1 save automatically. It copies the
original four-element list to **ʟSABAK**, retains your sap and enrichment level,
and rolls your old leaf count into a permanent canopy multiplier. Your starting
production is preserved, and new leaves receive that multiplier too. Future
launches load version 2 directly. Unsupported saves stop without overwriting
SAPCE. Back up SAPCE and SABAK with TI Connect CE before manually changing them.

Autosaving occurs after elapsed production and actions, and CLEAR saves before
quitting. Normal power-off preserves the RAM save; a RAM reset or deleting SAPCE
loses it. Keep SAPCE unarchived while playing. Browser saves use another format.
No sap is credited for time after quitting or powering off. **ON → Quit** keeps
only the last autosave, so use CLEAR for a normal exit.

To start a new tree and reset progress, quit and delete **SAPCE** through
**2nd → + (MEM) → Mem Management/Delete → List**, then relaunch. SABAK remains a
backup of the old text edition; it is not loaded automatically. To restore that
backup, quit and store `ʟSABAK→ʟSAPCE` from the home screen, then run SAPLING.

## Calculator settings and source

The game uses global variables **A–H, I–Q, R–Z** as scratch space. It uses named
lists **SATYP, SALVL, SAX, SAY, SAFLW, SARFL** for node state, positions, and flow.
These scratch lists are rebuilt from SAPCE each launch. Keep SAPCE and SABAK
when cleaning up game variables.

The program selects **Full, Float, Real, Func**, turns off functions/stat plots,
axes, grids, labels, expressions and the graph background, changes the graph
window to 0–264 by 0–164, and sets graph text color. It preserves equation and
other list contents. Restore your graph/MODE settings after playing as needed.
`SetUpEditor` displays SAPCE in the statistics editor; execute SetUpEditor without
arguments to restore the default statistics columns.

- `SAPLING.txt`: readable source; commands, `ʟ`, and `→` must be TI tokens when
  entered manually.
- `SAPLING.8xp`: transferable TI-BASIC program.
- `build.py`: standard-library Python packager. Rebuild from the project root:

  ```sh
  python3 calculator/build.py
  ```

The packager supports this program's token subset. Token values follow the
[TI-Toolkit token sheet](https://github.com/TI-Toolkit/tokens/blob/main/8X.xml);
file structure follows the
[TI-Toolkit variable library](https://github.com/TI-Toolkit/tivars_lib_py/blob/main/tivars/var.py).
Drawing commands and colors follow the
[TI-84 Plus CE reference guide](https://education.ti.com/download/en/ed-tech/158B7669E4C0493A84D33D9A22FDBD3C/D45832F01B5347A9AFD7B0ABCC594ABD/TI84_Plus_CE_ReferenceGuide_EN.pdf).

## Validation status

The package's token stream, color/clock header, lengths, checksum, source
round-trip, and control-block nesting were checked. Device execution, graphical
layout, and key responsiveness still need confirmation on a TI-84 Plus CE.

For a first device check: launch, verify the tree and growing sap bank, select
the Core and grow an amplifier, add two leaves beneath it, and check their
combined output is doubled. Upgrade the amplifier and check ×2.5 output. Add a
refinery with leaves and confirm resin increases. Prune a branch with two presses
of 5, spend amber on Roots, then quit and relaunch to confirm the saved topology,
levels, resources, and selection. Check an existing version-1 save migrates and
keeps its prior production rate.
