import SwiftUI
import Combine
import FirebaseAnalytics
import UIKit

// MARK: - Color Palette & Constants
extension Color {
    static let neoYellow = Color(red: 1.0, green: 0.92, blue: 0.23) // #FFE93B
    static let neoPink = Color(red: 1.0, green: 0.44, blue: 0.70)    // #FF6FB3
    static let neoGreen = Color(red: 0.38, green: 0.89, blue: 0.58)  // #62E495
    static let neoBlue = Color(red: 0.34, green: 0.73, blue: 1.0)    // #57BAFF
    static let neoWhite = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let neoBackground = Color(red: 0.96, green: 0.96, blue: 0.96)

    // Hex Color Initializer for JSON background parity
    init(hex: String?) {
        guard let hex = hex, !hex.isEmpty else {
            self = .white
            return
        }
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6: // RGB
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
            self.init(
                red: Double(r) / 255,
                green: Double(g) / 255,
                blue: Double(b) / 255
            )
        default:
            self = .white
        }
    }
}

// MARK: - Helper to Generate Asset Names (Android Parity)
func getResourceName(_ name: String?) -> String {
    guard let name = name else { return "" }
    if name.localizedStandardContains("Mama Bear") && name.localizedStandardContains("Mac") {
        return "mamabears_mac"
    }
    return name.lowercased()
        .replacingOccurrences(of: "&", with: " and ")
        .replacingOccurrences(of: " ", with: "_")
        .replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression)
        .replacingOccurrences(of: "__+", with: "_", options: .regularExpression)
        .trimmingCharacters(in: CharacterSet(charactersIn: "_"))
}

// MARK: - Reusable Neo Brutalist Card Component
struct NeoCard<Content: View>: View {
    var backgroundColor: Color = .white
    var onClick: (() -> Void)? = nil
    @ViewBuilder let content: Content

    @State private var isPressed = false

    var body: some View {
        let shadowX: CGFloat = isPressed && onClick != nil ? 2 : 6
        let shadowY: CGFloat = isPressed && onClick != nil ? 2 : 6
        let transX: CGFloat = isPressed && onClick != nil ? 4 : 0
        let transY: CGFloat = isPressed && onClick != nil ? 4 : 0

        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .offset(x: shadowX, y: shadowY)

            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black, lineWidth: 3)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    if let click = onClick {
                        withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                            click()
                        }
                    }
                }

            VStack(alignment: .leading, spacing: 10) {
                content
            }
            .padding(18)
        }
        .offset(x: transX, y: transY)
    }
}

// MARK: - Neo-Brutalist Search Field Component
struct NeoTextField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .offset(x: 4, y: 4)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .black))
                    .foregroundStyle(.black)

                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.gray))
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .foregroundColor(.black)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.black)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black, lineWidth: 3)
            )
        }
    }
}

// MARK: - Neo-Brutalist Multi-Selection Filter Sheet
struct FilterSelectionSheet: View {
    let title: String
    let options: [String]
    @Binding var selectedOptions: Set<String>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Color.neoYellow
                Text(title)
                    .font(.system(size: 16, weight: .black, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.black)
            }
            .frame(height: 55)
            .overlay(Rectangle().frame(height: 3).foregroundColor(.black), alignment: .bottom)

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(options, id: \.self) { option in
                        HStack {
                            Text(option)
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(.black)
                            Spacer()

                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(selectedOptions.contains(option) ? Color.neoYellow : Color.white)
                                    .frame(width: 26, height: 26)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 2))

                                if selectedOptions.contains(option) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12, weight: .black))
                                        .foregroundStyle(.black)
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                        .shadow(color: .black, radius: 0, x: 3, y: 3)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedOptions.contains(option) {
                                selectedOptions.remove(option)
                            } else {
                                selectedOptions.insert(option)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .background(Color.neoBackground)

            VStack(spacing: 0) {
                Rectangle().fill(Color.black).frame(height: 3)
                Button {
                    dismiss()
                } label: {
                    Text("APPLY FILTERS")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.neoYellow)
                        .foregroundStyle(.black)
                }
                .background(Color.neoYellow)
            }
        }
        .background(Color.neoBackground)
    }
}

// MARK: - Models
struct FAQItem: Codable, Identifiable, Hashable {
    let id = UUID()
    let question: String
    let answer: String
    enum CodingKeys: String, CodingKey { case question, answer }
}

struct SponsorLink: Codable, Hashable { let label: String; let url: String }
struct SponsorItem: Codable, Identifiable, Hashable {
    let id = UUID()
    let name: String
    let level: String
    let description: String
    let about: String?
    let website: String?
    let links: [SponsorLink]?
    let email: String?
    let phone: String?
    let background: String?
}

struct VendorItem: Codable, Identifiable, Hashable {
    let id = UUID()
    let name: String
    let category: String
    let description: String
    let about: String?
    let email: String?
    let phone: String?
    let website: String?
    let mapId: String?
    let background: String?
}

struct ScheduleItem: Codable, Identifiable, Hashable { let id = UUID(); let time: String; let event: String }
struct HotelItem: Codable, Identifiable, Hashable { let id = UUID(); let name: String; let link: String }
struct GeneralInfo: Codable, Hashable { let parking: String; let rules: String; let hotels: [HotelItem] }

struct EntertainmentItem: Codable, Identifiable, Hashable {
    let id = UUID()
    let name: String
    let role: String
    let category: String?
    let description: String?
    let about: String?
    let socialPlatform: String?
    let socialHandle: String?
    let socialUrl: String?
    let contactInfo: String?
}

struct EventData: Codable, Hashable {
    let sponsors: [SponsorItem]
    let vendors: [VendorItem]
    let schedule: [ScheduleItem]
    let info: GeneralInfo
    let faq: [FAQItem]?
    let groundEntertainment: [EntertainmentItem]?
    let performers: [EntertainmentItem]?
}

// MARK: - Data Loader
enum DataLoader {
    static func loadEventData() -> EventData? {
        guard let url = Bundle.main.url(forResource: "event_data", withExtension: "json") else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(EventData.self, from: data)
        } catch {
            print("Error loading event_data.json: \(error)")
            return nil
        }
    }
}

// MARK: - Root Scaffold Shell
struct ContentView: View {
    @State private var eventData: EventData? = DataLoader.loadEventData()
    @State private var currentTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            VStack(spacing: 0) {
                ZStack {
                    Color.neoYellow

                    Text(tabTitle(for: currentTab))
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .tracking(1.5)
                        .foregroundStyle(.black)

                    HStack {
                        Spacer()
                        Button {
                            Analytics.logEvent("get_tickets_tap", parameters: nil)
                            if let url = URL(string: "https://middletownaviationfoundation.ticketspice.com/hops-in-the-hangar-2026") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "ticket.fill")
                                    .font(.system(size: 11, weight: .black))
                                Text("TICKETS")
                                    .font(.system(size: 11, weight: .black, design: .monospaced))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.neoWhite)
                            .foregroundStyle(.black)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 2))
                            .shadow(color: .black, radius: 0, x: 2, y: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 56)
                
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 3)
            }
            .background(Color.neoYellow)
            .zIndex(1)

            // Content Host
            Group {
                switch currentTab {
                case 0:
                    HomeScreen(eventData: eventData)
                        .onAppear { Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "home"]) }
                case 1:
                    SponsorsScreen(eventData: eventData)
                        .onAppear { Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "sponsors"]) }
                case 2:
                    EntertainmentView(eventData: eventData)
                        .onAppear { Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "events"]) }
                case 3:
                    VendorsScreen(eventData: eventData)
                        .onAppear { Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "vendors"]) }
                default:
                    HomeScreen(eventData: eventData)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.neoBackground)

            // Bottom App Bar
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.black)
                    .frame(height: 3)

                HStack(spacing: 12) {
                    BottomNavItem(title: "HOME", icon: "house.fill", color: .neoYellow, index: 0, currentTab: $currentTab)
                    BottomNavItem(title: "SPONSORS", icon: "star.fill", color: .neoPink, index: 1, currentTab: $currentTab)
                    BottomNavItem(title: "EVENTS", icon: "list.bullet", color: .neoGreen, index: 2, currentTab: $currentTab)
                    BottomNavItem(title: "VENDORS", icon: "cart.fill", color: .neoBlue, index: 3, currentTab: $currentTab)
                }
                .padding(.horizontal, 16)
                .frame(height: 64)
                .background(Color.white)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .ignoresSafeArea(.keyboard)
        .background(Color.neoBackground)
        .preferredColorScheme(.light)
    }

    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "HOME"
        case 1: return "SPONSORS"
        case 2: return "EVENTS"
        case 3: return "VENDORS"
        default: return "HOME"
        }
    }
}

// MARK: - Custom Square-ish Bottom Nav Button
struct BottomNavItem: View {
    let title: String
    let icon: String
    let color: Color
    let index: Int
    @Binding var currentTab: Int

    var isSelected: Bool { currentTab == index }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .offset(x: isSelected ? 1 : 2, y: isSelected ? 1 : 2)

            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? color : Color.neoWhite)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                .contentShape(Rectangle())
                .onTapGesture {
                    currentTab = index
                }

            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: .bold))
                Text(title)
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .foregroundColor(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
        }
        .frame(maxWidth: 82, maxHeight: 46)
        .offset(x: isSelected ? 1 : 0, y: isSelected ? 1 : 0)
    }
}

// MARK: - Full Screen Image Viewer Sheet
struct FullScreenImageViewer: View {
    let imageName: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            if let uiImg = UIImage(named: imageName) {
                Image(uiImage: uiImg)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Image not found")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
                    .padding(20)
            }
        }
    }
}

struct IdentifiableString: Identifiable {
    let id: String
}

// MARK: - Home Screen
struct HomeScreen: View {
    let eventData: EventData?
    @State private var isWelcomeExpanded = false
    @State private var fullScreenImage: String? = nil
    @State private var expandedFaqIds: Set<UUID> = []
    
    @State private var carouselImages: [String] = {
        let explicitNames = [
            "carousel_1", "carousel_2", "carousel_3", "carousel_4", "carousel_5",
            "carousel_6", "carousel_7", "carousel_8", "carousel_9", "carousel_10",
            "carousel_11", "carousel_12", "carousel_13", "carousel_14", "carousel_15"
        ]
        let valid = explicitNames.filter { UIImage(named: $0) != nil }
        if valid.isEmpty {
            return ["main_icon", "AppIcon"]
        }
        return valid.sorted()
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !carouselImages.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            let middleIndex = carouselImages.count / 2

                            ForEach(Array(carouselImages.enumerated()), id: \.offset) { index, imageName in
                                let isCenter = (index == middleIndex)

                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.black)
                                        .offset(x: 4, y: 4)

                                    if let uiImg = UIImage(named: imageName) {
                                        Image(uiImage: uiImg)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 240, height: 240)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 3))
                                    } else {
                                        Image(systemName: "airplane.circle.fill")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 80, height: 80)
                                            .foregroundStyle(Color.neoYellow)
                                            .frame(width: 240, height: 240)
                                            .background(Color.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 3))
                                    }
                                }
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if isCenter {
                                        if let url = URL(string: "https://hopsinthehangar.com") {
                                            UIApplication.shared.open(url)
                                        }
                                    } else {
                                        fullScreenImage = imageName
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }

                // WELCOME CARD
                NeoCard(backgroundColor: .neoWhite) {
                    Button {
                        withAnimation { isWelcomeExpanded.toggle() }
                    } label: {
                        HStack {
                            Text("WELCOME TO THE SHOW")
                                .font(.system(size: 16, weight: .black, design: .monospaced))
                                .foregroundStyle(.black)
                            Spacer()
                            Text(isWelcomeExpanded ? " [-] " : " [+] ")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(.black)
                                .padding(4)
                                .background(Color.neoYellow)
                                .border(Color.black, width: 2)
                        }
                    }
                    .buttonStyle(.plain)

                    if isWelcomeExpanded {
                        Text("Welcome to Hops in the Hangar, your Craft Beer & Airshow event app! Explore a lineup of vendors and sponsors, discover detailed venue information, and enjoy exciting entertainment.")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.9))
                        Text("Craft beer, beverages, and aircraft come together to create not only a fun social event, but also an extremely unique community experience at the Middletown Regional Airport.")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.9))
                        Text("Whether you're here for the thrilling air show performances or the incredible selection of breweries, this app will help you make the most of your experience.")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.9))
                    }
                }

                // IN THE NEWS HEADER & RECAP CARD
                VStack(alignment: .leading, spacing: 12) {
                    Text("IN THE NEWS")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 4)

                    NeoCard(backgroundColor: .neoPink) {
                        Text("Hops 2026 Recap")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)

                        Text("As featured on WLWT, Hops in the Hangar 2026 was a stellar celebration of craft beer and aviation at the Middletown Regional Airport.")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.9))

                        if let url = URL(string: "https://www.wlwt.com/article/annual-hops-in-the-hangar-fundraiser-middletown-regional-airport/73466732") {
                            HStack(spacing: 0) {
                                Text("Watch the full news segment ")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.black.opacity(0.9))
                                Link("here", destination: url)
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .underline()
                                    .foregroundStyle(.blue)
                                Text(".")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.black.opacity(0.9))
                            }
                        }
                    }
                }

                if let info = eventData?.info {
                    NeoCard(backgroundColor: .neoBlue) {
                        Text("VENUE & LOGISTICS")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)

                        Text("Parking")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                        Text(info.parking)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.8))

                        Text("Event Rules")
                            .font(.system(size: 14, weight: .black, design: .monospaced))
                        Text(info.rules)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.8))
                    }
                }

                // FAQ SECTION WITH [+] / [-] BUTTONS
                if let faqs = eventData?.faq, !faqs.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("FAQ")
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 4)

                        ForEach(faqs) { faq in
                            let isExpanded = expandedFaqIds.contains(faq.id)

                            VStack(alignment: .leading, spacing: 0) {
                                Button {
                                    withAnimation {
                                        if isExpanded {
                                            expandedFaqIds.remove(faq.id)
                                        } else {
                                            expandedFaqIds.insert(faq.id)
                                        }
                                    }
                                } label: {
                                    HStack {
                                        Text(faq.question)
                                            .font(.system(size: 14, weight: .black, design: .monospaced))
                                            .foregroundStyle(.black)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Text(isExpanded ? " [-] " : " [+] ")
                                            .font(.system(size: 14, weight: .black, design: .monospaced))
                                            .foregroundStyle(.black)
                                            .padding(4)
                                            .background(Color.neoYellow)
                                            .border(Color.black, width: 2)
                                    }
                                }
                                .buttonStyle(.plain)

                                if isExpanded {
                                    Text(faq.answer)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.black.opacity(0.8))
                                        .padding(.top, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(14)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.black)
                                        .offset(x: 3, y: 3)
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.white)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2.5))
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }

                // MARK: - Our Team Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("OUR TEAM")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 4)

                    NeoCard(backgroundColor: .neoGreen) {
                        VStack(alignment: .center, spacing: 4) {
                            Text("Middletown Aviation Foundation")
                                .font(.system(size: 14, weight: .black, design: .monospaced))
                                .foregroundStyle(.black)
                                .lineLimit(1)
                            Text("Your Hops in the Hangar Crew")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(.black.opacity(0.8))

                            Spacer().frame(height: 16)

                            let crew = [
                                "Rich Bevis", "Kurt Yearout", "Sara Yearout", "Tom Spielmann",
                                "Sean Askren", "Mica Jones", "Missy Lawwill", "Jamie Murphy",
                                "Rahul Menon"
                            ]

                            let columns = [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 8)]
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(crew, id: \.self) { name in
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.black)
                                            .offset(x: 3, y: 3)

                                        Text(name)
                                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.black)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 8)
                                            .frame(maxWidth: .infinity)
                                            .background(Color.white)
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)

                // App Version Footer
                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    Text("v\(version)")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.gray)
                        .padding(.top, 10)
                }
            }
            .padding(16)
        }
        .sheet(item: Binding(
            get: { fullScreenImage.map { IdentifiableString(id: $0) } },
            set: { fullScreenImage = $0?.id }
        )) { item in
            FullScreenImageViewer(imageName: item.id)
        }
    }
}

// MARK: - Sponsors Screen
struct SponsorsScreen: View {
    let eventData: EventData?
    @State private var query = ""
    private let allTiers = ["Premier", "Top Flight", "First Class", "Business Class", "Coach Class", "Passport", "Brewery"]
    @State private var selectedTiers: Set<String> = ["Premier", "Top Flight", "First Class", "Business Class", "Coach Class", "Passport", "Brewery"]
    @State private var selectedSponsor: SponsorItem? = nil
    @State private var isFilterPresented = false

    var sponsors: [SponsorItem] { eventData?.sponsors ?? [] }
    var filtered: [SponsorItem] {
        sponsors.filter {
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) && selectedTiers.contains($0.level)
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        NeoTextField(placeholder: "SEARCH SPONSORS...", text: $query)
                            .frame(maxWidth: .infinity)

                        Button {
                            isFilterPresented = true
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black)
                                    .offset(x: 3, y: 3)
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.neoYellow)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 3))
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.black)
                            }
                            .frame(width: 52, height: 52)
                        }
                    }
                    .padding(.bottom, 4)

                    ForEach(filtered) { sponsor in
                        NeoCard(backgroundColor: .neoWhite) {
                            HStack(alignment: .center, spacing: 14) {
                                let resName = getResourceName(sponsor.name)
                                let boxBg = Color(hex: sponsor.background)
                                
                                if let uiImage = UIImage(named: resName) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 52, height: 52)
                                        .background(boxBg)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                                } else {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 20))
                                        .frame(width: 52, height: 52)
                                        .background(boxBg == .white ? Color.neoYellow : boxBg)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(sponsor.level.uppercased())
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.neoYellow)
                                        .border(Color.black, width: 1.5)

                                    Text(sponsor.name)
                                        .font(.system(size: 16, weight: .black, design: .monospaced))
                                        .foregroundStyle(.black)

                                    Text(sponsor.description)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.black.opacity(0.8))
                                }
                                Spacer()
                            }
                        }
                        .onTapGesture {
                            Analytics.logEvent("sponsor_open", parameters: ["sponsor_name": sponsor.name])
                            selectedSponsor = sponsor
                        }
                    }
                }
                .padding(16)
            }
        }
        .sheet(item: $selectedSponsor) { sponsor in
            SponsorDetailSheet(sponsor: sponsor)
        }
        .sheet(isPresented: $isFilterPresented) {
            FilterSelectionSheet(title: "FILTER SPONSORS", options: allTiers, selectedOptions: $selectedTiers)
        }
    }
}

// MARK: - Sponsor Detail Sheet
struct SponsorDetailSheet: View {
    let sponsor: SponsorItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    let resName = getResourceName(sponsor.name)
                    let boxBg = Color(hex: sponsor.background)
                    
                    if let uiImage = UIImage(named: resName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .background(boxBg)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(sponsor.level.uppercased())
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.neoYellow)
                            .border(Color.black, width: 1.5)

                        Text(sponsor.name)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                    }
                }

                NeoCard(backgroundColor: .neoWhite) {
                    Text("ABOUT")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                    Text(sponsor.about ?? sponsor.description)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.9))
                }

                if sponsor.email != nil || sponsor.phone != nil || sponsor.website != nil {
                    NeoCard(backgroundColor: .neoWhite) {
                        Text("CONTACT INFORMATION")
                            .font(.system(size: 14, weight: .black, design: .monospaced))

                        if let email = sponsor.email {
                            Button {
                                if let url = URL(string: "mailto:\(email)") { UIApplication.shared.open(url) }
                            } label: {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                    Text(email).font(.system(size: 13, weight: .bold, design: .monospaced))
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.neoBackground)
                                .border(Color.black, width: 2)
                            }
                            .buttonStyle(.plain)
                        }

                        if let phone = sponsor.phone {
                            Button {
                                if let url = URL(string: "tel:\(phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())") { UIApplication.shared.open(url) }
                            } label: {
                                HStack {
                                    Image(systemName: "phone.fill")
                                    Text(phone).font(.system(size: 13, weight: .bold, design: .monospaced))
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.neoBackground)
                                .border(Color.black, width: 2)
                            }
                            .buttonStyle(.plain)
                        }

                        if let website = sponsor.website {
                            Button {
                                if let url = URL(string: website) { UIApplication.shared.open(url) }
                            } label: {
                                HStack {
                                    Image(systemName: "globe")
                                    Text(website).font(.system(size: 13, weight: .bold, design: .monospaced)).lineLimit(1)
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.neoBackground)
                                .border(Color.black, width: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text("CLOSE")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.neoYellow)
                        .foregroundStyle(.black)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 3))
                        .shadow(color: .black, radius: 0, x: 3, y: 3)
                }
                .padding(.top, 10)
            }
            .padding(24)
        }
        .background(Color.neoBackground)
    }
}

// MARK: - Vendors Screen
struct VendorsScreen: View {
    let eventData: EventData?
    @State private var query = ""
    private let allCategories = ["Brewery", "Food Truck"]
    @State private var selectedCategories: Set<String> = ["Brewery", "Food Truck"]
    @State private var selectedVendor: VendorItem? = nil
    @State private var isFilterPresented = false

    var vendors: [VendorItem] { eventData?.vendors ?? [] }
    var filtered: [VendorItem] {
        vendors.filter {
            (query.isEmpty || $0.name.localizedCaseInsensitiveContains(query)) && selectedCategories.contains($0.category)
        }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 12) {
                        NeoTextField(placeholder: "SEARCH VENDORS...", text: $query)
                            .frame(maxWidth: .infinity)

                        Button {
                            isFilterPresented = true
                        } label: {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.black)
                                    .offset(x: 3, y: 3)
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.neoYellow)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 3))
                                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.black)
                            }
                            .frame(width: 52, height: 52)
                        }
                    }
                    .padding(.bottom, 4)

                    ForEach(filtered) { vendor in
                        NeoCard(backgroundColor: .neoWhite) {
                            HStack(alignment: .center, spacing: 14) {
                                let resName = getResourceName(vendor.name)
                                let boxBg = Color(hex: vendor.background)
                                
                                if let uiImage = UIImage(named: resName) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 52, height: 52)
                                        .background(boxBg)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                                } else {
                                    Image(systemName: vendor.category == "Brewery" ? "wineglass" : "fork.knife")
                                        .font(.system(size: 20))
                                        .frame(width: 52, height: 52)
                                        .background(boxBg == .white ? (vendor.category == "Brewery" ? Color.neoBlue : Color.neoPink) : boxBg)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(vendor.category.uppercased())
                                        .font(.system(size: 10, weight: .black, design: .monospaced))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.neoPink)
                                        .border(Color.black, width: 1.5)

                                    Text(vendor.name)
                                        .font(.system(size: 16, weight: .black, design: .monospaced))
                                        .foregroundStyle(.black)

                                    Text(vendor.description)
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.black.opacity(0.8))
                                }
                                Spacer()
                            }
                        }
                        .onTapGesture {
                            selectedVendor = vendor
                        }
                    }
                }
                .padding(16)
            }
        }
        .sheet(item: $selectedVendor) { vendor in
            VendorDetailSheet(vendor: vendor)
        }
        .sheet(isPresented: $isFilterPresented) {
            FilterSelectionSheet(title: "FILTER VENDORS", options: allCategories, selectedOptions: $selectedCategories)
        }
    }
}

// MARK: - Vendor Detail Sheet
struct VendorDetailSheet: View {
    let vendor: VendorItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    let resName = getResourceName(vendor.name)
                    let boxBg = Color(hex: vendor.background)
                    
                    if let uiImage = UIImage(named: resName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .background(boxBg)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(vendor.category.uppercased())
                            .font(.system(size: 11, weight: .black, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.neoPink)
                            .border(Color.black, width: 1.5)

                        Text(vendor.name)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                    }
                }

                NeoCard(backgroundColor: .neoWhite) {
                    Text("ABOUT")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                    Text(vendor.about ?? vendor.description)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.9))
                }

                if vendor.email != nil || vendor.phone != nil || vendor.website != nil {
                    NeoCard(backgroundColor: .neoWhite) {
                        Text("CONTACT INFORMATION")
                            .font(.system(size: 14, weight: .black, design: .monospaced))

                        if let email = vendor.email {
                            Button {
                                if let url = URL(string: "mailto:\(email)") { UIApplication.shared.open(url) }
                            } label: {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                    Text(email).font(.system(size: 13, weight: .bold, design: .monospaced))
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.neoBackground)
                                .border(Color.black, width: 2)
                            }
                            .buttonStyle(.plain)
                        }

                        if let phone = vendor.phone {
                            Button {
                                if let url = URL(string: "tel:\(phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined())") { UIApplication.shared.open(url) }
                            } label: {
                                HStack {
                                    Image(systemName: "phone.fill")
                                    Text(phone).font(.system(size: 13, weight: .bold, design: .monospaced))
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.neoBackground)
                                .border(Color.black, width: 2)
                            }
                            .buttonStyle(.plain)
                        }

                        if let website = vendor.website {
                            Button {
                                if let url = URL(string: website) { UIApplication.shared.open(url) }
                            } label: {
                                HStack {
                                    Image(systemName: "globe")
                                    Text(website).font(.system(size: 13, weight: .bold, design: .monospaced)).lineLimit(1)
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.neoBackground)
                                .border(Color.black, width: 2)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text("CLOSE")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.neoYellow)
                        .foregroundStyle(.black)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 3))
                        .shadow(color: .black, radius: 0, x: 3, y: 3)
                }
                .padding(.top, 10)
            }
            .padding(24)
        }
        .background(Color.neoBackground)
    }
}

// MARK: - Entertainment & Performers Screen
struct EntertainmentView: View {
    let eventData: EventData?
    @State private var selectedPerformer: EntertainmentItem? = nil

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("GROUND ENTERTAINMENT")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)

                    if let ground = eventData?.groundEntertainment {
                        ForEach(ground) { item in
                            NeoCard(backgroundColor: .neoWhite) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                            .font(.system(size: 16, weight: .black, design: .monospaced))
                                            .foregroundStyle(.black)
                                        Text(item.role)
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.black.opacity(0.7))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.black)
                                }
                            }
                            .onTapGesture {
                                selectedPerformer = item
                            }
                        }
                    }

                    Text("AIRSHOW PILOTS / PERFORMERS")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.top, 8)

                    if let performers = eventData?.performers {
                        ForEach(performers) { item in
                            NeoCard(backgroundColor: .neoWhite) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                            .font(.system(size: 16, weight: .black, design: .monospaced))
                                            .foregroundStyle(.black)
                                        Text(item.role)
                                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                                            .foregroundStyle(.black.opacity(0.7))
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(.black)
                                }
                            }
                            .onTapGesture {
                                selectedPerformer = item
                            }
                        }
                    }

                    Text("EVENT SCHEDULE")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.top, 8)

                    if let schedule = eventData?.schedule {
                        ForEach(schedule) { item in
                            NeoCard(backgroundColor: .neoGreen) {
                                Text(item.event)
                                    .font(.system(size: 16, weight: .black, design: .monospaced))
                                    .foregroundStyle(.black)
                                Text(item.time)
                                    .font(.system(size: 14, weight: .black, design: .monospaced))
                                    .foregroundStyle(.black)
                            }
                        }
                    }
                }
                .padding(16)
            }
        }
        .sheet(item: $selectedPerformer) { performer in
            PerformerDetailSheet(performer: performer)
        }
    }
}

// MARK: - Performer / Entertainer Detail Sheet
struct PerformerDetailSheet: View {
    let performer: EntertainmentItem
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let cat = performer.category {
                            Text(cat.uppercased())
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.neoPink)
                                .border(Color.black, width: 1.5)
                        }

                        Text(performer.name)
                            .font(.system(size: 20, weight: .black, design: .monospaced))
                            .foregroundStyle(.black)
                    }
                }

                NeoCard(backgroundColor: .neoWhite) {
                    Text("ROLE & DETAILS")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                    Text(performer.role)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.9))

                    if let about = performer.about ?? performer.description, !about.isEmpty {
                        Spacer().frame(height: 4)
                        Text(about)
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.8))
                    }
                }

                if !performer.socialUrl.isNilOrBlank || !performer.contactInfo.isNilOrBlank {
                    NeoCard(backgroundColor: .neoWhite) {
                        Text("CONNECT & CONTACT")
                            .font(.system(size: 14, weight: .black, design: .monospaced))

                        if let urlStr = performer.socialUrl, let url = URL(string: urlStr) {
                            Button {
                                UIApplication.shared.open(url)
                            } label: {
                                HStack {
                                    Image(systemName: "globe")
                                    Text(performer.socialHandle ?? urlStr)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(12)
                                .background(Color.neoBackground)
                                .border(Color.black, width: 2)
                            }
                            .buttonStyle(.plain)
                        }

                        if let contact = performer.contactInfo, !contact.isEmpty {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                Text(contact)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                Spacer()
                            }
                            .padding(12)
                            .background(Color.neoBackground)
                            .border(Color.black, width: 2)
                        }
                    }
                }

                Button {
                    dismiss()
                } label: {
                    Text("CLOSE")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.neoYellow)
                        .foregroundStyle(.black)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 3))
                        .shadow(color: .black, radius: 0, x: 3, y: 3)
                }
                .padding(.top, 10)
            }
            .padding(24)
        }
        .background(Color.neoBackground)
    }
}

extension Optional where Wrapped == String {
    var isNilOrBlank: Bool {
        return self?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true
    }
}

#Preview {
    ContentView()
}
