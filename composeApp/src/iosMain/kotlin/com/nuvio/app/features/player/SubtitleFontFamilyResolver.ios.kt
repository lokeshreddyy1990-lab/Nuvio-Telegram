package com.nuvio.app.features.player

import cnames.structs.__CTFontDescriptor
import kotlinx.cinterop.ExperimentalForeignApi
import kotlinx.cinterop.reinterpret
import platform.CoreFoundation.CFArrayGetCount
import platform.CoreFoundation.CFArrayGetValueAtIndex
import platform.CoreFoundation.CFRelease
import platform.CoreFoundation.CFURLRef
import platform.CoreText.CTFontCopyFamilyName
import platform.CoreText.CTFontCopyPostScriptName
import platform.CoreText.CTFontCreateWithFontDescriptor
import platform.CoreText.CTFontManagerCreateFontDescriptorsFromURL
import platform.Foundation.NSFileManager
import platform.Foundation.NSURL

/**
 * libmpv/libass matches [sub-font] against the font's internal family name, not the file name.
 */
@OptIn(ExperimentalForeignApi::class)
internal fun resolveSubtitleFontFamilyName(path: String): String? {
    if (!NSFileManager.defaultManager.fileExistsAtPath(path)) return null
    val url = NSURL.fileURLWithPath(path)
    val descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURLRef) ?: return null
    try {
        if (CFArrayGetCount(descriptors) <= 0L) return null
        val descriptor = CFArrayGetValueAtIndex(descriptors, 0)?.reinterpret<__CTFontDescriptor>()
            ?: return null
        val font = CTFontCreateWithFontDescriptor(descriptor, 12.0, null) ?: return null
        try {
            val family = (CTFontCopyFamilyName(font) as? String)?.trim()?.takeIf { it.isNotEmpty() }
            if (family != null) return family
            return (CTFontCopyPostScriptName(font) as? String)?.trim()?.takeIf { it.isNotEmpty() }
        } finally {
            CFRelease(font)
        }
    } finally {
        CFRelease(descriptors)
    }
}
