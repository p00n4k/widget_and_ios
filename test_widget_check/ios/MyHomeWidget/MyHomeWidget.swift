import WidgetKit
import SwiftUI
import CoreLocation

func roundedPm25Value(_ pm25: Pm25) -> Double? {
    switch pm25 {
    case .double(let value):
        return round(value)
    case .string(_):
        return nil
    }
}



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
    let datetimeEng: DateTimeEng?
    let graphPredictByHrs:[[Pm25]]
    let loc: Location?
}

struct DateTimeThai: Codable {
    let dateThai: String
    let timeThai: String
}

struct DateTimeEng: Codable {
    let dateEng: String
    let timeEng: String
}

struct Location: Codable {
    let loctext: String
    let loctext_en: String
    let tb_tn: String
    let ap_tn: String
    let pv_tn: String
    let tb_en: String
    let ap_en: String
    let pv_en: String
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), pmData: nil, error: nil, language: "th")
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
                datetimeEng: DateTimeEng(
                    dateEng: "Thursday, 3 March 2025",
                    timeEng: "15:00"
                ),
                graphPredictByHrs: [[Pm25.double(34.0), Pm25.string("13.00")],[Pm25.double(35.0), Pm25.string("14.00")],[Pm25.double(37.0), Pm25.string("15.00")]],
                loc: Location(
                    loctext: "หนองขนาน เมืองเพชรบุรี เพชรบุรี",
                    loctext_en: "Nong Khanan Mueang Phetchaburi Phetchaburi",
                    tb_tn: "หนองขนาน",
                    ap_tn: "เมืองเพชรบุรี",
                    pv_tn: "เพชรบุรี",
                    tb_en: "Nong Khanan",
                    ap_en: "Mueang Phetchaburi",
                    pv_en: "Phetchaburi"
                )
            ),
            error: nil,
            language: "th"
        )
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []
        let currentDate = Date()

        var pmData: PMData? = nil
        var errorMessage: String? = nil
        var language = "th" // Default language

        do {
            let result = try await fetchPMData()
            pmData = result.pmData
            language = result.language
        } catch {
            errorMessage = error.localizedDescription
        }

        for minuteOffset in 0..<12 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset * 5, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, pmData: pmData, error: errorMessage, language: language)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .after(Calendar.current.date(byAdding: .minute, value: 15, to: currentDate)!))
    }

    private func fetchPMData() async throws -> (pmData: PMData, language: String) {
        let userDefaults = UserDefaults(suiteName: "group.homescreenaapp")
        let textFromFlutterApp = userDefaults?.string(forKey: "locationData_from_flutter") ?? "13,100,th"
        let coordinates = textFromFlutterApp.components(separatedBy: ",")

        let lat = coordinates[0]
        let lng = coordinates[1]
        let language = coordinates.count > 2 ? coordinates[2] : "th" // Default to Thai if not specified

        let urlString = "https://pm25.gistda.or.th/rest/pred/getPm25byLocation?lat=\(lat)&lng=\(lng)"
        guard let url = URL(string: urlString) else { throw URLError(.badURL) }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }

        let pmData = try JSONDecoder().decode(PMResponse.self, from: data).data
        return (pmData, language)
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let pmData: PMData?
    let error: String?
    let language: String
}

struct MyHomeWidgetEntryView: View {
    var entry: Provider.Entry
    @Environment(\.widgetFamily) var family
    
    // Localized text based on language
    func localizedText(_ key: String) -> String {
        switch key {
        case "pm25_amount":
            return entry.language == "th" ? "ปริมาณฝุ่น PM2.5 " : "PM2.5 Amount "
        case "pm25_hourly":
            return entry.language == "th" ? "PM2.5 รายชั่วโมง" : "PM2.5 Hourly"
        case "very_good_air":
            return entry.language == "th" ? "อากาศดีมาก" : "Very Good"
        case "good_air":
            return entry.language == "th" ? "อากาศดี" : "Good"
        case "moderate_air":
            return entry.language == "th" ? "อากาศปานกลาง" : "Medium"
        case "start_health_effect":
            return entry.language == "th" ? "เริ่มมีผลต่อสุขภาพ" : "Starting to Affect Health"
        case "health_effect":
            return entry.language == "th" ? "มีผลต่อสุขภาพ" : "Health Effect"
        case "loading":
            return entry.language == "th" ? "กำลังโหลดข้อมูล PM2.5..." : "Loading PM2.5 data..."
        case "forecast":
            return entry.language == "th" ? "พยากรณ์" : "Forecast"
        case "hourly_trend":
            return entry.language == "th" ? "แนวโน้มรายชั่วโมง" : "Hourly Trend"
        case "location":
            if let pmData = entry.pmData, let loc = pmData.loc {
                return entry.language == "th" ? loc.loctext : loc.loctext_en
            }
            return ""
        default:
            return ""
        }
    }
    
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
        // Create a local variable to store the rounded value that will be accessible for the whole view
        let displayValue: String = {
            if let pmData = entry.pmData {
                switch pmData.pm25[0] {
                case .double(let value):
                    return "\(Int(round(value)))"
                case .string(let value):
                    return value
                }
            } else {
                return localizedText("loading")
            }
        }()
        
        return VStack(alignment: .center, spacing: 1) {
            // Rest of your view code remains the same
            VStack(alignment: .center, spacing: 8) {
                HStack {
                    HStack(spacing: 2) {
                        Text(localizedText("pm25_amount"))
                            .font(.custom("NotoSansThai-Regular", size: 12.5))
                            .bold()
                        
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                    }
                }
                
                if let pmData = entry.pmData {
                    if entry.language == "eng" && pmData.datetimeEng != nil {
                        Text(pmData.datetimeEng!.dateEng)
                            .font(.custom("NotoSansThai-Regular", size: 11))
                    } else {
                        let dateThaiWithoutDayOfWeek = pmData.datetimeThai.dateThai.replacingOccurrences(of: "จันทร์|อังคาร|พุธ|พฤหัสบดี|ศุกร์|เสาร์|อาทิตย์", with: "", options: .regularExpression)
                        
                        Text(dateThaiWithoutDayOfWeek)
                            .font(.custom("NotoSansThai-Regular", size: 11))
                    }
                }
                
                HStack {
                    if let pmData = entry.pmData {
                        switch pmData.pm25[0] {
                        case .double(let value):
                            let roundedValue = round(value)
                            if roundedValue <= 15 {
                                Image("verygood")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                            } else if roundedValue <= 25 {
                                Image("good")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                            } else if roundedValue <= 37 {
                                Image("medium")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 60, height: 60)
                            } else if roundedValue <= 75 {
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

                    VStack(spacing: -5) {
                        if let pmData = entry.pmData {
                            switch pmData.pm25[0] {
                            case .double(let value):
                                let roundedValue = Int(round(value))
                                Text("\(roundedValue)")
                                    .font(.custom("NotoSansThai-Regular", size: 25))
                                    .bold()
                            case .string(let value):
                                Text(value)
                                    .font(.custom("NotoSansThai-Regular", size: 25))
                                    .bold()
                            }
                        } else {
                            Text(localizedText("loading"))
                        }
                        Text("μg/m³")
                            .font(.caption)
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("PM2.5 Hourly at your current location \(displayValue) microgram per cubic meter")
    }

    
    var mediumWidgetView: some View {
        
        let displayValue: String = {
            if let pmData = entry.pmData {
                switch pmData.pm25[0] {
                case .double(let value):
                    return "\(Int(round(value)))"
                case .string(let value):
                    return value
                }
            } else {
                return localizedText("loading")
            }
        }()
        
        return HStack{
            VStack(alignment: .center, spacing: 16) {
                HStack (spacing: 10){
                    HStack(spacing: 2) {
                        Text(localizedText("pm25_hourly"))
                            .font(.custom("NotoSansThai-Regular", size: 13.5))
                            .bold()
                        
                        Image(systemName: "location.fill")
                            .font(.system(size: 12))
                    }
                }
                
                // Location is stored in the model but not displayed as requested
                
                VStack{
                    HStack{
                        VStack(alignment:.center,spacing: -2){
                            if let pmData = entry.pmData {
                                switch pmData.pm25[0] {
                                case .double(let value):
                                    let roundedValue = round(value)
                                    
                                    if roundedValue <= 15 {
                                        Image("verygood")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 60)
                                    } else if roundedValue <= 25 {
                                        Image("good")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 60)
                                    } else if roundedValue <= 37 {
                                        Image("medium")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 60, height: 60)
                                    } else if roundedValue <= 75 {
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
                                    Text("\(Int(value.rounded()))")
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
                                let roundedValue = round(value)
                                if roundedValue <= 15 {
                                    Text(localizedText("very_good_air"))
                                        .font(.custom("NotoSansThai-Regular", size: 14))
                                        .bold()
                                } else if roundedValue <= 25 {
                                    Text(localizedText("good_air"))
                                        .font(.custom("NotoSansThai-Regular", size: 14))
                                        .bold()
                                } else if roundedValue <= 37.5 {
                                    Text(localizedText("moderate_air"))
                                        .font(.custom("NotoSansThai-Regular", size: 14))
                                        .bold()
                                } else if roundedValue <= 75 {
                                    Text(localizedText("start_health_effect"))
                                        .font(.custom("NotoSansThai-Regular", size: 14))
                                        .bold()
                                } else {
                                    Text(localizedText("health_effect"))
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
                    VStack{
                        if entry.language == "eng" && pmData.datetimeEng != nil {
                            Text(pmData.datetimeEng!.dateEng)
                                .font(.custom("NotoSansThai-Regular", size: 11))
                            Text(pmData.datetimeEng!.timeEng)
                                .font(.custom("NotoSansThai-Regular", size: 11))
                        } else {
                            let dateThaiWithoutDayOfWeek = pmData.datetimeThai.dateThai.replacingOccurrences(of: "จันทร์|อังคาร|พุธ|พฤหัสบดี|ศุกร์|เสาร์|อาทิตย์", with: "", options: .regularExpression)
                            Text(dateThaiWithoutDayOfWeek)
                                .font(.custom("NotoSansThai-Regular", size: 11))
                            Text(pmData.datetimeThai.timeThai)
                                .font(.custom("NotoSansThai-Regular", size: 11))
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 20) {
                    // Loop through the available data points
                    ForEach(0..<min(entry.pmData?.graphPredictByHrs.count ?? 0, 3), id: \.self) { index in
                        VStack(alignment: .center) {
                            if let pmData = entry.pmData {
                                // Format and display time based on language
                                switch pmData.graphPredictByHrs[index][1] {
                                case .double(let value):
                                    Text("") // Empty Text for .double values
                                case .string(let value):
                                    if value.count >= 16 {
                                        let timeStr = String(value[value.index(value.startIndex, offsetBy: 11)..<value.index(value.startIndex, offsetBy: 16)])
                                        Text(timeStr)
                                            .font(.custom("NotoSansThai-Regular", size: 12))
                                    } else {
                                        Text(value)
                                            .font(.custom("NotoSansThai-Regular", size: 12))
                                    }
                                }
                            } else {
                                Text(localizedText("loading"))
                            }
                            
                            if let pmData = entry.pmData {
                                switch pmData.graphPredictByHrs[index][0] {
                                case .double(let value):
                                    let roundedValue = Int(round(value))
                                    Text("\(roundedValue)")
                                        .font(.custom("NotoSansThai-Regular", size: 12))
                                        .bold()
                                case .string(let value):
                                    Text(value)
                                        .font(.custom("NotoSansThai-Regular", size: 25))
                                        .bold()
                                }
                            } else {
                                Text(localizedText("loading"))
                            }
                        }
                    }
                }
                .font(.custom("NotoSansThai-Regular", size: 14))
                .padding(.bottom, 16)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel({
            // Start with the base text
            var accessibilityText = "PM2.5 Hourly at your current location "
            
            // Add the current PM value
            if let pmData = entry.pmData {
                switch pmData.pm25[0] {
                case .double(let value):
                    accessibilityText += "\(Int(round(value))) microgram per cubic meter "

                    let roundedValue = round(value)
                    if roundedValue <= 15 {
                        accessibilityText += "Big smiley face icon and blue thumbs up icon, showing very good air quality "
                    } else if roundedValue <= 25 {
                        accessibilityText += "Smiley face icon and green check mark icon, showing good air quality "
                    } else if roundedValue <= 37.5 {
                        accessibilityText += "Masked face icon and yellow check mark icon, showing moderate air quality "
                    } else if roundedValue <= 75 {
                        accessibilityText += "Masked face icon and orange thumbs down icon, showing air quality that begins to affect health "
                    } else {
                        accessibilityText += "Masked face icon and red cross mark icon, showing air quality that impacts health "
                    }

                case .string(let value):
                    accessibilityText += "\(value) microgram per cubic meter "
                }
                
                // Add forecast information
                if pmData.graphPredictByHrs.count > 0 {
                    accessibilityText += "Forecast: "
                    
                    for index in 0..<min(pmData.graphPredictByHrs.count, 3) {
                        var timeStr = ""
                        var valueStr = ""
                        
                        // Get time
                        switch pmData.graphPredictByHrs[index][1] {
                        case .string(let time):
                            if time.count >= 16 {
                                timeStr = String(time[time.index(time.startIndex, offsetBy: 11)..<time.index(time.startIndex, offsetBy: 16)])
                            } else {
                                timeStr = time
                            }
                        case .double:
                            timeStr = ""
                        }
                        
                        // Get value
                        switch pmData.graphPredictByHrs[index][0] {
                        case .double(let value):
                            valueStr = "\(Int(round(value)))"
                        case .string(let value):
                            valueStr = value
                        }
                        
                        accessibilityText += "\(timeStr), ,\(valueStr) microgram per cubic meter"
                        
                        // Add comma between forecast points but not after the last one
                        if index < min(pmData.graphPredictByHrs.count, 3) - 1 {
                            accessibilityText += ", "
                        }
                    }
                }
            } else {
                accessibilityText += localizedText("loading")
            }
            
            return accessibilityText
        }())
    }
}

struct MyHomeWidget: Widget {
    let kind: String = "MyHomeWidget"
    
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            if let pmData = entry.pmData {
                switch pmData.pm25[0] {
                case .double(let value):
                    let roundedValue = round(value)
                    if roundedValue <= 15 {
                        MyHomeWidgetEntryView(entry: entry)
                            .containerBackground(for: .widget) {
                                Image("Andwidjet")
                                    .resizable()
                                    .scaledToFill()
                                    .accessibilityHidden(true)
                            }
                            .foregroundColor(Color.white)
                    } else if roundedValue <= 25 {
                        MyHomeWidgetEntryView(entry: entry)
                            .containerBackground(for: .widget) {
                                Image("Andwidjet2")
                                    .resizable()
                                    .scaledToFill()
                                    .accessibilityHidden(true)
                            }
                            .foregroundColor(Color(hex: "#303C46"))
                    } else if roundedValue <= 37.5 {
                        MyHomeWidgetEntryView(entry: entry)
                            .containerBackground(for: .widget) {
                                Image("Andwidjet3")
                                    .resizable()
                                    .scaledToFill()
                                    .accessibilityHidden(true)
                            }
                            .foregroundColor(Color(hex: "#303C46"))
                    } else if roundedValue <= 75 {
                        MyHomeWidgetEntryView(entry: entry)
                            .containerBackground(for: .widget) {
                                Image("Andwidjet4")
                                    .resizable()
                                    .scaledToFill()
                                    .accessibilityHidden(true)
                            }
                            .foregroundColor(Color.white)
                    } else {
                        MyHomeWidgetEntryView(entry: entry)
                            .containerBackground(for: .widget) {
                                Image("Andwidjet5")
                                    .resizable()
                                    .scaledToFill()
                                    .accessibilityHidden(true)
                            }
                            .foregroundColor(Color.white)
                    }
                    
                case .string(let value):
                    Text(value)
                        .font(.custom("NotoSansThai-Regular", size: 25))
                        .bold()
                        .foregroundColor(Color.white)
                }
            }
            else {
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
    // Thai preview
    SimpleEntry(
        date: Date(),
        pmData: PMData(
            pm25: [Pm25.double(2.0), Pm25.string("")],
            datetimeThai: DateTimeThai(
                dateThai: "วันพฤหัสบดีที่ 3 มีนาคม 2568",
                timeThai: "เวลา 15:00 น."
            ),
            datetimeEng: DateTimeEng(
                dateEng: "Thursday, 3 March 2025",
                timeEng: "15:00"
            ),
            graphPredictByHrs: [[Pm25.double(50.0), Pm25.string("2025-03-06T09:00:00.000Z")],[Pm25.double(35.0), Pm25.string("2025-03-06T10:00:00.000Z")],[Pm25.double(37.0), Pm25.string("2025-03-06T11:00:00.000Z")]],
            loc: Location(
                loctext: "หนองขนาน เมืองเพชรบุรี เพชรบุรี",
                loctext_en: "Nong Khanan Mueang Phetchaburi Phetchaburi",
                tb_tn: "หนองขนาน",
                ap_tn: "เมืองเพชรบุรี",
                pv_tn: "เพชรบุรี",
                tb_en: "Nong Khanan",
                ap_en: "Mueang Phetchaburi",
                pv_en: "Phetchaburi"
            )
        ),
        error: nil,
        language: "th"
    )
    
    // English preview
    SimpleEntry(
        date: Date(),
        pmData: PMData(
            pm25: [Pm25.double(24.3), Pm25.string("")],
            datetimeThai: DateTimeThai(
                dateThai: "วันพฤหัสบดีที่ 1 พฤษภาคม 2568",
                timeThai: "เวลา 13:00 น."
            ),
            datetimeEng: DateTimeEng(
                dateEng: "Thursday, 1 May 2025",
                timeEng: "13:00"
            ),
            graphPredictByHrs: [[Pm25.double(22.4), Pm25.string("2025-05-01T14:00:00.000Z")],[Pm25.double(21.8), Pm25.string("2025-05-01T15:00:00.000Z")],[Pm25.double(20.7), Pm25.string("2025-05-01T16:00:00.000Z")]],
            loc: Location(
                loctext: "หนองขนาน เมืองเพชรบุรี เพชรบุรี",
                loctext_en: "Nong Khanan Mueang Phetchaburi Phetchaburi",
                tb_tn: "หนองขนาน",
                ap_tn: "เมืองเพชรบุรี",
                pv_tn: "เพชรบุรี",
                tb_en: "Nong Khanan",
                ap_en: "Mueang Phetchaburi",
                pv_en: "Phetchaburi"
            )
        ),
        error: nil,
        language: "eng"
    )
    
    // Error state preview
    SimpleEntry(date: .now, pmData: nil, error: "Failed to load data", language: "eng")
}
