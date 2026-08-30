# CarPal

CarPal is an iPhone app that turns standard OBD-II data into a cautious,
plain-language vehicle health summary for non-technical drivers.

<p align="center">
  <img src="CarPal/Assets.xcassets/LexusNX2020.imageset/lexus-nx-2020.png" width="720" alt="Lexus NX vehicle artwork used by CarPal">
</p>

## MVP

- Register and edit one supported Lexus vehicle.
- Support Canadian Lexus NX and RX models from 2015 through 2026.
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
- iOS 17+

## Run Locally

1. Open `CarPal.xcodeproj` in Xcode.
2. Select the CarPal target and configure your signing team.
3. Choose an iPhone or iOS Simulator and run the `CarPal` scheme.
4. For a real scan, run on an iPhone, plug in the Veepeak adapter, turn on the
   vehicle, and use **Check** on the adapter card before starting the scan.

Run the automated tests with:

```sh
xcodebuild -project CarPal.xcodeproj \
  -scheme CarPal \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

### Simulator Mock Scan

In **Product > Scheme > Edit Scheme > Run > Arguments**, enable these as two
separate launch arguments:

```text
-seedPreviewVehicle
-useMockAdapter
```

Add `-startMockScan` to open and run the scripted scan immediately. Keep the
leading hyphen on every argument; without it, CarPal uses the live Bluetooth
client and waits for a physical adapter.

## Current Limitations

- The MVP supports one vehicle and one adapter family.
- Vehicle compatibility outside the documented Lexus NX/RX catalog is not
  guaranteed.
- The current health score is an early deterministic rule set, not a complete
  mechanical diagnosis.
- Backend-generated explanations and wider reliability validation are planned
  for later milestones.

See [Project Brief](documents/PROJECT_BRIEF.md) for product scope and
[Implementation Plan](documents/Implementation.md) for architecture and
milestone details.
