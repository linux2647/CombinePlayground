import SwiftUI

enum UpdateOrigin {
    case `init`
    case ui
    case network
}

protocol UpdatableObject<Value>: ObservableObject {
    associatedtype Value = ObservableObject
    
    func uiDidUpdateValue<Value>(at keyPath: PartialKeyPath<Self>, to value: Value)
}

extension UpdatableObject {
    func update<Value>(
        _ keyPath: ReferenceWritableKeyPath<Self, Value>,
        to newValue: Value,
        origin: UpdateOrigin
    ) {
        self[keyPath: keyPath] = newValue
        if origin == .ui {
            uiDidUpdateValue(at: keyPath, to: newValue)
        }
    }
    
    func binding<Value: Equatable>(
            for keyPath: ReferenceWritableKeyPath<Self, Value>,
            origin: UpdateOrigin = .ui
        ) -> Binding<Value> {
            Binding(
                get: { self[keyPath: keyPath] },
                set: {
                    guard self[keyPath: keyPath] != $0 else { return }
                    self.update(keyPath, to: $0, origin: origin)
                }
            )
        }
    
    func binding<Value: Equatable, ConvertedValue>(
        for keyPath: ReferenceWritableKeyPath<Self, Value>,
        origin: UpdateOrigin = .ui,
        get: @escaping (Value) -> ConvertedValue,
        set: @escaping (ConvertedValue) -> Value
    ) -> Binding<ConvertedValue> {
        Binding(
            get: { get(self[keyPath: keyPath]) },
            set: {
                let newValue = set($0)
                guard self[keyPath: keyPath] != newValue else { return }
                self.update(keyPath, to: newValue, origin: origin)
            }
        )
    }
}

final class Track: UpdatableObject {
    @Published var title: String
    @Published var duration: Duration
    weak var album: Album?
    
    init(album: Album? = nil, title: String, duration: Duration) {
        self.album = album
        self.title = title
        self.duration = duration
    }
    
    func uiDidUpdateValue<Value>(at keyPath: PartialKeyPath<Track>, to value: Value) {
        debugPrint("Updating", keyPath, "to", value)
    }
}

final class Album: UpdatableObject {
    @Published var title: String
    @Published var releaseYear: Int
    @Published var tracks: [Track] = []
    weak var artist: Artist?
    
    init(artist: Artist? = nil, title: String, releaseYear: Int, tracks: [Track] = []) {
        self.artist = artist
        self.title = title
        self.releaseYear = releaseYear
        self.tracks = tracks.map { $0.album = self; return $0 }
    }
    
    func uiDidUpdateValue<Value>(at keyPath: PartialKeyPath<Album>, to value: Value) {
        debugPrint("Updating", keyPath, "to", value)
    }
    
//    func uiDidUpdateValue<Value>(at keyPath: PartialKeyPath<Self>, to value: Value) {
//        print("UI updated \(Self.self).\(keyPath): \(value)")
//    }
}

final class Artist: UpdatableObject {
    @Published var name: String
    @Published var yearFounded: Int
    @Published var albums: [Album] = []
    
    init(name: String, yearFounded: Int, albums: [Album] = []) {
        self.name = name
        self.yearFounded = yearFounded
        self.albums = albums.map { $0.artist = self; return $0 }
    }
    
    func uiDidUpdateValue<Value>(at keyPath: PartialKeyPath<Artist>, to value: Value) {
        debugPrint("Updating", keyPath, "to", value)
    }
}

struct ContentView: View {
//    @StateObject private var viewModel = RandomNumberViewModel()
    @State private var albumIndex = 0
    @StateObject private var artist = Artist(
        name: "August Burns Red", yearFounded: 2003,
        albums: [
            Album(title: "Thrill Seeker", releaseYear: 2005, tracks: [
                Track(title: "Your Little Suburbia is in Ruins", duration: .seconds(3*60+59)),
                Track(title: "Speech Impediment", duration: .seconds(4*60+1)),
                Track(title: "Endorphins", duration: .seconds(3*60+10)),
            ]),
            Album(title: "Messengers", releaseYear: 2007, tracks: [
                Track(title: "Truth of a Liar", duration: .seconds(4*60+12)),
                Track(title: "Up Against the Ropes", duration: .seconds(5*60+4)),
                Track(title: "Back Burner", duration: .seconds(3*60+43)),
            ])
        ]
    )
    
    var body: some View {
        VStack(spacing: 20) {
            TextField("Name", text: artist.binding(for: \.name))
            HStack {
                Text("Year Founded")
                TextField("Year", text: artist.binding(
                    for: \.yearFounded,
                    get: { NumberFormatter.localizedString(from: $0 as NSNumber, number: .none) },
                    set: { Int($0) ?? 0 }
                ))
                Stepper(value: artist.binding(for: \.yearFounded)) { }
                Button(action: {
                    artist.update(\.yearFounded, to: Int.random(in: 1990...2020), origin: .network)
                }) {
                    Text("Randomize")
                }
            }
            Text("Album Count: \(artist.albums.count)")
            if !artist.albums.isEmpty {
                Stepper("Album \(albumIndex+1)", value: $albumIndex, in: 0...(artist.albums.count-1))
                AlbumView(album: artist.albums[albumIndex])
            }
        }
    }
}

struct AlbumView: View {
    @StateObject var album: Album
    @State var trackIndex = 0
    
    var body: some View {
        VStack {
            TextField("Album Title", text: album.binding(for: \.title))
            TextField("Release Year", text: album.binding(for: \.releaseYear, get: { $0.description }, set: { Int($0, radix: 10) ?? 0 } ))
            if !album.tracks.isEmpty {
                Stepper("Track \(trackIndex+1)", value: $trackIndex, in: 0...(album.tracks.count-1))
                TrackView(track: album.tracks[trackIndex])
            }
        }
        .border(Color.secondary)
        .padding(5)
    }
}

struct TrackView: View {
    @StateObject var track: Track
    
    var body: some View {
        VStack {
            TextField("Title", text: track.binding(for: \.title))
            TextField("Duration", text: track.binding(for: \.duration, get: { $0.formatted() }, set: { $0.asDuration() }))
            Text(track.duration.formatted())
        }
        .border(Color.secondary)
        .padding(5)
    }
}

extension String {
    func asDuration() -> Duration {
        let components = self.split(separator: ":")
        switch components.count {
        case 1:
            return Duration.seconds(Int(components[0]) ?? 0)
        case 2:
            return Duration.seconds((Int(components[0]) ?? 0)*60 + (Int(components[1]) ?? 0))
        case 3:
            let hours = (Int(components[0]) ?? 0)*60*60
            let minutes = (Int(components[1]) ?? 0)*60
            let seconds = (Int(components[2]) ?? 0)
            return Duration.seconds(hours+minutes+seconds)
        default:
            return Duration.seconds(0)
        }
    }
}

#Preview {
    ContentView()
}
