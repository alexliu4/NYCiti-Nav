# Issues Found and Code Analysis

This document details the critical architectural and algorithmic issues identified in the project's routing layer, along with the concrete steps being implemented to fix them.

---

## 1. Identified Issues

### A. The Ignored Destination Coordinate
In `RoutingEngine.calculateRoutes(...)`, the signature accepted a `destination: CLLocationCoordinate2D? = nil` parameter, but **this parameter was completely ignored in the body of the function**.
- The map placed a "Goal" marker at the destination pin.
- However, the actual multi-modal route calculation only computed travel times from the user to candidates of start stations. It never directed the user to the final destination, meaning the route results displayed "how to get to a nearby station" rather than "how to reach your target address."

### B. Static Transit Duration Baseline
The transit duration was represented by a hardcoded constant:
```swift
private let trainRideBaseline: TimeInterval = 900 // 15 minutes default
```
Regardless of whether the destination was 1 block away or across the city, the app added a fixed 15 minutes for the train ride.

### C. Missing Last-Mile Leg (Subway to Destination)
Because the destination was ignored, there was no calculation of:
- The destination subway station (`destinationStation`) near the target coordinate.
- The last-mile travel duration from the destination subway station to the actual destination (walking/biking).

### D. Single Polyline Drawing
The polyline drawing was only fetching and displaying a single leg (from the start bike dock to the start subway station) rather than the complete, multi-modal journey (User $\rightarrow$ Start Dock $\rightarrow$ Start Station $\rightarrow$ End Station $\rightarrow$ Destination).

---

## 2. Next Steps / Action Plan

### Step 1: Destination-Aware Multi-Modal Orchestration
We are modifying `RoutingEngine.calculateRoutes` to perform a multi-leg routing calculation:
1. **Find Destination Station:** Locate the closest `SubwayStation` to the user-entered destination coordinate. This serves as the `destinationStation`.
2. **For each Candidate Starting Station (`startStation`):**
   - **Leg 1 (User to Bike Dock):** Walk duration from User to the nearest available Citi Bike dock.
   - **Leg 2 (Dock to Start Station):** Bike duration from the Citi Bike dock to the candidate `startStation` (or walk if no dock is available).
   - **Leg 3 (Start Station Wait Time):** Platform wait duration based on live upcoming train timestamps at the `startStation`.
   - **Leg 4 (Subway Transit):** Calculated train ride duration between `startStation` and `destinationStation` based on geographic distance at average MTA subway operating speeds (~10 m/s or ~22 mph).
   - **Leg 5 (End Station to Destination):** Last-mile walk/bike duration from `destinationStation` to the final destination coordinate.
3. **Sum the Durations:**
   $$\text{totalTripDuration} = \text{Leg 1} + \text{Leg 2} + \text{Leg 3} + \text{Leg 4} + \text{Leg 5}$$
4. **Sort Options:** Sort all calculated options in ascending order of `totalTripDuration`.

### Step 2: Multi-Polyline Map Drawing
We are updating `RoutingEngine` and `ContentView` to draw separate map polylines for the entire journey:
- Walk to Dock
- Bike to Subway
- Subway transit
- Walk to Destination

These will be clearly differentiated on the map by styling (e.g., dotted lines for walking, blue for biking, and colored paths matching the subway line for transit).
