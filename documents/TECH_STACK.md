# TECH_STACK.md

# CarPal - MVP Tech Stack

## Summary

CarPal MVP should use a thin-backend architecture.

The iPhone app is the primary product runtime. It owns:

* Vehicle profile management
* BLE adapter discovery and connection
* OBD-II command flow
* Scan normalization
* Deterministic health checks
* Local persistence
* User-facing assessment presentation

The backend should stay small and support only the parts of the product that benefit from central control or secret management.

---

# 1. Chosen Stack

## iOS app

* Language: `Swift`
* UI framework: `SwiftUI`
* Bluetooth: `CoreBluetooth`
* Local persistence: `SwiftData`
* Networking: `URLSession`
* Charts and score visualization: `Swift Charts`
* Concurrency model: Swift concurrency with `async` and `await`

## Backend

* Language: `Python`
* API framework: `FastAPI`
* Application server: `uvicorn`
* Data validation: `Pydantic`
* Database: none required for the first MVP

## AI

* Provider: `OpenAI`
* API style: `Responses API`
* Output contract: structured output with deterministic post-validation

## Testing

* iOS unit and integration tests: `Swift Testing`
* iOS UI tests: `XCTest`
* Backend tests: `pytest`

---

# 2. System Boundaries

## Responsibilities on-device

The iPhone app should own:

* Vehicle creation, editing, and display
* BLE scanning and connection lifecycle
* Adapter initialization
* PID support discovery
* Core dataset retrieval
* Scan parsing and normalization
* DTC parsing
* Deterministic health rules
* Minimum-data gating
* `Unable to assess` decisions
* Local scan storage
* Rendering the final assessment UI

## Responsibilities in the backend

The backend should initially own:

* Calling the OpenAI API
* Maintaining versioned prompts and explanation policy
* Optionally enriching known DTC descriptions
* Returning structured explanation content to the app

## Responsibilities explicitly out of scope for the backend in MVP

The backend should not own:

* BLE communication
* Raw scan orchestration
* Real-time PID polling control
* Core score calculation
* Vehicle profile source of truth
* Mandatory cloud persistence

---

# 3. Data Flow

The MVP data flow should be:

1. User opens the app and manages one vehicle profile.
2. App connects to the Veepeak OBDCheck BLE adapter through `CoreBluetooth`.
3. App retrieves the predefined core OBD-II dataset.
4. App normalizes the raw results into internal scan models.
5. App runs deterministic health checks and decides:
   * scoreable assessment
   * or `Unable to assess`
6. If a valid assessment exists, the app sends a structured summary of validated findings to the backend.
7. Backend calls the OpenAI Responses API and returns structured explanation fields.
8. App validates the backend response and renders:
   * status
   * score when allowed
   * completeness/confidence
   * explanation
   * recommended next action
9. If the backend or AI response fails, the app falls back to a deterministic explanation.

---

# 4. Why This Stack

## Why native iOS

The hardest part of the MVP is reliable BLE communication with the adapter, not cross-platform UI reuse.

Using `SwiftUI` plus `CoreBluetooth` keeps the BLE path native and reduces integration risk.

## Why SwiftData

The MVP is local-first and single-vehicle. `SwiftData` is sufficient for storing the vehicle profile, scans, findings, and assessments without introducing extra infrastructure.

## Why thin backend

The backend gives us:

* API key protection
* safer AI integration
* prompt iteration without app rebuilds
* room for future DTC knowledge management

It avoids premature complexity by not taking over scan execution or primary state management.

## Why no database at first

The MVP does not need accounts, synchronization, or cloud history to validate the product.

A backend database should only be added when a real requirement appears, such as:

* cross-device sync
* shared scoring configuration
* centralized scan history
* analytics or audit needs

---

# 5. Initial Service Interfaces

## App-side modules

Suggested app modules:

* `VehicleProfile`
* `BluetoothAdapterClient`
* `OBDCommandClient`
* `ScanNormalizer`
* `HealthAssessmentEngine`
* `AssessmentExplanationClient`
* `PersistenceStore`

## Backend endpoints

Initial backend surface should stay minimal:

* `POST /v1/assessments/explain`
  * input: validated structured assessment summary
  * output: structured explanation payload

Optional future endpoints:

* `GET /v1/dtc/{code}`
* `GET /v1/prompt-version`

---

# 6. Rejected or Deferred Options

These options are intentionally not chosen for the MVP:

* `Flutter` or `React Native`
  * deferred because native BLE reliability matters more than shared UI code
* `Firebase` or `Supabase`
  * deferred because auth and sync are not MVP needs
* `PostgreSQL` in v1
  * deferred because the app is local-first
* server-owned scoring
  * deferred because the product must remain usable when backend explanation is unavailable
* fully on-device LLM explanation
  * deferred because prompt control and iteration speed matter more for the MVP

---

# 7. Acceptance Criteria for the Stack

The chosen stack is validated when:

* the iOS app can repeatedly connect to the Veepeak OBDCheck BLE adapter
* the app can retrieve and store the predefined core dataset on the target vehicle
* deterministic rules can produce a valid status or `Unable to assess`
* the backend can receive structured findings and return structured explanation content
* the app remains functional when the backend or AI call fails

---

# 8. Assumptions

* Initial target platform is iPhone only.
* Initial hardware target is `Veepeak OBDCheck BLE`.
* AI is used for explanation, not primary diagnosis or safety decisions.
* The backend is allowed but should remain optional for local scan storage and rule execution.
* Score weighting and threshold research will continue after the MVP technical foundation is in place.
