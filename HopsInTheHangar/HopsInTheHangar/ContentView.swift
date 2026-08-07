import SwiftUI
import WebKit
import Combine
import FirebaseAnalytics
import UIKit

// MARK: - Models
struct SponsorLink: Codable, Hashable { let label: String; let url: String }
struct SponsorItem: Codable, Identifiable, Hashable { let id = UUID(); let name: String; let level: String; let description: String; let website: String?; let links: [SponsorLink]? }
struct VendorItem: Codable, Identifiable, Hashable { let id = UUID(); let name: String; let category: String; let description: String; let email: String?; let phone: String?; let website: String?; let mapId: String? }
struct ScheduleItem: Codable, Identifiable, Hashable { let id = UUID(); let time: String; let event: String }
struct HotelItem: Codable, Identifiable, Hashable { let id = UUID(); let name: String; let link: String }
struct GeneralInfo: Codable, Hashable { let parking: String; let rules: String; let hotels: [HotelItem] }
struct EventData: Codable, Hashable { let sponsors: [SponsorItem]; let vendors: [VendorItem]; let schedule: [ScheduleItem]; let info: GeneralInfo }

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

// MARK: - App Shell
struct ContentView: View {
    init() {
        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(Color.primaryNavy)
        navAppearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        navAppearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        UINavigationBar.appearance().tintColor = UIColor(Color.aestheticGold)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = UIColor(Color.primaryNavy)
        tabAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.aestheticGold)
        tabAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.white]
        tabAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(Color.secondarySlate)
        tabAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor(Color.secondarySlate)]
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance
        UITabBar.appearance().tintColor = UIColor(Color.aestheticGold)
        UITabBar.appearance().unselectedItemTintColor = UIColor(Color.secondarySlate)
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

// MARK: - Home
struct HomeView: View {
    let eventData: EventData?
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // App icon circle
                ZStack {
                    Circle().fill(Color.white).frame(width: 140, height: 140)
                    Image(systemName: "airplane.circle.fill")
                        .resizable().scaledToFit().frame(width: 120, height: 120)
                        .foregroundStyle(.primary)
                }
                .padding(.top, 8)

                // Welcome card
                VStack(alignment: .leading, spacing: 12) {
                    Text("Welcome to the Show")
                        .foregroundStyle(Color.aestheticGold)
                    Text("Welcome to Hops in the Hangar, your Craft Beer & Airshow event app! Explore vendors, sponsors, venue info, hotels, entertainment, and performers.")
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(RoundedRectangle(cornerRadius: 16).fill(Color.primaryNavy))

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
                    .background(RoundedRectangle(cornerRadius: 16).fill(Color.primaryNavy))
                }

                // Persistent Tickets button
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
            .padding(16)
        }
        .background(Color.deepNavy)
        .navigationTitle("Hops in the Hangar")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Sponsors
struct SponsorsView: View {
    let eventData: EventData?
    @Environment(\.openURL) private var openURL
    @State private var query = ""
    @State private var sheetSponsor: SponsorItem? = nil

    var sponsors: [SponsorItem] { eventData?.sponsors ?? [] }
    var filtered: [SponsorItem] {
        guard !query.isEmpty else { return sponsors }
        return sponsors.filter { $0.name.localizedCaseInsensitiveContains(query) || $0.level.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
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
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 2).frame(width: 48, height: 48)
                                    if let image = Image(uiImage: UIImage(named: assetName(from: sponsor.name)) ?? UIImage()) as Image?, UIImage(named: assetName(from: sponsor.name)) != nil {
                                        Image(assetName(from: sponsor.name))
                                            .resizable().scaledToFill().frame(width: 44, height: 44).clipShape(Circle())
                                    } else {
                                        Image(systemName: "star.fill").foregroundStyle(Color.aestheticGold)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(sponsor.name)
                                    Text(sponsor.description).foregroundStyle(.secondary).lineLimit(2)
                                    Text(sponsor.level.uppercased()).font(.caption).foregroundStyle(Color.aestheticGold)
                                }
                                Spacer()
                            }
                            .padding(12)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.primaryNavy))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .listRowBackground(Color.clear)
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search Sponsors")
        .navigationTitle("Sponsors")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.deepNavy)
        .listStyle(.plain)
        .sheet(item: $sheetSponsor) { sponsor in
            NavigationStack {
                List {
                    Section("Open Website") {
                        ForEach(sponsor.links ?? [], id: \.self) { link in
                            Button(link.label) {
                                Analytics.logEvent("sponsor_open", parameters: ["name": sponsor.name])
                                if let url = URL(string: link.url) { openURL(url) }
                            }
                        }
                    }
                }
                .navigationTitle(sponsor.name)
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { sheetSponsor = nil } } }
            }
        }
    }
    private func assetName(from name: String) -> String {
        let lower = name.lowercased()
        let allowed = lower.replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression)
        return allowed.replacingOccurrences(of: " ", with: "_")
    }
}

// MARK: - Vendors
struct VendorsView: View {
    let eventData: EventData?
    @ObservedObject var favorites: FavoritesStore
    @Environment(\.openURL) private var openURL

    @State private var query = ""
    @State private var selected: Set<String> = ["Brewery", "Food Truck"]

    var vendors: [VendorItem] { eventData?.vendors ?? [] }
    var filtered: [VendorItem] {
        vendors.filter { v in
            (query.isEmpty || v.name.localizedCaseInsensitiveContains(query) || v.category.localizedCaseInsensitiveContains(query)) &&
            selected.contains(v.category)
        }
    }

    var body: some View {
        List {
            Section {
                ForEach(filtered) { vendor in
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle().stroke(Color.secondary.opacity(0.4), lineWidth: 2).frame(width: 48, height: 48)
                            if UIImage(named: assetName(from: vendor.name)) != nil {
                                Image(assetName(from: vendor.name))
                                    .resizable().scaledToFill().frame(width: 44, height: 44).clipShape(Circle())
                            } else {
                                Image(systemName: iconName(for: vendor.category)).foregroundStyle(.secondary)
                            }
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vendor.name)
                            Text(vendor.description).foregroundStyle(.secondary).lineLimit(2)
                            Text(vendor.category.uppercased()).font(.caption).foregroundStyle(.secondary)
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
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primaryNavy))
                }
            }
            .listRowBackground(Color.clear)
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search Vendors")
        .toolbar {
            Menu {
                ForEach(["Brewery", "Food Truck"], id: \.self) { c in
                    Button(action: { toggle(category: c) }) {
                        Label(c, systemImage: selected.contains(c) ? "checkmark" : "")
                    }
                }
            } label: { Image(systemName: "line.3.horizontal.decrease.circle") }
        }
        .navigationTitle("Vendors")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.deepNavy)
        .listStyle(.plain)
    }

    private func toggle(category: String) {
        if selected.contains(category) { selected.remove(category) } else { selected.insert(category) }
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
        List {
            Section("Ground Entertainment") {
                Label("Jane Doe — Entertainment Host", systemImage: "mic.fill")
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primaryNavy))
                    .listRowBackground(Color.clear)
                Label("DJ Mixmaster — Live Music DJ", systemImage: "music.note")
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primaryNavy))
                    .listRowBackground(Color.clear)
                Label("John Smith — National Anthem", systemImage: "person.wave.2.fill")
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primaryNavy))
                    .listRowBackground(Color.clear)
            }
            Section("In Flight Performers") {
                Label("Wild Bill — Steven Hanshew", systemImage: "mic.fill")
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primaryNavy))
                    .listRowBackground(Color.clear)
                Label("Team Fastrax — Opening Jump", systemImage: "airplane")
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primaryNavy))
                    .listRowBackground(Color.clear)
            }
            Section("Event Schedule") {
                ForEach(schedule, id: \.id) { item in
                    HStack {
                        Image(systemName: "calendar")
                        VStack(alignment: .leading) {
                            Text(item.event)
                            Text(item.time).foregroundStyle(Color.aestheticGold).font(.subheadline)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color.primaryNavy))
                    .listRowBackground(Color.clear)
                }
            }
        }
        .navigationTitle("Events")
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
        .background(Color.deepNavy)
        .listStyle(.plain)
    }
}

// MARK: - Map Overlay State
final class MapOverlayState: ObservableObject {
    @Published var zoomScale: CGFloat = 1.0
    @Published var selectedRegionId: String? = nil
}

// MARK: - Map (Zoomable SVG with progressive detail)
struct MapContainerView: View {
    let eventData: EventData?
    @ObservedObject var favorites: FavoritesStore

    @StateObject private var overlayState = MapOverlayState()

    var body: some View {
        ZStack {
            MapView(svgName: "map", eventData: eventData, favorites: favorites, overlayState: overlayState)
            MapOverlayView(eventData: eventData, favorites: favorites, overlayState: overlayState)
            if overlayState.zoomScale > 1.2 || overlayState.selectedRegionId != nil {
                Button {
                    overlayState.zoomScale = 1.0
                    overlayState.selectedRegionId = nil
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }
        }
        .background(Color.deepNavy)
        .ignoresSafeArea()
        .navigationTitle("Event Map")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { Analytics.logEvent(AnalyticsEventScreenView, parameters: [AnalyticsParameterScreenName: "map"]) }
    }
}

struct MapOverlayView: View {
    let eventData: EventData?
    @ObservedObject var favorites: FavoritesStore
    @ObservedObject var overlayState: MapOverlayState

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Vendor overlays by zoom thresholds
                if let vendors = eventData?.vendors {
                    ForEach(vendors, id: \.name) { vendor in
                        if let regionId = vendor.mapId, let anchor = anchorForRegion(id: regionId, in: geo.size) {
                            let isFav = favorites.ids.contains(vendor.name)
                            let isSelected = overlayState.selectedRegionId == regionId
                            let z = overlayState.zoomScale

                            Group {
                                if z > 5.5 || isFav || isSelected {
                                    // Logo/Label
                                    VStack(spacing: 4) {
                                        overlayCircle(size: 40, fill: isSelected ? Color.aestheticGold : (isFav ? Color.pink : Color.primaryNavy), stroke: Color.white)
                                            .overlay(logoView(for: vendor.name).clipShape(Circle()))
                                        if z > 7.5 || isSelected {
                                            Text(vendor.name)
                                                .font(.caption2)
                                                .fontWeight(.semibold)
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.black.opacity(isSelected ? 0.8 : 0.6), in: RoundedRectangle(cornerRadius: 4))
                                                .fixedSize()
                                        }
                                    }
                                } else if z > 3.5 {
                                    // Booth number (derived from regionId digits)
                                    let booth = regionId.filter { $0.isNumber }
                                    overlayCircle(size: 28, fill: Color.primaryNavy, stroke: Color.aestheticGold)
                                        .overlay(Text(booth.isEmpty ? "?" : booth).font(.caption).fontWeight(.bold).foregroundColor(.white))
                                } else {
                                    // Category icon
                                    overlayCircle(size: 20, fill: Color.primaryNavy, stroke: Color.secondarySlate)
                                        .overlay(Image(systemName: iconName(for: vendor.category)).font(.system(size: 10)).foregroundColor(Color.aestheticGold))
                                }
                            }
                            .position(anchor)
                            .onTapGesture { overlayState.selectedRegionId = regionId }
                        }
                    }
                }

                // HUD for debug
                VStack(spacing: 6) {
                    if let id = overlayState.selectedRegionId {
                        Text("Selected: \(id)").font(.caption).padding(6).background(Color.black.opacity(0.6), in: Capsule()).foregroundColor(.white)
                    }
                    Text(String(format: "Zoom: %.2fx", overlayState.zoomScale)).font(.caption2).padding(4).background(Color.black.opacity(0.5), in: Capsule()).foregroundColor(.white)
                }
                .padding(.top, 8)
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .allowsHitTesting(true)
    }

    private func overlayCircle(size: CGFloat, fill: Color, stroke: Color) -> some View {
        Circle().fill(fill).frame(width: size, height: size).overlay(Circle().stroke(stroke, lineWidth: 2))
    }
    private func logoView(for name: String) -> some View {
        if UIImage(named: assetName(from: name)) != nil {
            return AnyView(Image(assetName(from: name)).resizable().scaledToFill())
        } else {
            return AnyView(Image(systemName: "photo").resizable().scaledToFit().padding(6).foregroundColor(.white))
        }
    }
    private func assetName(from name: String) -> String {
        let lower = name.lowercased()
        let underscored = lower.replacingOccurrences(of: " ", with: "_")
        return underscored.replacingOccurrences(of: "[^a-z0-9_]", with: "", options: .regularExpression)
    }
    private func iconName(for category: String) -> String {
        if category.localizedCaseInsensitiveContains("Food") { return "fork.knife" }
        if category.localizedCaseInsensitiveContains("Brewery") { return "wineglass" }
        if category.localizedCaseInsensitiveContains("Spirits") { return "wineglass" }
        return "cart"
    }
    // Map region -> screen anchor approximation. Without true SVG geometry, we place anchors evenly as a placeholder.
    private func anchorForRegion(id: String, in size: CGSize) -> CGPoint? {
        // Placeholder: distribute anchors in a grid based on hash of id
        let hash = abs(id.hashValue)
        let cols = 6
        let rows = 6
        let col = hash % cols
        let row = (hash / cols) % rows
        let x = CGFloat(col + 1) / CGFloat(cols + 1) * size.width
        let y = CGFloat(row + 1) / CGFloat(rows + 1) * size.height
        return CGPoint(x: x, y: y)
    }
}

// Simple WebKit-based SVG renderer with overlay logic hooks. You asked for progressive detail on zoom; we start with a working SVG view and hooks for detail overlays.
struct MapView: UIViewRepresentable {
    let svgName: String
    let eventData: EventData?
    @ObservedObject var favorites: FavoritesStore
    @ObservedObject var overlayState: MapOverlayState

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        // JS to report zoom scale and taps
        let js = """
        (function(){
            function send(msg){ window.webkit.messageHandlers.mapBridge.postMessage(msg); }
            document.addEventListener('click', function(e){
                var target = e.target;
                var id = target.id || (target.closest('[id]') ? target.closest('[id]').id : null);
                if(id){ send({type:'tap', id:id}); }
            }, true);
            var lastScale = 1.0;
            function reportScale(){
                var scale = window.visualViewport ? window.visualViewport.scale : 1.0;
                if(scale !== lastScale){ lastScale = scale; send({type:'zoom', scale: scale}); }
                window.requestAnimationFrame(reportScale);
            }
            reportScale();
        })();
        """
        let userScript = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(userScript)
        contentController.add(context.coordinator, name: "mapBridge")
        config.userContentController = contentController

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = UIColor(Color.deepNavy)
        web.scrollView.minimumZoomScale = 1.0
        web.scrollView.maximumZoomScale = 8.0

        if let url = Bundle.main.url(forResource: svgName, withExtension: "svg") {
            web.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // Optionally, could programmatically reset zoom/selection via JS
    }

    final class Coordinator: NSObject, WKScriptMessageHandler {
        let parent: MapView
        init(_ parent: MapView) { self.parent = parent }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "mapBridge" else { return }
            if let dict = message.body as? [String: Any] {
                if let type = dict["type"] as? String {
                    switch type {
                    case "zoom":
                        if let scale = dict["scale"] as? CGFloat {
                            DispatchQueue.main.async { self.parent.overlayState.zoomScale = max(1.0, scale) }
                        }
                    case "tap":
                        if let id = dict["id"] as? String {
                            DispatchQueue.main.async { self.parent.overlayState.selectedRegionId = id }
                        }
                    default: break
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

// MARK: - Asset placement instructions (for you):
// - Add event_data.json and map.svg to your Xcode project target (Build Phases -> Copy Bundle Resources). Name the files exactly: event_data.json and map.svg.
// - Place sponsor/vendor logos in the Asset Catalog with names matching your vendor/sponsor identifiers, or keep SF Symbols fallback.

