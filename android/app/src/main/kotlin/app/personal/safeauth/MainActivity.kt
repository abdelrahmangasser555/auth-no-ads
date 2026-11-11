package app.personal.safeauth

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ImportStore.captureIntent(this, intent)
        intent?.getStringExtra("open")?.let { WidgetStore.setLaunchAction(this, it) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        ImportStore.captureIntent(this, intent)
        intent.getStringExtra("open")?.let { WidgetStore.setLaunchAction(this, it) }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == ImportStore.pickRequest) {
            ImportStore.onPickResult(this, resultCode, data)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.personal.safeauth/secure",
        ).setMethodCallHandler { call, result ->
            if (call.method == "setSecure") {
                val secure = call.argument<Boolean>("secure") ?: true
                runOnUiThread {
                    if (secure) {
                        window.setFlags(
                            WindowManager.LayoutParams.FLAG_SECURE,
                            WindowManager.LayoutParams.FLAG_SECURE,
                        )
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                    }
                }
                result.success(null)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.personal.safeauth/widget",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "syncAccounts" -> {
                    val raw = call.argument<List<Any>>("accounts") ?: emptyList()
                    val accounts = raw.mapNotNull { item ->
                        val map = item as? Map<*, *> ?: return@mapNotNull null
                        val id = map["id"] as? String ?: return@mapNotNull null
                        val secret = map["secret"] as? String ?: return@mapNotNull null
                        WidgetAccount(
                            id = id,
                            issuer = map["issuer"] as? String ?: "Account",
                            label = map["label"] as? String ?: "",
                            secret = secret,
                            algorithm = map["algorithm"] as? String ?: "SHA1",
                            digits = (map["digits"] as? Number)?.toInt() ?: 6,
                            period = (map["period"] as? Number)?.toInt() ?: 30,
                        )
                    }
                    WidgetStore.saveAccounts(this, accounts)
                    CodesWidgetProvider.refresh(this)
                    result.success(null)
                }
                "takeLaunch" -> result.success(WidgetStore.takeLaunchAction(this))
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "app.personal.safeauth/import",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickAndLink" -> ImportStore.beginPick(this, result)
                "readLinked" -> {
                    val uri = call.argument<String>("uri")
                    if (uri.isNullOrEmpty()) {
                        result.success(mapOf("content" to "", "missing" to true))
                    } else {
                        try {
                            val file = ImportStore.read(this, Uri.parse(uri))
                            result.success(file.toMap())
                        } catch (_: Exception) {
                            result.success(
                                mapOf(
                                    "content" to "",
                                    "uri" to uri,
                                    "missing" to true,
                                ),
                            )
                        }
                    }
                }
                "unlink" -> {
                    val uri = call.argument<String>("uri")
                    if (!uri.isNullOrEmpty()) {
                        ImportStore.release(this, Uri.parse(uri))
                    }
                    result.success(null)
                }
                "takeIncoming" -> {
                    val incoming = ImportStore.takeIncoming()
                    result.success(incoming?.toMap())
                }
                else -> result.notImplemented()
            }
        }
    }
}
