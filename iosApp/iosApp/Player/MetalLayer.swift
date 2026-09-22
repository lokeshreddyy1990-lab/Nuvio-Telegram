import Foundation
import UIKit

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
