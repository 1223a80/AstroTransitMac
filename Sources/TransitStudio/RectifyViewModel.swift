import SwiftUI

@MainActor
class RectifyViewModel: ObservableObject {
    @Published var response: RectifyResponse?
    @Published var level2Response: RectifyResponse?
    @Published var level3Response: RectifyResponse?
    @Published var s1Index = 0
    @Published var s2Index = 0
    @Published var activeLevel = 1
    @Published var level2Gen = 0
    @Published var level3Gen = 0
    @Published var level3ResponseID = 0
}
