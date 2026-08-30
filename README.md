# CarPal

CarPal is an iPhone app that turns standard OBD-II data into a cautious,
plain-language vehicle health summary for non-technical drivers.

<p align="center">
  <img src="CarPal/Assets.xcassets/LexusNX2020.imageset/lexus-nx-2020.png" width="720" alt="Lexus NX vehicle artwork used by CarPal">
</p>

## MVP

- Require an initialized Veepeak OBD session before registering one vehicle.
- Read VIN and available ECU identity through OBD Mode 09.
- Decode and normalize vehicle identity through the CarPal backend, with
  source-attributed user confirmation before local persistence.
- Unregister the saved vehicle and clear its scan history to restart registration.
- Check and connect to a Veepeak OBDCheck BLE adapter using CoreBluetooth.
- Initialize an ELM327 session and retrieve standard Mode 01 and Mode 03 data.
- Show a seven-stage scan, local scan history, and a conservative health result.
- Store vehicle and scan data locally with SwiftData.

The initial hardware target is a 2020 Lexus NX 300, an iPhone, and a Veepeak
OBDCheck BLE adapter. A real-device scan has completed successfully; broader
hardware validation is ongoing.

## Tech Stack

- Swift 6 and SwiftUI
- CoreBluetooth
- SwiftData
- Swift Testing
- FastAPI and Pydantic
- iOS 17+

## Run Locally

1. Open `CarPal.xcodeproj` in Xcode.
2. Select the CarPal target and configure your signing team.
3. Choose an iPhone or iOS Simulator and run the `CarPal` scheme.
4. Start the backend from `backend/` with
   `.venv/bin/uvicorn carpal_backend.main:app --reload`.
5. For a real device, set the Run scheme environment variable
   `CARPAL_BACKEND_URL` to your Mac's LAN URL, such as
   `http://192.168.1.20:8000`. The simulator defaults to
   `http://127.0.0.1:8000`.
6. Plug in the Veepeak adapter, turn on the ignition, and complete registration
   from the adapter-provided VIN before starting a scan.

Run the automated tests with:

```sh
xcodebuild -project CarPal.xcodeproj \
  -scheme CarPal \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

### Simulator Mock Registration

In **Product > Scheme > Edit Scheme > Run > Arguments**, enable:

```text
-useMockAdapter
```

Delete the app from the simulator first if a vehicle is already saved. This
argument runs the same registration gate with deterministic adapter, VIN, and
backend fixtures; it does not seed a profile or bypass `vehicleReady`.

## Current Limitations

- The MVP supports one vehicle and one adapter family.
- Health Scan eligibility is currently enabled only for the versioned 2020
  Lexus NX 300 diagnostic profile.
- The current health score is an early deterministic rule set, not a complete
  mechanical diagnosis.
- Backend-generated explanations and wider reliability validation are planned
  for later milestones.

See [Project Brief](documents/PROJECT_BRIEF.md) for product scope and
[Implementation Plan](documents/Impl/Implementation.md) for architecture and
milestone details.
