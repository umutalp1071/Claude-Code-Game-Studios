# Terrarium — Concept Prototype

## Hypothesis
If the player tends a small terrarium (watering, repositioning objects) and the
ecosystem drifts over time between visits, they will feel curious satisfaction
noticing what changed — evidenced by spontaneously pointing out a specific
change without being prompted, within their first couple of visits.

## How to Run
Open `prototype.html` directly in a browser. Single self-contained file, no
build step, no server needed.

## Status
Concluded — verdict **PROCEED** (see `REPORT.md` for full findings).

## Findings
The core loop read as legible, not random: watering → moisture → moss
growth/decay → creature appearance/departure was consistently understood by
the tester. The main gap found was possibility-space depth — the tester
exhausted the small state space (3 moss patches, 1 creature, no environmental
variables) within 5-10 "time pass" cycles, after which anticipation dropped
off. This directly shaped `ecosystem-simulation.md`'s later design (staggered
plant types, a second `light_level` variable, condition-based creature
spawning) rather than being treated as a shortcoming to just fix here.

Full detail, tuning values discovered, and recommendations: `REPORT.md`.
