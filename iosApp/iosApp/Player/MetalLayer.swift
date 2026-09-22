import Foundation
import UIKit

class MetalLayer: CAMetalLayer {
    override var drawableSize: CGSize {
        get { super.drawableSize }
        set {
            guard Int(newValue.width) > 1, Int(newValue.height) > 1 else { return }
            applyOnMain { super.drawableSize = newValue }
        }
    }

    override var wantsExtendedDynamicRangeContent: Bool {
        get { super.wantsExtendedDynamicRangeContent }
        set {
            applyOnMain { super.wantsExtendedDynamicRangeContent = newValue }
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
