import SwiftUI
import SwiftData

@main
struct SpeakUpApp: App {
    let dataService = DataService.shared

    init() {
        // Ensure singletons exist before any view queries
        _ = try? dataService.getProgress()
        _ = try? dataService.getSettings()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .modelContainer(dataService.container)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.indigo.ignoresSafeArea())
        }
    }
}

struct ContentView: View {
    @Query(filter: #Predicate<SettingsModel> { $0.id == "singleton" })
    private var settings: [SettingsModel]

    @State private var selectedTab = 0
    @State private var showSplash = true

    var body: some View {
        ZStack {
            // Splash as base layer — rendered first, no white flash
            splashView
                .opacity(showSplash ? 1 : 0)

            // Main content — hidden until splash fades
            TabView(selection: $selectedTab) {
                NavigationStack { HomeView() }
                    .tabItem { Label("训练", systemImage: "dumbbell.fill") }
                    .tag(0)

                NavigationStack { ChatListView() }
                    .tabItem { Label("对话", systemImage: "message.fill") }
                    .tag(1)

                NavigationStack { ReviewView() }
                    .tabItem { Label("复习", systemImage: "brain.head.profile") }
                    .tag(2)

                NavigationStack { ProgressDashboardView() }
                    .tabItem { Label("数据", systemImage: "chart.bar.fill") }
                    .tag(3)

                NavigationStack { SettingsView() }
                    .tabItem { Label("设置", systemImage: "gearshape.fill") }
                    .tag(4)
            }
            .opacity(showSplash ? 0 : 1)
        }
        .tint(.blue)
        .preferredColorScheme(settings.first?.theme == "dark" ? .dark : .light)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeOut(duration: 0.4)) {
                    showSplash = false
                }
            }
        }
    }

    private var splashView: some View {
        ZStack {
            Color.indigo.ignoresSafeArea()
            VStack(spacing: 20) {
                Image("LaunchIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 160, height: 160)

                Text("SpeakUp")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("开口说，每天进步一点点")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
}
