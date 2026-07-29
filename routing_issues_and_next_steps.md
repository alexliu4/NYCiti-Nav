# NYCiti Nav - Routing Issues Analysis and Next Steps

This document outlines an in-depth analysis of why entering an address in NYCiti Nav does not trigger routing/navigation, details the underlying technical and architectural bugs, and defines the explicit next steps required to resolve these issues.

---

## 1. Executive Summary

When a user attempts to enter an address, the NYCiti Nav application **fails to calculate or display any routes**. Through a detailed comparison of the active production branch (`main`) and the unmerged feature branch (`origin/feature/subway-map-setup-17063587865734986410`), the core reasons for this failure were identified:

1. **No Routing/Search Code on `main`**: The `main` branch only has basic map setup and static subway stations. No text field, search completion, or routing logic resides on `main` yet.
2. **Ignored Destination in `RoutingEngine`**: In the feature branch, the `RoutingEngine`'s calculation function (`calculateRoutes`) accepts a `destination: CLLocationCoordinate2D?` parameter but **completely ignores it**. It calculates route times and options purely based on proximity to the starting user location and subway stations, with no consideration of the destination or train ride routes.
3. **Invalid/Placeholder API Keys**: Both `Secrets.plist` and `Secrets.swift` utilize invalid placeholder values (`YOUR_ACTUAL_API_KEY_HERE` and `"GhgXFxYWFxYXFhcWFxYXFhcWFxYXFhc="` which decodes to invalid plaintext). This results in a persistent HTTP 401 Unauthorized status code returned by the Cloudflare Transit Proxy Worker.
4. **Incorrect/Outdated API Query Parameters**: Earlier versions used `lan` instead of `lat` as the query parameter for latitude, which returned HTTP 400 Bad Request error codes. While corrected in some commits, it must be thoroughly aligned across all environments.

---

## 2. Detailed Technical Breakdown & Issues Found

### Issue A: Completely Missing UI and State for Routing on `main`
On the `main` branch, the `ContentView.swift` file is a skeleton view containing only a basic Apple Map and annotations for the stations loaded from `SubwayEntrances.json`.
- There is no search bar, search autocomplete, or gesture to input/select a location.
- The `RoutingEngine`, `SearchViewModel`, `RouteSummaryCard`, and `TransitProxyModels` do not exist on `main` at all.
- Entering an address is impossible because there is literally no UI text field or key submission action.

### Issue B: The Destination Parameter is Ignored during Routing Calculations (Feature Branch)
In the unmerged feature branch where routing UI was introduced, `RoutingEngine.swift` implements the following route calculation logic:
```swift
func calculateRoutes(
    userLocation: CLLocationCoordinate2D,
    destination: CLLocationCoordinate2D? = nil,
    availableStations: [SubwayStation]
) async {
    do {
        let transitData = try await fetchTransitData(lat: userLocation.latitude, lon: userLocation.longitude)
        // ... (Sets up docks and walking/biking durations from userLocation to Subway Station) ...

        for station in availableStations {
            let walkToDockDuration = ...
            let bikeToStationDuration = ...
            let timeToPlatform = walkToDockDuration + bikeToStationDuration

            // ... (Calculates next subway arrivals for the station and platform wait) ...

            // BUG: It adds a constant 'trainRideBaseline' of 900 seconds (15 minutes) as a dummy fallback!
            let totalTrip = timeToPlatform + platformWait + trainRideBaseline

            let route = MultimodalRoute(
                id: station.id,
                station: station,
                startDock: bestDock,
                totalTripDuration: totalTrip,
                bikeDuration: timeToPlatform,
                platformWaitDuration: platformWait,
                trainRideDuration: trainRideBaseline
            )
            calculatedOptions.append(route)
        }
        // ...
    }
}
```
**Why this fails:**
- The destination coordinate `destination` is completely bypassed.
- It uses a hardcoded 15-minute train baseline (`trainRideBaseline`) regardless of where the destination is, or even if a destination is provided.
- Because it doesn't calculate the route to the actual destination, it cannot filter for subway stations that actually connect to the destination. It calculates a static list of walks/rides from the user location to the nearest subway platforms and labels it a "multimodal route".

### Issue C: Invalid API Credentials Triggering HTTP 401 Unauthorized
The app relies on a Cloudflare Transit Worker proxy at `https://nyc-transit-worker.transit-proxy.workers.dev/` that demands authentication.
- **`Secrets.plist`**: Contains the placeholder string `YOUR_ACTUAL_API_KEY_HERE`.
- **`Secrets.swift`**: Uses a hardcoded base64-encoded XOR obfuscated string `"GhgXFxYWFxYXFhcWFxYXFhcWFxYXFhc="` as a fallback. When decrypted using the salt `"NYCitiNavSalt2026"`, it yields `TAT~bYwaEvzc$'$!XNU~b~`, which is a placeholder key and not a valid app token.
- When calling `fetchTransitData`, the Transit Worker returns `HTTP 401: Unauthorized` plaintext.
- Because the server returns a plaintext error rather than JSON, decoding fails (`DecodingError.dataCorrupted` with `"Unexpected character 'U' around line 1, column 1."`), masking the auth issue with a JSON decoding error.

### Issue D: Query Parameter Naming Errors (HTTP 400 Bad Request)
Historically, the Transit Worker endpoint has returned HTTP 400 errors due to queries containing `lan` instead of `lat` for latitude. Although a fix was implemented in the feature branch, mismatched versions or reverting commits can easily break this unless standard parameters are strictly enforced.

---

## 3. Recommended Next Steps

To successfully enable multimodal routing, the following sequential development tasks must be executed:

### Step 1: Merge the Feature Branch and Clean up the UI
- Merge `origin/feature/subway-map-setup-17063587865734986410` into your working branch to bring in the `SearchViewModel`, `RoutingEngine`, and Map layout.
- Bind the Map camera viewport dynamically to frame the entire route once computed (User Location, Bike Dock, Subway Station, Destination).

### Step 2: Implement True Destination Routing Logic
- **MapKit Directions Integration**: Instead of a hardcoded 15-minute baseline (`trainRideBaseline`), use `MKDirections` or another transit routing service to estimate the actual transit ride duration from the subway station to the final `destination` address.
- **Filter Available Stations**: Filter or rank stations based on proximity to the destination, or verify that the subway line at the chosen station connects to a station close to the destination.

### Step 3: Configure and Provision Valid API Keys
- Obtain a valid Cloudflare Worker Transit API Key from the systems administrator.
- Create a local `Secrets.plist` in the `NYCiti Nav/Resources/` directory with the key:
  ```xml
  <key>AppAPIKey</key>
  <string>YOUR_VALID_API_KEY_HERE</string>
  ```
- Generate an obfuscated Base64 string for the new key and update the hardcoded `obfuscatedKeyBase64` fallback in `Secrets.swift`.
- Add `Secrets.plist` to `.gitignore` to prevent leaking production secrets.

### Step 4: Enhance Error Handling in `RoutingEngine`
- Explicitly intercept HTTP status 401 in `fetchTransitData` and throw a clear `RoutingError.unauthorized` error before parsing the JSON body. This avoids misleading "Unexpected character" decoding exceptions.
- Provide a user-facing alert or banner if an API key is invalid or if the server is down.

---

## 4. Verification Checklists

### Manual Testing Checklist
- [ ] User enters an address in the search bar and presses **Enter**.
- [ ] Autocomplete suggestions load and are selectable.
- [ ] After selecting a destination, map automatically frames the journey.
- [ ] Optimal route card appears showing:
  - Walk to nearby Citi Bike Dock.
  - Bike to Subway Station.
  - Subway transit time to destination.
- [ ] Route polyline renders correctly on the map.

### Automated Test Checklist
- Run tests using `xcodebuild`:
  ```bash
  xcodebuild test -scheme "NYCiti Nav" -destination "platform=iOS Simulator,name=iPhone 17"
  ```
- Ensure `RoutingEngineTests` and `NYCiti_NavTests` compile and pass.
