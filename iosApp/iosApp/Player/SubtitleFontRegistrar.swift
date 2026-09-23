import CoreText
import Foundation

/// Registers imported subtitle fonts with CoreText and resolves their real family name.
///
/// The bundled libass (MPVKit) is built with `-Dfontconfig=disabled -Dcoretext=enabled`, so mpv's
/// `sub-fonts-dir` (mapped to libass' `ass_set_fonts_dir`) is never scanned: the CoreText font
/// provider only enumerates fonts registered inside the process. Registering the imported file
/// here makes it visible to libass, and `sub-font` must then hold the font's family name instead
/// of the imported file name.
enum SubtitleFontRegistrar {
    /// `kCTFontManagerErrorAlreadyRegistered` from `CTFontManagerErrors.h`.
    private static let alreadyRegisteredErrorCode: CFIndex = 105

    private static let lock = NSLock()
    private static var familyCache: [String: String] = [:]

    /// Directory the app copies imported subtitle fonts into (see `SubtitleFontFileBridge.ios.kt`).
    static var importDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("subtitle-fonts", isDirectory: true)
    }

    /// Registers every font in the import directory.
    ///
    /// Called during app startup because process scoped registrations do not survive a relaunch.
    static func registerImportedFonts() {
        let directory = importDirectory
        guard
            let entries = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
        else {
            return
        }
        for entry in entries where isSupportedFontFile(entry.pathExtension) {
            register(path: entry.path)
        }
    }

    /// Registers a single font file with CoreText for the current process. Registration is
    /// idempotent: re-registering an already registered file is reported as success.
    @discardableResult
    static func register(path: String) -> Bool {
        guard !path.isEmpty, FileManager.default.fileExists(atPath: path) else {
            NSLog("[NuvioSubtitleFont] register skipped, missing file path=\(path)")
            return false
        }
        var error: Unmanaged<CFError>?
        let registered = CTFontManagerRegisterFontsForURL(
            URL(fileURLWithPath: path) as CFURL,
            .process,
            &error
        )
        if registered {
            return true
        }
        if let error = error?.takeRetainedValue() {
            let code = CFErrorGetCode(error)
            if code == alreadyRegisteredErrorCode {
                return true
            }
            NSLog("[NuvioSubtitleFont] register failed path=\(path) code=\(code)")
            return false
        }
        return false
    }

    /// Resolves the family name libass should receive as `sub-font`.
    ///
    /// Registers the font first (so it exists in the CoreText database), then reads the family
    /// name, falling back to the display and PostScript names for fonts that only expose those.
    static func resolveFamilyName(path: String?, fallback: String?) -> String? {
        guard let path, !path.isEmpty else {
            return fallback?.isEmpty == false ? fallback : nil
        }

        let cacheKey = familyCacheKey(path: path)
        lock.lock()
        defer { lock.unlock() }

        if let cached = familyCache[cacheKey] {
            return cached
        }

        register(path: path)

        guard let family = familyName(path: path) else {
            NSLog(
                "[NuvioSubtitleFont] no CoreText family for path=\(path), using \(fallback ?? "-")"
            )
            let fallbackValue = fallback?.isEmpty == false ? fallback : nil
            if let fallbackValue {
                familyCache[cacheKey] = fallbackValue
            }
            return fallbackValue
        }

        familyCache[cacheKey] = family
        NSLog("[NuvioSubtitleFont] resolved family=\(family) path=\(path)")
        return family
    }

    /// Reads a usable font name from the font file via CoreText.
    private static func familyName(path: String) -> String? {
        guard
            let descriptors = CTFontManagerCreateFontDescriptorsFromURL(
                URL(fileURLWithPath: path) as CFURL
            ) as? [CTFontDescriptor]
        else {
            return nil
        }

        let attributes: [CFString] = [
            kCTFontFamilyNameAttribute,
            kCTFontDisplayNameAttribute,
            kCTFontNameAttribute,
        ]

        for descriptor in descriptors {
            for attribute in attributes {
                guard let rawValue = CTFontDescriptorCopyAttribute(descriptor, attribute) else {
                    continue
                }
                if let value = rawValue as? String, !value.isEmpty {
                    return value
                }
                if let value = rawValue as? NSString, value.length > 0 {
                    return value as String
                }
            }
        }
        return nil
    }

    private static func familyCacheKey(path: String) -> String {
        let attributes = try? FileManager.default.attributesOfItem(atPath: path)
        let modificationDate = attributes?[.modificationDate] as? Date
        let timestamp = modificationDate?.timeIntervalSince1970 ?? 0
        return "\(path)|\(timestamp)"
    }

    private static func isSupportedFontFile(_ pathExtension: String) -> Bool {
        switch pathExtension.lowercased() {
        case "ttf", "otf", "ttc":
            return true
        default:
            return false
        }
    }
}
