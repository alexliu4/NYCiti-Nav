import Foundation

class StationDataManager: ObservableObject {
    @Published var stations: [SubwayStation] = []

    init() {
        loadStations()
    }

    func loadStations() {
        guard let url = Bundle.main.url(forResource: "SubwayEntrances", withExtension: "json") else {
            print("Failed to locate SubwayEntrances.json in bundle.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            self.stations = try decoder.decode([SubwayStation].self, from: data)
        } catch {
            print("Failed to decode SubwayEntrances.json: \(error)")
        }
    }
}
