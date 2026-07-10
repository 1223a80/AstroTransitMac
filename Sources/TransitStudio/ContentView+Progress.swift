import OSLog
import SwiftUI

extension ContentView {
    @MainActor
    func startEstimatedProgress(totalWork: Int, label: String) {
        calcVM.progressTask?.cancel()
        calcVM.calculationProgress = 0.02
        calcVM.calculationProgressText = "\(label) 2%"
        calcVM.progressTask = Task {
            Logger.viewLifecycle.debug("calcVM.progressTask started: label=\(label) totalWork=\(totalWork)")
            var progress = 0.02
            let step = totalWork > 500 ? 0.01 : 0.025
            while !Task.isCancelled && progress < 0.92 {
                try? await Task.sleep(nanoseconds: 250_000_000)
                progress = min(progress + step, 0.92)
                await MainActor.run {
                    calcVM.calculationProgress = progress
                    calcVM.calculationProgressText = "\(label) \(Int(progress * 100))%"
                }
            }
            Logger.viewLifecycle.debug("calcVM.progressTask done: cancelled=\(Task.isCancelled)")
        }
    }

    @MainActor
    func finishProgress(cancelled: Bool = false) {
        calcVM.progressTask?.cancel()
        calcVM.progressTask = nil
        if cancelled {
            calcVM.calculationProgress = nil
            calcVM.calculationProgressText = ""
            return
        }
        calcVM.calculationProgress = 1.0
        calcVM.calculationProgressText = "完成 100%"
        Task {
            try? await Task.sleep(nanoseconds: 900_000_000)
            await MainActor.run {
                calcVM.calculationProgress = nil
                calcVM.calculationProgressText = ""
            }
        }
    }
}
