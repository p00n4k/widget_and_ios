import WidgetKit
import SwiftUI
import CoreLocation



// Usage Example

struct PMResponse: Decodable {
    let status: Int
    let errMsg: String
    let data: PMData
}

struct PMData: Codable {
    let pm25: Double
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            pmData: nil,
            error: nil
        )
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        let samplePM = PMData(pm25: 34.5)
        return SimpleEntry(date: Date(), pmData: samplePM, error: nil)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        let currentDate = Date()
        
        var pmData: PMData? = nil
        var errorMessage: String? = nil
        
        do {
            pmData = try await fetchPMData()
        } catch {
            errorMessage = error.localizedDescription
        }
        
        for secondOffset in 0..<12 {
            let entryDate = Calendar.current.date(byAdding: .second, value: secondOffset * 5, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, pmData: pmData, error: errorMessage)
            entries.append(entry)
        }
        
        return Timeline(entries: entries, policy: .after(Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!))
    }
    
    private func fetchPMData() async throws -> PMData {
        
        let userDefaults = UserDefaults(suiteName: "group.homeScreenApp")
        let textFromFlutterApp = userDefaults?.string(forKey: "locationData_from_flutter") ?? "13,100"
        
        let coordinates = textFromFlutterApp.components(separatedBy: ",")

        let lat = String(coordinates[0])
        let lng = String(coordinates[1])
        
        // Retrieve saved location from UserDefaults or use default values
 

        
        

        let urlString = "https://pm25.gistda.or.th/rest/getPm25byLocation?lat=\(lat)&lng=\(lng)"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        do {
            let decodedResponse = try JSONDecoder().decode(PMResponse.self, from: data)
            return decodedResponse.data
        } catch {
            throw error
        }
    }


}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let pmData: PMData?
    let error: String?
}

struct MyHomeWidgetEntryView: View {
    var entry: Provider.Entry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("PM2.5")
                .font(.headline)
                .padding(.bottom, 2)
            
            if let pmData = entry.pmData {
                HStack {
                    Text("🌫️")
                    Text("\(String(format: "%.1f", pmData.pm25)) μg/m³")
                        .font(.title2)
                        .bold()
                }
                
                Text("Updated: \(entry.date.formatted(.dateTime.hour().minute()))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if let error = entry.error {
                Text("Error: \(error)")
                    .font(.caption)
                    .foregroundColor(.red)
            } else {
                Text("Loading PM2.5 data...")
            }
        }
        .padding()
    }
}

struct MyHomeWidget: Widget {
    let kind: String = "MyHomeWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            MyHomeWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
    }
}

#Preview(as: .systemSmall) {
    MyHomeWidget()
} timeline: {
    SimpleEntry(
        date: .now,
        pmData: PMData(pm25: 34.5),
        error: nil
    )
    
    SimpleEntry(
        date: .now,
        pmData: nil,
        error: "Failed to load data"
    )
}
