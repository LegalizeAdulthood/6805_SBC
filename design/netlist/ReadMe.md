# Netlist staging

This directory holds normalized, evidence-backed netlist information before it
is imported into KiCad.

The files are intentionally simple csv tables. Each connection should be one
atomic assertion, and every assertion should retain its source and confidence
status. This keeps inferred or unresolved wiring visible instead of silently
turning it into board design fact.

## Files

- `parts.csv`: reusable part definitions and preferred symbols or footprints.
- `components.csv`: board instances such as `U1`, `U2`, and `J1`.
- `pins.csv`: per-part pin names, pin numbers, and electrical metadata.
- `nets.csv`: named nets and their broad purpose.
- `connections.csv`: one net member per row.
- `aliases.csv`: equivalent names used by notes, datasheets, or schematics.
- `decisions.csv`: open or settled design choices that affect wiring.
- `sources.csv`: source documents referenced by other tables.

## Status values

Use these values consistently:

- `confirmed`: directly supported by a design document, datasheet, or schematic.
- `inferred`: derived from confirmed information but not stated directly.
- `todo`: intentionally unresolved.
- `conflict`: contradictory sources need review.

## Conventions

- Use stable net names from the design documents where possible, such as `A0`,
  `D0`, `AS`, `DS`, `R/~W`, `~ROMCS`, and `RTCCS`.
- Prefer `pin_number` plus `pin_name` when both are known.
- Leave `pin_number` blank when only the signal name is known.
- Use `aliases.csv` for context-dependent names, such as a multiplexed CPU pin
  that appears as address during one bus phase and data during another.
- Keep unresolved design choices in `decisions.csv`; do not encode them as
  final connections until the choice is made.
