# NYCiti Nav - Known Errors and Warnings

This document tracks system-level errors and warnings encountered during development, along with their explanations and resolutions where applicable.

## 1. Sandbox & Telemetry Warnings

### Error
`Connection error: Error Domain=NSCocoaErrorDomain Code=4099 "The connection to service named com.apple.PerfPowerTelemetryClientRegistrationService was invalidated: Connection init failed at lookup with error 159 - Sandbox restriction."`

`(+[PPSClientDonation isRegisteredSubsystem:category:]) Permission denied: Maps / SpringfieldUsage`

### Explanation
These warnings are triggered by the iOS system's telemetry and power usage reporting services (`PerfPowerServices`). When running in the Xcode Simulator or a sandboxed environment, the application is restricted from connecting to these specific system-level services.

### Resolution
**Outside of Scope:** This is a benign system-level warning. It does not impact the application's functionality or performance. There is no developer-accessible configuration to "fix" this, as it is a limitation of the Simulator's sandbox environment. It can be safely ignored.

---

## 2. MapKit Internal Rendering Warnings

### Error
`The variant selector cell index number could not be found.`

`clip: empty path.`

`iterating over too many half edges in walkCWEdgesIncidentToVertex incident to half edge (432968 = (144322, 2), interior)`

### Explanation
* **Variant Selector:** Internal MapKit warning regarding the selection of specific map tile variants or UI components.
* **Empty Path:** Core Graphics warning when the rendering engine attempts to clip a drawing operation to a path with no area (often happens during rapid zoom or transition animations).
* **Half Edges:** A low-level geometry error within the vector map engine. It indicates that the rendering engine encountered a highly complex or malformed piece of geometry in a map tile.

### Resolution
**Outside of Scope:** These are internal to Apple's `MapKit` and `CoreGraphics` frameworks. They are usually transient and triggered by specific viewport conditions or edge cases in map tile data. They do not indicate a bug in the application logic. If these cause noticeable lag, simplifying custom annotation view hierarchies can help, but the warnings themselves are managed by the OS.

---

## 3. General Guidance
If the logs become too noisy during development, you can suppress most system-level OS logs by adding an Environment Variable in your Xcode Scheme:
- **Name:** `OS_ACTIVITY_MODE`
- **Value:** `disable`

*Note: Use this with caution as it may also suppress useful error messages from your own code.*
