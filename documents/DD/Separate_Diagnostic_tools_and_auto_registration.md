# CarPal Product Discoveries & MVP Update

## Purpose

Capture two product discoveries that should influence CarPal's MVP design and implementation:

1. **Separate familiar OBD diagnostic tools from CarPal's intelligent scan workflows.**
2. **Automatically identify the connected vehicle using OBD vehicle information + VIN decoding.**

Background Monitor, persistent telemetry, and personal historical baselines remain post-MVP.

---

## Executive Summary

CarPal should not be designed as only an all-in-one health scanner. Mature OBD scanner apps expose individual capabilities such as trouble codes, live data, freeze frame, emissions readiness, ECU self-tests, and code clearing because users often have a specific diagnostic task in mind.

CarPal should support these familiar tools while keeping **Quick Scan** and **Health Scan** as the intelligent workflows that combine and interpret them.

Vehicle onboarding can also be simplified significantly. CarPal should attempt to read the VIN and available ECU information directly from the OBD interface, use the VIN to build a richer vehicle profile, and ask the user to confirm or correct the result. Manual make/model/year entry should become a fallback.

> **Updated product concept:** CarPal is an OBD diagnostic platform with familiar scanner tools underneath an intelligent layer that answers the simpler question: **"How is my car doing?"**

---

# Discovery 1 — Diagnostic Tools + Intelligent Scan Workflows

## Product Structure

```text
CarPal
├── AI Scan Workflows
│   ├── Quick Scan
│   └── Health Scan
│
└── Diagnostic Tools
    ├── Trouble Codes
    ├── Clear Codes
    ├── Live Data + Graphs
    ├── Record / Export Data
    ├── Freeze Frame
    ├── Emissions / Readiness
    └── ECU Self-Tests / Mode $06
```

The diagnostic tools are **capabilities**. Quick Scan and Health Scan are **workflows that orchestrate those capabilities**.

## MVP Diagnostic Capabilities

| Capability | Status | Requirement |
|---|---|---|
| Trouble Codes | MVP | Read stored, pending, and permanent DTCs; provide plain-language interpretation and supporting evidence. |
| Clear Codes | MVP | Explicit user action with warning that clearing can reset diagnostic context and readiness state. |
| Live Data | MVP | Browse supported PIDs, display real-time values, select signals, and graph them. |
| Record / Export Data | MVP-lite | Allow user-initiated recording/export without requiring long-term telemetry infrastructure. |
| Freeze Frame | MVP | Show operating conditions captured when a fault was detected; associate with the relevant DTC when possible. |
| Emissions / Readiness | MVP | Show supported, ready, and not-ready monitors and explain inspection readiness. |
| ECU Self-Tests / Mode $06 | MVP | Show ECU monitor results and limits where supported and translate them for non-technical users. |
| Acceleration Tests | Deferred | Useful enthusiast feature but not central to the health-focused MVP. |

## Quick Scan

Quick Scan is a user-initiated diagnostic snapshot that automatically performs the relevant underlying checks:

- Read stored, pending, and permanent DTCs.
- Read freeze-frame data where available.
- Read readiness / emissions monitor status.
- Read Mode $06 / ECU self-test results where supported.
- Capture a current live-data snapshot.
- Generate findings and an explainable **Quick Assessment**.

```text
DTCs + Freeze Frame + Readiness + Mode $06 + PID Snapshot
                          ↓
                    Quick Scan
                          ↓
                 Interpreted Findings
                          ↓
                  Quick Assessment
```

## Health Scan

Health Scan builds on the same capabilities, but continuously observes live OBD data during a user-initiated driving session.

```text
Live OBD Stream
      ↓
Operating Context / Driving-State Detection
      ↓
Rolling Diagnostic Windows
      ↓
Feature Extraction + ECU Evidence
      ↓
Diagnostic Findings
      ↓
Category Scores + OBD Health Score + Confidence
```

The same underlying data can therefore serve multiple user intents. **Live Data** can be a standalone technical tool while **Health Scan** consumes that stream and turns it into higher-level findings.

### Product Principle

Do not force every diagnostic task through Health Scan. Users should be able to access familiar tools directly while Quick Scan and Health Scan provide the differentiated **"interpret it for me"** experience.

---

# Discovery 2 — Automatic Vehicle Identification

## Objective

CarPal should not require manual make/model/year/engine entry when the vehicle can provide enough information to identify itself.

The app should first attempt to read standardized vehicle information from the OBD interface, especially the VIN, then enrich that VIN using a VIN decoder or vehicle-data service.

## Recommended Onboarding Flow

```text
Connect OBD Adapter
      ↓
Read Standardized Vehicle Information
      ↓
VIN + ECU / Calibration Information
      ↓
VIN Decoder / Vehicle Data Source
      ↓
Candidate Vehicle Profile
      ↓
User Confirms or Corrects
      ↓
Save Vehicle Profile
```

## Data Responsibilities

### OBD Interface

Potentially contributes:

- VIN
- ECU/module names
- Calibration IDs
- Other standardized vehicle/ECU information where supported

### VIN Decoder / Vehicle Data Source

Potentially contributes:

- Make
- Model
- Model year
- Engine characteristics
- Fuel type
- Drivetrain
- Transmission
- Other configuration data when encoded/available

### User Confirmation

Used to correct or complete ambiguous information such as:

- Trim
- Engine variant
- Drivetrain
- Option/package information

## Fallback Hierarchy

1. Read VIN from the connected OBD interface.
2. If unavailable, scan the VIN using the phone camera.
3. If scanning is unavailable, allow manual VIN entry.
4. Use manual make/model/year entry as the final fallback.

## Vehicle Profile Source and Confidence

CarPal should track the source of each vehicle attribute rather than treating the entire profile as equally certain.

```typescript
interface VehicleAttribute<T> {
  value: T;
  source: "OBD" | "VIN_DECODER" | "OEM_DATABASE" | "USER";
  confidence: number;
}
```

Example:

- VIN — OBD — very high confidence
- Make/model/model year — VIN decoder — high confidence
- Engine/drivetrain — VIN decoder or OEM data — confidence depends on coverage
- Trim/package — user confirmation when not uniquely identifiable

## Diagnostic Benefit

Automatic vehicle identification is not only an onboarding improvement. It is also an input to the diagnostic system.

Once CarPal identifies the engine and powertrain, it can progressively apply more specific rules:

```text
Generic OBD Rules
      +
Manufacturer Rules
      +
Engine / Powertrain Profile
      +
Future Personal Vehicle Baseline
      ↓
More Specific Diagnostic Interpretation
```

This supports the previously defined rule hierarchy and reduces reliance on universal hardcoded thresholds.

---

# Updated MVP Definition

The MVP should now be considered as three product layers:

| Layer | Scope | Status |
|---|---|---|
| Vehicle Identification | Automatic VIN-based setup with user confirmation and manual fallbacks | MVP |
| Core OBD Toolkit | Trouble codes, clear codes, live data/graphs, freeze frame, emissions/readiness, ECU self-tests, basic record/export | MVP |
| Intelligent Scan Workflows | Quick Scan and Health Scan combine the toolkit and generate findings, health/confidence outputs, and guidance | MVP |
| Passive Monitoring | Automatic drive detection, persistent telemetry, personal baseline, predictive degradation | Post-MVP |

## Recommended Top-Level App Model

- **Vehicle Home** — identified vehicle, connection status, latest assessment, Quick Scan, Health Scan.
- **Scans** — Quick Scan and Health Scan workflows.
- **Diagnostics / Tools** — Trouble Codes, Live Data, Freeze Frame, Emissions, ECU Self-Tests, Clear Codes, Export.
- **Vehicle Profile** — VIN-derived information, source/confidence, and manual correction.

---

# Recommended Implementation Order

1. Implement a canonical `VehicleProfile` and automatic VIN read/decode flow with user confirmation.
2. Expose core read-only OBD capabilities: supported PIDs, DTCs, readiness, freeze frame, Mode $06, and live data.
3. Build standalone diagnostic screens on top of those capabilities, including live-data graphs.
4. Implement Quick Scan as an orchestration layer over the existing capabilities.
5. Implement the continuous monitoring engine and Health Scan on top of the live-data stream.
6. Add safe write actions such as Clear Codes with explicit warnings and post-clear confidence handling.
7. Add lightweight session export if useful.
8. Defer persistent historical telemetry, Background Monitor, personal baselines, and acceleration testing.

---

# Product Positioning

> CarPal should not compete by exposing the most gauges. It should offer the scanner tools users already expect, automatically understand which vehicle it is connected to, and combine the available evidence into an understandable assessment of how the vehicle is behaving.
