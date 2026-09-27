# NYCiti Nav

SwiftUI NYC map and destination directions, with a Cloudflare Worker for live transit data.

## Run

Open `NYCiti Nav.xcodeproj` in Xcode. Select the NYCiti Nav scheme and an iOS 26.2+ device or simulator. Allow location access; in Simulator, set a simulated NYC location if needed. Search for a destination to preview walking directions or open transit navigation in Apple Maps.

For live Worker data:

1. Copy `docs/Secrets.example.plist` to `NYCiti Nav/Resources/Secrets.plist`.
2. Set `AppAPIKey` to the value configured as `APP_API_KEY` on your Worker. Do not commit this file.
3. Verify the file is included in the app target and built app bundle. The project uses a synchronized app source folder.

Without a key, destination directions still work and the app displays a configuration message. No fabricated fallback key is shipped. A bundled key is extractable from an app; protect the Worker with server-side rate limits and appropriate upstream credential handling.

## Worker contract currently expected by the app

GET `https://nyc-transit-worker.transit-proxy.workers.dev/?lat=40.7549&lon=-73.9840`

Headers: `X-App-API-Key: <configured value>`, `Accept: application/json`.

```json
{
  "lastUpdated": 1790145000,
  "bikeStations": [
    { "id": "dock-1", "bikes": 2, "docks": 3, "lat": 40.75, "lon": -73.98 }
  ],
  "subwayTimes": [
    { "stationId": "L08", "arrivals": [
      { "routeId": "L", "nextArrivals": [1790145300] }
    ] }
  ]
}
```

This documents the client contract, not a verified authenticated Worker response. The Worker source is outside this repository. Timestamps are Unix seconds; coordinates are optional but must never be fabricated. HTTP errors are checked before JSON decoding. Worker validation messages are shown with bounded length and the configured key redacted; decoding errors identify the failing field.

## Navigation scope and remaining work

The previous planner ignored the destination, randomized bike dock locations, treated driving geometry as a bike route, and added a fixed 15-minute train journey. Those results could not take a rider to the selected destination. The app now provides real destination walking geometry/instructions and a transit handoff to Apple Maps. It does **not** implement in-app subway or Citi Bike itinerary planning or live turn-by-turn tracking.

Before restoring combined bike/subway recommendations:

- Import the full NYC station/entrance dataset. The ten bundled records use local IDs `1`–`10`, with no verified mapping to Worker stop IDs. Do not guess mappings for multi-line complexes or merge northbound and southbound arrivals.
- Include transit direction, stop sequences, transfers, service alerts, and exit-to-destination legs in an itinerary service. Arrival times alone cannot determine a valid destination trip.
- Join real Citi Bike station information and status, including rentable bikes, return dock availability, and station operating status. Use cycling-safe routing and include pickup/return time.
- Validate freshness, empty/partial upstream responses, and the exact Worker schema with authenticated fixtures.
- Search regions are relevance hints, not strict NYC boundaries. Add borough-boundary validation if trips outside NYC must be rejected.

The legacy `MultimodalRoute` type remains available for future itinerary work but is no longer used to display fabricated journeys.

## Tests

The shared scheme includes the XCTest target. Run:

```sh
xcodebuild test -project "NYCiti Nav.xcodeproj" -scheme "NYCiti Nav" \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
  CODE_SIGNING_ALLOWED=NO
```

Network tests use a stub URL protocol, so they need no production key. Coverage includes request construction, invalid keys/coordinates, 400/401/403 handling, schema errors, destination routing independent of Worker availability, missing coordinates, station-ID mismatches, and discarding in-flight results after reset.
