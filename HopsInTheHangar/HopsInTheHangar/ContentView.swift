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
        case 6:
            r = (int >> 16) & 0xFF
            g = (int >> 8) & 0xFF
            b = int & 0xFF
            self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
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
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 3))
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

// MARK: - Reusable Neo-Brutalist Tactile Button Component
struct NeoButton<Content: View>: View {
    let backgroundColor: Color
    let onClick: () -> Void
    @ViewBuilder let content: Content

    @State private var isPressed = false

    var body: some View {
        let shadowX: CGFloat = isPressed ? 1 : 4
        let shadowY: CGFloat = isPressed ? 1 : 4
        let transX: CGFloat = isPressed ? 3 : 0
        let transY: CGFloat = isPressed ? 3 : 0

        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black)
                .offset(x: shadowX, y: shadowY)

            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 3))
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                        onClick()
                    }
                }

            HStack(alignment: .center) {
                content
            }
            .padding(14)
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
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
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
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 3))
        }
    }
}

// MARK: - Neo-Brutalist Filter Sheet Component
struct FilterSelectionSheet: View {
    let title: String
    let options: [String]
    @Binding var selectedOptions: Set<String>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(title)
                    .font(.system(size: 18, weight: .black, design: .monospaced))
                    .foregroundStyle(.black)

                VStack(spacing: 12) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = selectedOptions.contains(option)

                        NeoButton(backgroundColor: .white, onClick: {
                            if isSelected {
                                selectedOptions.remove(option)
                            } else {
                                selectedOptions.insert(option)
                            }
                        }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(isSelected ? Color.neoYellow : Color.white)
                                    .frame(width: 22, height: 22)
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 2))

                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .black))
                                        .foregroundColor(.black)
                                }
                            }

                            Text(option)
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundColor(.black)

                            Spacer()
                        }
                    }
                }

                NeoButton(backgroundColor: .neoYellow, onClick: {
                    dismiss()
                }) {
                    Text("APPLY FILTERS")
                        .font(.system(size: 15, weight: .black, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.black)
                }
                .padding(.top, 10)
            }
            .padding(24)
        }
        .background(Color.neoBackground)
    }
}

// MARK: - Reusable Contact Row Component
struct DetailContactRow: View {
    let icon: String
    let value: String
    let onClick: () -> Void

    var body: some View {
        NeoButton(backgroundColor: .white, onClick: onClick) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.black)
            Text(value)
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundColor(.black)
                .lineLimit(1)
            Spacer()
        }
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

// MARK: - Top Bar Tickets Button Component
struct TicketsButton: View {
    @State private var isPressed = false

    var body: some View {
        let shadowX: CGFloat = isPressed ? 1 : 3
        let shadowY: CGFloat = isPressed ? 1 : 3
        let transX: CGFloat = isPressed ? 2 : 0
        let transY: CGFloat = isPressed ? 2 : 0

        HStack(spacing: 4) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 11, weight: .black))
            Text("TICKETS")
                .font(.system(size: 11, weight: .black, design: .monospaced))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.neoPink)
        .foregroundColor(.black)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.black, lineWidth: 3))
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.black)
                .offset(x: shadowX, y: shadowY)
        )
        .offset(x: transX, y: transY)
        .contentShape(Rectangle())
        .onTapGesture {
            Analytics.logEvent("get_tickets_tap", parameters: nil)
            withAnimation(.easeInOut(duration: 0.1)) { isPressed = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.easeInOut(duration: 0.1)) { isPressed = false }
                if let url = URL(string: "https://middletownaviationfoundation.ticketspice.com/hops-in-the-hangar-2026") {
                    UIApplication.shared.open(url)
                }
            }
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
                        TicketsButton()
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 56)
                
                Rectangle().fill(Color.black).frame(height: 3)
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
                Rectangle().fill(Color.black).frame(height: 3)

                HStack(spacing: 12) {
                    BottomNavItem(title: "HOME", icon: "house.fill", color: .neoYellow, index: 0, currentTab: $currentTab)
                    BottomNavItem(title: "SPONSORS", icon: "star.fill", color: .neoPink, index: 1, currentTab: $currentTab)
                    BottomNavItem(title: "EVENTS", icon: "list.bullet", color: .neoGreen, index: 2, currentTab: $currentTab)
                    BottomNavItem(title: "VENDORS", icon: "cart.fill", color: .neoBlue, index: 3, currentTab: $currentTab)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 2)
                .frame(height: 58)
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
                .offset(x: isSelected ? 1 : 3, y: isSelected ? 1 : 3)

            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? color : Color.neoWhite)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                .contentShape(Rectangle())
                .onTapGesture { currentTab = index }

            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .bold))
                    .frame(height: 22)
                
                Text(title)
                    .font(.system(size: 15, weight: .black, design: .monospaced))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .foregroundColor(.black)
            .padding(.horizontal, 2)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, minHeight: 46, maxHeight: 46)
        .offset(x: isSelected ? 1 : 0, y: isSelected ? 1 : 0)
    }
}

// MARK: - Full Screen Image Viewer Sheet with Custom Zoom & Pan Center Tracking
struct FullScreenImageViewer: View {
    let imageName: String
    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImg = UIImage(named: imageName) {
                GeometryReader { geometry in
                    Image(uiImage: uiImg)
                        .resizable()
                        .scaledToFit()
                        .scaleEffect(scale, anchor: .center)
                        .offset(offset)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .gesture(
                            SimultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let delta = value / lastScale
                                        lastScale = value
                                        let newScale = scale * delta
                                        scale = min(max(newScale, 1.0), 5.0)
                                    }
                                    .onEnded { _ in
                                        lastScale = 1.0
                                        if scale <= 1.0 {
                                            withAnimation(.spring()) {
                                                scale = 1.0
                                                offset = .zero
                                            }
                                        }
                                    },
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            let currentX = lastOffset.width + value.translation.width
                                            let currentY = lastOffset.height + value.translation.height
                                            offset = CGSize(width: currentX, height: currentY)
                                        }
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                        )
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded {
                                withAnimation(.spring()) {
                                    if scale > 1.0 {
                                        scale = 1.0
                                        offset = .zero
                                        lastOffset = .zero
                                    } else {
                                        scale = 2.5
                                    }
                                }
                            }
                        )
                        .simultaneousGesture(
                            TapGesture(count: 1).onEnded {
                                if scale <= 1.0 {
                                    dismiss()
                                }
                            }
                        )
                }
            } else {
                Text("Image not found")
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .onTapGesture {
                        dismiss()
                    }
            }
        }
    }
}

struct IdentifiableString: Identifiable { let id: String }

// MARK: - Home Screen
struct HomeScreen: View {
    let eventData: EventData?
    @State private var isWelcomeExpanded = false
    @State private var fullScreenImage: String? = nil
    @State private var expandedFaqIds: Set<UUID> = []
    
    @State private var carouselImages: [String] = {
        let explicitCarousels = [
            "carousel_20260822_184940", "carousel_img_1291", "carousel_img_1301", "carousel_img_1307",
            "carousel_img_1323", "carousel_img_1393", "carousel_img_1405", "carousel_img_1406",
            "carousel_img_1408", "carousel_img_1409", "carousel_img_1437", "carousel_img_1444",
            "carousel_img_1445", "carousel_img_1447", "carousel_img_2888"
        ]
        let foundImages = explicitCarousels.filter { UIImage(named: $0) != nil }
        let centerLogo = UIImage(named: "main_icon") != nil ? "main_icon" : (UIImage(named: "AppIcon") != nil ? "AppIcon" : "")

        let mid = foundImages.count / 2 + 1
        let leftSide = Array(foundImages[..<mid])
        let rightSide = Array(foundImages[mid...])

        var combined: [String] = []
        combined.append(contentsOf: leftSide)
        if !centerLogo.isEmpty { combined.append(centerLogo) }
        combined.append(contentsOf: rightSide)
        
        return combined.isEmpty ? ["carousel_1"] : combined
    }()

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if !carouselImages.isEmpty {
                    ScrollViewReader { proxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                let middleIndex = carouselImages.count / 2

                                ForEach(Array(carouselImages.enumerated()), id: \.offset) { index, imageName in
                                    let isCenter = (imageName == "main_icon" || imageName == "AppIcon" || index == middleIndex)

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
                                    .id(index)
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
                        .onAppear {
                            let middleIndex = carouselImages.count / 2
                            DispatchQueue.main.async { proxy.scrollTo(middleIndex, anchor: .center) }
                        }
                    }
                }

                // WELCOME CARD
                NeoCard(backgroundColor: .neoWhite) {
                    Button {
                        withAnimation { isWelcomeExpanded.toggle() }
                    } label: {
                        HStack {
                            Text("WELCOME TO THE SHOW")
                                .font(.system(size: 16, design: .monospaced))
                                .foregroundStyle(.black)
                            Spacer()
                            Text(isWelcomeExpanded ? " [-] " : " [+] ")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(.black)
                                .padding(4)
                                .background(Color.white)
                                .border(Color.black, width: 2)
                        }
                    }
                    .buttonStyle(.plain)

                    if isWelcomeExpanded {
                        Text("Welcome to Hops in the Hangar, your Craft Beer & Airshow event app! Explore a lineup of vendors and sponsors, discover detailed venue information, find the best hotels nearby, enjoy exciting entertainment, and get to know the featured airshow performers.")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.9))
                        Text("Craft beer, beverages, and aircraft come together to create not only a fun social event, but also an extremely unique community experience. Hops in the Hangar celebrates aviation, local businesses, and great craft beverages while bringing people together for an unforgettable evening at the Middletown Regional Airport.")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.9))
                        Text("Whether you're here for the thrilling air show performances, the incredible selection of breweries and beverage vendors, or simply to enjoy time with friends and family, this app will help you make the most of your experience. Stay connected with schedules, updates, event maps, and everything you need for an amazing experience at Hops in the Hangar 2026.")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.9))
                    }
                }

                // IN THE NEWS HEADER & RECAP CARD
                VStack(alignment: .leading, spacing: 12) {
                    Text("IN THE NEWS")
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 4)

                    NeoCard(backgroundColor: .neoPink) {
                        Text("Hops 2026 Recap")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)

                        Text("As featured on WLWT, Hops in the Hangar 2026 was a stellar celebration of craft beer and aviation. Saturday, August 22nd at the Middletown Regional Airport proved to be a perfect backdrop for a fun night where specialty beer enthusiasts and plane lovers combined their passions into one unforgettable experience.")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.9))

                        if let url = URL(string: "https://www.wlwt.com/article/annual-hops-in-the-hangar-fundraiser-middletown-regional-airport/73466732?utm_campaign=snd-autopilot&fbclid=IwY2xjawUANr9wZG9mBWV4dG4DYWVtAjEwAGJyaWQRMVlwcXpNeXpWYUNFWWhGR29zcnRjBmFwcF9pZBAyMjIwMzkxNzg4MjAwODkyAAEe-doI-qUEQTUaFejKpMXCGEVudnU0I_GSflwfU8n9y6sPHQnYEw02Nxthr-I_aem_yoV-Z7vcQlzoQCkJhKZvYQ") {
                            HStack(spacing: 0) {
                                Text("Watch the full news segment ")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(.black.opacity(0.7))
                                Link("here", destination: url)
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .underline()
                                    .foregroundStyle(.blue)
                                Text(".")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundStyle(.black.opacity(0.7))
                            }
                        }
                    }
                }

                // VENUE & LOGISTICS HEADER & CARD
                if let info = eventData?.info {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("VENUE & LOGISTICS")
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 4)

                        NeoCard(backgroundColor: .neoBlue) {
                            Text("Parking")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.black)
                            Text(info.parking)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.black.opacity(0.8))

                            Spacer().frame(height: 8)

                            Text("Event Rules")
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(.black)
                            Text(info.rules)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.black.opacity(0.8))
                        }
                    }
                }

                // FAQ SECTION
                if let faqs = eventData?.faq, !faqs.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("FAQ")
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 4)

                        ForEach(faqs) { faq in
                            let isExpanded = expandedFaqIds.contains(faq.id)

                            VStack(alignment: .leading, spacing: 0) {
                                Button {
                                    withAnimation {
                                        if isExpanded { expandedFaqIds.remove(faq.id) }
                                        else { expandedFaqIds.insert(faq.id) }
                                    }
                                } label: {
                                    HStack {
                                        Text(faq.question)
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundStyle(.black)
                                            .multilineTextAlignment(.leading)
                                        Spacer()
                                        Text(isExpanded ? " [-] " : " [+] ")
                                            .font(.system(size: 14, design: .monospaced))
                                            .foregroundStyle(.black)
                                            .padding(4)
                                            .background(Color.white)
                                            .border(Color.black, width: 2)
                                    }
                                }
                                .buttonStyle(.plain)

                                if isExpanded {
                                    Text(faq.answer)
                                        .font(.system(size: 13, design: .monospaced))
                                        .foregroundStyle(.black.opacity(0.8))
                                        .padding(.top, 10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .padding(14)
                            .background(
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6).fill(Color.black).offset(x: 3, y: 3)
                                    RoundedRectangle(cornerRadius: 6).fill(Color.neoYellow).overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2.5))
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }

                // MARK: - Our Team Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("OUR TEAM")
                        .font(.system(size: 18, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 4)

                    NeoCard(backgroundColor: .neoGreen) {
                        VStack(alignment: .center, spacing: 4) {
                            Text("Middletown Aviation Foundation")
                                .font(.system(size: 14, design: .monospaced))
                                .foregroundStyle(.black)
                                .lineLimit(1)
                            Text("Your Hops in the Hangar Crew")
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.black.opacity(0.8))

                            Spacer().frame(height: 16)

                            let crew = [
                                "Rich Bevis", "Kurt Yearout", "Sara Yearout", "Tom Spielmann",
                                "Sean Askren", "Mica Jones", "Missy Lawwill", "Jamie Murphy",
                                "Rahul Menon"
                            ]

                            let columns = [GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 8)]
                            LazyVGrid(columns: columns, spacing: 8) {
                                ForEach(crew, id: \.self) { fullName in
                                    let parts = fullName.split(separator: " ")
                                    let firstName = parts.first.map(String.init) ?? ""
                                    let lastName = parts.dropFirst().joined(separator: " ")

                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.black)
                                            .offset(x: 3, y: 3)

                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white)
                                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))

                                        VStack(spacing: 2) {
                                            Text(firstName)
                                                .font(.system(size: 12, design: .monospaced))
                                                .fontWeight(.bold)
                                                .foregroundColor(.black)
                                            if !lastName.isEmpty {
                                                Text(lastName)
                                                    .font(.system(size: 12, design: .monospaced))
                                                    .fontWeight(.bold)
                                                    .foregroundColor(.black)
                                            }
                                        }
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 8)
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)

                if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                    VStack(spacing: 4) {
                        Text("v\(version)")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.gray)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 96)
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

                        NeoButton(backgroundColor: .neoYellow, onClick: { isFilterPresented = true }) {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.black)
                        }
                        .frame(width: 52, height: 52)
                    }
                    .padding(.bottom, 4)

                    let pinnedNames = Set(["City of Middletown", "MWO", "Start Skydiving", "Team Fastrax"])
                    let pinnedSponsors = filtered.filter { pinnedNames.contains($0.name) }
                    let otherSponsors = filtered.filter { !pinnedNames.contains($0.name) }

                    if !pinnedSponsors.isEmpty {
                        Text("PREMIER SPONSORS")
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)

                        ForEach(pinnedSponsors) { sponsor in
                            SponsorCard(sponsor: sponsor, isPinned: true) {
                                Analytics.logEvent("sponsor_open", parameters: ["sponsor_name": sponsor.name])
                                selectedSponsor = sponsor
                            }
                        }

                        Divider().background(Color.black).frame(height: 3).padding(.vertical, 8)
                    }

                    ForEach(otherSponsors) { sponsor in
                        SponsorCard(sponsor: sponsor, isPinned: false) {
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

struct SponsorCard: View {
    let sponsor: SponsorItem
    let isPinned: Bool
    let onClick: () -> Void

    var body: some View {
        NeoCard(backgroundColor: isPinned ? Color.neoYellow : Color.neoWhite, onClick: onClick) {
            HStack(alignment: .center, spacing: 14) {
                let names = (sponsor.name.contains("Kara Goheen") || sponsor.name.contains("Affordable Dentures")) ? [sponsor.name] : sponsor.name.split(separator: "&").map { String($0).trimmingCharacters(in: .whitespaces) }
                let boxBg = Color(hex: sponsor.background)

                HStack(spacing: 4) {
                    ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                        let resName = getResourceName(name)
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
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(sponsor.level.uppercased())
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.7))

                    Text(sponsor.name)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(.black)

                    Text(sponsor.description)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.8))
                }
                Spacer()
            }
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
                    let names = (sponsor.name.contains("Kara Goheen") || sponsor.name.contains("Affordable Dentures")) ? [sponsor.name] : sponsor.name.split(separator: "&").map { String($0).trimmingCharacters(in: .whitespaces) }
                    let boxBg = Color(hex: sponsor.background)

                    HStack(spacing: 4) {
                        ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                            let resName = getResourceName(name)
                            if let uiImage = UIImage(named: resName) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 64, height: 64)
                                    .background(boxBg)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(boxBg == .white ? Color.neoYellow : boxBg)
                                        .frame(width: 64, height: 64)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(sponsor.level.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.7))

                        Text(sponsor.name)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(.black)
                    }
                }

                NeoCard(backgroundColor: .neoWhite) {
                    Text("ABOUT")
                        .font(.system(size: 14, design: .monospaced))
                    Text(sponsor.about ?? sponsor.description)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.9))
                }

                if sponsor.email != nil || sponsor.phone != nil || sponsor.website != nil || !(sponsor.links?.isEmpty ?? true) {
                    NeoCard(backgroundColor: .neoWhite) {
                        Text("CONTACT INFORMATION")
                            .font(.system(size: 14, design: .monospaced))

                        if let email = sponsor.email {
                            DetailContactRow(icon: "envelope.fill", value: email) {
                                if let url = URL(string: "mailto:\(email)") { UIApplication.shared.open(url) }
                            }
                        }

                        if let phone = sponsor.phone {
                            DetailContactRow(icon: "phone.fill", value: phone) {
                                let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                                if let url = URL(string: "tel:\(cleaned)") { UIApplication.shared.open(url) }
                            }
                        }

                        if let links = sponsor.links, !links.isEmpty {
                            ForEach(links, id: \.url) { link in
                                DetailContactRow(icon: "globe", value: "\(link.label): \(link.url)") {
                                    if let url = URL(string: link.url) { UIApplication.shared.open(url) }
                                }
                            }
                        } else if let website = sponsor.website {
                            DetailContactRow(icon: "globe", value: website) {
                                if let url = URL(string: website) { UIApplication.shared.open(url) }
                            }
                        }
                    }
                }

                NeoButton(backgroundColor: .neoYellow, onClick: { dismiss() }) {
                    Text("CLOSE")
                        .font(.system(size: 15, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.black)
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

                        NeoButton(backgroundColor: .neoYellow, onClick: { isFilterPresented = true }) {
                            Image(systemName: "line.3.horizontal.decrease.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.black)
                        }
                        .frame(width: 52, height: 52)
                    }
                    .padding(.bottom, 4)

                    ForEach(filtered) { vendor in
                        NeoCard(backgroundColor: .neoWhite, onClick: { selectedVendor = vendor }) {
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
                                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.black.opacity(0.7))

                                    Text(vendor.name)
                                        .font(.system(size: 16, design: .monospaced))
                                        .foregroundStyle(.black)

                                    Text(vendor.description)
                                        .font(.system(size: 12, design: .monospaced))
                                        .foregroundStyle(.black.opacity(0.8))
                                }
                                Spacer()
                            }
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
                    } else {
                        Image(systemName: vendor.category == "Brewery" ? "wineglass" : "fork.knife")
                            .font(.system(size: 24))
                            .frame(width: 64, height: 64)
                            .background(boxBg == .white ? (vendor.category == "Brewery" ? Color.neoBlue : Color.neoPink) : boxBg)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(vendor.category.uppercased())
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.7))

                        Text(vendor.name)
                            .font(.system(size: 18, design: .monospaced))
                            .foregroundStyle(.black)
                    }
                }

                NeoCard(backgroundColor: .neoWhite) {
                    Text("ABOUT")
                        .font(.system(size: 14, design: .monospaced))
                    Text(vendor.about ?? vendor.description)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.black.opacity(0.9))
                }

                if vendor.email != nil || vendor.phone != nil || vendor.website != nil {
                    NeoCard(backgroundColor: .neoWhite) {
                        Text("CONTACT INFORMATION")
                            .font(.system(size: 14, design: .monospaced))

                        if let email = vendor.email {
                            DetailContactRow(icon: "envelope.fill", value: email) {
                                if let url = URL(string: "mailto:\(email)") { UIApplication.shared.open(url) }
                            }
                        }

                        if let phone = vendor.phone {
                            DetailContactRow(icon: "phone.fill", value: phone) {
                                let cleaned = phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
                                if let url = URL(string: "tel:\(cleaned)") { UIApplication.shared.open(url) }
                            }
                        }

                        if let website = vendor.website {
                            DetailContactRow(icon: "globe", value: website) {
                                if let url = URL(string: website) { UIApplication.shared.open(url) }
                            }
                        }
                    }
                }

                NeoButton(backgroundColor: .neoYellow, onClick: { dismiss() }) {
                    Text("CLOSE")
                        .font(.system(size: 15, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.black)
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
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(.black)

                    if let ground = eventData?.groundEntertainment {
                        ForEach(ground) { item in
                            EntertainmentCard(item: item) { selectedPerformer = item }
                        }
                    }

                    Text("AIRSHOW PILOTS / PERFORMERS")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.top, 8)

                    if let performers = eventData?.performers {
                        ForEach(performers) { item in
                            EntertainmentCard(item: item) { selectedPerformer = item }
                        }
                    }

                    Text("EVENT SCHEDULE")
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.top, 8)

                    if let schedule = eventData?.schedule {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8).fill(Color.black).offset(x: 6, y: 6)

                            VStack(spacing: 0) {
                                ForEach(Array(schedule.enumerated()), id: \.offset) { index, item in
                                    HStack(alignment: .center, spacing: 14) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(Color.neoPink)
                                                .frame(width: 40, height: 40)
                                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                                            Image(systemName: "calendar")
                                                .font(.system(size: 18))
                                                .foregroundColor(.black)
                                        }

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.event)
                                                .font(.system(size: 15, design: .monospaced))
                                                .foregroundStyle(.black)
                                            Text(item.time)
                                                .font(.system(size: 13, design: .monospaced))
                                                .foregroundStyle(.black.opacity(0.8))
                                        }
                                        Spacer()
                                    }
                                    .padding(16)

                                    if index < schedule.count - 1 {
                                        Rectangle().fill(Color.black).frame(height: 2).padding(.horizontal, 16)
                                    }
                                }
                            }
                            .background(Color.white)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 3))
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

// MARK: - Entertainment Card Button
struct EntertainmentCard: View {
    let item: EntertainmentItem
    let onClick: () -> Void

    var category: String {
        if let cat = item.category, !cat.isEmpty { return cat }
        let role = item.role.lowercased()
        if role.contains("singer") || role.contains("anthem") { return "ANTHEM" }
        if role.contains("dj") || role.contains("music") { return "MUSIC" }
        if role.contains("check in") { return "CHECK IN" }
        if role.contains("announcer") { return "ANNOUNCER" }
        return "PERFORMANCE"
    }

    var iconName: String {
        switch category {
        case "MUSIC": return "music.note"
        case "ANTHEM": return "mic.fill"
        case "CHECK IN": return "heart.fill"
        case "ANNOUNCER": return "waveform"
        default: return "airplane"
        }
    }

    var body: some View {
        NeoCard(backgroundColor: .neoWhite, onClick: onClick) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.neoYellow)
                        .frame(width: 42, height: 42)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                    Image(systemName: iconName)
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(category.uppercased())
                        .font(.system(size: 9, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.neoPink)
                        .border(Color.black, width: 1.5)

                    Text(item.name)
                        .font(.system(size: 16, design: .monospaced))
                        .foregroundStyle(.black)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14))
                    .foregroundStyle(.black)
            }
        }
    }
}

// MARK: - Performer / Entertainer Detail Sheet
struct PerformerDetailSheet: View {
    let performer: EntertainmentItem
    @Environment(\.dismiss) private var dismiss

    var category: String {
        if let cat = performer.category, !cat.isEmpty { return cat }
        let role = performer.role.lowercased()
        if role.contains("singer") || role.contains("anthem") { return "ANTHEM" }
        if role.contains("dj") || role.contains("music") { return "MUSIC" }
        if role.contains("check in") { return "CHECK IN" }
        if role.contains("announcer") { return "ANNOUNCER" }
        return "PERFORMANCE"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.neoYellow)
                            .frame(width: 64, height: 64)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                        Image(systemName: "star.fill")
                            .font(.system(size: 26))
                            .foregroundColor(.black)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(category.uppercased())
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.neoPink)
                            .border(Color.black, width: 1.5)

                        Text(performer.name)
                            .font(.system(size: 20, design: .monospaced))
                            .foregroundStyle(.black)
                    }
                }

                NeoCard(backgroundColor: .neoWhite) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ROLE & DETAILS")
                            .font(.system(size: 14, design: .monospaced))
                        Text(performer.role)
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundStyle(.black.opacity(0.9))

                        if let about = performer.about ?? performer.description, !about.isEmpty {
                            Spacer().frame(height: 4)
                            Text(about)
                                .font(.system(size: 13, design: .monospaced))
                                .foregroundStyle(.black.opacity(0.8))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !performer.socialUrl.isNilOrBlank || !performer.contactInfo.isNilOrBlank {
                    NeoCard(backgroundColor: .neoWhite) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CONNECT & CONTACT")
                                .font(.system(size: 14, design: .monospaced))

                            if let urlStr = performer.socialUrl, let url = URL(string: urlStr) {
                                DetailContactRow(icon: "globe", value: performer.socialHandle ?? urlStr) {
                                    UIApplication.shared.open(url)
                                }
                            }

                            if let contact = performer.contactInfo, !contact.isEmpty {
                                let parts = contact.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespaces) }
                                ForEach(parts, id: \.self) { part in
                                    let icon = part.contains("@") ? "envelope.fill" : (part.contains("http") ? "globe" : "info.circle.fill")
                                    DetailContactRow(icon: icon, value: part) {
                                        if part.contains("http"), let url = URL(string: part) {
                                            UIApplication.shared.open(url)
                                        } else if part.contains("@"), let url = URL(string: "mailto:\(part)") {
                                            UIApplication.shared.open(url)
                                        }
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                NeoButton(backgroundColor: .neoYellow, onClick: { dismiss() }) {
                    Text("CLOSE")
                        .font(.system(size: 15, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.black)
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
