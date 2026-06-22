import SwiftUI
import Combine

// ── Color helpers ─────────────────────────────────────
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xff) / 255
        let g = Double((int >> 8)  & 0xff) / 255
        let b = Double(int         & 0xff) / 255
        self.init(red: r, green: g, blue: b)
    }
    static let cream     = Color(hex: "F5F0E8")
    static let creamDeep = Color(hex: "EDE8DF")
    static let ink       = Color(hex: "1A1A18")
    static let inkLight  = Color(hex: "6B6B60")
}

// ── Preset card colors ────────────────────────────────
struct CardColorPair: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let light: String
    let dark: String
}

let cardColorPresets: [CardColorPair] = [
    CardColorPair(name: "Sand",     light: "E8C99A", dark: "D4A574"),
    CardColorPair(name: "Sage",     light: "A3BEA8", dark: "7B9E87"),
    CardColorPair(name: "Terra",    light: "D4A090", dark: "C17767"),
    CardColorPair(name: "Slate",    light: "A3B4C8", dark: "7B8FA8"),
    CardColorPair(name: "Lavender", light: "BEB3DC", dark: "9B8EC4"),
    CardColorPair(name: "Rose",     light: "E8A8B8", dark: "C97888"),
    CardColorPair(name: "Moss",     light: "A8C4A0", dark: "6E9E64"),
    CardColorPair(name: "Dusk",     light: "B8A8D4", dark: "8878B4"),
    CardColorPair(name: "Copper",   light: "D4B89A", dark: "B8845A"),
    CardColorPair(name: "Ocean",    light: "A8C8D8", dark: "5A98B8"),
]

// ── Tag ───────────────────────────────────────────────
enum TemplateTag: String, CaseIterable, Codable {
    case header    = "Header"
    case internal_ = "Internal"
    case qa        = "QA"
    case client    = "Client"
    case custom    = "Custom"

    var defaultColorPair: CardColorPair {
        switch self {
        case .header:    return cardColorPresets[0]
        case .internal_: return cardColorPresets[1]
        case .qa:        return cardColorPresets[2]
        case .client:    return cardColorPresets[3]
        case .custom:    return cardColorPresets[4]
        }
    }
}

// ── Models ────────────────────────────────────────────
struct BuiltInTemplate: Identifiable {
    let id = UUID()
    let title: String
    let tag: TemplateTag
    let people: [String]?
    let colorLight: String
    let colorDark: String
    let body: (String) -> String
}

struct CustomTemplate: Identifiable, Codable {
    var id = UUID()
    var title: String
    var tag: TemplateTag
    var people: [String]
    var bodyText: String
    var colorLight: String
    var colorDark: String
}

struct AnyTemplateCard: Identifiable {
    let id: UUID
    var title: String
    var tag: TemplateTag
    var people: [String]?
    var colorLight: String
    var colorDark: String
    let resolveBody: (String) -> String
    let isCustom: Bool
    let customId: UUID?

    init(builtIn t: BuiltInTemplate) {
        id = t.id; title = t.title; tag = t.tag
        people = t.people
        colorLight = t.colorLight; colorDark = t.colorDark
        resolveBody = t.body; isCustom = false; customId = nil
    }
    init(custom t: CustomTemplate) {
        id = t.id; title = t.title; tag = t.tag
        people = t.people.isEmpty ? nil : t.people
        colorLight = t.colorLight; colorDark = t.colorDark
        // Replace [name] placeholder with the actual person name when copying
        resolveBody = { person in
            person.isEmpty ? t.bodyText : t.bodyText.replacingOccurrences(of: "[name]", with: person)
        }
        isCustom = true; customId = t.id
    }
}

// ── User settings ─────────────────────────────────────
final class UserSettings: ObservableObject {
    @Published var name: String {
        didSet { UserDefaults.standard.set(name, forKey: "user_name") }
    }
    @Published var team: [String] {
        didSet { UserDefaults.standard.set(team, forKey: "user_team") }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: "onboarding_done") }
    }
    init() {
        self.name = UserDefaults.standard.string(forKey: "user_name") ?? ""
        self.team = UserDefaults.standard.stringArray(forKey: "user_team") ?? []
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "onboarding_done")
    }
}

// ── Template store ────────────────────────────────────
final class TemplateStore: ObservableObject {
    @Published var customs: [CustomTemplate] = []
    private let key = "clippyboard_custom_v1"
    init() { load() }
    func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([CustomTemplate].self, from: data)
        else { return }
        customs = decoded
    }
    func save() {
        if let encoded = try? JSONEncoder().encode(customs) {
            UserDefaults.standard.set(encoded, forKey: key)
        }
    }
    func add(_ t: CustomTemplate) { customs.append(t); save() }
    func update(_ t: CustomTemplate) {
        if let i = customs.firstIndex(where: { $0.id == t.id }) { customs[i] = t; save() }
    }
    func delete(id: UUID) { customs.removeAll { $0.id == id }; save() }
}

// ── Built-in templates ────────────────────────────────
func makeBuiltIns(name: String, team: [String]) -> [BuiltInTemplate] {
    let date = Date().formatted(date: .long, time: .omitted)
    let byName = name.isEmpty ? "Me" : name
    let people = team.isEmpty ? ["Team"] : team
    let p = cardColorPresets

    func header(_ person: String) -> String {
        "• Prepared For: \(person)\n• Prepared By: \(byName)\n• Date: \(date)"
    }
    return [
        BuiltInTemplate(title: "Copy header", tag: .header, people: people, colorLight: p[0].light, colorDark: p[0].dark) { header($0) },
        BuiltInTemplate(title: "Client feedback → dev", tag: .internal_, people: people, colorLight: p[1].light, colorDark: p[1].dark) {
            "\(header($0))\n\nPlease review the client feedback below and update the page accordingly. Once the updates are complete, please send this back for review."
        },
        BuiltInTemplate(title: "Text/copy correction", tag: .internal_, people: people, colorLight: p[1].light, colorDark: p[1].dark) {
            "\(header($0))\n\nPlease review the client feedback below and update all instances of [incorrect text] to [correct text] in the section [section name]."
        },
        BuiltInTemplate(title: "Approved design → dev", tag: .internal_, people: people, colorLight: p[1].light, colorDark: p[1].dark) {
            "\(header($0))\n\nThe design has been reviewed and is approved to move forward. Please send this to development to get updated on the website."
        },
        BuiltInTemplate(title: "Internal QA handoff", tag: .internal_, people: people, colorLight: p[1].light, colorDark: p[1].dark) {
            "\(header($0))\n\nI've completed the initial review and the work is ready for QA. Please review the link below and confirm if any additional revisions are needed.\n[link]"
        },
        BuiltInTemplate(title: "QA with small issue", tag: .qa, people: people, colorLight: p[2].light, colorDark: p[2].dark) {
            "\(header($0))\n\nI reviewed this and everything is looking good overall. The only item I noticed is [specific issue]. Please update this and send it back for review once complete."
        },
        BuiltInTemplate(title: "Mobile issue", tag: .qa, people: [people[0]], colorLight: p[2].light, colorDark: p[2].dark) {
            "\(header($0))\n\nHi \($0), on mobile [specific issue]. Can we please get this adjusted?\n[link/screenshot]"
        },
        BuiltInTemplate(title: "Ready for client review", tag: .client, people: nil, colorLight: p[3].light, colorDark: p[3].dark) { _ in
            "Hi [Client Name],\n\nThe [page/design/assets] are ready for your review here:\n[link]\n\nPlease let us know if this is approved or if there are any changes that need to be made."
        },
        BuiltInTemplate(title: "Website update live", tag: .client, people: nil, colorLight: p[3].light, colorDark: p[3].dark) { _ in
            "Hi [Client Name],\n\nThe requested updates are now live on the website:\n[link]\n\nPlease let us know if everything is approved or if there are any additional changes that need to be made."
        },
    ]
}

// ── Root ──────────────────────────────────────────────
struct RootView: View {
    @StateObject private var settings = UserSettings()
    @StateObject private var store    = TemplateStore()
    var body: some View {
        if settings.hasCompletedOnboarding {
            MainView(settings: settings, store: store)
        } else {
            OnboardingView(settings: settings)
        }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - ONBOARDING
// ═══════════════════════════════════════════════════════
struct OnboardingView: View {
    @ObservedObject var settings: UserSettings
    @State private var step: Int = 0
    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            switch step {
            case 0: WelcomeStep(onNext: { advance() })
            case 1: NameStep(settings: settings, onNext: { advance() })
            case 2: TeamStep(settings: settings, onNext: { advance() })
            case 3: ReadyStep(settings: settings, onDone: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    settings.hasCompletedOnboarding = true
                }
            })
            default: EmptyView()
            }
        }
        .frame(minWidth: 480, minHeight: 580)
        .preferredColorScheme(.light)
    }
    func advance() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { step += 1 }
    }
}

struct StepDots: View {
    let total: Int; let current: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<total, id: \.self) { i in
                Capsule()
                    .fill(i == current ? Color.ink : Color.inkLight.opacity(0.2))
                    .frame(width: i == current ? 20 : 6, height: 6)
                    .animation(.spring(duration: 0.3), value: current)
            }
        }
    }
}

struct OnboardingButton: View {
    let label: String; let filled: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(filled ? .white : Color.inkLight)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(filled ? Color.ink : Color.creamDeep)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .animation(.spring(duration: 0.25), value: filled)
        }
        .buttonStyle(.plain)
    }
}

struct WelcomeStep: View {
    let onNext: () -> Void
    @State private var appeared = false
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.ink)
                        .frame(width: 52, height: 52)
                    Text("C")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Welcome to")
                        .font(.system(size: 32, weight: .thin, design: .rounded))
                        .foregroundStyle(Color.inkLight)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.2), value: appeared)
                    Text("Clippyboard.")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 16)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.28), value: appeared)
                }
                Text("Your team's copy-paste toolkit.\nBeautiful templates, one click away.")
                    .font(.system(size: 15, weight: .light, design: .rounded))
                    .foregroundStyle(Color.inkLight)
                    .lineSpacing(4)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)
                    .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.38), value: appeared)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 48)
            Spacer()
            VStack(spacing: 16) {
                OnboardingButton(label: "Get started", filled: true, action: onNext)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.5), value: appeared)
                StepDots(total: 4, current: 0)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6).delay(0.55), value: appeared)
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 44)
        }
        .onAppear { appeared = true }
    }
}

struct NameStep: View {
    @ObservedObject var settings: UserSettings
    let onNext: () -> Void
    @State private var appeared = false
    @FocusState private var focused: Bool
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("First things first.")
                        .font(.system(size: 13, weight: .light, design: .rounded))
                        .foregroundStyle(Color.inkLight)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.1), value: appeared)
                    Text("What's your name?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.15), value: appeared)
                }
                Text("This will appear on every template you send.")
                    .font(.system(size: 14, weight: .light, design: .rounded))
                    .foregroundStyle(Color.inkLight)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5).delay(0.22), value: appeared)
                TextField("Your name", text: $settings.name)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .light, design: .rounded))
                    .foregroundStyle(Color.ink)
                    .focused($focused)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color.creamDeep)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(focused ? Color.ink.opacity(0.3) : Color.clear, lineWidth: 1.5))
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(.spring(response: 0.6).delay(0.3), value: appeared)
            }
            .padding(.horizontal, 48)
            Spacer()
            VStack(spacing: 16) {
                OnboardingButton(
                    label: settings.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Skip for now" : "Continue",
                    filled: !settings.name.trimmingCharacters(in: .whitespaces).isEmpty,
                    action: onNext
                )
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5).delay(0.4), value: appeared)
                StepDots(total: 4, current: 1)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6).delay(0.45), value: appeared)
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 44)
        }
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }
}

struct TeamStep: View {
    @ObservedObject var settings: UserSettings
    let onNext: () -> Void
    @State private var appeared = false
    @State private var newName = ""
    @FocusState private var focused: Bool
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Almost there.")
                        .font(.system(size: 13, weight: .light, design: .rounded))
                        .foregroundStyle(Color.inkLight)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.1), value: appeared)
                    Text("Who's on your team?")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.15), value: appeared)
                }
                Text("These names appear as person pickers on your templates.")
                    .font(.system(size: 14, weight: .light, design: .rounded))
                    .foregroundStyle(Color.inkLight)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5).delay(0.22), value: appeared)
                HStack(spacing: 10) {
                    TextField("Add a name…", text: $newName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15, weight: .light, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .focused($focused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 11)
                        .background(Color.creamDeep)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .onSubmit { addPerson() }
                    Button(action: addPerson) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(newName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.inkLight.opacity(0.3) : Color.ink)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                    .animation(.spring(duration: 0.2), value: newName.isEmpty)
                }
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.6).delay(0.3), value: appeared)
                if !settings.team.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(settings.team, id: \.self) { person in
                            HStack {
                                Text(person)
                                    .font(.system(size: 14, weight: .light, design: .rounded))
                                    .foregroundStyle(Color.ink)
                                Spacer()
                                Button {
                                    withAnimation(.spring(duration: 0.25)) {
                                        settings.team.removeAll { $0 == person }
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(Color.inkLight)
                                        .frame(width: 22, height: 22)
                                        .background(Color.creamDeep)
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.creamDeep)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }
                    }
                }
            }
            .padding(.horizontal, 48)
            Spacer()
            VStack(spacing: 16) {
                OnboardingButton(
                    label: settings.team.isEmpty ? "Skip for now" : "Continue",
                    filled: !settings.team.isEmpty,
                    action: onNext
                )
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5).delay(0.4), value: appeared)
                StepDots(total: 4, current: 2)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6).delay(0.45), value: appeared)
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 44)
        }
        .onAppear {
            appeared = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { focused = true }
        }
    }
    func addPerson() {
        let t = newName.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, !settings.team.contains(t) else { return }
        withAnimation(.spring(duration: 0.3)) { settings.team.append(t); newName = "" }
    }
}

struct ReadyStep: View {
    @ObservedObject var settings: UserSettings
    let onDone: () -> Void
    @State private var appeared = false
    var firstName: String {
        settings.name.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? settings.name
    }
    var headerPreview: String {
        let date = Date().formatted(date: .long, time: .omitted)
        let person = settings.team.first ?? "Team"
        let byName = settings.name.trimmingCharacters(in: .whitespaces).isEmpty ? "Me" : settings.name
        return "• Prepared For: \(person)\n• Prepared By: \(byName)\n• Date: \(date)"
    }
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(firstName.isEmpty ? "You're all set." : "You're all set, \(firstName).")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 12)
                        .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.1), value: appeared)
                    Text("Here's a preview of your header template.")
                        .font(.system(size: 14, weight: .light, design: .rounded))
                        .foregroundStyle(Color.inkLight)
                        .opacity(appeared ? 1 : 0)
                        .animation(.spring(response: 0.5).delay(0.2), value: appeared)
                }
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(colors: [Color(hex: "E8C99A"), Color(hex: "D4A574")], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .shadow(color: Color(hex: "D4A574").opacity(0.3), radius: 16, y: 6)
                    RoundedRectangle(cornerRadius: 20)
                        .fill(LinearGradient(colors: [Color.white.opacity(0.25), Color.clear], startPoint: .top, endPoint: .center))
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Header")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.65))
                        Text("Copy header")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Divider().background(Color.white.opacity(0.25))
                        Text(headerPreview)
                            .font(.system(size: 12, weight: .light, design: .rounded))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineSpacing(4)
                    }
                    .padding(20)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 16)
                .animation(.spring(response: 0.65, dampingFraction: 0.75).delay(0.3), value: appeared)
            }
            .padding(.horizontal, 48)
            Spacer()
            VStack(spacing: 16) {
                OnboardingButton(label: "Open Clippyboard →", filled: true, action: onDone)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.5).delay(0.45), value: appeared)
                StepDots(total: 4, current: 3)
                    .opacity(appeared ? 1 : 0)
                    .animation(.spring(response: 0.6).delay(0.5), value: appeared)
            }
            .padding(.horizontal, 48)
            .padding(.bottom, 44)
        }
        .onAppear { appeared = true }
    }
}

// ═══════════════════════════════════════════════════════
// MARK: - MAIN APP
// ═══════════════════════════════════════════════════════
struct MainView: View {
    @ObservedObject var settings: UserSettings
    @ObservedObject var store: TemplateStore
    @State private var showAdd = false
    @State private var editingCard: AnyTemplateCard? = nil
    // Store builtIns in @State so UUIDs are stable across renders.
    // Recompute only when name or team actually changes.
    @State private var builtIns: [BuiltInTemplate] = []

    var body: some View {
        ContentView(settings: settings, store: store, builtIns: builtIns, showAdd: $showAdd, editingCard: $editingCard)
        .onAppear {
            builtIns = makeBuiltIns(name: settings.name, team: settings.team)
        }
        .onChange(of: settings.name) { _, _ in
            builtIns = makeBuiltIns(name: settings.name, team: settings.team)
        }
        .onChange(of: settings.team) { _, _ in
            builtIns = makeBuiltIns(name: settings.name, team: settings.team)
        }
            .sheet(isPresented: $showAdd) {
                AddEditTemplateView(store: store, isPresented: $showAdd, editing: nil)
            }
            .sheet(item: $editingCard) { card in
                if card.isCustom, let cid = card.customId,
                   let custom = store.customs.first(where: { $0.id == cid }) {
                    AddEditTemplateView(store: store, isPresented: .constant(true), editing: custom) {
                        editingCard = nil
                    }
                } else {
                    BuiltInEditView(card: card, store: store, onDismiss: { editingCard = nil })
                }
            }
    }
}

// ── Content view ──────────────────────────────────────
struct ContentView: View {
    @ObservedObject var settings: UserSettings
    @ObservedObject var store: TemplateStore
    let builtIns: [BuiltInTemplate]
    @Binding var showAdd: Bool
    @Binding var editingCard: AnyTemplateCard?

    @State private var selectedTag: TemplateTag? = nil
    @State private var activeIndex: Int = 0
    @State private var toastVisible = false
    @State private var toastText = ""
    @State private var search = ""
    @State private var showGrid = false

    var allCards: [AnyTemplateCard] {
        builtIns.map { AnyTemplateCard(builtIn: $0) } +
        store.customs.map { AnyTemplateCard(custom: $0) }
    }

    var filtered: [AnyTemplateCard] {
        allCards.filter { t in
            let matchTag = selectedTag == nil || t.tag == selectedTag
            let matchSearch = search.isEmpty || t.title.lowercased().contains(search.lowercased())
            return matchTag && matchSearch
        }
    }

    var firstName: String {
        settings.name.trimmingCharacters(in: .whitespaces).components(separatedBy: " ").first ?? settings.name
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Color.cream.ignoresSafeArea()
            VStack(spacing: 0) {
                headerSection
                filterBar
                if showGrid { gridView } else { cardDeck }
                Spacer(minLength: 0)
            }
            if toastVisible {
                toastBanner
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(99)
            }
        }
        .frame(minWidth: 460, minHeight: 700)
        .preferredColorScheme(.light)
        .onChange(of: filtered.count) { _, _ in activeIndex = 0 }
    }

    var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 7) {
                    Text("Hello,")
                        .font(.system(size: 32, weight: .thin, design: .rounded))
                        .foregroundStyle(Color.inkLight)
                    Text("\(firstName.isEmpty ? "there" : firstName).")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.ink)
                }
                Spacer()
                HStack(spacing: 8) {
                    // Settings / restart onboarding
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            settings.hasCompletedOnboarding = false
                        }
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.ink)
                            .frame(width: 34, height: 34)
                            .background(Color.creamDeep)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.ink.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    // Grid / deck toggle
                    Button {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { showGrid.toggle() }
                    } label: {
                        Image(systemName: showGrid ? "rectangle.stack" : "square.grid.2x2")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.ink)
                            .frame(width: 34, height: 34)
                            .background(Color.creamDeep)
                            .clipShape(RoundedRectangle(cornerRadius: 9))
                            .overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.ink.opacity(0.08), lineWidth: 1))
                    }
                    .buttonStyle(.plain)

                    // New template
                    Button { showAdd = true } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                            Text("New").font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(Color.creamDeep)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.ink.opacity(0.1), lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer().frame(height: 14)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color.inkLight)
                TextField("Search templates…", text: $search)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, weight: .light, design: .rounded))
                    .foregroundStyle(Color.ink)
                if !search.isEmpty {
                    Button { search = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.inkLight.opacity(0.5))
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(Color.creamDeep)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 14)
    }

    var filterBar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Templates")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.ink)
                Text("(\(filtered.count))")
                    .font(.system(size: 13, weight: .light, design: .rounded))
                    .foregroundStyle(Color.inkLight)
                Spacer()
                if selectedTag != nil {
                    Button("See all") {
                        withAnimation(.spring(duration: 0.3)) { selectedTag = nil }
                    }
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Color.inkLight)
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TemplateTag.allCases, id: \.self) { tag in
                        FilterPill(tag: tag, isActive: selectedTag == tag) {
                            withAnimation(.spring(duration: 0.25)) {
                                selectedTag = selectedTag == tag ? nil : tag
                                activeIndex = 0
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
            }
            .padding(.bottom, 16)
        }
    }

    var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(filtered) { card in
                    GridCard(card: card, onEdit: { editingCard = card }, onDelete: {
                        if let cid = card.customId { store.delete(id: cid) }
                    })
                }
            }
            .padding(.horizontal, 24).padding(.bottom, 24)
        }
    }

    var cardDeck: some View {
        VStack(spacing: 0) {
            if filtered.isEmpty {
                emptyState
            } else {
                ZStack(alignment: .top) {
                    ForEach(Array(filtered.enumerated()), id: \.element.id) { i, card in
                        let offset = i - activeIndex
                        if offset >= 0 && offset <= 3 {
                            TemplateCardView(
                                card: card,
                                isActive: offset == 0,
                                stackOffset: offset,
                                onCopied: { name in showToast(name) },
                                onEdit: { editingCard = card }
                            )
                            .zIndex(Double(100 - offset))
                        }
                    }
                }
                .frame(height: 420)
                .padding(.horizontal, 24)
                navControls
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 8) {
            Text("No templates found")
                .font(.system(size: 15, weight: .light, design: .rounded))
                .foregroundStyle(Color.inkLight)
            Button("Add your first template") { showAdd = true }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(Color.inkLight)
                .buttonStyle(.plain)
        }
        .frame(height: 200)
    }

    var navControls: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                    if activeIndex > 0 { activeIndex -= 1 }
                }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(activeIndex > 0 ? Color.ink : Color.inkLight.opacity(0.25))
                    .frame(width: 32, height: 32)
                    .background(Color.creamDeep)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain).disabled(activeIndex == 0)

            HStack(spacing: 5) {
                ForEach(0..<min(filtered.count, 12), id: \.self) { i in
                    Circle()
                        .fill(i == activeIndex ? Color.ink : Color.inkLight.opacity(0.25))
                        .frame(width: i == activeIndex ? 7 : 5, height: i == activeIndex ? 7 : 5)
                        .animation(.spring(duration: 0.2), value: activeIndex)
                }
            }

            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                    if activeIndex < filtered.count - 1 { activeIndex += 1 }
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(activeIndex < filtered.count - 1 ? Color.ink : Color.inkLight.opacity(0.25))
                    .frame(width: 32, height: 32)
                    .background(Color.creamDeep)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain).disabled(activeIndex >= filtered.count - 1)
        }
        .padding(.top, 16)
    }

    var toastBanner: some View {
        Text(toastText)
            .font(.system(size: 12.5, weight: .medium, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 20).padding(.vertical, 10)
            .background(Capsule().fill(Color.ink).shadow(color: .black.opacity(0.15), radius: 12, y: 4))
            .padding(.bottom, 24)
    }

    func showToast(_ name: String) {
        toastText = name.isEmpty ? "Copied to clipboard ✓" : "Copied for \(name) ✓"
        withAnimation(.spring(duration: 0.3)) { toastVisible = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { toastVisible = false }
        }
    }
}

// ── Grid card ─────────────────────────────────────────
struct GridCard: View {
    let card: AnyTemplateCard
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(
                    colors: [Color(hex: card.colorLight), Color(hex: card.colorDark)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .shadow(color: Color(hex: card.colorDark).opacity(0.2), radius: 8, y: 3)
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: [Color.white.opacity(0.2), Color.clear], startPoint: .top, endPoint: .center))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(card.tag.rawValue)
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                    Spacer()
                    if isHovered {
                        HStack(spacing: 4) {
                            Button(action: onEdit) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            if card.isCustom {
                                Button(action: onDelete) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white)
                                        .frame(width: 22, height: 22)
                                        .background(Color.white.opacity(0.2))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .transition(.opacity)
                    }
                }
                Text(card.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                Text(card.resolveBody(card.people?.first ?? ""))
                    .font(.system(size: 10, weight: .light, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .lineLimit(3)
                    .lineSpacing(2)
            }
            .padding(14)
        }
        .frame(height: 140)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.spring(duration: 0.2), value: isHovered)
        .onHover { isHovered = $0 }
    }
}

// ── Template card (deck) ──────────────────────────────
struct TemplateCardView: View {
    let card: AnyTemplateCard
    let isActive: Bool
    let stackOffset: Int
    let onCopied: (String) -> Void
    let onEdit: () -> Void

    @State private var copiedPerson: String? = nil
    @State private var dragX: CGFloat = 0

    var stackScale: CGFloat {
        switch stackOffset {
        case 0: return 1.0; case 1: return 0.96; case 2: return 0.92; default: return 0.88
        }
    }
    var stackY: CGFloat {
        switch stackOffset {
        case 0: return 0; case 1: return -18; case 2: return -32; default: return -42
        }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(
                    colors: [Color(hex: card.colorLight), Color(hex: card.colorDark)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .shadow(color: Color(hex: card.colorDark).opacity(isActive ? 0.3 : 0.1), radius: isActive ? 20 : 6, y: isActive ? 8 : 3)
            RoundedRectangle(cornerRadius: 24)
                .fill(LinearGradient(colors: [Color.white.opacity(0.25), Color.clear], startPoint: .top, endPoint: .center))

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(card.tag.rawValue)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.65))
                    Spacer()
                    if isActive {
                        Button(action: onEdit) {
                            HStack(spacing: 4) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 10, weight: .medium))
                                Text(card.isCustom ? "Edit" : "Edit")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 22).padding(.horizontal, 22)

                Divider().background(Color.white.opacity(0.2)).padding(.horizontal, 22).padding(.vertical, 12)

                if isActive {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(card.title)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text(card.resolveBody(card.people?.first ?? ""))
                                .font(.system(size: 12.5, weight: .light, design: .rounded))
                                .foregroundStyle(.white.opacity(0.88))
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 22)
                    }
                    .frame(maxHeight: 120)
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(card.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                        Text(card.resolveBody(card.people?.first ?? ""))
                            .font(.system(size: 10, weight: .light, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 22)
                }

                Spacer(minLength: 10)

                if isActive {
                    if let people = card.people {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(people, id: \.self) { person in
                                    PersonButton(name: person, isCopied: copiedPerson == person) {
                                        doCopy(card.resolveBody(person), person: person)
                                    }
                                }
                            }
                            .padding(.horizontal, 22).padding(.bottom, 22)
                        }
                    } else {
                        Button { doCopy(card.resolveBody(""), person: "") } label: {
                            HStack(spacing: 6) {
                                Image(systemName: copiedPerson != nil ? "checkmark" : "doc.on.doc")
                                    .font(.system(size: 11, weight: .medium))
                                Text(copiedPerson != nil ? "Copied!" : "Copy")
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                            }
                            .foregroundStyle(Color(hex: card.colorDark))
                            .padding(.horizontal, 18).padding(.vertical, 10)
                            .background(Color.white.opacity(0.9))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 22).padding(.bottom, 22)
                    }
                } else {
                    Color.clear.frame(height: 52)
                }
            }
        }
        .frame(maxWidth: .infinity).frame(height: 320)
        .scaleEffect(stackScale)
        .offset(y: stackY)
        .offset(x: isActive ? dragX : 0)
        .opacity(stackOffset > 3 ? 0 : 1)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: stackOffset)
        .animation(.spring(response: 0.42, dampingFraction: 0.8), value: isActive)
        .gesture(isActive ? DragGesture()
            .onChanged { v in dragX = v.translation.width * 0.25 }
            .onEnded { _ in withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { dragX = 0 } }
            : nil
        )
    }

    func doCopy(_ text: String, person: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
        withAnimation(.spring(duration: 0.2)) { copiedPerson = person }
        onCopied(person)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation { copiedPerson = nil }
        }
    }
}

// ── Built-in edit view ────────────────────────────────
// Lets user duplicate a built-in as a custom editable template
struct BuiltInEditView: View {
    let card: AnyTemplateCard
    @ObservedObject var store: TemplateStore
    let onDismiss: () -> Void

    @State private var title: String
    @State private var bodyText: String
    @State private var selectedTag: TemplateTag
    @State private var peopleInput: String
    @State private var hasPeople: Bool
    @State private var selectedColorPair: CardColorPair
    @State private var showError = false
    @State private var saved = false

    init(card: AnyTemplateCard, store: TemplateStore, onDismiss: @escaping () -> Void) {
        self.card = card
        self.store = store
        self.onDismiss = onDismiss
        _title = State(initialValue: card.title)
        _bodyText = State(initialValue: card.resolveBody(card.people?.first ?? ""))
        _selectedTag = State(initialValue: card.tag)
        _hasPeople = State(initialValue: card.people != nil && !card.people!.isEmpty)
        _peopleInput = State(initialValue: card.people?.joined(separator: ", ") ?? "")
        _selectedColorPair = State(initialValue: cardColorPresets.first(where: { $0.light == card.colorLight }) ?? cardColorPresets[0])
    }

    var parsedPeople: [String] {
        peopleInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Edit template")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ink)
                        Text("Saves as a custom copy — original stays intact")
                            .font(.system(size: 12, weight: .light, design: .rounded))
                            .foregroundStyle(Color.inkLight)
                    }
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.inkLight)
                            .frame(width: 28, height: 28)
                            .background(Color.creamDeep)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 24)

                Divider().background(Color.inkLight.opacity(0.1))

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        FormField(label: "Title") {
                            TextField("Title", text: $title)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, weight: .light, design: .rounded))
                                .foregroundStyle(Color.ink)
                                .padding(12)
                                .background(Color.creamDeep)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        FormField(label: "Card color") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                                ForEach(cardColorPresets) { pair in
                                    Button {
                                        withAnimation(.spring(duration: 0.2)) { selectedColorPair = pair }
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(LinearGradient(
                                                    colors: [Color(hex: pair.light), Color(hex: pair.dark)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                                ))
                                                .frame(height: 36)
                                            if selectedColorPair.id == pair.id {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedColorPair.id == pair.id ? Color.ink.opacity(0.4) : Color.clear, lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        FormField(label: "Template body") {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topLeading) {
                                    if bodyText.isEmpty {
                                        Text("Template text…")
                                            .font(.system(size: 13, weight: .light, design: .rounded))
                                            .foregroundStyle(Color.inkLight.opacity(0.6))
                                            .padding(12)
                                            .allowsHitTesting(false)
                                    }
                                    TextEditor(text: $bodyText)
                                        .font(.system(size: 13, weight: .light, design: .rounded))
                                        .foregroundStyle(Color.ink)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 140)
                                        .padding(8)
                                }
                                .background(Color.creamDeep)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Placeholder tips")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.inkLight)
                                    Text("• Use [name] where you want the selected person's name to appear automatically when copying.")
                                        .font(.system(size: 11, weight: .light, design: .rounded))
                                        .foregroundStyle(Color.inkLight)
                                        .lineSpacing(2)
                                    Text("• Use [placeholder] for anything you'll fill in manually after pasting, like [link] or [issue].")
                                        .font(.system(size: 11, weight: .light, design: .rounded))
                                        .foregroundStyle(Color.inkLight)
                                        .lineSpacing(2)
                                }
                                .padding(10)
                                .background(Color.creamDeep.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        FormField(label: "People picker") {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle(isOn: $hasPeople.animation()) {
                                    Text("Add person picker to this card")
                                        .font(.system(size: 13, weight: .light, design: .rounded))
                                        .foregroundStyle(Color.ink)
                                }
                                .toggleStyle(.switch)
                                if hasPeople {
                                    TextField("Alex, Jordan, Casey…", text: $peopleInput)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13, weight: .light, design: .rounded))
                                        .foregroundStyle(Color.ink)
                                        .padding(12)
                                        .background(Color.creamDeep)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    Text("Separate names with commas")
                                        .font(.system(size: 11, weight: .light, design: .rounded))
                                        .foregroundStyle(Color.inkLight)
                                }
                            }
                        }

                        if showError {
                            Text("Please add a title and body before saving.")
                                .font(.system(size: 12, weight: .light, design: .rounded))
                                .foregroundStyle(Color(hex: "C17767"))
                        }
                    }
                    .padding(28)
                }

                Divider().background(Color.inkLight.opacity(0.1))

                HStack {
                    Button("Cancel", action: onDismiss)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkLight)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.creamDeep).clipShape(Capsule())
                        .buttonStyle(.plain)
                    Spacer()
                    Button {
                        let t = title.trimmingCharacters(in: .whitespaces)
                        let b = bodyText.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty, !b.isEmpty else { showError = true; return }
                        store.add(CustomTemplate(
                            title: t, tag: selectedTag,
                            people: hasPeople ? parsedPeople : [],
                            bodyText: b,
                            colorLight: selectedColorPair.light,
                            colorDark: selectedColorPair.dark
                        ))
                        onDismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus").font(.system(size: 11, weight: .semibold))
                            Text("Save as custom")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.ink).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28).padding(.vertical, 18)
            }
        }
        .frame(minWidth: 480, minHeight: 600)
    }
}

// ── Add / Edit custom template ────────────────────────
struct AddEditTemplateView: View {
    @ObservedObject var store: TemplateStore
    @Binding var isPresented: Bool
    let editing: CustomTemplate?
    var onDismiss: (() -> Void)? = nil

    @State private var title = ""
    @State private var bodyText = ""
    @State private var selectedTag: TemplateTag = .custom
    @State private var peopleInput = ""
    @State private var hasPeople = false
    @State private var selectedColorPair: CardColorPair = cardColorPresets[4]
    @State private var showError = false

    var isEditing: Bool { editing != nil }
    var parsedPeople: [String] {
        peopleInput.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    var body: some View {
        ZStack {
            Color.cream.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(isEditing ? "Edit template" : "New template")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.ink)
                        Text(isEditing ? "Update this template" : "Add a reusable message to your deck")
                            .font(.system(size: 13, weight: .light, design: .rounded))
                            .foregroundStyle(Color.inkLight)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.inkLight)
                            .frame(width: 28, height: 28)
                            .background(Color.creamDeep)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28).padding(.top, 28).padding(.bottom, 24)

                Divider().background(Color.inkLight.opacity(0.1))

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        FormField(label: "Title") {
                            TextField("e.g. Design revision request", text: $title)
                                .textFieldStyle(.plain)
                                .font(.system(size: 14, weight: .light, design: .rounded))
                                .foregroundStyle(Color.ink)
                                .padding(12)
                                .background(Color.creamDeep)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        FormField(label: "Category") {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(TemplateTag.allCases, id: \.self) { tag in
                                        Button {
                                            withAnimation(.spring(duration: 0.2)) { selectedTag = tag }
                                        } label: {
                                            HStack(spacing: 5) {
                                                Circle().fill(Color(hex: tag.defaultColorPair.dark)).frame(width: 6, height: 6)
                                                Text(tag.rawValue)
                                                    .font(.system(size: 12, weight: selectedTag == tag ? .semibold : .light, design: .rounded))
                                                    .foregroundStyle(selectedTag == tag ? Color.ink : Color.inkLight)
                                            }
                                            .padding(.horizontal, 12).padding(.vertical, 7)
                                            .background(selectedTag == tag ? Color.creamDeep : Color.clear)
                                            .clipShape(Capsule())
                                            .overlay(Capsule().stroke(selectedTag == tag ? Color.ink.opacity(0.15) : Color.inkLight.opacity(0.2), lineWidth: 1))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }
                        }

                        FormField(label: "Card color") {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 8) {
                                ForEach(cardColorPresets) { pair in
                                    Button {
                                        withAnimation(.spring(duration: 0.2)) { selectedColorPair = pair }
                                    } label: {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 8)
                                                .fill(LinearGradient(
                                                    colors: [Color(hex: pair.light), Color(hex: pair.dark)],
                                                    startPoint: .topLeading, endPoint: .bottomTrailing
                                                ))
                                                .frame(height: 36)
                                            if selectedColorPair.id == pair.id {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 11, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }
                                        }
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selectedColorPair.id == pair.id ? Color.ink.opacity(0.4) : Color.clear, lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        FormField(label: "Template body") {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topLeading) {
                                    if bodyText.isEmpty {
                                        Text("Write your template here.")
                                            .font(.system(size: 13, weight: .light, design: .rounded))
                                            .foregroundStyle(Color.inkLight.opacity(0.6))
                                            .padding(12)
                                            .allowsHitTesting(false)
                                    }
                                    TextEditor(text: $bodyText)
                                        .font(.system(size: 13, weight: .light, design: .rounded))
                                        .foregroundStyle(Color.ink)
                                        .scrollContentBackground(.hidden)
                                        .frame(minHeight: 140)
                                        .padding(8)
                                }
                                .background(Color.creamDeep)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Placeholder tips")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                        .foregroundStyle(Color.inkLight)
                                    Text("• Use [name] where you want the selected person's name to appear automatically when copying.")
                                        .font(.system(size: 11, weight: .light, design: .rounded))
                                        .foregroundStyle(Color.inkLight)
                                        .lineSpacing(2)
                                    Text("• Use [placeholder] for anything you'll fill in manually after pasting, like [link] or [issue].")
                                        .font(.system(size: 11, weight: .light, design: .rounded))
                                        .foregroundStyle(Color.inkLight)
                                        .lineSpacing(2)
                                }
                                .padding(10)
                                .background(Color.creamDeep.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }

                        FormField(label: "People picker") {
                            VStack(alignment: .leading, spacing: 10) {
                                Toggle(isOn: $hasPeople.animation()) {
                                    Text("Add person picker to this card")
                                        .font(.system(size: 13, weight: .light, design: .rounded))
                                        .foregroundStyle(Color.ink)
                                }
                                .toggleStyle(.switch)
                                if hasPeople {
                                    TextField("Alex, Jordan, Casey…", text: $peopleInput)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13, weight: .light, design: .rounded))
                                        .foregroundStyle(Color.ink)
                                        .padding(12)
                                        .background(Color.creamDeep)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                    Text("Separate names with commas")
                                        .font(.system(size: 11, weight: .light, design: .rounded))
                                        .foregroundStyle(Color.inkLight)
                                }
                            }
                        }

                        if showError {
                            Text("Please add a title and body before saving.")
                                .font(.system(size: 12, weight: .light, design: .rounded))
                                .foregroundStyle(Color(hex: "C17767"))
                        }
                    }
                    .padding(28)
                }

                Divider().background(Color.inkLight.opacity(0.1))

                HStack(spacing: 10) {
                    Button("Cancel") { dismiss() }
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.inkLight)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.creamDeep).clipShape(Capsule())
                        .buttonStyle(.plain)

                    if isEditing {
                        Button {
                            if let e = editing { store.delete(id: e.id) }
                            dismiss()
                        } label: {
                            Text("Delete")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(Color(hex: "C17767"))
                                .padding(.horizontal, 20).padding(.vertical, 10)
                                .background(Color(hex: "C17767").opacity(0.1))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()

                    Button {
                        let t = title.trimmingCharacters(in: .whitespaces)
                        let b = bodyText.trimmingCharacters(in: .whitespaces)
                        guard !t.isEmpty, !b.isEmpty else { showError = true; return }
                        if var e = editing {
                            e.title = t; e.tag = selectedTag
                            e.people = hasPeople ? parsedPeople : []
                            e.bodyText = b
                            e.colorLight = selectedColorPair.light
                            e.colorDark = selectedColorPair.dark
                            store.update(e)
                        } else {
                            store.add(CustomTemplate(
                                title: t, tag: selectedTag,
                                people: hasPeople ? parsedPeople : [],
                                bodyText: b,
                                colorLight: selectedColorPair.light,
                                colorDark: selectedColorPair.dark
                            ))
                        }
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isEditing ? "checkmark" : "plus")
                                .font(.system(size: 11, weight: .semibold))
                            Text(isEditing ? "Save changes" : "Add template")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20).padding(.vertical, 10)
                        .background(Color.ink).clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 28).padding(.vertical, 18)
            }
        }
        .frame(minWidth: 480, minHeight: 600)
        .onAppear { loadEditing() }
    }

    func loadEditing() {
        guard let e = editing else { return }
        title = e.title; bodyText = e.bodyText; selectedTag = e.tag
        hasPeople = !e.people.isEmpty
        peopleInput = e.people.joined(separator: ", ")
        selectedColorPair = cardColorPresets.first(where: { $0.light == e.colorLight }) ?? cardColorPresets[4]
    }

    func dismiss() { onDismiss?(); isPresented = false }
}

// ── Filter pill ───────────────────────────────────────
struct FilterPill: View {
    let tag: TemplateTag; let isActive: Bool; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Circle().fill(Color(hex: tag.defaultColorPair.dark)).frame(width: 7, height: 7)
                Text(tag.rawValue)
                    .font(.system(size: 12, weight: isActive ? .semibold : .light, design: .rounded))
                    .foregroundStyle(isActive ? Color.ink : Color.inkLight)
            }
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(isActive ? Color.creamDeep : Color.clear)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(isActive ? Color.ink.opacity(0.1) : Color.inkLight.opacity(0.2), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

// ── Person button ─────────────────────────────────────
struct PersonButton: View {
    let name: String; let isCopied: Bool; let action: () -> Void
    @State private var isHovered = false
    var body: some View {
        Button(action: action) {
            Text(isCopied ? "✓ \(name)" : name)
                .font(.system(size: 12.5, weight: .medium, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Capsule().fill(isHovered || isCopied ? Color.white.opacity(0.35) : Color.white.opacity(0.2)))
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .animation(.spring(duration: 0.18), value: isHovered)
    }
}

// ── Form field ────────────────────────────────────────
struct FormField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.inkLight)
            content
        }
    }
}

#Preview { RootView() }
