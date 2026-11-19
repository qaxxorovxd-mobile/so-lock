package uz.solock.so_lock

import android.app.Application
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel

class SoLockApp : Application() {

    companion object {
        const val LOCK_ENGINE = "solock_lock_engine"
        const val CHANNEL = "solock/native"
        lateinit var app: SoLockApp
            private set
        var lockChannel: MethodChannel? = null
            private set
    }

    override fun onCreate() {
        super.onCreate()
        app = this
        Config.load(this)
    }

    /**
     * The lock UI runs in its own pre-warmed Flutter engine so the lock screen
     * appears in the same frame the protected app is opened — no cold start.
     */
    fun ensureLockEngine(): FlutterEngine {
        FlutterEngineCache.getInstance().get(LOCK_ENGINE)?.let { return it }
        val loader = FlutterInjector.instance().flutterLoader()
        if (!loader.initialized()) {
            loader.startInitialization(this)
            loader.ensureInitializationComplete(this, null)
        }
        val engine = FlutterEngine(this)
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(NativeBridge(this) { LockActivity.current })
        lockChannel = channel
        engine.dartExecutor.executeDartEntrypoint(
            DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "lockMain")
        )
        FlutterEngineCache.getInstance().put(LOCK_ENGINE, engine)
        return engine
    }
}
