import SwiftUI
import Combine
import FirebaseAnalytics
import UIKit

// MARK: - Color Palette & Constants
extension Color {
    static let neoYellow = Color(red: 1.0, green: 0.92, blue: 0.23) // #FFE93B
    static let neoPink = Color(red: 1.0, green: 0.44, blue: 0.70)   // #FF6FB3
    static let neoGreen = Color(red: 0.38, green: 0.89, blue: 0.58)  // #62E495
    static let neoBlue = Color(red: 0.34, green: 0.73, blue: 1.0)    // #57BAFF
    static let neoWhite = Color(red: 1.0, green: 1.0, blue: 1.0)
    static let neoBackground = Color(red: 0.96, green: 0.96, blue: 0.96)
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

// MARK: - Reusable Neo Card Component
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

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(20)
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
                    .font(.system(size: 16, weight: .bold))
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
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black, lineWidth: 3)
            )
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

// MARK: - Favorites Store
final class FavoritesStore: ObservableObject {
    @Published var ids: Set<String>
    private let key = "favorite_ids"

    init() {
        if let saved = UserDefaults.standard.array(forKey: key) as? [String] {
            ids = Set(saved)
        } else {
            ids = []
        }
    }

    func toggle(_ id: String) {
        var current = ids
        if current.contains(id) { current.remove(id) } else { current.insert(id) }
        ids = current
        UserDefaults.standard.set(Array(current), forKey: key)
        
        Analytics.logEvent("vendor_favorite_toggle", parameters: [
            "vendor_name": id as NSObject,
            "is_favorite": ids.contains(id) as NSObject
        ])
    }
}

// MARK: - Root Scaffold Shell
struct ContentView: View {
    @State private var eventData: EventData? = DataLoader.loadEventData()
    @StateObject private var favorites = FavoritesStore()
    @State private var currentTab = 0

    var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            VStack(spacing: 0) {
                ZStack {
                    Color.neoYellow

                    Text(tabTitle(for: currentTab))
                        .font(.system(size: 16, weight: .black))
                        .tracking(1)
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
                                    .font(.system(size: 10, weight: .black))
                                Text("TICKETS")
                                    .font(.system(size: 10, weight: .black))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.neoWhite)
                            .foregroundStyle(.black)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                            .shadow(color: .black, radius: 0, x: 2, y: 2)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .frame(height: 50)
                
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
                    VendorsScreen(eventData: eventData, favorites: favorites)
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

                HStack(spacing: 8) {
                    BottomNavItem(title: "HOME", icon: "house.fill", color: .neoYellow, index: 0, currentTab: $currentTab)
                    BottomNavItem(title: "SPONSORS", icon: "star.fill", color: .neoPink, index: 1, currentTab: $currentTab)
                    BottomNavItem(title: "EVENTS", icon: "list.bullet", color: .neoGreen, index: 2, currentTab: $currentTab)
                    BottomNavItem(title: "VENDORS", icon: "cart.fill", color: .neoBlue, index: 3, currentTab: $currentTab)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
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

// MARK: - Custom Bottom Nav Tab Item
struct BottomNavItem: View {
    let title: String
    let icon: String
    let color: Color
    let index: Int
    @Binding var currentTab: Int

    var isSelected: Bool { currentTab == index }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black)
                .offset(x: isSelected ? 1 : 2, y: isSelected ? 1 : 2)

            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? color : Color.neoWhite)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                .contentShape(Rectangle())
                .onTapGesture {
                    currentTab = index
                }

            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 8, weight: .black))
            }
            .foregroundColor(.black)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
        }
        .frame(maxWidth: .infinity)
        .offset(x: isSelected ? 1 : 0, y: isSelected ? 1 : 0)
    }
}

// MARK: - Home Screen
struct HomeScreen: View {
    let eventData: EventData?
    @State private var isWelcomeExpanded = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                NeoCard(backgroundColor: .neoWhite) {
                    Button {
                        withAnimation { isWelcomeExpanded.toggle() }
                    } label: {
                        HStack {
                            Text("WELCOME TO THE SHOW")
                                .font(.headline)
                                .fontWeight(.black)
                                .foregroundStyle(.black)
                            Spacer()
                            Text(isWelcomeExpanded ? "[-] " : "[+] ")
                                .fontWeight(.black)
                                .foregroundStyle(.black)
                                .padding(4)
                                .background(Color.neoYellow)
                                .border(Color.black, width: 2)
                        }
                    }
                    .buttonStyle(.plain)

                    Text("Welcome to Hops in the Hangar, your Craft Beer & Airshow event app! Explore a lineup of vendors and sponsors, discover detailed venue information, and enjoy exciting entertainment.")
                        .font(.body)
                        .foregroundStyle(.black.opacity(0.8))

                    if isWelcomeExpanded {
                        Text("Craft beer, beverages, and aircraft come together to create not only a fun social event, but also an extremely unique community experience at the Middletown Regional Airport.")
                            .font(.body)
                            .foregroundStyle(.black.opacity(0.8))
                    }
                }

                NeoCard(backgroundColor: .neoPink) {
                    Text("Hops 2026 Recap")
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundStyle(.black)

                    Text("As featured on WLWT, Hops in the Hangar 2026 was a stellar celebration of craft beer and aviation.")
                        .font(.body)
                        .foregroundStyle(.black.opacity(0.8))

                    if let url = URL(string: "https://www.wlwt.com/article/annual-hops-in-the-hangar-fundraiser-middletown-regional-airport/73466732") {
                        Link("Watch the full news segment here.", destination: url)
                            .font(.subheadline)
                            .fontWeight(.black)
                            .underline()
                            .foregroundStyle(.blue)
                    }
                }

                if let info = eventData?.info {
                    NeoCard(backgroundColor: .neoBlue) {
                        Text("VENUE & LOGISTICS")
                            .font(.headline)
                            .fontWeight(.black)

                        Text("Parking").fontWeight(.black)
                        Text(info.parking).font(.subheadline).foregroundStyle(.black.opacity(0.8))

                        Divider().overlay(.black)

                        Text("Event Rules").fontWeight(.black)
                        Text(info.rules).font(.subheadline).foregroundStyle(.black.opacity(0.8))
                    }
                }
            }
            .padding(16)
        }
    }
}

// MARK: - Sponsors Screen
struct SponsorsScreen: View {
    let eventData: EventData?
    @State private var query = ""
    @State private var selectedTiers: Set<String> = ["Premier", "Top Flight", "First Class", "Business Class", "Coach Class", "Passport", "Brewery"]
    @State private var selectedSponsor: SponsorItem? = nil

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
                    NeoTextField(placeholder: "SEARCH SPONSORS...", text: $query)
                        .padding(.bottom, 8)

                    ForEach(filtered) { sponsor in
                        NeoCard(backgroundColor: .neoWhite) {
                            HStack(alignment: .center, spacing: 14) {
                                // Logo Asset Thumbnail
                                let resName = getResourceName(sponsor.name)
                                if let uiImage = UIImage(named: resName) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 50)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                                } else {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 20))
                                        .frame(width: 50, height: 50)
                                        .background(Color.neoYellow)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sponsor.level.uppercased())
                                        .font(.system(size: 9, weight: .black))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.neoYellow)
                                        .border(Color.black, width: 1.5)

                                    Text(sponsor.name)
                                        .font(.headline)
                                        .fontWeight(.black)
                                        .foregroundStyle(.black)

                                    Text(sponsor.description)
                                        .font(.subheadline)
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
                    if let uiImage = UIImage(named: resName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(sponsor.level.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.neoYellow)
                            .border(Color.black, width: 1.5)

                        Text(sponsor.name)
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundStyle(.black)
                    }
                }

                NeoCard(backgroundColor: .neoWhite) {
                    Text("ABOUT")
                        .font(.headline)
                        .fontWeight(.black)
                    Text(sponsor.about ?? sponsor.description)
                        .font(.body)
                        .foregroundStyle(.black.opacity(0.9))
                }

                if sponsor.email != nil || sponsor.phone != nil || sponsor.website != nil {
                    NeoCard(backgroundColor: .neoWhite) {
                        Text("CONTACT INFORMATION")
                            .font(.headline)
                            .fontWeight(.black)

                        if let email = sponsor.email {
                            Button {
                                if let url = URL(string: "mailto:\(email)") { UIApplication.shared.open(url) }
                            } label: {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                    Text(email).font(.system(size: 14, weight: .bold, design: .monospaced))
                                    Spacer()
                                }
                                .padding(10)
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
                                    Text(phone).font(.system(size: 14, weight: .bold, design: .monospaced))
                                    Spacer()
                                }
                                .padding(10)
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
                                    Text(website).font(.system(size: 14, weight: .bold, design: .monospaced)).lineLimit(1)
                                    Spacer()
                                }
                                .padding(10)
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
                        .font(.headline)
                        .fontWeight(.black)
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
    @ObservedObject var favorites: FavoritesStore
    @State private var query = ""
    @State private var selectedCategories: Set<String> = ["Brewery", "Food Truck"]
    @State private var selectedVendor: VendorItem? = nil

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
                    NeoTextField(placeholder: "SEARCH VENDORS...", text: $query)
                        .padding(.bottom, 8)

                    ForEach(filtered) { vendor in
                        NeoCard(backgroundColor: .neoWhite) {
                            HStack(alignment: .center, spacing: 14) {
                                let resName = getResourceName(vendor.name)
                                if let uiImage = UIImage(named: resName) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 50, height: 50)
                                        .background(Color.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                                } else {
                                    Image(systemName: vendor.category == "Brewery" ? "wineglass" : "fork.knife")
                                        .font(.system(size: 20))
                                        .frame(width: 50, height: 50)
                                        .background(vendor.category == "Brewery" ? Color.neoBlue : Color.neoPink)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black, lineWidth: 2))
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(vendor.category.uppercased())
                                        .font(.system(size: 9, weight: .black))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.neoPink)
                                        .border(Color.black, width: 1.5)

                                    Text(vendor.name)
                                        .font(.headline)
                                        .fontWeight(.black)
                                        .foregroundStyle(.black)

                                    Text(vendor.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.black.opacity(0.8))
                                }
                                Spacer()

                                Button {
                                    favorites.toggle(vendor.name)
                                } label: {
                                    Image(systemName: favorites.ids.contains(vendor.name) ? "heart.fill" : "heart")
                                        .font(.title3)
                                        .foregroundStyle(.black)
                                        .padding(8)
                                        .background(favorites.ids.contains(vendor.name) ? Color.neoPink : Color.white)
                                        .border(Color.black, width: 2)
                                }
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
                    if let uiImage = UIImage(named: resName) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 64, height: 64)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.black, lineWidth: 2))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(vendor.category.uppercased())
                            .font(.system(size: 10, weight: .black))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.neoPink)
                            .border(Color.black, width: 1.5)

                        Text(vendor.name)
                            .font(.title2)
                            .fontWeight(.black)
                            .foregroundStyle(.black)
                    }
                }

                NeoCard(backgroundColor: .neoWhite) {
                    Text("ABOUT")
                        .font(.headline)
                        .fontWeight(.black)
                    Text(vendor.about ?? vendor.description)
                        .font(.body)
                        .foregroundStyle(.black.opacity(0.9))
                }

                if vendor.email != nil || vendor.phone != nil || vendor.website != nil {
                    NeoCard(backgroundColor: .neoWhite) {
                        Text("CONTACT INFORMATION")
                            .font(.headline)
                            .fontWeight(.black)

                        if let email = vendor.email {
                            Button {
                                if let url = URL(string: "mailto:\(email)") { UIApplication.shared.open(url) }
                            } label: {
                                HStack {
                                    Image(systemName: "envelope.fill")
                                    Text(email).font(.system(size: 14, weight: .bold, design: .monospaced))
                                    Spacer()
                                }
                                .padding(10)
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
                                    Text(phone).font(.system(size: 14, weight: .bold, design: .monospaced))
                                    Spacer()
                                }
                                .padding(10)
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
                                    Text(website).font(.system(size: 14, weight: .bold, design: .monospaced)).lineLimit(1)
                                    Spacer()
                                }
                                .padding(10)
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
                        .font(.headline)
                        .fontWeight(.black)
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

// MARK: - Entertainment Screen
struct EntertainmentView: View {
    let eventData: EventData?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("GROUND ENTERTAINMENT")
                    .font(.headline)
                    .fontWeight(.black)

                if let ground = eventData?.groundEntertainment {
                    ForEach(ground) { item in
                        NeoCard(backgroundColor: .neoWhite) {
                            Text(item.name).fontWeight(.black)
                            Text(item.role).font(.subheadline).foregroundStyle(.black.opacity(0.7))
                        }
                    }
                }

                Text("EVENT SCHEDULE")
                    .font(.headline)
                    .fontWeight(.black)
                    .padding(.top, 10)

                if let schedule = eventData?.schedule {
                    ForEach(schedule) { item in
                        NeoCard(backgroundColor: .neoGreen) {
                            Text(item.event).fontWeight(.black)
                            Text(item.time).font(.subheadline).fontWeight(.bold)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

#Preview {
    ContentView()
}
