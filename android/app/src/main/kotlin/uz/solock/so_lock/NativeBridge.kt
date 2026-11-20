package uz.solock.so_lock

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.Drawable
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/** One method-channel handler shared by the main app engine and the lock engine. */
class NativeBridge(
    private val ctx: Context,
    private val activity: () -> Activity?,
) : MethodChannel.MethodCallHandler {

    companion object {
        private val io = Executors.newFixedThreadPool(2)
        private val main = Handler(Looper.getMainLooper())
        private val iconCache = HashMap<String, ByteArray>()

        // permission request plumbing
        const val REQ = 4710
        var pendingPermission: MethodChannel.Result? = null
        var pendingPermissionName: String? = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getApps" -> io.execute {
                val list = loadApps()
                main.post { result.success(list) }
            }
            "getAppInfo" -> {
                val pkg = call.arguments as String
                io.execute {
                    val info = appInfo(pkg)
                    main.post { result.success(info) }
                }
            }
            "saveConfig" -> {
                Config.save(ctx, call.arguments as String)
                result.success(true)
            }
            "accessibilityEnabled" -> result.success(LockService.isEnabled(ctx))
            "openAccessibility" -> {
                startSettings(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                result.success(true)
            }
            "openAppSettings" -> {
                startSettings(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${ctx.packageName}")))
                result.success(true)
            }
            "hasPermission" -> result.success(hasPermission(call.arguments as String))
            "requestPermission" -> requestPermission(call.arguments as String, result)
            "currentWifi" -> result.success(SmartEval.currentSsid(ctx))
            "currentLocation" -> {
                val l = SmartEval.lastLocation(ctx)
                result.success(l?.let { mapOf("lat" to it.latitude, "lng" to it.longitude) })
            }
            "lockDevice" -> {
                val s = LockService.instance
                if (s == null) { result.success(false); return }
                LockActivity.current?.moveTaskToBack(true)
                result.success(s.lockDevice())
            }
            "goHome" -> {
                LockService.instance?.goHome() ?: homeIntent()
                LockActivity.current?.let { main.postDelayed({ it.finish() }, 120) }
                result.success(true)
            }
            "moveToBack" -> {
                activity()?.moveTaskToBack(true)
                result.success(true)
            }
            "unlockSuccess" -> {
                val pkg = call.arguments as String?
                if (pkg == null || pkg != LockActivity.pendingTarget || LockActivity.current?.isFinishing != false) {
                    result.success(false)
                    return
                }
                if (pkg != null) LockService.instance?.markUnlocked(pkg)
                LockActivity.pendingTarget = null
                LockActivity.current?.finish()
                result.success(true)
            }
            "getLockTarget" -> result.success(LockActivity.pendingTarget)
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            "vibrate" -> {
                val a = call.arguments as Map<*, *>
                vibrate(a["kind"] as String, (a["level"] as Number).toInt())
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private val vibrator: Vibrator? by lazy {
        if (Build.VERSION.SDK_INT >= 31) {
            (ctx.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as? VibratorManager)?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            ctx.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
    }

    /**
     * Crisp haptics independent of the system "touch feedback" toggle.
     * kind: key | success | error   level: 1 light, 2 medium, 3 strong
     */
    private fun vibrate(kind: String, level: Int) {
        val v = vibrator ?: return
        if (!v.hasVibrator() || level <= 0) return
        val amp = when (level) { 1 -> 70; 2 -> 150; else -> 255 }
        if (Build.VERSION.SDK_INT < 26) {
            @Suppress("DEPRECATION")
            v.vibrate(if (kind == "error") 120L else 12L)
            return
        }
        val effect = when (kind) {
            "key" -> if (Build.VERSION.SDK_INT >= 29) {
                VibrationEffect.createPredefined(
                    when (level) { 1 -> VibrationEffect.EFFECT_TICK; 2 -> VibrationEffect.EFFECT_CLICK; else -> VibrationEffect.EFFECT_HEAVY_CLICK }
                )
            } else VibrationEffect.createOneShot(longArrayOf(0, 8, 12, 18)[level], amp)
            "success" -> VibrationEffect.createWaveform(longArrayOf(0, 18, 70, 28), intArrayOf(0, amp / 2 + 20, 0, amp), -1)
            "error" -> VibrationEffect.createWaveform(longArrayOf(0, 45, 55, 45, 55, 70), intArrayOf(0, amp, 0, amp, 0, amp), -1)
            else -> VibrationEffect.createOneShot(20, amp)
        }
        runCatching { v.vibrate(effect) }
    }

    private fun startSettings(i: Intent) {
        val a = activity()
        if (a != null) a.startActivity(i) else ctx.startActivity(i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun homeIntent() {
        ctx.startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    private fun permissionsFor(name: String): Array<String> = when (name) {
        "camera" -> arrayOf(Manifest.permission.CAMERA)
        "location" -> arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
        "backgroundLocation" ->
            if (Build.VERSION.SDK_INT >= 29) arrayOf(Manifest.permission.ACCESS_BACKGROUND_LOCATION)
            else arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        else -> emptyArray()
    }

    private fun hasPermission(name: String): Boolean {
        val perms = permissionsFor(name)
        if (name == "location") return perms.any { ctx.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }
        return perms.isNotEmpty() && perms.all { ctx.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED }
    }

    private fun requestPermission(name: String, result: MethodChannel.Result) {
        if (hasPermission(name)) { result.success(true); return }
        val a = activity()
        if (a == null) { result.success(false); return }
        pendingPermission?.success(false)
        pendingPermission = result
        pendingPermissionName = name
        a.requestPermissions(permissionsFor(name), REQ)
    }

    fun onPermissionResult() {
        val r = pendingPermission ?: return
        val name = pendingPermissionName ?: ""
        pendingPermission = null
        r.success(hasPermission(name))
    }

    private fun loadApps(): List<Map<String, Any>> {
        val pm = ctx.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val seen = HashSet<String>()
        val out = ArrayList<Map<String, Any>>()
        for (ri in pm.queryIntentActivities(intent, 0)) {
            val pkg = ri.activityInfo.packageName
            if (pkg == ctx.packageName || !seen.add(pkg)) continue
            val label = ri.loadLabel(pm)?.toString() ?: pkg
            val icon = iconCache[pkg] ?: runCatching { toPng(ri.loadIcon(pm)) }.getOrNull()?.also { iconCache[pkg] = it }
            val m = hashMapOf<String, Any>("pkg" to pkg, "name" to label)
            if (icon != null) m["icon"] = icon
            out.add(m)
        }
        out.sortBy { (it["name"] as String).lowercase() }
        return out
    }

    private fun appInfo(pkg: String): Map<String, Any>? {
        val pm = ctx.packageManager
        return runCatching {
            val ai = pm.getApplicationInfo(pkg, 0)
            val m = hashMapOf<String, Any>("pkg" to pkg, "name" to pm.getApplicationLabel(ai).toString())
            val icon = iconCache[pkg] ?: toPng(pm.getApplicationIcon(ai)).also { iconCache[pkg] = it }
            m["icon"] = icon
            m
        }.getOrNull()
    }

    private fun toPng(d: Drawable, size: Int = 144): ByteArray {
        val bmp = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        d.setBounds(0, 0, size, size)
        d.draw(c)
        val bos = ByteArrayOutputStream()
        bmp.compress(Bitmap.CompressFormat.PNG, 100, bos)
        bmp.recycle()
        return bos.toByteArray()
    }
}
