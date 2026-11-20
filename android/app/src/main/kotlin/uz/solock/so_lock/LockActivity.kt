package uz.solock.so_lock

import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

/** Hosts the lock UI from the pre-warmed engine. */
class LockActivity : FlutterFragmentActivity() {

    var lockVisible = false
        private set

    companion object {
        @Volatile var current: LockActivity? = null
            private set
        @Volatile var pendingTarget: String? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        SoLockApp.app.ensureLockEngine()
        super.onCreate(savedInstanceState)
        current = this
        // Lock screen never appears in screenshots or the recents thumbnail.
        if (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE == 0) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
        intent?.getStringExtra("pkg")?.let { pendingTarget = it }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.getStringExtra("pkg")?.let {
            pendingTarget = it
            SoLockApp.lockChannel?.invokeMethod("target", it)
        }
    }

    override fun onResume() {
        super.onResume()
        current = this
        SoLockApp.lockChannel?.invokeMethod("resumed", pendingTarget)
    }

    override fun onStop() {
        lockVisible = false
        super.onStop()
        SoLockApp.lockChannel?.invokeMethod("stopped", null)
    }

    override fun getCachedEngineId(): String = SoLockApp.LOCK_ENGINE

    override fun onStart() {
        super.onStart()
        lockVisible = true
    }

    override fun shouldDestroyEngineWithHost(): Boolean = false

    override fun finish() {
        super.finish()
        @Suppress("DEPRECATION")
        overridePendingTransition(0, 0)
    }

    override fun onDestroy() {
        if (current === this) current = null
        super.onDestroy()
    }
}
