# Mechanical Condition Scoring Research

Research date: 2026-08-29

## Key Finding

Generic OBD-II is primarily an emissions and powertrain fault-detection system.
It cannot inspect brakes, tires, suspension, body condition, fluid quality, or
many manufacturer-specific modules. CarPal should call its result an **OBD
health assessment**, not a comprehensive mechanical-condition score.

No DTC is not proof of good condition. EPA explains that a `not ready` monitor
has not completed its subsystem test, so an empty DTC list provides no positive
evidence for that monitor. CARB similarly notes that incomplete readiness can
follow a battery disconnect or code clear and does not itself prove a defect.

## Proposed Decision Order

1. **Evidence gate:** Require a known engine state, successful DTC query,
   required readings, and adequate monitor readiness. Return `unableToAssess`
   instead of penalizing missing evidence.
2. **Safety override:** Give credible imminent-risk evidence precedence, such
   as extreme coolant temperature or a flashing MIL associated with severe
   misfire. Do not average urgent evidence away.
3. **OBD fault evidence:** Evaluate MIL command and confirmed, pending, and
   permanent DTCs. Categorize by affected subsystem and consequence rather than
   assigning the same deduction to every code.
4. **Contextual live data:** Interpret RPM, load, coolant, fuel trim, throttle,
   and voltage only against capture conditions. Prefer sustained samples and
   cross-signal agreement over a single value.
5. **Result confidence:** Report confidence/completeness separately from the
   condition band. More available data increases confidence, not health.

## Initial Criterion Matrix

| Evidence | Interpretation | Result behavior |
| --- | --- | --- |
| DTC query unavailable or required engine-state data absent | Insufficient evidence | No score; request another scan |
| Too many applicable readiness monitors incomplete | Subsystems have not finished self-tests | No positive credit for no-DTC result |
| MIL off, monitors complete, no DTCs, coherent warm sample | No OBD-detected issue in sampled systems | `good`, with scope disclaimer |
| Abnormal live-data trend without DTC | Possible developing issue or invalid capture context | `attention`; confirm with repeat/profile |
| Confirmed DTC with MIL on | ECU has identified an emissions/powertrain fault | At least `serviceSoon`; classify by code |
| Flashing MIL / severe active misfire evidence | Potential catalyst-damaging event | `urgent`; reduce driving and diagnose |
| Extreme coolant temperature corroborated by warm running state | Overheat risk | `urgent`; stop-driving guidance |

## Data Gaps To Close

Before replacing the current scorer, retrieve these standard OBD signals:

- MIL command and number of emission-related DTCs (Mode 01 PID 01).
- Readiness status for each applicable monitor (Mode 01 PID 01).
- Pending DTCs (Mode 07) and permanent DTCs (Mode 0A), not only stored codes.
- Engine run time and intake-air temperature to establish capture context.
- A short time series at defined profiles, initially warm idle and steady RPM.

Manufacturer-specific Lexus data can improve coverage later, but thresholds
must be scoped by engine/powertrain and model year. For example, an NX hybrid
cannot be evaluated with the same idle assumptions as a conventional RX.

## Sources

- US EPA, [On-Board Diagnostic Regulations and Requirements Q&A](https://nepis.epa.gov/Exe/ZyPURL.cgi?Dockey=P100LW9G.TXT): OBD monitors emissions-related and selected engine systems and illuminates the MIL when deterioration or malfunction is detected.
- US EPA, [Evaluation of OBD Systems](https://nepis.epa.gov/Exe/ZyPURL.cgi?Dockey=P100KPTW.TXT): a ready monitor has completed its test; a not-ready monitor supplies no conclusion about whether a malfunction exists.
- California Air Resources Board, [OBD II Systems Fact Sheet](https://ww2.arb.ca.gov/resources/fact-sheets/board-diagnostic-ii-obd-ii-systems-fact-sheet): explains MIL behavior and why incomplete readiness is not equivalent to a vehicle fault.
- US EPA, [OBD II Test Procedures](https://www.epa.gov/sites/default/files/2018-02/documents/table_e_ut_section_x_vehicle_inspection_and_maintenance_program.pdf): inspection logic treats commanded-on MIL and readiness as distinct evidence.
- US EPA, [40 CFR 86.005-17](https://www.govinfo.gov/content/pkg/CFR-2006-title40-vol18/pdf/CFR-2006-title40-vol18-chapI-subchapC.pdf): a blinking MIL identifies an active misfire condition for which catalyst damage is imminent.
- Lexus Tech Tip L-TT-0242-18, [Engine Coolant Temperature Gauge Diagnosis](https://static.nhtsa.gov/odi/tsbs/2019/MC-10169437-9999.pdf): requires corroborating gauge, Techstream, and physical temperature evidence rather than trusting one display value.
- Lexus Service Bulletin L-SB-0008-21, [MIL ON With Companion Cylinder Misfire DTCs](https://static.nhtsa.gov/odi/tsbs/2021/MC-10198143-9999.pdf): demonstrates that Lexus diagnosis uses DTC combinations, freeze-frame context, and misfire counts.

## Current Engine Gap

`HealthAssessmentEngine` currently maps all complete no-DTC scans to `92`, any
first DTC to `68`, and coolant at or above `115 C` to `28`. These numbers are
useful UI placeholders but are not evidence-based mechanical scores. The
`fuel-trim-degraded-no-dtc` and `low-running-voltage` fixtures intentionally
expose cases that the current implementation would incorrectly label `good`.
