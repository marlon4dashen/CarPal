# PROJECT_BRIEF.md

# CarPal - MVP Project Brief

## Overview

CarPal is an iPhone application that helps ordinary car owners understand basic vehicle health information without requiring mechanical knowledge.

The long-term vision remains broader: a trusted digital home for each vehicle a person owns. That is not the MVP.

The MVP is a narrow prototype that proves one thing:

> CarPal can turn real standard OBD-II data from one supported vehicle setup into a cautious, understandable next-step recommendation for a non-technical driver.

The current MVP has two product capabilities:

1. Register one vehicle and maintain its profile.
2. Connect to one supported BLE OBD-II adapter, retrieve standard diagnostic data, and produce a vehicle-health assessment with plain-language guidance.

The prototype should prioritize truthfulness, reliability, and clarity over breadth or polish.

---

# 1. Problem Statement

## Vehicle health information is difficult to interpret

Most drivers cannot tell whether a vehicle issue is minor, urgent, or harmless without consulting a mechanic.

OBD-II scanners expose diagnostic trouble codes, sensor readings, and operating data, but the output is typically too technical for an ordinary user to interpret confidently.

The user needs clear answers to practical questions:

* Is the vehicle operating normally right now?
* Is there an urgent issue?
* Can I continue driving?
* Should I schedule service?
* What should I do next?

CarPal exists to convert technical vehicle data into cautious, useful guidance.

## Vehicle information is scattered

Vehicle identity, history, and diagnostic information are often spread across many places. The MVP does not solve the full records-management problem.

The MVP only establishes the beginning of a digital vehicle home by combining:

* Basic vehicle profile information
* Recent scan results
* Health assessment history for that single vehicle

---

# 2. MVP Definition

CarPal MVP means:

* One iPhone application
* One user
* One registered vehicle in the shipped user experience
* One specifically supported BLE OBD-II adapter model
* One tested real-world vehicle environment
* One repeatable end-to-end scan and assessment workflow

The initial real-world test environment is:

* 2020 Lexus NX 300
* iPhone
* Veepeak OBDCheck BLE OBD-II adapter

The architecture should remain extendable to additional vehicles and adapters later, but the MVP must not promise broad compatibility.

---

# 3. Target User

The MVP user is an everyday car owner who:

* Has little or no mechanical knowledge
* Does not want to interpret raw OBD-II data
* Wants to understand whether a problem is urgent
* Wants a clear next action before deciding whether to visit a mechanic
* Wants a simple digital profile for their vehicle

The developer is the first user and first tester.

---

# 4. Core MVP Scope

## Part 1: Single-Vehicle Registration and Profile

The app should allow the user to create and maintain one vehicle profile.

Required vehicle fields for MVP:

* Vehicle nickname
* Make selected from the supported profile catalog
* Model selected from the supported models for that make
* Model year
* VIN or licence plate
* Current mileage

Optional enrichment fields for MVP:

* Trim
* Body colour from the supported CarPal colour palette
* Fuel type

The initial profile catalog supports:

* Lexus: NX 300, RX 350, IS 300, and ES 350
* BMW: 330i, 530i, and 740i

Model remains disabled until a make is selected. Changing make clears a model
that does not belong to the newly selected make.

The initial body-colour palette is white, black, silver, gray, red, blue, and
green. The initial fuel-type options are gasoline, diesel, hybrid, plug-in
hybrid, electric, and other. These lists must be shared by the setup UI,
validation, persistence normalization, and vehicle visual resolver.

The vehicle profile is the home screen for the vehicle and should display:

* A static vehicle image matched to the supported model and selected body colour
* Basic vehicle information
* OBD adapter connection status
* Latest scan time
* Latest assessment status
* Latest health score, only when a valid assessment is available

The MVP should support:

* Creating the vehicle profile
* Viewing the vehicle profile
* Editing the vehicle profile

The MVP does not need true multi-vehicle product behavior. Internal data models may remain extendable for multiple vehicles later.

### Vehicle image scope

Vehicle Home uses one static front three-quarter image. The MVP does not include
3D models, 360-degree rotation, or drag-to-rotate interaction.

CarPal maintains a finite on-device vehicle visual catalog. A vehicle is
visually supported only when its normalized make, model family, and body
generation map to an approved asset set. Model year is used to select the body
generation. The first implemented catalog entry is the 2020 Lexus NX 300.

Each supported asset set contains:

* One neutral, model-specific base render
* One pixel-aligned paint mask identifying only recolourable body panels

The app applies a selected colour token to the masked paint region at runtime
while preserving the base render's lighting, panel detail, windows, tires,
lights, grille, and trim. A normal full-colour image without a paint mask is not
considered a complete supported asset.

If no exact catalog entry exists, Vehicle Home displays a polished default-car
asset using the same runtime colour pipeline. It must not show artwork for a
different real model or imply an exact match.

The MVP uses a finite CarPal colour palette rather than arbitrary colour text.
Colours are representative categories, not guaranteed matches for every OEM
paint code or finish.

## Part 2: OBD-II Connection and Health Assessment

The app should connect to the single supported BLE adapter and complete a repeatable scan flow.

The workflow is:

1. Discover the supported adapter.
2. Establish a Bluetooth connection.
3. Initialize adapter communication.
4. Determine which standard OBD-II parameters are supported.
5. Retrieve the predefined core diagnostic dataset.
6. Normalize and store the scan results.
7. Run deterministic health checks.
8. Produce a health status and score when minimum data conditions are met.
9. Generate a plain-language explanation.
10. Recommend a next action.

Supported hardware in MVP:

* Veepeak OBDCheck BLE only

Anything beyond that adapter should be treated as future scope until explicitly validated.

---

# 5. MVP Data Policy

The MVP should score vehicle health from a small, fixed core dataset rather than from whatever data happens to be available.

The initial core dataset should include:

* Diagnostic trouble codes
* Freeze-frame data when available
* Engine RPM
* Vehicle speed
* Engine coolant temperature
* Calculated engine load
* Throttle position
* Short-term fuel trim
* Long-term fuel trim
* Control-module voltage
* Fuel-system status

Optional enrichment data may include:

* Intake-air temperature
* Airflow data
* Fuel level
* Engine runtime
* Vehicle identification number

Rules for missing data:

* Missing optional enrichment data is not a fault.
* Missing core data does not automatically mean the vehicle is unhealthy.
* Missing core data may prevent the app from producing a trustworthy score.

---

# 6. Health-Assessment Policy

The health assessment should combine:

* Deterministic software rules
* Diagnostic trouble code interpretation
* Vehicle context
* Data completeness
* AI-generated explanation of validated findings

AI must not be the primary decision-maker for safety-sensitive conclusions.

Deterministic logic should handle:

* Minimum data gating
* Known DTC interpretation
* Threshold-based checks that are validated for MVP use
* Score eligibility
* Recommended action categories

AI should only help with:

* Translating technical findings into plain language
* Summarizing multiple validated observations
* Explaining why a finding matters
* Describing urgency
* Communicating uncertainty

The app must never guarantee that a vehicle is safe and must never claim to replace a professional mechanic.

## Assessment gate

The app must be allowed to refuse scoring.

CarPal should show `Unable to assess` instead of a reassuring score when any of the following is true:

* The adapter connection is incomplete or unstable
* The scan did not retrieve the required minimum core dataset
* The engine state or scan context makes the result unreliable
* Deterministic validation fails

When the result is incomplete or ambiguous, the product should default to conservative language such as monitoring or arranging inspection rather than presenting a strong positive conclusion.

---

# 7. Health-Assessment Output

Each completed scan should produce a user-facing summary with the following fields:

* Overall status
* Overall score from `0` to `100`, only when minimum assessment conditions are satisfied
* Last scan time
* Confidence or data-completeness indicator
* Plain-language explanation
* Recommended next action

Suggested statuses:

* Excellent
* Good
* Attention recommended
* Service soon
* Urgent warning
* Unable to assess

The score is a heuristic estimate based on available standard OBD-II data. It is not a guarantee of safety or mechanical condition.

Category scores are optional in MVP and should only be shown when enough relevant validated data exists. The brief does not freeze category weighting or score formulas yet; those require further research and testing.

Recommended next actions may include:

* No immediate action required
* Continue monitoring
* Schedule routine service
* Arrange a diagnostic inspection
* Stop driving when safe
* Seek immediate professional assistance

---

# 8. AI Contract

AI behavior in the MVP should be constrained.

AI input should be structured and validated before submission. It should contain:

* Vehicle context needed for interpretation
* Deterministic findings
* DTC interpretations
* Score or status outcome
* Confidence and data-completeness context
* Disallowed claims or safety boundaries

AI output should also be structured and limited to:

* Plain-language summary
* Why the main findings matter
* Urgency explanation
* Recommended next action phrasing
* Uncertainty or limitation wording

If AI fails, times out, or returns invalid output, the app must still show a deterministic fallback explanation and next action based on validated findings.

AI should never generate unsupported repairs, guarantee safety, or overrule deterministic assessment gates.

---

# 9. MVP User Experience

A successful MVP should allow the user to complete this workflow:

1. Open the app.
2. Register one vehicle.
3. View the vehicle profile.
4. Plug the supported adapter into the vehicle.
5. Connect the app to the adapter.
6. Run a scan and retrieve the predefined core diagnostic dataset.
7. Save the scan to the vehicle profile.
8. View either:
   * a health status, score, explanation, and next action
   * or `Unable to assess` with a clear reason
9. Understand what to do next without reading raw OBD-II data.

Detailed screen flows, error cases, and interaction copy should move into `USER_WORKFLOWS.md` or `docs/user-workflows/`.

---

# 10. MVP Success Criteria

The MVP is successful when all of the following are true:

* A user can create, view, and edit one vehicle profile.
* The app can repeatedly connect to the Veepeak OBDCheck BLE on the target setup.
* The app can repeatedly retrieve and parse the predefined core OBD-II dataset on the target vehicle.
* Scan results are stored and associated with the vehicle profile.
* Diagnostic trouble codes are detected and interpreted when present.
* The app shows status, explanation, and next action for completed valid scans.
* The app shows `Unable to assess` when minimum assessment conditions are not met.
* Confidence or data completeness is visible to the user.
* A non-technical user can more accurately state the issue urgency and next action after using CarPal than they could from raw OBD-II output alone.

The primary validation question is:

> Does CarPal help an ordinary driver make a better immediate decision from real vehicle data?

## Real-world proof standard

The MVP is not proven by a one-time demo.

It should be validated through repeatable real-world scans on the target vehicle and adapter combination across multiple sessions.

---

# 11. Non-Goals for the MVP

The MVP will not attempt to:

* Replace a mechanic
* Provide a certified vehicle inspection
* Predict every possible failure
* Control vehicle systems
* Modify ECU settings
* Clear diagnostic trouble codes
* Support manufacturer-specific diagnostics
* Support more than one adapter model
* Support broad multi-vehicle household workflows
* Manage insurance policies
* Store registration or licence documents
* Retrieve complete repair or accident histories
* Integrate with CarPlay
* Train a proprietary AI model
* Build a mechanic marketplace
* Render interactive 3D vehicles or provide 360-degree vehicle rotation
* Generate vehicle artwork at runtime
* Provide exact imagery for every make, model, trim, or model year
* Reproduce every manufacturer paint code or finish exactly

---

# 12. Design Principles

## Explain, do not overwhelm

Prioritize useful conclusions over raw technical detail.

## Safety before confidence

When information is incomplete, the product should say so clearly.

## Evidence before conclusions

Every assessment must be grounded in retrieved vehicle data or explicit vehicle context.

## AI with guardrails

Use deterministic logic for validated checks and AI for explanation only.

## Start narrow

Solve one vehicle, one adapter, and one workflow reliably before expanding.

## Vehicle-independent core

Use a normalized model around standard OBD-II information so broader support can be added later without rewriting core concepts.

## Privacy by design

Collect and transmit only the information needed to deliver the requested functionality.

---

# 13. Initial Technical Direction

The MVP should use a thin-backend architecture.

The mobile app owns the user experience, BLE communication, scan execution, local persistence, and deterministic health checks.

The backend should remain intentionally small and should only exist for responsibilities that are safer or easier to manage off-device.

## Mobile

* Swift
* SwiftUI
* Core Bluetooth
* SwiftData for local persistence
* Asset catalogs and a masked image compositor for static vehicle visuals
* URLSession for backend communication
* iOS-first delivery

## Vehicle integration

* Veepeak OBDCheck BLE adapter
* Standard OBD-II modes and parameter identifiers
* A normalized internal scan format

## Backend

The backend should be thin and initially responsible for:

* AI requests
* Diagnostic-code knowledge
* Versioned prompt and explanation policy management
* Future scoring configuration if needed

The backend should not be responsible for BLE communication, raw scan orchestration, or core app state.

Initial backend technologies:

* Python
* FastAPI
* No required database in the first prototype

If centralized persistence becomes necessary later, add a relational database at that point.

The MVP should remain local-first. Vehicle profiles, scan results, and deterministic assessment inputs should live on-device first, with the backend used only where it materially reduces risk or iteration cost.

## AI

* OpenAI Responses API
* Structured input
* Structured output
* Deterministic validation before display
* Deterministic fallback if generation fails

---

# 14. Key Risks and Open Questions

The MVP should help answer these questions, but they should not expand scope during initial implementation:

* How stable is repeated BLE communication on the target setup?
* Which validated thresholds are safe enough for MVP use?
* Which scan contexts should block scoring and force `Unable to assess`?
* How should confidence and completeness be communicated most clearly?
* Which data must remain on-device?
* What legal, privacy, or automotive-safety review is required before broader release?
* How should the scoring formula evolve after additional research and real-world testing?

---

# 15. Current Product Definition

For the initial implementation, CarPal is:

> An iPhone application that allows a user to register one vehicle, connect to a single supported BLE OBD-II adapter, retrieve a predefined core set of standard diagnostic data, and receive a cautious, plain-language vehicle-health assessment with a recommended next action.

Anything outside this definition should be treated as future scope unless it is necessary to complete the core MVP workflow.

---

# Appendix A: Example Interpretation

Example raw data:

* Coolant temperature: `98 C`
* Short-term fuel trim: `+12%`
* Diagnostic code: `P0171`
* Control-module voltage: `12.1V`

What the user needs to understand:

* Whether the findings look normal
* Whether the issue seems urgent
* Whether continued driving may be reasonable
* Whether a mechanic visit should be scheduled
* What action should be taken next

Example CarPal explanation:

> The engine is detecting a lean air-fuel mixture. The vehicle may still be drivable if it feels normal, but the issue should be inspected soon. A likely next step is arranging a diagnostic inspection.
