import Foundation
import Combine

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()
    @Published var audio = UserDefaults.standard.string(forKey: "StreamShelf.audio") ?? "Original"
    @Published var quality = UserDefaults.standard.string(forKey: "StreamShelf.quality") ?? "Auto"
    @Published var adBlock = UserDefaults.standard.object(forKey: "StreamShelf.adBlock") as? Bool ?? true
    @Published var autoResume = UserDefaults.standard.object(forKey: "StreamShelf.autoResume") as? Bool ?? true
    private var bag = Set<AnyCancellable>()

    private init() {
        $audio.dropFirst().sink { UserDefaults.standard.set($0, forKey: "StreamShelf.audio") }.store(in: &bag)
        $quality.dropFirst().sink { UserDefaults.standard.set($0, forKey: "StreamShelf.quality") }.store(in: &bag)
        $adBlock.dropFirst().sink { UserDefaults.standard.set($0, forKey: "StreamShelf.adBlock") }.store(in: &bag)
        $autoResume.dropFirst().sink { UserDefaults.standard.set($0, forKey: "StreamShelf.autoResume") }.store(in: &bag)
    }
}
