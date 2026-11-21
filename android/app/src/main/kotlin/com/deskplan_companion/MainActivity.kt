package com.deskplan_companion

import android.content.ActivityNotFoundException
import android.content.pm.ActivityInfo
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID

/**
 * Receives what other apps share (Android's share sheet) and hands it to
 * Dart over the "deskplan/share" channel.
 *
 * A shared file arrives as a content:// link that may stop working soon, so
 * each file is copied into the app cache straight away, on a background
 * thread (a big file would freeze the screen otherwise).
 */
class MainActivity : FlutterActivity() {
    private lateinit var channel: MethodChannel

    /** The share this activity was started with, until Dart asks for it. */
    private var startIntent: Intent? = null

    /** Waiting for the user to choose files in the system file chooser. */
    private var pickResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        startIntent = intent
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "deskplan/share")
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takeInitial" -> {
                    val shared = startIntent
                    startIntent = null // hand it over once only
                    readInBackground(shared) { items -> result.success(items) }
                }
                "pickFiles" -> startPicker(result)
                else -> result.notImplemented()
            }
        }
    }

    /** Opens Android's own file chooser (documents, photos, Drive...). */
    @Suppress("DEPRECATION")
    private fun startPicker(result: MethodChannel.Result) {
        if (pickResult != null) {
            result.error("busy", "The file chooser is already open", null)
            return
        }
        val intent = chooseFilesIntent()
        if (intent == null) {
            result.error("no-chooser", "No app on this phone can choose files", null)
            return
        }
        pickResult = result
        try {
            startActivityForResult(intent, PICK_REQUEST)
        } catch (e: ActivityNotFoundException) {
            pickResult = null
            result.error("no-chooser", "No app on this phone can choose files", null)
        }
    }

    /**
     * Works out how to ask for files on this phone, or null if it cannot.
     *
     * The modern "open document" chooser is used when something answers it.
     * Some phones (Samsung, for example) switch Google's document viewer off
     * and use their own My Files instead; that answers the older "get
     * content" request, so that is used then, and the file manager is opened
     * directly. Two things are avoided on purpose:
     *
     * - Android's own app chooser, which may send the request to a photo
     *   picker.
     * - Any photo picker. With no document viewer behind it, a photo picker
     *   starts itself again and again until Android closes the app.
     */
    @Suppress("DEPRECATION")
    private fun chooseFilesIntent(): Intent? {
        val open = filesIntent(Intent.ACTION_OPEN_DOCUMENT)
        if (open.resolveActivity(packageManager) != null) {
            Log.i(TAG, "File chooser: OPEN_DOCUMENT")
            return open
        }

        val get = filesIntent(Intent.ACTION_GET_CONTENT)
        val handlers = packageManager.queryIntentActivities(get, 0).map { it.activityInfo }
        Log.i(TAG, "GET_CONTENT handlers: " + handlers.joinToString { "${it.packageName}/${it.name}" })

        val usable = handlers.filter { !isPhotoPicker(it) }
        val chosen = FILE_MANAGERS.firstNotNullOfOrNull { pkg ->
            usable.firstOrNull { it.packageName == pkg }
        } ?: usable.firstOrNull()
        if (chosen == null) {
            Log.w(TAG, "File chooser: none usable")
            return null
        }
        Log.i(TAG, "File chooser: ${chosen.packageName}/${chosen.name}")
        return get.apply { setClassName(chosen.packageName, chosen.name) }
    }

    private fun isPhotoPicker(info: ActivityInfo): Boolean =
        info.packageName.contains("photopicker", ignoreCase = true) ||
            info.packageName.contains("providers.media", ignoreCase = true) ||
            info.name.contains("photopicker", ignoreCase = true)

    /** An intent asking for any number of files of any type. */
    private fun filesIntent(action: String) = Intent(action).apply {
        addCategory(Intent.CATEGORY_OPENABLE)
        type = "*/*"
        putExtra(Intent.EXTRA_ALLOW_MULTIPLE, true)
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_REQUEST) return
        val result = pickResult ?: return
        pickResult = null
        if (resultCode != RESULT_OK || data == null) {
            result.success(emptyList<Map<String, String>>()) // backed out
            return
        }
        val uris = mutableListOf<Uri>()
        data.clipData?.let { clip ->
            for (i in 0 until clip.itemCount) uris.add(clip.getItemAt(i).uri)
        }
        if (uris.isEmpty()) data.data?.let { uris.add(it) }
        // Copy off the main thread, the same way shared files are copied.
        Thread {
            val items = uris.mapNotNull { uri ->
                try { copyToCache(uri) } catch (e: Exception) { null }
            }
            runOnUiThread { result.success(items) }
        }.start()
    }

    /** A share that arrives while the app is already open. */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        readInBackground(intent) { items ->
            if (items.isNotEmpty()) channel.invokeMethod("shared", items)
        }
    }

    private fun readInBackground(
        intent: Intent?,
        done: (List<Map<String, String>>) -> Unit,
    ) {
        Thread {
            val items = try {
                readShare(intent)
            } catch (e: Exception) {
                emptyList()
            }
            runOnUiThread { done(items) }
        }.start()
    }

    private fun readShare(intent: Intent?): List<Map<String, String>> {
        if (intent == null) return emptyList()
        // Opening the app again from the recent-apps list replays the old
        // share intent: ignore that, it was already handled.
        if (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) {
            return emptyList()
        }
        val items = mutableListOf<Map<String, String>>()
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val uri = streamUri(intent)
                if (uri != null) {
                    copyToCache(uri)?.let { items.add(it) }
                } else {
                    intent.getStringExtra(Intent.EXTRA_TEXT)?.let { text ->
                        val entry = mutableMapOf("type" to "text", "text" to text)
                        intent.getStringExtra(Intent.EXTRA_SUBJECT)?.let { entry["subject"] = it }
                        items.add(entry)
                    }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                streamUris(intent).forEach { uri -> copyToCache(uri)?.let { items.add(it) } }
            }
        }
        return items
    }

    @Suppress("DEPRECATION")
    private fun streamUri(intent: Intent): Uri? =
        if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableExtra(Intent.EXTRA_STREAM)
        }

    @Suppress("DEPRECATION")
    private fun streamUris(intent: Intent): List<Uri> =
        (if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableArrayListExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
        }) ?: emptyList()

    /** Copies the shared file into the cache. Returns null if it can't be read. */
    private fun copyToCache(uri: Uri): Map<String, String>? {
        val name = displayName(uri) ?: "shared-file"
        val folder = File(cacheDir, "shared/${UUID.randomUUID()}")
        folder.mkdirs()
        val target = File(folder, "payload")
        val input = contentResolver.openInputStream(uri) ?: return null
        input.use { source -> target.outputStream().use { sink -> source.copyTo(sink) } }
        return mapOf("type" to "file", "path" to target.absolutePath, "name" to name)
    }

    private fun displayName(uri: Uri): String? {
        if (uri.scheme == "content") {
            contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)
                ?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val name = cursor.getString(0)
                        if (!name.isNullOrBlank()) return name
                    }
                }
        }
        return uri.lastPathSegment?.substringAfterLast('/')
    }

    companion object {
        private const val PICK_REQUEST = 4711

        private const val TAG = "DeskPlan"

        /** File managers to prefer, best first, when the phone has several. */
        private val FILE_MANAGERS = listOf(
            "com.google.android.documentsui",
            "com.android.documentsui",
            "com.sec.android.app.myfiles",
        )
    }
}
