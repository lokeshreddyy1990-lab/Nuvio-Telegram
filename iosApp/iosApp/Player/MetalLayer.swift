import Foundation
import UIKit

class MetalLayer: CAMetalLayer {
    override var drawableSize: CGSize {
        get { super.drawableSize }
        set {
            guard Int(newValue.width) > 1, Int(newValue.height) > 1 else { return }
            // #region agent log
            if !Thread.isMainThread {
                AgentDebugLog.emit(
                    hypothesisId: "A",
                    location: "MetalLayer.swift:drawableSize",
                    message: "drawableSize set off-main (marshalled async)",
                    data: ["w": newValue.width, "h": newValue.height]
                )
            }
            // #endregion
            applyOnMain { super.drawableSize = newValue }
        }
    }

    override var wantsExtendedDynamicRangeContent: Bool {
        get { super.wantsExtendedDynamicRangeContent }
        set {
            // #region agent log
            if !Thread.isMainThread {
                AgentDebugLog.emit(
                    hypothesisId: "A",
                    location: "MetalLayer.swift:edr",
                    message: "wantsEDR set off-main (marshalled async)",
                    data: ["value": newValue]
                )
            }
            // #endregion
            applyOnMain { super.wantsExtendedDynamicRangeContent = newValue }
        }
    }

    override var bounds: CGRect {
        get { super.bounds }
        set {
            // #region agent log
            if !Thread.isMainThread {
                AgentDebugLog.emit(
                    hypothesisId: "A",
                    location: "MetalLayer.swift:bounds",
                    message: "bounds set OFF-MAIN (unmarshalled — crash candidate)",
                    data: ["w": newValue.width, "h": newValue.height]
                )
            }
            // #endregion
            super.bounds = newValue
        }
    }

    override var contentsScale: CGFloat {
        get { super.contentsScale }
        set {
            // #region agent log
            if !Thread.isMainThread {
                AgentDebugLog.emit(
                    hypothesisId: "A",
                    location: "MetalLayer.swift:contentsScale",
                    message: "contentsScale set OFF-MAIN (unmarshalled — crash candidate)",
                    data: ["scale": Double(newValue)]
                )
            }
            // #endregion
            super.contentsScale = newValue
        }
    }

    override var position: CGPoint {
        get { super.position }
        set {
            // #region agent log
            if !Thread.isMainThread {
                AgentDebugLog.emit(
                    hypothesisId: "A",
                    location: "MetalLayer.swift:position",
                    message: "position set OFF-MAIN (unmarshalled — crash candidate)",
                    data: ["x": newValue.x, "y": newValue.y]
                )
            }
            // #endregion
            super.position = newValue
        }
    }

    /// mpv's vo thread mutates CAMetalLayer during init/teardown while holding the
    /// core lock; a sync hop deadlocks against main-thread property reads, and
    /// writing layer props off-main trips Auto Layout ("layout engine" crash).
    private func applyOnMain(_ body: @escaping () -> Void) {
        if Thread.isMainThread {
            body()
        } else {
            DispatchQueue.main.async(execute: body)
        }
    }
}

// #region agent log
enum AgentDebugLog {
    static func emit(
        hypothesisId: String,
        location: String,
        message: String,
        data: [String: Any] = [:]
    ) {
        var payload: [String: Any] = [
            "sessionId": "ba4530",
            "runId": "pre-fix",
            "hypothesisId": hypothesisId,
            "location": location,
            "message": message,
            "timestamp": Int(Date().timeIntervalSince1970 * 1000),
            "data": data.merging([
                "isMainThread": Thread.isMainThread,
                "thread": Thread.current.description,
            ]) { _, new in new },
        ]
        if let json = try? JSONSerialization.data(withJSONObject: payload),
           let line = String(data: json, encoding: .utf8) {
            NSLog("[agent-debug] %@", line)
        }
        guard let url = URL(string: "http://127.0.0.1:7506/ingest/0da04b14-66c3-448a-86b7-3c2501161af3"),
              let body = try? JSONSerialization.data(withJSONObject: payload) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("ba4530", forHTTPHeaderField: "X-Debug-Session-Id")
        request.httpBody = body
        URLSession.shared.dataTask(with: request).resume()
    }
}
// #endregion
