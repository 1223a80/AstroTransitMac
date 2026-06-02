import OSLog
import SwiftUI

extension ContentView {
    @MainActor
    func startEstimatedProgress(totalWork: Int, label: String) {
        progressTask?.cancel()
        calculationProgress = 0.02
        calculationProgressText = "\(label) 2%"
        progressTask = Task {
            Logger.viewLifecycle.debug("progressTask started: label=\(label) totalWork=\(totalWork)")
            var progress = 0.02
            let step = totalWork > 500 ? 0.01 : 0.025
            while !Task.isCancelled && progress < 0.92 {
                try? await Task.sleep(nanoseconds: 250_000_000)
                progress = min(progress + step, 0.92)
                await MainActor.run {
                    calculationProgress = progress
                    calculationProgressText = "\(label) \(Int(progress * 100))%"
                }
            }
            Logger.viewLifecycle.debug("progressTask done: cancelled=\(Task.isCancelled)")
        }
    }

    @MainActor
    func finishProgress() {
        progressTask?.cancel()
        progressTask = nil
        calculationProgress = 1.0
        calculationProgressText = "完成 100%"
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run {
                calculationProgress = nil
                calculationProgressText = ""
            }
        }
    }
}
