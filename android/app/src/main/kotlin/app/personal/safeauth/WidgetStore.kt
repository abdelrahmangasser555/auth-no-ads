package app.personal.safeauth

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.json.JSONArray
import org.json.JSONObject

data class WidgetAccount(
    val id: String,
    val issuer: String,
    val label: String,
    val secret: String,
    val algorithm: String,
    val digits: Int,
    val period: Int,
)

object WidgetStore {
    private const val fileName = "widget_vault"
    private const val keyAccounts = "accounts"
    private const val keyLaunch = "launch_action"

    @Volatile
    private var cached: SharedPreferences? = null

    fun saveAccounts(context: Context, accounts: List<WidgetAccount>) {
        val array = JSONArray()
        for (account in accounts) {
            array.put(
                JSONObject()
                    .put("id", account.id)
                    .put("issuer", account.issuer)
                    .put("label", account.label)
                    .put("secret", account.secret)
                    .put("algorithm", account.algorithm)
                    .put("digits", account.digits)
                    .put("period", account.period),
            )
        }
        prefs(context).edit().putString(keyAccounts, array.toString()).apply()
    }

    fun loadAccounts(context: Context): List<WidgetAccount> {
        val raw = prefs(context).getString(keyAccounts, "[]") ?: "[]"
        val array = JSONArray(raw)
        val out = ArrayList<WidgetAccount>(array.length())
        for (i in 0 until array.length()) {
            val obj = array.getJSONObject(i)
            out.add(
                WidgetAccount(
                    id = obj.optString("id"),
                    issuer = obj.optString("issuer"),
                    label = obj.optString("label"),
                    secret = obj.optString("secret"),
                    algorithm = obj.optString("algorithm", "SHA1"),
                    digits = obj.optInt("digits", 6),
                    period = obj.optInt("period", 30),
                ),
            )
        }
        return out
    }

    fun setLaunchAction(context: Context, action: String?) {
        prefs(context).edit().putString(keyLaunch, action).apply()
    }

    fun takeLaunchAction(context: Context): String? {
        val value = prefs(context).getString(keyLaunch, null)
        if (!value.isNullOrEmpty()) {
            prefs(context).edit().remove(keyLaunch).apply()
        }
        return value
    }

    private fun prefs(context: Context): SharedPreferences {
        cached?.let { return it }
        synchronized(this) {
            cached?.let { return it }
            val created = try {
                val masterKey = MasterKey.Builder(context)
                    .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                    .build()
                EncryptedSharedPreferences.create(
                    context,
                    fileName,
                    masterKey,
                    EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                    EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM,
                )
            } catch (_: Exception) {
                context.applicationContext.getSharedPreferences(
                    "${fileName}_fallback",
                    Context.MODE_PRIVATE,
                )
            }
            cached = created
            return created
        }
    }
}
