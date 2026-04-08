package com.smekda.mobiletest

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.UserManager
import android.view.View
import android.view.WindowManager
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val CHANNEL = "com.smekda.mobiletest/kiosk"
  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    window.decorView.systemUiVisibility = (
      View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
        or View.SYSTEM_UI_FLAG_FULLSCREEN
        or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
        or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
    )
  }

  override fun onResume() {
    super.onResume()
    enableKioskMode()
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "exitKiosk" -> {
          stopKioskIfPossible()
          result.success(true)
        }
        else -> result.notImplemented()
      }
    }
  }

  override fun onWindowFocusChanged(hasFocus: Boolean) {
    super.onWindowFocusChanged(hasFocus)
    if (hasFocus) {
      window.decorView.systemUiVisibility = (
        View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY
          or View.SYSTEM_UI_FLAG_FULLSCREEN
          or View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
          or View.SYSTEM_UI_FLAG_LAYOUT_STABLE
          or View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
          or View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN
      )
    }
  }

  private fun stopKioskIfPossible() {
    try {
      stopLockTask()
    } catch (_: IllegalStateException) {
      // No lock task active.
    }
    finishAndRemoveTask()
  }

  private fun enableKioskMode() {
    val devicePolicyManager =
      getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
    val adminComponent = ComponentName(this, ExamDeviceAdminReceiver::class.java)

    try {
      if (devicePolicyManager.isDeviceOwnerApp(packageName)) {
        devicePolicyManager.setLockTaskPackages(adminComponent, arrayOf(packageName))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
          devicePolicyManager.setStatusBarDisabled(adminComponent, true)
        }
        devicePolicyManager.addUserRestriction(adminComponent, UserManager.DISALLOW_OUTGOING_CALLS)
        devicePolicyManager.addUserRestriction(adminComponent, UserManager.DISALLOW_SMS)
        devicePolicyManager.addUserRestriction(adminComponent, UserManager.DISALLOW_USB_FILE_TRANSFER)
        startLockTask()
        return
      }

      if (devicePolicyManager.isAdminActive(adminComponent) &&
          devicePolicyManager.isLockTaskPermitted(packageName)) {
        startLockTask()
        return
      }
    } catch (_: SecurityException) {
      // Lock task package setup failed when the app is not device owner.
    }

    Toast.makeText(
      this,
      "Kiosk mode tidak diaktifkan. Perangkat perlu di-provision sebagai device owner atau admin.",
      Toast.LENGTH_LONG,
    ).show()
  }
}
