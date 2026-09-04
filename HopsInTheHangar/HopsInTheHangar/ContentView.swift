import SwiftUI
import WebKit
import Combine
import FirebaseAnalytics
import UIKit

// MARK: - Models
struct FAQItem: Codable, Identifiable, Hashable {
    let id = UUID()
    let question: String
    let answer: String

    enum CodingKeys: String, CodingKey {
        case question, answer
    }
}

struct SponsorLink: Codable, Hashable { let label: String; let url: String }
struct SponsorItem: Codable, Identifiable, Hashable { let id = UUID(); let name: String; let level: String; let description: String; let website: String?; let links: [SponsorLink]? }
struct VendorItem: Codable, Identifiable, Hashable { let id = UUID(); let name: String; let category: String; let description: String; let email: String?; let phone: String?; let website: String?; let mapId: String? }
struct ScheduleItem: Codable, Identifiable, Hashable { let id = UUID(); let time: String; let event: String }
struct HotelItem: Codable, Identifiable, Hashable { let id = UUID(); let name: String; let link: String }
struct GeneralInfo: Codable, Hashable { let parking: String; let rules: String; let hotels: [HotelItem] }

struct EventData: Codable, Hashable {
    let sponsors: [SponsorItem]
    let vendors: [VendorItem]
    let schedule: [ScheduleItem]
    let info: GeneralInfo
    let faq: [FAQItem]?
}

// MARK: - Data Loader
enum DataLoader {
    static func loadEventData() -> EventData? {
        guard let url = Bundle.main.url(forResource: "event_data", withExtension: "json") else { return nil }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            return try decoder.decode(EventData.self, from: data)
        } catch {
            print("Error loading event_data.json: \(error)")
            return nil
        }
    }
}

// MARK: - Favorites Store (UserDefaults)
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
        Analytics.logEvent("vendor_favorite_toggle", parameters: ["name": id, "is_favorite": ids.contains(id)])
    }
}

// MARK: - Theme
extension Color {
    static let deepNavy = Color(red: 0.039, green: 0.098, blue: 0.184)      // 0x0A192F
    static let primaryNavy = Color(red: 0.066, green: 0.133, blue: 0.251)   // 0x112240
    static let secondarySlate = Color(red: 0.533, green: 0.572, blue: 0.690)// 0x8892B0
    static let aestheticGold = Color(red: 0.969, green: 0.816, blue: 0.541) // 0xF7D08A
}

struct NavyTheme: ViewModifier {
    func body(content: Content) -> some View {
        content
            .tint(Color.aestheticGold)
            .background(Color.deepNavy)
            .environment(\.colorScheme, .dark)
            .fontDesign(.rounded)
    }
}

// MARK: - Reusable Custom Header Component
struct ScreenHeaderView: View {
    let title: String
    var showAppIcon: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            if showAppIcon {
                if let appIcon = UIImage(named: "AppIcon") ?? UIImage(named: "AppIcon60x60") {
                    Image(uiImage: appIcon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.aestheticGold, lineWidth: 2))
                } else {
                    Image(systemName: "airplane.circle.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 36, height: 36)
                        .foregroundStyle(Color.aestheticGold)
                }
            }

            Text(title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Spacer()
        }
        .padding(.top, 8)
        .padding(.bottom, 4)
        .background(Color.deepNavy)
    }
}

// MARK: - Multi-Selection Filter Sheet
struct FilterSelectionSheet: View {
    let title: String
    let options: [String]
    @Binding var selectedOptions: Set<String>
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section {
                        ForEach(options, id: \.self) { option in
                            Button {
                                toggle(option)
                            } label: {
                                HStack {
                                    Text(option)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: selectedOptions.contains(option) ? "checkmark.circle.fill" : "circle")
                                        .font(.title3)
                                        .foregroundStyle(selectedOptions.contains(option) ? Color.aestheticGold : Color.secondarySlate)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.primaryNavy)
                        }
                    } header: {
                        Text("Select categories to display")
                            .foregroundStyle(Color.secondarySlate)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.deepNavy)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundStyle(Color.aestheticGold)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Select All") {
                        selectedOptions = Set(options)
                    }
                    .foregroundStyle(Color.secondarySlate)
                }
            }
        }
        .modifier(NavyTheme())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func toggle(_ option: String) {
        if selectedOptions.contains(option) {
            selectedOptions.remove(option)
        } else {
            selectedOptions.insert(option)
        }
    }
}

// MARK: - App Shell
struct ContentView: View {
    init() {
        UINavigationBar.appearance().standardAppearance = UINavigationBarAppearance()
        UINavigationBar.appearance().scrollEdgeAppearance = UINavigationBarAppearance()
        UITabBar.appearance().standardAppearance = UITabBarAppearance()
        UITabBar.appearance().scrollEdgeAppearance = UITabBarAppearance()
    }

    @State private var eventData: EventData? = DataLoader.loadEventData()
    @StateObject private var favorites = FavoritesStore()

    var body: some View {
        TabView {
            NavigationStack { HomeView(eventData: eventData).onAppear { Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "home"]) } }
                .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack { SponsorsView(eventData: eventData).onAppear { Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "sponsors"]) } }
                .tabItem { Label("Sponsors", systemImage: "star.fill") }

            NavigationStack { EntertainmentView(eventData: eventData).onAppear { Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "events"]) } }
                .tabItem { Label("Events", systemImage: "list.bullet.rectangle.fill") }

            NavigationStack { VendorsView(eventData: eventData, favorites: favorites).onAppear { Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "vendors"]) } }
                .tabItem { Label("Vendors", systemImage: "cart.fill") }
        }
        .modifier(NavyTheme())
    }
}

// MARK: - Clickable Answer Helper View
struct ClickableTextView: View {
    let text: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        let words = text.split(separator: " ")
        
        words.reduce(Text("")) { partial, wordStr in
            let word = String(wordStr)
            if word.hasPrefix("http://") || word.hasPrefix("https://") {
                if let url = URL(string: word) {
                    return partial + Text(" ") + Text(word).foregroundColor(Color.aestheticGold).underline()
                }
            } else if word.contains("@") && word.contains(".") {
                if let url = URL(string: "mailto:\(word)") {
                    return partial + Text(" ") + Text(word).foregroundColor(Color.aestheticGold).underline()
                }
            }
            return partial + (partial == Text("") ? Text("") : Text(" ")) + Text(word)
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .environment(\.openURL, OpenURLAction { url in
            openURL(url)
            return .handled
        })
    }
}

// MARK: - Home View
struct HomeView: View {
    let eventData: EventData?
    @Environment(\.openURL) private var openURL
    @State private var isDescriptionExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderView(title: "Home", showAppIcon: true)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Welcome Card with Expandable Text
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Welcome to the Show")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.aestheticGold)
                        
                        Text("Welcome to Hops in the Hangar, your Craft Beer & Airshow event app! Explore a lineup of vendors and sponsors, discover detailed venue information, find the best hotels nearby, enjoy exciting entertainment, and get to know the featured airshow performers.")
                            .foregroundStyle(.secondary)
                        
                        if isDescriptionExpanded {
                            Text("Craft beer, beverages, and aircraft come together to create not only a fun social event, but also an extremely unique community experience. Hops in the Hangar celebrates aviation, local businesses, and great craft beverages while bringing people together for an unforgettable evening at the Middletown Regional Airport.")
                                .foregroundStyle(.secondary)
                            
                            Text("Whether you're here for the thrilling air show performances, the incredible selection of breweries and beverage vendors, or simply to enjoy time with friends and family, this app will help you make the most of your experience. Stay connected with schedules, updates, event maps, and everything you need for an amazing experience at Hops in the Hangar 2026.")
                                .foregroundStyle(.secondary)
                        }
                        
                        Button {
                            withAnimation {
                                isDescriptionExpanded.toggle()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isDescriptionExpanded ? "Show Less" : "Read More")
                                    .fontWeight(.semibold)
                                Image(systemName: isDescriptionExpanded ? "chevron.up" : "chevron.down")
                            }
                            .font(.subheadline)
                            .foregroundStyle(Color.aestheticGold)
                        }
                        .padding(.top, 4)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.primaryNavy))

                    // Hops 2026 Recap Card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Hops 2026 Recap")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.aestheticGold)
                        
                        Text("As featured on WLWT, Hops in the Hangar 2026 was a stellar celebration of craft beer and aviation. Saturday, August 22nd at the Middletown Regional Airport proved to be a perfect backdrop for a fun night where specialty beer enthusiasts and plane lovers combined their passions into one unforgettable experience.")
                            .foregroundStyle(.secondary)

                        HStack(spacing: 4) {
                            Text("Watch the full news segment")
                                .foregroundStyle(.secondary)
                            Button("here") {
                                if let url = URL(string: "https://www.wlwt.com/article/annual-hops-in-the-hangar-fundraiser-middletown-regional-airport/73466732?utm_campaign=snd-autopilot&fbclid=IwY2xjawUANr9wZG9mBWV4dG4DYWVtAjEwAGJyaWQRMVlwcXpNeXpWYUNFWWhGR29zcnRjBmFwcF9pZBAyMjIwMzkxNzg4MjAwODkyAAEe-doI-qUEQTUaFejKpMXCGEVudnU0I_GSflwfU8n9y6sPHQnYEw02Nxthr-I_aem_yoV-Z7vcQlzoQCkJhKZvYQ") {
                                    openURL(url)
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(Color.aestheticGold)
                            .underline()
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.primaryNavy))

                    // FAQ Section
                    if let faqs = eventData?.faq, !faqs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Frequently Asked Questions")
                                .font(.headline)
                                .foregroundStyle(Color.aestheticGold)
                        
                            ForEach(faqs) { item in
                                DisclosureGroup {
                                    ClickableTextView(text: item.answer)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                } label: {
                                    Text(item.question)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                        .multilineTextAlignment(.leading)
                                }
                                .tint(Color.aestheticGold)
                                .padding()
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primaryNavy))
                    }

                    // Venue & Logistics
                    if let info = eventData?.info {
                        VStack(alignment: .leading, spacing: 16) {
                            Group {
                                Text("Parking").font(.headline).foregroundStyle(Color.aestheticGold)
                                Text(info.parking).foregroundStyle(.secondary)
                            }
                            Group {
                                Text("Event Rules").font(.headline).foregroundStyle(Color.aestheticGold)
                                Text(info.rules).foregroundStyle(.secondary)
                            }
                            Group {
                                Text("Nearby Hotels").font(.headline).foregroundStyle(Color.aestheticGold)
                                ForEach(info.hotels) { hotel in
                                    Button {
                                        if let url = URL(string: hotel.link) { openURL(url) }
                                    } label: {
                                        HStack {
                                            Image(systemName: "bed.double.fill")
                                            Text(hotel.name).fontWeight(.semibold)
                                            Spacer()
                                            let phoneString: String = {
                                                if hotel.link.hasPrefix("tel:") {
                                                    let raw = hotel.link.replacingOccurrences(of: "tel:", with: "")
                                                    if raw.count == 10 {
                                                        let a = raw.prefix(3)
                                                        let b = raw.dropFirst(3).prefix(3)
                                                        let c = raw.dropFirst(6)
                                                        return "(\(a)) \(b)-\(c)"
                                                    }
                                                    return raw
                                                }
                                                return hotel.link
                                            }()
                                            Text(phoneString)
                                                .font(.subheadline)
                                                .foregroundStyle(Color.aestheticGold)
                                            Image(systemName: "chevron.forward").font(.footnote)
                                        }
                                        .padding()
                                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.06)))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 16).fill(Color.primaryNavy))
                    }

                    // Persistent Tickets Button
                    Button {
                        if let url = URL(string: "https://middletownaviationfoundation.ticketspice.com/hops-in-the-hangar-2026") {
                            openURL(url)
                            Analytics.logEvent("get_tickets_tap", parameters: nil)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "ticket.fill")
                            Text("Get Tickets").fontWeight(.bold)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Color.aestheticGold))
                        .foregroundStyle(Color.deepNavy)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color.deepNavy)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Sponsors
struct SponsorsView: View {
    let eventData: EventData?
    @Environment(\.openURL) private var openURL
    @State private var query = ""
    @State private var selectedTiers: Set<String> = [
        "Premier", "Top Flight", "First Class", "Business Class", "Coach Class", "Passport", "Breweries"
    ]
    @State private var sheetSponsor: SponsorItem? = nil
    @State private var isFilterPresented: Bool = false

    private let allTiers = [
        "Premier", "Top Flight", "First Class", "Business Class", "Coach Class", "Passport", "Breweries"
    ]

    let premierItems: [SponsorItem] = [
        SponsorItem(name: "City of Middletown", level: "Premier", description: "City of Middletown Sponsor", website: nil, links: nil),
        SponsorItem(name: "MWO", level: "Premier", description: "Middletown Regional Airport Sponsor", website: nil, links: nil),
        SponsorItem(name: "Start Skydiving", level: "Premier", description: "Start Skydiving Sponsor", website: nil, links: nil),
        SponsorItem(name: "Team Fastrax", level: "Premier", description: "Team Fastrax Sponsor", website: nil, links: nil)
    ]

    var baseSponsors: [SponsorItem] {
        let raw = eventData?.sponsors ?? []
        let excludedNames = ["City of Middletown", "MWO", "Start Skydiving", "Team Fastrax", "City of Middletown & MWO", "Start Skydiving & Team Fastrax"]
        return raw.filter { sponsor in
            !excludedNames.contains { sponsor.name.localizedCaseInsensitiveContains($0) }
        }
    }
    
    var filteredPremier: [SponsorItem] {
        premierItems.filter { sponsor in
            let matchesQuery = query.isEmpty || sponsor.name.localizedCaseInsensitiveContains(query)
            let matchesTier = selectedTiers.contains("Premier")
            return matchesQuery && matchesTier
        }
    }

    var filteredBase: [SponsorItem] {
        baseSponsors.filter { sponsor in
            let matchesQuery = query.isEmpty ||
                sponsor.name.localizedCaseInsensitiveContains(query) ||
                sponsor.level.localizedCaseInsensitiveContains(query)
            
            let matchesTier = selectedTiers.contains { tier in
                tier != "Premier" && sponsor.level.localizedCaseInsensitiveContains(tier)
            }
            
            return matchesQuery && matchesTier
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderView(title: "Sponsors", showAppIcon: false)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            // Search Bar + Filter Trigger Button
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search Sponsors", text: $query)
                        .foregroundStyle(.white)
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))

                Button {
                    isFilterPresented = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.aestheticGold)
                        
                        if selectedTiers.count < allTiers.count {
                            Circle()
                                .fill(Color.pink)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                    .padding(.trailing, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            // Sponsor List
            List {
                if !filteredPremier.isEmpty {
                    Section {
                        ForEach(filteredPremier) { sponsor in
                            Button {
                                Analytics.logEvent("sponsor_open", parameters: ["name": sponsor.name])
                                let urlString = sponsor.links?.first?.url ?? sponsor.website
                                if let u = urlString, let url = URL(string: u) { openURL(url) }
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    ZStack {
                                        Circle().stroke(Color.aestheticGold.opacity(0.6), lineWidth: 2).frame(width: 40, height: 40)
                                        let asset = assetName(from: sponsor.name)
                                        if UIImage(named: asset) != nil {
                                            Image(asset)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 36, height: 36)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(Color.aestheticGold)
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sponsor.name).fontWeight(.semibold).foregroundStyle(.white)
                                        Text(sponsor.description).foregroundStyle(Color.aestheticGold.opacity(0.8)).font(.subheadline).lineLimit(2)
                                        Text(sponsor.level).font(.caption2).foregroundStyle(Color.aestheticGold)
                                    }
                                    Spacer()
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.aestheticGold.opacity(0.15)))
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("Premier Sponsors")
                            .font(.headline)
                            .foregroundStyle(Color.aestheticGold)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                }

                if !filteredBase.isEmpty {
                    Section {
                        ForEach(filteredBase) { sponsor in
                            Button {
                                Analytics.logEvent("sponsor_open", parameters: ["name": sponsor.name])
                                if let links = sponsor.links, links.count > 1 {
                                    sheetSponsor = sponsor
                                } else {
                                    let urlString = sponsor.links?.first?.url ?? sponsor.website
                                    if let u = urlString, let url = URL(string: u) { openURL(url) }
                                }
                            } label: {
                                HStack(alignment: .center, spacing: 12) {
                                    ZStack {
                                        Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 2).frame(width: 40, height: 40)
                                        let asset = assetName(from: sponsor.name)
                                        if UIImage(named: asset) != nil {
                                            Image(asset)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 36, height: 36)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "star.fill")
                                                .foregroundStyle(Color.aestheticGold)
                                        }
                                    }
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(sponsor.name).fontWeight(.semibold)
                                        Text(sponsor.description).foregroundStyle(.secondary).font(.subheadline).lineLimit(2)
                                        Text(sponsor.level).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primaryNavy))
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        if !filteredPremier.isEmpty {
                            Text("All Sponsors")
                                .font(.headline)
                                .foregroundStyle(Color.aestheticGold)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                }
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
        }
        .background(Color.deepNavy)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isFilterPresented) {
            FilterSelectionSheet(
                title: "Filter Sponsors",
                options: allTiers,
                selectedOptions: $selectedTiers
            )
        }
        .sheet(item: $sheetSponsor) { sponsor in
            NavigationStack {
                List {
                    Section {
                        ForEach(sponsor.links ?? [], id: \.self) { link in
                            Button {
                                Analytics.logEvent("sponsor_open", parameters: ["name": sponsor.name])
                                if let url = URL(string: link.url) { openURL(url) }
                            } label: {
                                HStack {
                                    Text(link.label)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.white)
                                    Spacer()
                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundStyle(Color.aestheticGold)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.primaryNavy))
                            }
                            .buttonStyle(.plain)
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                        }
                    } header: {
                        Text("Open Website")
                            .foregroundStyle(Color.aestheticGold)
                    }
                }
                .scrollContentBackground(.hidden)
                .background(Color.deepNavy)
                .listStyle(.plain)
                .navigationTitle(sponsor.name)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { sheetSponsor = nil }
                            .foregroundStyle(Color.aestheticGold)
                    }
                }
            }
            .modifier(NavyTheme())
            .presentationDetents([.medium, .large])
        }
    }

    private func assetName(from name: String) -> String {
        let lower = name.lowercased()
        if lower.contains("mwo") || lower.contains("middletown regional airport") {
            return "mwo"
        }
        if lower.contains("kara goheen") {
            return "kara_goheen_friends_and_furball"
        }
        if lower.contains("affordable dentures") {
            return "affordable_dentures_and_implants"
        }
        let underscored = lower.replacingOccurrences(of: " & ", with: "_")
            .replacingOccurrences(of: " ", with: "_")
        return underscored.replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression)
    }
}

// MARK: - Vendors
struct VendorsView: View {
    let eventData: EventData?
    @ObservedObject var favorites: FavoritesStore
    @Environment(\.openURL) private var openURL

    @State private var query = ""
    @State private var selected: Set<String> = ["Brewery", "Food Truck"]
    @State private var isFilterPresented: Bool = false

    private let categories = ["Brewery", "Food Truck"]

    var vendors: [VendorItem] { eventData?.vendors ?? [] }
    var filtered: [VendorItem] {
        vendors.filter { v in
            (query.isEmpty || v.name.localizedCaseInsensitiveContains(query) || v.category.localizedCaseInsensitiveContains(query)) &&
            selected.contains(v.category)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderView(title: "Vendors", showAppIcon: false)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            // Search Bar + Filter Trigger Button
            HStack(spacing: 8) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search Vendors", text: $query)
                        .foregroundStyle(.white)
                    if !query.isEmpty {
                        Button {
                            query = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.1)))

                Button {
                    isFilterPresented = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.aestheticGold)
                        
                        if selected.count < categories.count {
                            Circle()
                                .fill(Color.pink)
                                .frame(width: 8, height: 8)
                                .offset(x: 2, y: -2)
                        }
                    }
                    .padding(.trailing, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)

            // Vendor List
            List {
                Section {
                    ForEach(filtered) { vendor in
                        HStack(alignment: .center, spacing: 12) {
                            ZStack {
                                Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 2).frame(width: 40, height: 40)
                                let asset = assetName(from: vendor.name)
                                if UIImage(named: asset) != nil {
                                    Image(asset)
                                        .resizable().scaledToFill().frame(width: 36, height: 36).clipShape(Circle())
                                } else {
                                    Image(systemName: iconName(for: vendor.category)).foregroundStyle(.secondary)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vendor.name).fontWeight(.semibold)
                                Text(vendor.description).foregroundStyle(.secondary).font(.subheadline).lineLimit(2)
                                Text(vendor.category).font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                favorites.toggle(vendor.name)
                            } label: {
                                Image(systemName: favorites.ids.contains(vendor.name) ? "heart.fill" : "heart")
                                    .foregroundStyle(favorites.ids.contains(vendor.name) ? Color.pink : Color.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primaryNavy))
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
            }
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
        }
        .background(Color.deepNavy)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $isFilterPresented) {
            FilterSelectionSheet(
                title: "Filter Vendors",
                options: categories,
                selectedOptions: $selected
            )
        }
    }

    private func iconName(for category: String) -> String {
        if category.localizedCaseInsensitiveContains("Food") { return "fork.knife" }
        if category.localizedCaseInsensitiveContains("Brewery") { return "wineglass" }
        if category.localizedCaseInsensitiveContains("Spirits") { return "wineglass" }
        return "cart"
    }
    private func assetName(from name: String) -> String {
        let lower = name.lowercased()
        let underscored = lower.replacingOccurrences(of: " ", with: "_")
        return underscored.replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression)
    }
}

// MARK: - Entertainment
struct EntertainmentView: View {
    let eventData: EventData?
    var schedule: [ScheduleItem] { eventData?.schedule ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            ScreenHeaderView(title: "Events", showAppIcon: false)
                .padding(.horizontal, 16)
                .padding(.bottom, 16)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    // MARK: Ground Entertainment
                    SectionTitleHeader(title: "Ground Entertainment", isFirst: true)
                    
                    EntertainmentRow(
                        title: "DJ Ron Perry — Live Music DJ",
                        subtitle: "Live Performance",
                        icon: "music.note"
                    )
                    EntertainmentRow(
                        title: "Jennifer Kauffman — National Anthem",
                        subtitle: "Special Vocalist",
                        icon: "person.wave.2.fill"
                    )
                    EntertainmentRow(
                        title: "Steel Drum Dave — Check In Entertainment",
                        subtitle: "Live Performance",
                        icon: "music.note"
                    )

                    // MARK: In Flight Performers
                    SectionTitleHeader(title: "In Flight Performers")
                    
                    EntertainmentRow(
                        title: "Wild Bill (Steve Henshew)",
                        subtitle: "Announcer",
                        icon: "mic.fill"
                    )
                    EntertainmentRow(
                        title: "Team Fastrax (Nicole Condrey)",
                        subtitle: "Flag Jump",
                        icon: "airplane"
                    )
                    EntertainmentRow(
                        title: "Nick Coleman",
                        subtitle: "Aerobatic Performance",
                        icon: "airplane"
                    )
                    EntertainmentRow(
                        title: "Bob Richards",
                        subtitle: "Aerobatic Performance",
                        icon: "airplane"
                    )
                    EntertainmentRow(
                        title: "Smoke on Aviation Team",
                        subtitle: "8 Pilot Formation Team",
                        icon: "airplane"
                    )
                    EntertainmentRow(
                        title: "Mike Hartman",
                        subtitle: "Aerobatic Performance",
                        icon: "airplane"
                    )
                    EntertainmentRow(
                        title: "Emerson Stewart III",
                        subtitle: "Aerobatic Performance",
                        icon: "airplane"
                    )
                    EntertainmentRow(
                        title: "Rob LeCerda",
                        subtitle: "Aerobatic Performance",
                        icon: "airplane"
                    )

                    // MARK: Event Schedule Timeline
                    SectionTitleHeader(title: "Event Schedule")
                    
                    ForEach(schedule, id: \.id) { item in
                        HStack(alignment: .center, spacing: 12) {
                            ZStack {
                                Circle()
                                    .stroke(Color.secondary.opacity(0.4), lineWidth: 2)
                                    .frame(width: 40, height: 40)
                                Image(systemName: "calendar")
                                    .foregroundStyle(Color.aestheticGold)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.event)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.white)
                                Text(item.time)
                                    .font(.subheadline)
                                    .foregroundStyle(Color.gray)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primaryNavy))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .background(Color.deepNavy)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Supporting Subviews for Events Layout
private struct SectionTitleHeader: View {
    let title: String
    var isFirst: Bool = false

    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.bold)
            .foregroundStyle(Color.aestheticGold)
            .padding(.top, isFirst ? 0 : 12)
            .padding(.bottom, 2)
    }
}

private struct EntertainmentRow: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.4), lineWidth: 2)
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .foregroundStyle(Color.aestheticGold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primaryNavy))
    }
}

#Preview {
    ContentView()
}
