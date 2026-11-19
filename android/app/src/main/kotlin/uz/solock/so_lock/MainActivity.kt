package uz.solock.so_lock

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {

    private var bridge: NativeBridge? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // App contents (locked app list, intruder photos) never show in recents/screenshots.
        if (applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE == 0) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val b = NativeBridge(applicationContext) { this }
        bridge = b
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SoLockApp.CHANNEL).setMethodCallHandler(b)
    }

    @Deprecated("Deprecated in Java")
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == NativeBridge.REQ) bridge?.onPermissionResult()
    }
}
