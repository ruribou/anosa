import AnosaKit
import MapKit
import SwiftUI

struct ContentView: View {
    let model: WatchSyncModel

    var body: some View {
        NavigationStack {
            Group {
                if model.visiblePlaces.isEmpty {
                    ContentUnavailableView(WatchComplicationContent.emptyMessage, systemImage: "figure.walk")
                } else {
                    List(model.visiblePlaces) { place in
                        Section {
                            VStack(alignment: .leading) {
                                Text(place.name)
                                Text("徒歩\(place.walkingMinutes)分")
                                    .foregroundStyle(.secondary)
                            }
                            Button("行ってみる") {
                                Self.openWalkingDirections(to: place)
                            }
                            Button("もう行った") {
                                model.markVisited(place)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Anosa")
        }
    }

    /// Apple マップで徒歩ルートを開く。
    private static func openWalkingDirections(to place: NearbyPlace) {
        let location = CLLocation(latitude: place.coordinate.latitude, longitude: place.coordinate.longitude)
        let item = MKMapItem(location: location, address: nil)
        item.name = place.name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}
