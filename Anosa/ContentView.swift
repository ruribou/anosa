import AnosaKit
import SwiftUI

struct ContentView: View {
    @State private var status: PlaceStatus = .wantToGo
    @State private var isAdding = false
    @State private var isShowingLocationPermission = false
    @State private var isShowingSettings = false
    @AppStorage(OnboardingState.hasCompletedKey) private var hasCompletedOnboarding = false
    @Environment(LocationService.self) private var locationService

    var body: some View {
        NavigationStack {
            PlaceListView(status: status, onAdd: { isAdding = true })
                .navigationTitle("Anosa")
                .safeAreaBar(edge: .top) {
                    Picker("表示する場所", selection: $status) {
                        ForEach(PlaceStatus.allCases, id: \.self) { status in
                            Text(status.title).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("設定", systemImage: "gearshape") {
                            isShowingSettings = true
                        }
                    }
                    if locationService.guidance != .none {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("位置情報", systemImage: "location") {
                                isShowingLocationPermission = true
                            }
                        }
                    }
                    ToolbarItem(placement: .primaryAction) {
                        Button("場所を追加", systemImage: "plus") {
                            isAdding = true
                        }
                    }
                }
                .sheet(isPresented: $isAdding) {
                    AddPlaceView()
                }
                .sheet(isPresented: $isShowingLocationPermission) {
                    LocationPermissionView()
                }
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView()
                }
                .fullScreenCover(isPresented: isShowingOnboarding, onDismiss: requestLocationAfterOnboarding) {
                    OnboardingView { hasCompletedOnboarding = true }
                }
                .onChange(of: locationService.guidance) { _, guidance in
                    // 「使用中のみ」を許可した直後にだけ、常に許可の説明を出す。決まったら閉じる。
                    // オンボーディングの表示中は重ねない。
                    switch guidance {
                    case .askAlways where hasCompletedOnboarding: isShowingLocationPermission = true
                    case .none: isShowingLocationPermission = false
                    default: break
                    }
                }
        }
    }

    private var isShowingOnboarding: Binding<Bool> {
        Binding(
            get: { !hasCompletedOnboarding },
            set: { isPresented in
                if !isPresented { hasCompletedOnboarding = true }
            }
        )
    }

    /// 権限の 1 段階目（使用中のみ）は、オンボーディングを閉じてから求める（説明とダイアログを重ねないため）。
    private func requestLocationAfterOnboarding() {
        guard locationService.guidance == .askWhenInUse else { return }
        locationService.requestWhenInUseAuthorization()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PlaceEntity.self, inMemory: true)
        .environment(LocationService(notifier: PlaceNotifier(), watchSync: WatchSyncService()))
}
