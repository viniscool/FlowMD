# FlowMD iOS

Native SwiftUI conversion of FlowMD. In Xcode, create an iOS App project named `FlowMD` using SwiftUI, add all files in this folder to the target, set the deployment target to iOS 17 or newer, add `Info.plist`, and enable the **HealthKit** capability using `FlowMD.entitlements`.

The app supports:

- Apple HealthKit authorization and native reads
- Importing Apple Health `export.xml` files through the Files picker
- Streaming-style XML record parsing into local app memory
- Personalized 30-day vs prior 30-day trend analysis
- On-device insight cards and patient view
- Optional localhost-only MCP bridge scaffold in `LocalMCPClient.swift`

HealthKit data is not sent to FlowMD’s web backend. The MCP bridge is intentionally disabled unless a local service is running at `127.0.0.1:8787`.
