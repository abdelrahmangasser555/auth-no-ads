package app.personal.safeauth

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.widget.RemoteViews
import android.widget.Toast

class CodesWidgetProvider : AppWidgetProvider() {
    override fun onEnabled(context: Context) {
        super.onEnabled(context)
        schedule(context)
        refresh(context)
    }

    override fun onDisabled(context: Context) {
        super.onDisabled(context)
        cancel(context)
        pulseHandler.removeCallbacksAndMessages(null)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            bind(context, appWidgetManager, id)
        }
        schedule(context)
        startPulse(context)
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_COPY -> copy(context, intent.getStringExtra(EXTRA_ID))
            ACTION_REFRESH, ACTION_TICK, Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            -> {
                refresh(context)
                schedule(context)
                startPulse(context)
            }
        }
    }

    private fun bind(context: Context, manager: AppWidgetManager, widgetId: Int) {
        val accounts = WidgetStore.loadAccounts(context)
        val views = RemoteViews(context.packageName, R.layout.codes_widget)
        views.setOnClickPendingIntent(R.id.widget_refresh, broadcast(context, ACTION_REFRESH, widgetId))
        views.setOnClickPendingIntent(R.id.widget_header, openApp(context, "widget"))
        views.setOnClickPendingIntent(R.id.widget_empty, openApp(context, "widget"))
        if (accounts.isEmpty()) {
            views.setViewVisibility(R.id.widget_empty, android.view.View.VISIBLE)
            views.setViewVisibility(R.id.widget_list, android.view.View.GONE)
        } else {
            views.setViewVisibility(R.id.widget_empty, android.view.View.GONE)
            views.setViewVisibility(R.id.widget_list, android.view.View.VISIBLE)
            val service = Intent(context, CodesWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                data = android.net.Uri.parse("safeauth://widget/$widgetId")
            }
            views.setRemoteAdapter(R.id.widget_list, service)
            views.setPendingIntentTemplate(R.id.widget_list, copyTemplate(context))
            views.setEmptyView(R.id.widget_list, R.id.widget_empty)
        }
        manager.updateAppWidget(widgetId, views)
        manager.notifyAppWidgetViewDataChanged(widgetId, R.id.widget_list)
    }

    companion object {
        const val ACTION_COPY = "app.personal.safeauth.WIDGET_COPY"
        const val ACTION_REFRESH = "app.personal.safeauth.WIDGET_REFRESH"
        const val ACTION_TICK = "app.personal.safeauth.WIDGET_TICK"
        const val EXTRA_ID = "account_id"

        private val pulseHandler = Handler(Looper.getMainLooper())

        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, CodesWidgetProvider::class.java))
            if (ids.isEmpty()) return
            val provider = CodesWidgetProvider()
            provider.onUpdate(context, manager, ids)
        }

        private fun startPulse(context: Context) {
            pulseHandler.removeCallbacksAndMessages(null)
            val app = context.applicationContext
            var ticks = 0
            val pulse = object : Runnable {
                override fun run() {
                    val manager = AppWidgetManager.getInstance(app)
                    val ids = manager.getAppWidgetIds(
                        ComponentName(app, CodesWidgetProvider::class.java),
                    )
                    if (ids.isEmpty()) return
                    for (id in ids) {
                        manager.notifyAppWidgetViewDataChanged(id, R.id.widget_list)
                    }
                    ticks += 1
                    if (ticks < 29) {
                        pulseHandler.postDelayed(this, 1000)
                    }
                }
            }
            pulseHandler.postDelayed(pulse, 1000)
        }

        fun schedule(context: Context) {
            val accounts = WidgetStore.loadAccounts(context)
            val period = accounts.minOfOrNull { it.period.coerceAtLeast(10) } ?: 30
            val at = Totp.nextBoundaryMs(period)
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pending = broadcast(context, ACTION_TICK, 0, immutable = true)
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarm.canScheduleExactAlarms()) {
                    alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
                } else {
                    alarm.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
                }
            } catch (_: SecurityException) {
                alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending)
            }
        }

        private fun cancel(context: Context) {
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarm.cancel(broadcast(context, ACTION_TICK, 0, immutable = true))
        }

        private fun copy(context: Context, id: String?) {
            val account = WidgetStore.loadAccounts(context).firstOrNull { it.id == id } ?: return
            val code = Totp.code(
                secretBase32 = account.secret,
                digits = account.digits,
                period = account.period,
                algorithm = account.algorithm,
            )
            val clipboard = context.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            clipboard.setPrimaryClip(ClipData.newPlainText("otp", code))
            Toast.makeText(context, "Copied ${account.issuer} code", Toast.LENGTH_SHORT).show()
        }

        private fun openApp(context: Context, action: String): PendingIntent {
            WidgetStore.setLaunchAction(context, action)
            val intent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("open", action)
            }
            return PendingIntent.getActivity(
                context,
                42,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        private fun copyTemplate(context: Context): PendingIntent {
            val intent = Intent(context, CodesWidgetProvider::class.java).apply {
                this.action = ACTION_COPY
            }
            return PendingIntent.getBroadcast(
                context,
                43,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
        }

        private fun broadcast(
            context: Context,
            action: String,
            requestCode: Int,
            immutable: Boolean = true,
        ): PendingIntent {
            val intent = Intent(context, CodesWidgetProvider::class.java).apply {
                this.action = action
            }
            val flags = PendingIntent.FLAG_UPDATE_CURRENT or
                if (immutable) PendingIntent.FLAG_IMMUTABLE else PendingIntent.FLAG_MUTABLE
            return PendingIntent.getBroadcast(context, requestCode, intent, flags)
        }
    }
}

class CodesWidgetService : android.widget.RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return CodesRemoteViewsFactory(applicationContext)
    }
}

private class CodesRemoteViewsFactory(
    private val context: Context,
) : android.widget.RemoteViewsService.RemoteViewsFactory {
    private var accounts: List<WidgetAccount> = emptyList()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        accounts = WidgetStore.loadAccounts(context)
    }

    override fun onDestroy() {
        accounts = emptyList()
    }

    override fun getCount(): Int = accounts.size

    override fun getViewAt(position: Int): RemoteViews {
        val account = accounts[position]
        val now = System.currentTimeMillis()
        val code = Totp.format(
            Totp.code(
                secretBase32 = account.secret,
                digits = account.digits,
                period = account.period,
                algorithm = account.algorithm,
                nowMs = now,
            ),
        )
        val remaining = Totp.remainingSeconds(account.period, now)
        val views = RemoteViews(context.packageName, R.layout.codes_widget_item)
        views.setTextViewText(R.id.item_letter, letter(account.issuer))
        views.setTextViewText(R.id.item_issuer, account.issuer)
        views.setTextViewText(R.id.item_label, account.label)
        views.setTextViewText(R.id.item_code, code)
        views.setTextViewText(R.id.item_countdown, remaining.toString())
        val fill = Intent().putExtra(CodesWidgetProvider.EXTRA_ID, account.id)
        views.setOnClickFillInIntent(R.id.item_root, fill)
        return views
    }

    override fun getLoadingView(): RemoteViews? = null

    override fun getViewTypeCount(): Int = 1

    override fun getItemId(position: Int): Long =
        accounts.getOrNull(position)?.id.hashCode().toLong()

    override fun hasStableIds(): Boolean = true

    private fun letter(issuer: String): String {
        val trimmed = issuer.trim()
        return if (trimmed.isEmpty()) "?" else trimmed.substring(0, 1).uppercase()
    }
}
