import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "保存したら、忘れていい。",
                systemImage: "mappin.and.ellipse"
            )
            .navigationTitle("Anosa")
        }
    }
}

#Preview {
    ContentView()
}
