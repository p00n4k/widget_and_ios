import WidgetKit
import SwiftUI
import CoreLocation

extension Color {
    init(hex: String) {
        let hexSanitized = hex.replacingOccurrences(of: "#", with: "")
        var hexInt: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&hexInt)
        
        let red = Double((hexInt & 0xFF0000) >> 16) / 255.0
        let green = Double((hexInt & 0x00FF00) >> 8) / 255.0
        let blue = Double(hexInt & 0x0000FF) / 255.0
        
        self.init(red: red, green: green, blue: blue)
    }
}



func formatTime(from dateString: String) -> String? {
    // Define the input date format
    let inputFormatter = DateFormatter()
    inputFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    
    // Convert the string to a Date object
    if let date = inputFormatter.date(from: dateString) {
        // Define the output time format
        let outputFormatter = DateFormatter()
        outputFormatter.dateFormat = "HH:mm"
        
        // Return the formatted time string
        return outputFormatter.string(from: date)
    } else {
        // Return nil if the date string couldn't be parsed
        return nil
    }
}




struct PMResponse: Decodable {
    let status: Int
    let errMsg: String
    let data: PMData
}
enum Pm25: Codable {
    case double(Double)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let x = try? container.decode(Double.self) {
            self = .double(x)
            return
        }
        if let x = try? container.decode(String.self) {
            self = .string(x)
            return
        }
        throw DecodingError.typeMismatch(Pm25.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Wrong type for Pm25"))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .double(let x):
            try container.encode(x)
        case .string(let x):
            try container.encode(x)
        }
    }
}


struct PMData: Codable {
    let pm25: [Pm25]
    let datetimeThai: DateTimeThai
    let graphPredictByHrs:[[Pm25]]
}

struct DateTimeThai: Codable {
    let dateThai: String
    let timeThai: String
}
struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), pmData: nil, error: nil)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(
            date: Date(),
            pmData: PMData(
                pm25: [Pm25.double(34.0), Pm25.string("")],
                datetimeThai: DateTimeThai(
                    dateThai: "วันพฤหัสบดีที่ 3 มีนาคม 2568",
                    timeThai: "เวลา 15:00 น."
                ),
                graphPredictByHrs: [[Pm25.double(34.0), Pm25.string("13.00")],[Pm25.double(35.0), Pm25.string("14.00")],[Pm25.double(37.0), Pm25.string("15.00")]]
            
            ),
            error: nil
        )


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

        for minuteOffset in 0..<12 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset * 5, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, pmData: pmData, error: errorMessage)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .after(Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!))
    }

    private func fetchPMData() async throws -> PMData {
        let userDefaults = UserDefaults(suiteName: "group.homescreenaapp")
        let textFromFlutterApp = userDefaults?.string(forKey: "locationData_from_flutter") ?? "13,100"
        let coordinates = textFromFlutterApp.components(separatedBy: ",")

        let lat = coordinates[0]
        let lng = coordinates[1]

        let urlString = "https://pm25.gistda.or.th/rest/pred/getPm25byLocation?lat=\(lat)&lng=\(lng)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(PMResponse.self, from: data).data
    }
    
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let pmData: PMData?
    let error: String?
}

struct MyHomeWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    var body: some View {
        switch family {
        case .systemSmall:
            smallWidgetView
        case .systemMedium:
            mediumWidgetView
        case .systemLarge, .systemExtraLarge:
            smallWidgetView
        @unknown default:
            smallWidgetView
        }
    }
    
    var smallWidgetView: some View {
        VStack(alignment: .center, spacing: 1) {
            VStack(alignment: .center, spacing: 8) {
                HStack {
                    HStack(spacing: 2) {
                        Text("ปริมาณฝุ่น PM2.5 ")
                            .font(.custom("NotoSansThai-Regular", size: 12.5))
                            .bold()
                            
                        
                        Image(systemName: "location.fill")
                            
                            .font(.system(size: 12))
                    }
                }
                
                
                if let pmData = entry.pmData {
                    let dateThaiWithoutDayOfWeek = pmData.datetimeThai.dateThai.replacingOccurrences(of: "จันทร์|อังคาร|พุธ|พฤหัสบดี|ศุกร์|เสาร์|อาทิตย์", with: "", options: .regularExpression)
                    
                    Text(dateThaiWithoutDayOfWeek)
                        
                        .font(.custom("NotoSansThai-Regular", size: 11))

                }
                
                HStack{
                    if let pmData = entry.pmData {
                        switch pmData.pm25[0] {
                        case .double(let value):
                            if value <= 15 {
                                Image("verygood")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    
                            } else if value <= 25 {
                                Image("good")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    
                            } else if value <= 37.5 {
                                Image("medium")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    
                            } else if value <= 75 {
                                Image("bad")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                    
                            } else {
                                Image("verybad")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                                   
                            }
                            
                        case .string(let value):
                            Text(value)
                                .font(.custom("NotoSansThai-Regular", size: 25))
                                .bold()
                                .foregroundColor(Color.white)
                        }
                    }

                    VStack(spacing:-5){
                    if let pmData = entry.pmData {
                        switch pmData.pm25[0] {
                        case .double(let value):
                            Text("\(String(format: "%.1f", value))")
                                .font(.custom("NotoSansThai-Regular", size: 25))
                                .bold()
                                
                        case .string(let value):
                            Text(value)
                                .font(.custom("NotoSansThai-Regular", size: 25))
                                .bold()
                                
                        }
                    }
                    else {
                        Text("Loading PM2.5 data...")
                            
                    }
                    Text("μg/m³")
                        .font(.caption)
                        
                    
                }
                }
                
                if let pmData = entry.pmData {
                    switch pmData.pm25[0] {
                    case .double(let value):
                        if value <= 15 {
                            Text("อากาศดีมาก")
                                .font(.custom("NotoSansThai-Regular", size: 14))
                                .bold()
                   
                        } else if value <= 25 {
                            Text("อากาศดี")
                                .font(.custom("NotoSansThai-Regular", size: 14))
                                .bold()
                    
                        } else if value <= 37.5 {
                            Text("อากาศปานกลาง")
                                .font(.custom("NotoSansThai-Regular", size: 14))
                                .bold()
                          
                        } else if value <= 75 {
                            Text("เริ่มมีผลต่อสุขภาพ")
                                .font(.custom("NotoSansThai-Regular", size: 14))
                                .bold()
                         
                        } else {
                            Text("มีผลต่อสุขภาพ")
                                .font(.custom("NotoSansThai-Regular", size: 14))
                                .bold()
                         
                        }
                        
                    case .string(let value):
                        Text(value)
                            .font(.custom("NotoSansThai-Regular", size: 25))
                            .bold()
                            .foregroundColor(Color.white)
                    }
                }

            }
        }
    }
    
    
    
    
    
    var mediumWidgetView: some View {
        HStack{
        VStack(alignment: .center, spacing: 16) {
            HStack (spacing: 10){
                HStack(spacing: 2) {
                    Text("PM2.5 รายชั่วโมง")
                        .font(.custom("NotoSansThai-Regular", size: 13.5))
                        .bold()
                        
                    
                    Image(systemName: "location.fill")
                        
                        .font(.system(size: 12))
                }
                
                
                
            }
            VStack{
                HStack{
                    
                    VStack(alignment:.center,spacing: -2){
                        
                        if let pmData = entry.pmData {
                            switch pmData.pm25[0] {
                            case .double(let value):
                                if value <= 15 {
                                    Image("verygood")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        
                                } else if value <= 25 {
                                    Image("good")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        
                                } else if value <= 37.5 {
                                    Image("medium")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        
                                } else if value <= 75 {
                                    Image("bad")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        
                                } else {
                                    Image("verybad")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 60, height: 60)
                                        
                                }
                                
                            case .string(let value):
                                Text(value)
                                    .font(.custom("NotoSansThai-Regular", size: 25))
                                    .bold()
                                    .foregroundColor(Color.white)
                            }
                        }

                    }
                    VStack(spacing:-5){
                    if let pmData = entry.pmData {
                        switch pmData.pm25[0] {
                        case .double(let value):
                            Text("\(String(format: "%.1f", value))")
                                .font(.custom("NotoSansThai-Regular", size: 25))
                                .bold()
                                
                        case .string(let value):
                            Text(value)
                                .font(.custom("NotoSansThai-Regular", size: 25))
                                .bold()
                                
                        }
                        Text("μg/m³")
                            .font(.caption)
                            
                    }
                }
                    
                }
                HStack{
                    if let pmData = entry.pmData {
                        switch pmData.pm25[0] {
                        case .double(let value):
                            if value <= 15 {
                                Text("อากาศดีมาก")
                                    .font(.custom("NotoSansThai-Regular", size: 14))
                                    .bold()
                                   
                            } else if value <= 25 {
                                Text("อากาศดี")
                                    .font(.custom("NotoSansThai-Regular", size: 14))
                                    .bold()
                                    
                            } else if value <= 37.5 {
                                Text("อากาศปานกลาง")
                                    .font(.custom("NotoSansThai-Regular", size: 14))
                                    .bold()
                                   
                            } else if value <= 75 {
                                Text("เริ่มมีผลต่อสุขภาพ")
                                    .font(.custom("NotoSansThai-Regular", size: 14))
                                    .bold()
                                    
                            } else {
                                Text("มีผลต่อสุขภาพ")
                                    .font(.custom("NotoSansThai-Regular", size: 14))
                                    .bold()
                                    
                            }
                            
                        case .string(let value):
                            Text(value)
                                .font(.custom("NotoSansThai-Regular", size: 25))
                                .bold()
                                .foregroundColor(Color.white)
                        }
                    }

                        
                    
                    
                }
            }
            
            
        }
            Spacer()
            VStack(alignment: .trailing, spacing: 16) {
                if let pmData = entry.pmData {
                    let dateThaiWithoutDayOfWeek = pmData.datetimeThai.dateThai.replacingOccurrences(of: "จันทร์|อังคาร|พุธ|พฤหัสบดี|ศุกร์|เสาร์|อาทิตย์", with: "", options: .regularExpression)
                    VStack{
                        Text(dateThaiWithoutDayOfWeek)
                            
                            .font(.custom("NotoSansThai-Regular", size: 11))
                        Text(pmData.datetimeThai.timeThai)
                            
                            .font(.custom("NotoSansThai-Regular", size: 11))
                    }
                }
                Spacer()
                HStack(spacing: 20) {
                    // Loop through the available data points
                    ForEach(0..<min(entry.pmData?.graphPredictByHrs.count ?? 0, 3), id: \.self) { index in
                        VStack(alignment: .center) {
                            if let pmData = entry.pmData {
                                // Check if data for this index exists
                                switch pmData.graphPredictByHrs[index][1] {
                                case .double(let value):
                                    Text("") // Empty Text for .double values
                                case .string(let value):
                                    let timeStr = String(value[value.index(value.startIndex, offsetBy: 11)..<value.index(value.startIndex, offsetBy: 16)])
                                    Text(timeStr)
                                        .font(.custom("NotoSansThai-Regular", size: 12))
                                }
                            } else {
                                Text("Loading PM2.5 data...")
                            }

                            if let pmData = entry.pmData {
                                switch pmData.graphPredictByHrs[index][0] {
                                case .double(let value):
                                    Text("\(String(format: "%.1f", value))")
                                        .font(.custom("NotoSansThai-Regular", size: 12))
                                        .bold()
                                case .string(let value):
                                    Text(value)
                                        .font(.custom("NotoSansThai-Regular", size: 25))
                                        .bold()
                                }
                            } else {
                                Text("Loading PM2.5 data...")
                            }
                        }
                    }
                }
                .font(.custom("NotoSansThai-Regular", size: 14))
                .padding(.bottom, 16)

            }
    }
    }
}
    
    
    
    
    
    
    struct MyHomeWidget: Widget {
        let kind: String = "MyHomeWidget"
        
        var body: some WidgetConfiguration {
            AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
                if let pmData = entry.pmData {
                    switch pmData.pm25[0] {
                    case .double(let value):
                        if value <= 15 {
                            MyHomeWidgetEntryView(entry: entry)
                                .containerBackground(for: .widget) {
                                    Image("Andwidjet")
                                        .resizable()
                                        .scaledToFill()
                                }
                                .foregroundColor(Color.white)
                        } else if value <= 25 {
                            MyHomeWidgetEntryView(entry: entry)
                                .containerBackground(for: .widget) {
                                    Image("Andwidjet2")
                                        .resizable()
                                        .scaledToFill()
                                }
                                .foregroundColor(Color(hex: "#303C46"))

                        } else if value <= 37.5 {
                            MyHomeWidgetEntryView(entry: entry)
                                .containerBackground(for: .widget) {
                                    Image("Andwidjet3")
                                        .resizable()
                                        .scaledToFill()
                                }
                                .foregroundColor(Color(hex: "#303C46"))

                        } else if value <= 75 {
                            MyHomeWidgetEntryView(entry: entry)
                                .containerBackground(for: .widget) {
                                    Image("Andwidjet4")
                                        .resizable()
                                        .scaledToFill()
                                }
                                .foregroundColor(Color.white)
                        } else {
                            MyHomeWidgetEntryView(entry: entry)
                                .containerBackground(for: .widget) {
                                    Image("Andwidjet5")
                                        .resizable()
                                        .scaledToFill()
                                }
                                .foregroundColor(Color.white)
                        }
                        
                    case .string(let value):
                        Text(value)
                            .font(.custom("NotoSansThai-Regular", size: 25))
                            .bold()  .foregroundColor(Color.white)
                        }
                    
                    }
                else{
                    MyHomeWidgetEntryView(entry: entry)
                        .containerBackground(for: .widget) {
                            Image("Andwidjet5")
                                .resizable()
                                .scaledToFill()
                        }
                        .foregroundColor(Color.white)
                }
                }
            

            .configurationDisplayName("PM2.5 Widget")
            .description("Displays the latest PM2.5 air quality data.")
            .supportedFamilies([.systemMedium, .systemSmall])
            
        }
    }
    
    #Preview(as: .systemMedium) {
        MyHomeWidget()
    } timeline: {
        SimpleEntry(
            date: Date(),
            pmData: PMData(
                pm25: [Pm25.double(2.0), Pm25.string("")],
                datetimeThai: DateTimeThai(
                    dateThai: "วันพฤหัสบดีที่ 3 มีนาคม 2568",
                    timeThai: "เวลา 15:00 น."
                ),
                graphPredictByHrs: [[Pm25.double(50.0), Pm25.string("2025-03-06T09:00:00.000Z")],[Pm25.double(35.0), Pm25.string("2025-03-06T10:00:00.000Z")],[Pm25.double(37.0), Pm25.string("2025-03-06T11:00:00.000Z")]]
            ),
            error: nil
        )
        SimpleEntry(date: .now, pmData: nil, error: "Failed to load data")
    }

