import AnosaKit
import SwiftUI

struct ContentView: View {
    @State private var status: PlaceStatus = .wantToGo
    @State private var isAdding = false

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
                    ToolbarItem(placement: .primaryAction) {
                        Button("場所を追加", systemImage: "plus") {
                            isAdding = true
                        }
                    }
                }
                .sheet(isPresented: $isAdding) {
                    AddPlaceView()
                }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: PlaceEntity.self, inMemory: true)
}
