package com.pypecrm.dialer.recording

import android.content.ContentUris
import android.content.Context
import android.provider.MediaStore
import android.util.Log
import android.webkit.MimeTypeMap
import com.pypecrm.dialer.util.PhoneNumberUtils
import java.io.File

/**
 * Tier 0: looks for a file the OEM's own call-recorder already wrote to
 * MediaStore. Ported near-verbatim from Dad-call-recorder's
 * `call_recording_engine/scanner/NativeRecordingScanner.kt` (a separate
 * repo, referenced for its proven pattern only — not shared code): this app
 * being the actual default dialer doesn't change how this tier works at all,
 * it just reads whatever the phone's own recorder already produced.
 *
 * Needs no RECORD_AUDIO-adjacent permission — only READ_MEDIA_AUDIO (33+) /
 * READ_EXTERNAL_STORAGE (legacy), the same permission any gallery/media app
 * needs, which is why this tier alone is safe to add here without touching
 * this app's Play-compliance stance on live capture (see the approved
 * plan's §3 — Tier 1 live capture is deliberately NOT part of this pass).
 */
object NativeRecordingScanner {

    private const val TAG = "NativeRecordingScanner"

    private const val WINDOW_BEFORE_MS = 60_000L
    private const val WINDOW_AFTER_MS = 5 * 60_000L
    private const val FALLBACK_WINDOW_MS = 30_000L
    private const val MIN_FILE_SIZE_BYTES = 1024L

    fun scanOnce(context: Context, phoneNumber: String, callEndMillis: Long): File? {
        val suffix = PhoneNumberUtils.last10Digits(phoneNumber)
        val numberMatch = if (suffix.length >= 10) queryMatching(context, suffix, callEndMillis) else null
        if (numberMatch != null) {
            Log.d(TAG, "Tier 0 match by number suffix: ${numberMatch.absolutePath}")
            return numberMatch
        }

        val fallbackMatch = queryNewestWithinWindow(context, callEndMillis)
        if (fallbackMatch != null) {
            Log.d(TAG, "Tier 0 match by nearest-timestamp fallback: ${fallbackMatch.absolutePath}")
            return fallbackMatch
        }

        return null
    }

    private fun queryMatching(context: Context, suffix: String, callEndMillis: Long): File? {
        val resolver = context.contentResolver
        val uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.MIME_TYPE,
        )
        val selection = "${MediaStore.Audio.Media.DISPLAY_NAME} LIKE ?"
        val selectionArgs = arrayOf("%$suffix%")
        val sortOrder = "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"

        try {
            resolver.query(uri, projection, selection, selectionArgs, sortOrder)?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
                val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
                val mimeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)

                while (cursor.moveToNext()) {
                    val id = cursor.getLong(idCol)
                    val name = cursor.getString(nameCol) ?: ""
                    val lastModifiedMillis = cursor.getLong(dateCol) * 1000
                    val size = cursor.getLong(sizeCol)
                    val mimeType = cursor.getString(mimeCol)

                    val delta = lastModifiedMillis - callEndMillis
                    if (delta < -WINDOW_BEFORE_MS || delta > WINDOW_AFTER_MS) continue
                    if (size in 0 until MIN_FILE_SIZE_BYTES) continue

                    val copied = copyToCache(context, uri, id, name, mimeType)
                    if (copied != null) return copied
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "MediaStore query failed", e)
        }
        return null
    }

    private fun queryNewestWithinWindow(context: Context, callEndMillis: Long): File? {
        val resolver = context.contentResolver
        val uri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.DISPLAY_NAME,
            MediaStore.Audio.Media.DATE_MODIFIED,
            MediaStore.Audio.Media.SIZE,
            MediaStore.Audio.Media.MIME_TYPE,
        )
        val sortOrder = "${MediaStore.Audio.Media.DATE_MODIFIED} DESC"

        data class Candidate(val id: Long, val name: String, val mimeType: String?)
        val candidates = mutableListOf<Candidate>()

        try {
            resolver.query(uri, projection, null, null, sortOrder)?.use { cursor ->
                val idCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val nameCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DISPLAY_NAME)
                val dateCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_MODIFIED)
                val sizeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.SIZE)
                val mimeCol = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.MIME_TYPE)

                while (cursor.moveToNext() && candidates.size <= 1) {
                    val lastModifiedMillis = cursor.getLong(dateCol) * 1000
                    val delta = lastModifiedMillis - callEndMillis
                    if (delta < -FALLBACK_WINDOW_MS) break
                    if (delta > FALLBACK_WINDOW_MS) continue
                    val size = cursor.getLong(sizeCol)
                    if (size in 0 until MIN_FILE_SIZE_BYTES) continue
                    candidates.add(Candidate(cursor.getLong(idCol), cursor.getString(nameCol) ?: "", cursor.getString(mimeCol)))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "MediaStore fallback query failed", e)
            return null
        }

        if (candidates.size != 1) return null
        val candidate = candidates.first()
        return copyToCache(context, uri, candidate.id, candidate.name, candidate.mimeType)
    }

    private fun copyToCache(context: Context, uri: android.net.Uri, id: Long, name: String, mimeType: String?): File? {
        val contentUri = ContentUris.withAppendedId(uri, id)
        val extension = extensionFor(mimeType, name)
        val cacheFile = File(context.cacheDir, "tier0_call_$id.$extension")
        val copied = context.contentResolver.openInputStream(contentUri)?.use { input ->
            cacheFile.outputStream().use { output -> input.copyTo(output) }
            true
        } ?: false
        return if (copied && cacheFile.exists() && cacheFile.length() >= MIN_FILE_SIZE_BYTES) cacheFile else null
    }

    private fun extensionFor(mimeType: String?, displayName: String): String {
        val fromMime = mimeType?.let { MimeTypeMap.getSingleton().getExtensionFromMimeType(it) }
        if (!fromMime.isNullOrEmpty()) return fromMime
        val fromName = displayName.substringAfterLast('.', missingDelimiterValue = "")
        return fromName.ifEmpty { "m4a" }
    }
}
