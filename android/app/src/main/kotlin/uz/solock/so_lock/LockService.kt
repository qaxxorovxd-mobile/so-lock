package uz.solock.so_lock

import android.accessibilityservice.AccessibilityService
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.provider.Settings
import android.view.accessibility.AccessibilityEvent
import android.view.inputmethod.InputMethodManager

/**
 * Watches which app comes to the foreground (window-state events only — no content is read)
 * and raises the lock screen for protected apps.
 */
class LockService : AccessibilityService() {

    companion object {
        @Volatile var instance: LockService? = null
            private set

        fun isEnabled(ctx: Context): Boolean {
            if (instance != null) return true
            val list = Settings.Secure.getString(ctx.contentResolver, Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
            return list.contains("${ctx.packageName}/") && list.contains("LockService")
        }
    }

    /** pkg -> 0 while the user is inside it, otherwise the time they left. */
    private val unlocked = HashMap<String, Long>()
    private var currentPkg: String? = null
    private var ignored: Set<String> = emptySet()
    private var launchers: Set<String> = emptySet()
    private val HOP_GRACE_MS = 30_000L
    private val main = Handler(Looper.getMainLooper())

    private val screenReceiver = object : BroadcastReceiver() {
        override fun onReceive(c: Context, i: Intent) {
            when (i.action) {
                Intent.ACTION_SCREEN_OFF -> unlocked.clear()
                Intent.ACTION_SCREEN_ON, Intent.ACTION_USER_PRESENT -> currentPkg?.let { evaluate(it) }
            }
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        refreshIgnored()
        refreshLaunchers()
        val f = IntentFilter().apply {
            addAction(Intent.ACTION_SCREEN_OFF)
            addAction(Intent.ACTION_SCREEN_ON)
            addAction(Intent.ACTION_USER_PRESENT)
        }
        if (Build.VERSION.SDK_INT >= 33) registerReceiver(screenReceiver, f, Context.RECEIVER_EXPORTED)
        else registerReceiver(screenReceiver, f)
        // Warm the lock UI so the first lock is instant.
        main.post { runCatching { SoLockApp.app.ensureLockEngine() } }
    }

    override fun onDestroy() {
        runCatching { unregisterReceiver(screenReceiver) }
        instance = null
        super.onDestroy()
    }

    override fun onInterrupt() {}

    private fun refreshIgnored() {
        val s = hashSetOf(packageName, "com.android.systemui", "android")
        runCatching {
            val imm = getSystemService(INPUT_METHOD_SERVICE) as InputMethodManager
            imm.enabledInputMethodList.forEach { s.add(it.packageName) }
        }
        ignored = s
    }

    override fun onAccessibilityEvent(e: AccessibilityEvent?) {
        if (e == null || e.eventType != AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED) return
        val pkg = e.packageName?.toString() ?: return
        if (pkg in ignored) return
        if (pkg != currentPkg) {
            currentPkg?.let { onLeave(it, pkg) }
            currentPkg = pkg
        }
        evaluate(pkg)
    }

    /**
     * An unlocked app often hands off to another package for a moment and comes back:
     * a gallery's private-album password prompt (security center), share sheets, pickers,
     * camera, payment screens… Re-locking on that hop would interrupt the flow and loop
     * forever. So a hop to a non-launcher app keeps a short grace window; going home
     * ends the session immediately.
     */
    private fun onLeave(pkg: String, to: String) {
        val now = SystemClock.elapsedRealtime()
        val toHome = to in launchers
        if (toHome && Config.relock == "exit") {
            // Home pressed: end this session and any pending hop sessions.
            unlocked.entries.removeAll { it.key == pkg || it.value != 0L }
            return
        }
        if (!unlocked.containsKey(pkg)) return
        if (Config.relock != "screen") unlocked[pkg] = now
    }

    private fun isUnlocked(pkg: String): Boolean {
        val left = unlocked[pkg] ?: return false
        if (left == 0L) return true
        val away = SystemClock.elapsedRealtime() - left
        val ok = when (Config.relock) {
            "screen" -> true
            "timeout" -> away < maxOf(HOP_GRACE_MS, Config.relockMinutes * 60_000L)
            else -> away < HOP_GRACE_MS
        }
        if (ok) unlocked[pkg] = 0L else unlocked.remove(pkg)
        return ok
    }

    private fun refreshLaunchers() {
        launchers = runCatching {
            val i = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
            packageManager.queryIntentActivities(i, 0).map { it.activityInfo.packageName }.toSet()
        }.getOrDefault(emptySet())
    }

    private fun evaluate(pkg: String) {
        if (!Config.enabled || pkg !in Config.locked) return
        if (isUnlocked(pkg)) return
        if (!SmartEval.shouldLock(this)) return
        showLock(pkg)
    }

    private fun showLock(pkg: String) {
        LockActivity.pendingTarget = pkg
        SoLockApp.lockChannel?.invokeMethod("target", pkg)
        val i = Intent(this, LockActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_NO_ANIMATION or
                    Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            )
            putExtra("pkg", pkg)
        }
        startActivity(i)
    }

    /** Called by the lock UI after a correct PIN / biometric. */
    fun markUnlocked(pkg: String) {
        unlocked[pkg] = 0L
        currentPkg = pkg
    }

    fun goHome() {
        performGlobalAction(GLOBAL_ACTION_HOME)
    }

    fun lockDevice(): Boolean {
        if (Build.VERSION.SDK_INT >= 28) return performGlobalAction(GLOBAL_ACTION_LOCK_SCREEN)
        performGlobalAction(GLOBAL_ACTION_HOME)
        return false
    }
}
