package com.sirandev.flashnote

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.IOException
import java.security.MessageDigest

/**
 * Receives ACTION_SEND / ACTION_SEND_MULTIPLE intents and forwards them to
 * Flutter.
 *
 * Shared images are copied out of the sender's content:// URI into app-private
 * cache before Flutter sees them, so saved records never depend on a temporary
 * read grant. Text is forwarded untouched; URL/source classification is done by
 * the Dart intake service.
 */
class ShareIntentHandler(private val activity: Activity) {
    companion object {
        private const val TAG = "ShareIntentHandler"
        private const val CHANNEL = "com.sirandev.flashnote/share"
        private const val EXTRA_CONSUMED = "com.sirandev.flashnote.SHARE_CONSUMED"
        private const val TEMP_DIR = "shared_attachments"
    }

    private val lock = Any()
    private var channel: MethodChannel? = null
    private var channelEngine: FlutterEngine? = null
    private var dartReady = false
    private var pendingPayload: Map<String, Any?>? = null

    /** Wires the channel for the given engine and drains a pending share. */
    fun attach(engine: FlutterEngine) {
        val newChannel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        val pending =
            synchronized(lock) {
                val sameEngine = engine === channelEngine
                if (!sameEngine) {
                    // A new engine means a new Dart isolate that will call ready().
                    dartReady = false
                    pendingPayload = null
                }
                channelEngine = engine
                channel = newChannel
                if (dartReady) pendingPayload.also { pendingPayload = null } else null
            }

        newChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "ready" -> {
                    onDartReady(newChannel)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        if (pending != null) deliver(newChannel, pending)
    }

    fun detach() {
        channel?.setMethodCallHandler(null)
        synchronized(lock) { channel = null }
        // Keep dartReady: an activity recreation can reuse the same Flutter
        // engine and its Dart isolate, which will not call ready() again.
    }

    /** Handles a share intent from onCreate (cold start) or onNewIntent (warm). */
    fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return
        // Activity recreation may replay the same intent; consume it once.
        if (intent.getBooleanExtra(EXTRA_CONSUMED, false)) return
        intent.putExtra(EXTRA_CONSUMED, true)

        val shareId = shareSignature(intent)
        Thread {
                val payload =
                    try {
                        buildPayload(intent, shareId)
                    } catch (error: Exception) {
                        Log.e(TAG, "Failed to read shared content", error)
                        mapOf(
                            "shareId" to shareId,
                            "text" to "",
                            "files" to emptyList<Map<String, Any?>>(),
                            "failedFileCount" to 1,
                        )
                    }
                postPayload(payload)
            }
            .start()
    }

    private fun onDartReady(channel: MethodChannel) {
        val pending =
            synchronized(lock) {
                dartReady = true
                pendingPayload.also { pendingPayload = null }
            }
        if (pending != null) deliver(channel, pending)
    }

    private fun postPayload(payload: Map<String, Any?>) {
        activity.runOnUiThread {
            val target =
                synchronized(lock) {
                    if (dartReady) {
                        channel
                    } else {
                        pendingPayload = payload
                        null
                    }
                }
            if (target != null) deliver(target, payload)
        }
    }

    private fun deliver(channel: MethodChannel, payload: Map<String, Any?>) {
        try {
            channel.invokeMethod("onShareReceived", payload)
        } catch (error: Exception) {
            Log.e(TAG, "Failed to deliver shared content to Flutter", error)
        }
    }

    private fun buildPayload(
        intent: Intent,
        shareId: String,
    ): Map<String, Any?> {
        val context = activity.applicationContext
        val files = mutableListOf<Map<String, Any?>>()
        var failed = 0

        extractUris(intent).forEachIndexed { index, uri ->
            val mimeType = resolveMimeType(context, uri, intent.type)
            // Only image shares are advertised by the manifest; ignore others.
            if (!mimeType.startsWith("image/")) return@forEachIndexed
            try {
                files.add(copyImage(context, uri, shareId, index, mimeType))
            } catch (error: Exception) {
                failed += 1
                Log.w(TAG, "Failed to copy shared image $uri", error)
            }
        }

        return mapOf(
            "shareId" to shareId,
            "text" to extractText(intent),
            "files" to files,
            "failedFileCount" to failed,
        )
    }

    private fun extractText(intent: Intent): String {
        val texts = mutableListOf<String>()
        when (val raw = intent.extras?.get(Intent.EXTRA_TEXT)) {
            is CharSequence -> texts.add(raw.toString())
            is Array<*> -> raw.forEach { if (it is CharSequence) texts.add(it.toString()) }
            is Iterable<*> -> raw.forEach { if (it is CharSequence) texts.add(it.toString()) }
        }
        intent.clipData?.let { clip ->
            for (index in 0 until clip.itemCount) {
                clip.getItemAt(index).text?.toString()?.let { texts.add(it) }
            }
        }
        return texts
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .distinct()
            .joinToString("\n")
    }

    @Suppress("DEPRECATION")
    private fun extractUris(intent: Intent): List<Uri> {
        val uris = LinkedHashMap<String, Uri>()
        fun add(uri: Uri?) {
            if (uri != null) uris.putIfAbsent(uri.toString(), uri)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
                ?.forEach(::add)
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)?.let(::add)
        } else {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)?.forEach(::add)
            intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)?.let(::add)
        }
        intent.clipData?.let { clip ->
            for (index in 0 until clip.itemCount) add(clip.getItemAt(index).uri)
        }
        return uris.values.toList()
    }

    private fun copyImage(
        context: Context,
        uri: Uri,
        shareId: String,
        index: Int,
        mimeType: String,
    ): Map<String, Any?> {
        val displayName = resolveDisplayName(context, uri)
        val fileName =
            sanitizeFileName(
                displayName ?: "shared_image_${System.currentTimeMillis()}_$index",
            )
        val directory = File(context.cacheDir, TEMP_DIR).apply { mkdirs() }
        val destination = File(directory, "${shareId}_${index}_$fileName")

        try {
            val input =
                context.contentResolver.openInputStream(uri)
                    ?: throw IOException("Cannot open shared URI: $uri")
            input.use { source ->
                destination.outputStream().use { sink -> source.copyTo(sink, 64 * 1024) }
            }
            if (!destination.exists() || destination.length() <= 0L) {
                throw IOException("Shared file is empty: $uri")
            }
        } catch (error: Exception) {
            destination.delete()
            throw error
        }

        return mapOf(
            "path" to destination.absolutePath,
            "fileName" to fileName,
            "mimeType" to mimeType,
            "size" to destination.length(),
        )
    }

    private fun resolveMimeType(
        context: Context,
        uri: Uri,
        fallback: String?,
    ): String {
        val resolved = context.contentResolver.getType(uri)
        if (resolved != null && resolved.contains('/')) return resolved
        if (fallback != null && fallback.startsWith("image/")) return fallback
        return resolved ?: fallback ?: ""
    }

    private fun resolveDisplayName(
        context: Context,
        uri: Uri,
    ): String? {
        return try {
            context.contentResolver
                .query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (!cursor.moveToFirst()) return@use null
                    val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                    if (index < 0 || cursor.isNull(index)) null else cursor.getString(index)
                }
        } catch (error: Exception) {
            Log.w(TAG, "Failed to query display name for $uri", error)
            null
        }
    }

    private fun sanitizeFileName(name: String): String {
        val base = name.substringAfterLast('/').substringAfterLast('\\').trim()
        val cleaned =
            base
                .map { character ->
                    if (character.isISOControl() || character in "\\/:*?\"<>|") '_' else character
                }
                .joinToString("")
                .trim('.', ' ')
        val result = cleaned.ifEmpty { "shared_image" }
        return if (result.length > 120) result.takeLast(120) else result
    }

    private fun shareSignature(intent: Intent): String {
        val builder = StringBuilder()
        builder.append(intent.type ?: "")
        builder.append('|').append(intent.extras?.get(Intent.EXTRA_TEXT)?.toString() ?: "")
        for (uri in extractUris(intent)) {
            builder.append('|').append(uri)
        }
        val digest =
            MessageDigest
                .getInstance("SHA-256")
                .digest(builder.toString().toByteArray())
        return digest.take(8).joinToString("") { "%02x".format(it) }
    }
}
