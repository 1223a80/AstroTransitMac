import Foundation
import OSLog

extension Logger {
    static let app = Logger(subsystem: "com.gacu.TransitStudio", category: "app")
    static let backend = Logger(subsystem: "com.gacu.TransitStudio", category: "backend")
    static let viewLifecycle = Logger(subsystem: "com.gacu.TransitStudio", category: "view")
    static let rendering = Logger(subsystem: "com.gacu.TransitStudio", category: "rendering")
    static let export = Logger(subsystem: "com.gacu.TransitStudio", category: "export")
}
