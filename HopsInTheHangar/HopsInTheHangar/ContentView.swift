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

            NavigationStack { MapContainerView(eventData: eventData, favorites: favorites) }
                .tabItem { Label("Map", systemImage: "map.fill") }

            NavigationStack { EntertainmentView(eventData: eventData).onAppear { Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "events"]) } }
                .tabItem { Label("Events", systemImage: "list.bullet.rectangle.fill") }

            NavigationStack { VendorsView(eventData: eventData, favorites: favorites).onAppear { Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "vendors"]) } }
                .tabItem { Label("Vendors", systemImage: "cart.fill") }
        }
        .modifier(NavyTheme())
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

                    // FAQ Section
                    if let faqs = eventData?.faq, !faqs.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Frequently Asked Questions")
                                .font(.headline)
                                .foregroundStyle(Color.aestheticGold)
                            
                            ForEach(faqs) { item in
                                DisclosureGroup {
                                    Text(item.answer)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
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
        "Top Flight", "First Class", "Business Class", "Coach Class", "Passport", "Breweries"
    ]
    @State private var sheetSponsor: SponsorItem? = nil
    @State private var isFilterPresented: Bool = false

    private let allTiers = [
        "Top Flight", "First Class", "Business Class", "Coach Class", "Passport", "Breweries"
    ]

    var sponsors: [SponsorItem] { eventData?.sponsors ?? [] }
    
    var filtered: [SponsorItem] {
        sponsors.filter { sponsor in
            let matchesQuery = query.isEmpty ||
                sponsor.name.localizedCaseInsensitiveContains(query) ||
                sponsor.level.localizedCaseInsensitiveContains(query)
            
            let matchesTier = selectedTiers.contains { tier in
                sponsor.level.localizedCaseInsensitiveContains(tier)
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
                if !sponsors.isEmpty {
                    Section {
                        ForEach(filtered) { sponsor in
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
                                        if UIImage(named: assetName(from: sponsor.name)) != nil {
                                            Image(assetName(from: sponsor.name))
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
        let underscored = lower.replacingOccurrences(of: " ", with: "_")
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
                                if UIImage(named: assetName(from: vendor.name)) != nil {
                                    Image(assetName(from: vendor.name))
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
                .padding(.bottom, 0)

            List {
                // MARK: Ground Entertainment
                Section {
                    EntertainmentRow(
                        title: "Jane Doe — Entertainment Host",
                        subtitle: "Ground Host",
                        icon: "mic.fill"
                    )
                    EntertainmentRow(
                        title: "DJ Mixmaster — Live Music DJ",
                        subtitle: "Live Performance",
                        icon: "music.note"
                    )
                    EntertainmentRow(
                        title: "John Smith — National Anthem",
                        subtitle: "Special Vocalist",
                        icon: "person.wave.2.fill"
                    )
                } header: {
                    SectionTitleHeader(title: "Ground Entertainment")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))

                // MARK: In Flight Performers
                Section {
                    EntertainmentRow(
                        title: "Wild Bill — Steven Hanshew",
                        subtitle: "Aerobatic Performer",
                        icon: "mic.fill"
                    )
                    EntertainmentRow(
                        title: "Team Fastrax — Opening Jump",
                        subtitle: "Skydiving Exhibition",
                        icon: "airplane"
                    )
                } header: {
                    SectionTitleHeader(title: "In Flight Performers")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))

                // MARK: Event Schedule Timeline
                Section {
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
                                    .foregroundStyle(Color.aestheticGold)
                            }
                            Spacer()
                        }
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 10).fill(Color.primaryNavy))
                    }
                } header: {
                    SectionTitleHeader(title: "Event Schedule")
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
            }
            .listRowSpacing(0)
            .scrollContentBackground(.hidden)
            .listStyle(.plain)
        }
        .background(Color.deepNavy)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Supporting Subviews for Events Layout
private struct SectionTitleHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.bold)
            .foregroundStyle(Color.aestheticGold)
            .padding(.top, 8)
            .padding(.bottom, 2)
            .textCase(nil)
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

// MARK: - OpenStreetMap Route View (Leaflet)
struct OSMRouteView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.isOpaque = false
        webView.backgroundColor = UIColor(Color.deepNavy)
        
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no" />
            <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" />
            <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
            <style>
                body, html, #map { height: 100%; width: 100%; margin: 0; padding: 0; background: #0A192F; }
                .leaflet-container { background: #0A192F; }
            </style>
        </head>
        <body>
            <div id="map"></div>
            <script>
                var map = L.map('map').setView([39.5255, -84.3950], 15);
                L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                    maxZoom: 19,
                    attribution: '© OpenStreetMap'
                }).addTo(map);

                var waypoints = [
                    [39.5219738270208, -84.39756916125495],
                    [39.52392228883309, -84.39758570695065],
                    [39.523858475447454, -84.39595871354263],
                    [39.527066399999974, -84.39509747693043],
                    [39.527587748793955, -84.3938167808926],
                    [39.52815437416716, -84.39416932546087],
                    [39.528705851297936, -84.39335856931429],
                    [39.52926176496046, -84.39276198740617]
                ];

                var polyline = L.polyline(waypoints, {color: '#F7D08A', weight: 5, opacity: 0.9}).addTo(map);
                
                L.marker(waypoints[0]).addTo(map).bindPopup('<b>Start:</b> 500 Tytus Ave');
                L.marker(waypoints[waypoints.length - 1]).addTo(map).bindPopup('<b>Destination:</b> Start Skydiving (1711 Run Way)');

                map.fitBounds(polyline.getBounds(), {padding: [30, 30]});
            </script>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

// MARK: - Map Main Container View
struct MapContainerView: View {
    let eventData: EventData?
    @ObservedObject var favorites: FavoritesStore
    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .top) {
            // Background Base
            Color.deepNavy
                .ignoresSafeArea()

            // Content Area
            if selectedTab == 0 {
                VStack(spacing: 0) {
                    ScreenHeaderView(title: "Map", showAppIcon: false)
                        .padding(.horizontal, 16)

                    Picker("Map Option", selection: $selectedTab) {
                        Text("Event Map").tag(0)
                        Text("Getting to Event").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    ZStack {
                        Color.deepNavy
                        VStack(spacing: 12) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(Color.aestheticGold)
                            Text("Event Map Coming Soon")
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                // Leaflet Map layer extending edge-to-edge
                OSMRouteView()
                    .ignoresSafeArea(edges: .bottom)

                // Floating Header Controls pinned to top
                VStack(spacing: 0) {
                    ScreenHeaderView(title: "Map", showAppIcon: false)
                        .padding(.horizontal, 16)

                    Picker("Map Option", selection: $selectedTab) {
                        Text("Event Map").tag(0)
                        Text("Getting to Event").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .background(Color.deepNavy)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear { Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "map"]) }
    }
}

#Preview {
    ContentView()
}
