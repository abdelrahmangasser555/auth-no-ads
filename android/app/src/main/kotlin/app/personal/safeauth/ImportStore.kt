package app.personal.safeauth

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

object ImportStore {
    const val pickRequest = 7101

    @Volatile
    var pendingIncoming: IncomingFile? = null

    @Volatile
    var pickResult: MethodChannel.Result? = null

    data class IncomingFile(
        val content: String,
        val uri: String?,
        val name: String?,
    )

    fun captureIntent(context: Context, intent: Intent?) {
        val file = fromIntent(context, intent) ?: return
        pendingIncoming = file
    }

    fun takeIncoming(): IncomingFile? {
        val value = pendingIncoming
        pendingIncoming = null
        return value
    }

    fun beginPick(activity: Activity, result: MethodChannel.Result) {
        pickResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
            putExtra(
                Intent.EXTRA_MIME_TYPES,
                arrayOf(
                    "application/json",
                    "text/plain",
                    "application/octet-stream",
                    "*/*",
                ),
            )
            addFlags(
                Intent.FLAG_GRANT_READ_URI_PERMISSION or
                    Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION,
            )
        }
        activity.startActivityForResult(intent, pickRequest)
    }

    fun onPickResult(context: Context, resultCode: Int, data: Intent?) {
        val pending = pickResult
        pickResult = null
        if (pending == null) return
        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            pending.error("canceled", "No file selected", null)
            return
        }
        val uri = data.data!!
        try {
            try {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (_: SecurityException) {
            }
            val file = read(context, uri)
            pending.success(file.toMap())
        } catch (e: Exception) {
            pending.error("read_failed", e.message, null)
        }
    }

    fun read(context: Context, uri: Uri): IncomingFile {
        val name = queryName(context, uri)
        val content = context.contentResolver.openInputStream(uri)?.use { stream ->
            BufferedReader(InputStreamReader(stream, Charsets.UTF_8)).readText()
        } ?: throw IllegalStateException("Could not read file")
        return IncomingFile(content = content, uri = uri.toString(), name = name)
    }

    fun release(context: Context, uri: Uri) {
        try {
            context.contentResolver.releasePersistableUriPermission(
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION,
            )
        } catch (_: SecurityException) {
        }
    }

    private fun fromIntent(context: Context, intent: Intent?): IncomingFile? {
        if (intent == null) return null
        val uri = when (intent.action) {
            Intent.ACTION_SEND -> {
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(Intent.EXTRA_STREAM)
                }
            }
            Intent.ACTION_VIEW, Intent.ACTION_EDIT -> intent.data
            else -> intent.data
        } ?: return null
        return try {
            try {
                context.contentResolver.takePersistableUriPermission(
                    uri,
                    Intent.FLAG_GRANT_READ_URI_PERMISSION,
                )
            } catch (_: SecurityException) {
            }
            read(context, uri)
        } catch (_: Exception) {
            null
        }
    }

    private fun queryName(context: Context, uri: Uri): String? {
        val cursor = context.contentResolver.query(uri, null, null, null, null) ?: return uri.lastPathSegment
        cursor.use {
            val index = it.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && it.moveToFirst()) {
                return it.getString(index)
            }
        }
        return uri.lastPathSegment
    }
}

fun ImportStore.IncomingFile.toMap(): Map<String, Any?> {
    return mapOf(
        "content" to content,
        "uri" to uri,
        "name" to name,
        "missing" to false,
    )
}
