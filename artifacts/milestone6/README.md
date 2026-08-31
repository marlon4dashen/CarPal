# Milestone 6 Emulator Evidence

Captured on an iPhone 17 Pro simulator using the debug scripted-adapter path.

| File | Scenario |
| --- | --- |
| `01-launch.png` | Vehicle Home with the Scans / Diagnostic Tools workspace control |
| `02-trouble-codes.png` | Loaded confirmed, pending, and permanent DTC groups |
| `03-readiness.png` | Loaded MIL status and supported readiness monitors |

The diagnostic screens were launched deterministically with:

```text
-useMockAdapter -openMockTroubleCodes
-useMockAdapter -openMockReadiness
```

These flags are compiled only in Debug builds. They still prepare the scripted
adapter session before navigation and do not change production routing.

This evidence verifies simulator layout and scripted capability behavior. It
does not replace real Veepeak/NX hardware testing or device-to-backend network
validation.
