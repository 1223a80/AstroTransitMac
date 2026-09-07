import Foundation

enum AppResources {
    private static let resourceBundleName = "AstroTransitMac_TransitStudio.bundle"

    static var bundle: Bundle? {
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent(resourceBundleName),
            Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/\(resourceBundleName)"),
            Bundle.main.bundleURL.appendingPathComponent(resourceBundleName)
        ].compactMap { $0 }

        for url in candidates {
            if let bundle = Bundle(url: url) {
                return bundle
            }
        }
        // SwiftPM tests and `swift run` keep the resource bundle beside the
        // executable, outside an application's Contents/Resources layout.
        return Bundle.module
    }

    static func url(forResource name: String, withExtension ext: String, subdirectory: String? = nil) -> URL? {
        bundle?.url(forResource: name, withExtension: ext, subdirectory: subdirectory)
    }
}
