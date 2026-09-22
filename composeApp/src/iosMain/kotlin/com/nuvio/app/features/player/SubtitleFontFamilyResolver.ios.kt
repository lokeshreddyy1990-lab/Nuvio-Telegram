package com.nuvio.app.features.player

import kotlinx.cinterop.ExperimentalForeignApi
import platform.CoreText.CTFontCopyFamilyName
import platform.CoreText.CTFontCopyPostScriptName
import platform.CoreText.CTFontCreateWithURL
import platform.Foundation.NSFileManager
import platform.Foundation.NSURL

/**
 * libmpv/libass matches [sub-font] against the font's internal family name, not the file name.
 */
@OptIn(ExperimentalForeignApi::class)
internal fun resolveSubtitleFontFamilyName(path: String): String? {
    if (!NSFileManager.defaultManager.fileExistsAtPath(path)) return null
    val url = NSURL.fileURLWithPath(path)
    val font = CTFontCreateWithURL(url, 12.0, null, null) ?: return null
    val family = (CTFontCopyFamilyName(font) as? String)?.trim()?.takeIf { it.isNotEmpty() }
    if (family != null) return family
    return (CTFontCopyPostScriptName(font) as? String)?.trim()?.takeIf { it.isNotEmpty() }
}
