# NYCiti Nav - Transit-Proxy & Local Setup Guide

Welcome to the **NYCiti Nav** development repository. This app is a high-performance, modern SwiftUI-based multi-modal routing engine designed to optimize daily commutes using New York City Citi Bikes and the MTA Subway system.

---

## 1. Cloudflare Transit-Proxy API Response Schema

The app retrieves real-time subway arrival times and Citi Bike station availability from a secure Cloudflare Worker proxy located at `https://nyc-transit-worker.transit-proxy.workers.dev/`.

### API Key Header
All requests must include the API key passed via the HTTP header:
```http
X-App-API-Key: <YOUR_API_KEY>
```

### JSON Response Format
The endpoint returns a minimized JSON payload matching the following schema:

```json
{
  "lastUpdated": 1783097114,
  "bikeStations": [
    {
      "id": "66db408f-0aca-11e7-82f6-3863bb44ef7c",
      "bikes": 5,
      "docks": 10
    }
  ],
  "subwayTimes": [
    {
      "stationId": "123",
      "arrivals": [
        {
          "routeId": "1",
          "nextArrivals": [1783097128, 1783097250, 1783097970]
        }
      ]
    }
  ]
}
```

#### Fields Description:
- **`lastUpdated`**: `Int64` Unix epoch timestamp indicating when the proxy data was last refreshed.
- **`bikeStations`**: An array of objects representing Citi Bike docks:
  - **`id`**: Unique identifier for the bike station.
  - **`bikes`**: Number of standard/electric bikes currently available.
  - **`docks`**: Number of empty docks available for parking.
- **`subwayTimes`**: An array of objects representing MTA subway station platforms:
  - **`stationId`**: Canonical MTA station ID matching `SubwayEntrances.json`.
  - **`arrivals`**: A collection of route-specific arrivals:
    - **`routeId`**: Subway line/route identifier (e.g., `"1"`, `"N"`, `"F"`).
    - **`nextArrivals`**: Sorted array of upcoming train arrival Unix epoch timestamps.

---

## 2. Local Secrets Configuration

To protect sensitive keys, the Cloudflare API Key is not included in the public GitHub repository. Follow these steps to set up your local development environment:

### Step 1: Create the Secrets Plist
Create a new file named `Secrets.plist` inside the project under the Resources directory:
`NYCiti Nav/Resources/Secrets.plist`

### Step 2: Add your API Key
Populate the file with your actual Cloudflare Worker API key using the standard Apple Property List format:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AppAPIKey</key>
    <string>YOUR_CLOUDFLARE_API_KEY_HERE</string>
</dict>
</plist>
```

### Step 3: Target Membership
Ensure that `Secrets.plist` has **Target Membership** checked for the main `NYCiti Nav` app target in Xcode so that it gets properly bundled at build-time.
