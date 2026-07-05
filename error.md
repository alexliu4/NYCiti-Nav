# NYCiti Nav - Known Errors and Warnings

This document tracks system-level errors and warnings encountered during development, along with their explanations and resolutions where applicable.

## 1. Network & Authentication Errors

### Error
`Server returned status 401: Unauthorized`
`Decoding failed. Response body: Unauthorized`
`Routing Error: DecodingError.dataCorrupted ... "Unexpected character 'U' around line 1, column 1."`

### Explanation
The "Unexpected character 'U'" error is a byproduct of the Cloudflare Worker returning a plaintext string ("Unauthorized") instead of the expected JSON. This happens when the `X-App-API-Key` header is missing, incorrect, or doesn't match the `APP_API_KEY` secret on the server.

### Resolution
1. **Check Secrets.plist:** Ensure `NYCiti Nav/Resources/Secrets.plist` exists and contains the correct `AppAPIKey` string.
2. **Target Membership:** Verify that `Secrets.plist` is included in the App's **Target Membership** in Xcode so it is bundled with the application.
3. **Obfuscation Sync:** If using the hardcoded fallback in `Secrets.swift`, ensure the `obfuscatedKeyBase64` string was generated using the matching `salt`.

---

## 2. Sandbox & Telemetry Warnings

### Error
`Connection error: Error Domain=NSCocoaErrorDomain Code=4099 "The connection to service named com.apple.PerfPowerTelemetryClientRegistrationService was invalidated: Connection init failed at lookup with error 159 - Sandbox restriction."`

`(+[PPSClientDonation isRegisteredSubsystem:category:]) Permission denied: Maps / SpringfieldUsage`

### Explanation
These warnings are triggered by the iOS system's telemetry and power usage reporting services (`PerfPowerServices`). When running in the Xcode Simulator or a sandboxed environment, the application is restricted from connecting to these specific system-level services.

### Resolution
**Outside of Scope:** This is a benign system-level warning. It does not impact the application's functionality or performance. It can be safely ignored.

---

## 3. MapKit Internal Rendering Warnings

### Error
`The variant selector cell index number could not be found.`

`clip: empty path.`

`iterating over too many half edges in walkCWEdgesIncidentToVertex incident to half edge (432968 = (144322, 2), interior)`

### Explanation
These are internal MapKit engine warnings related to tile rendering and geometry processing.

### Resolution
**Outside of Scope:** These are managed by Apple's frameworks and usually triggered by transient viewport conditions. They do not indicate an application-level bug.

---

## 4. General Guidance
To suppress noisy system-level logs in Xcode:
- Edit Scheme -> Run -> Arguments -> Environment Variables
- **Name:** `OS_ACTIVITY_MODE`, **Value:** `disable`
