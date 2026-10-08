import AnosaKit
import SwiftUI

struct ContentView: View {
    @State private var status: PlaceStatus = .wantToGo
    @State private var isAdding = false
    @State private var isShowingLocationPermission = false
    @Environment(LocationService.self) private var locationService

    var body: some View {
        NavigationStack {
            PlaceListView(status: status)
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
                .onChange(of: locationService.guidance) { _, guidance in
                    // 「使用中のみ」を許可した直後にだけ、常に許可の説明を出す。決まったら閉じる。
                    switch guidance {
                    case .askAlways: isShowingLocationPermission = true
                    case .none: isShowingLocationPermission = false
                    default: break
                    }
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PlaceEntity.self, inMemory: true)
        .environment(LocationService(notifier: PlaceNotifier()))
}
