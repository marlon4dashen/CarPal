# OBD Scan Mock Data

Deterministic OBD snapshots for developing and testing CarPal's assessment
engine without a vehicle or Bluetooth adapter.

## Layout

- `fixtures/` contains one JSON document per scenario.
- `schema.json` defines the fixture contract.
- `RESEARCH_NOTES.md` records the evidence model and source material.

Each fixture separates three concerns:

1. `captureContext` describes when the readings were taken. Live OBD values
   are not meaningful without engine state, temperature, and vehicle motion.
2. `rawScanData` mirrors CarPal's current `RawScanData` fields and metric names.
3. `obdEvidence` preserves important evidence the app does not retrieve yet,
   including MIL command, readiness monitors, and DTC state.

`expectedInterpretation` is an oracle for future tests. It intentionally uses
condition bands instead of exact scores because the current fixed scores are
not calibrated against inspection outcomes or Lexus service data.

## Scenarios

| Fixture | Primary evidence | Expected band |
| --- | --- | --- |
| `healthy-warm-idle.json` | Complete monitors, no codes, plausible warm-idle snapshot | `good` |
| `fuel-trim-degraded-no-dtc.json` | Sustained positive fuel correction without a stored DTC | `attention` |
| `mil-on-p0171.json` | MIL on, confirmed lean-condition DTC and freeze frame | `serviceSoon` |
| `flashing-mil-misfire.json` | Flashing MIL and confirmed cylinder misfire | `urgent` |
| `engine-overheating.json` | Very high coolant temperature while stationary | `urgent` |
| `low-running-voltage.json` | Low module voltage with the engine running | `attention` |
| `incomplete-after-reset.json` | Monitors incomplete and required readings absent | `unableToAssess` |

## Validation

Validate JSON syntax from the repository root:

```sh
for file in MockData/OBDScans/fixtures/*.json; do
  jq empty "$file"
done
```

The values are synthetic and are not diagnostic advice or claims about a real
vehicle. A fixture marked `good` means no issue was detected in the evidence
sampled; it does not establish whole-vehicle mechanical condition.
