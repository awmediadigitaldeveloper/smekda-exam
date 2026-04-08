package com.smekda.mobiletest

import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import android.os.UserManager
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.widget.Toast
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
  private val CHANNEL = "com.smekda.mobiletest/kiosk"

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    applySecureWindowFlags()
  }

  override fun onResume() {
    super.onResume()
    applySecureWindowFlags()
    enableKioskMode()
  }

  override fun onWindowFocusChanged(hasFocus: Boolean) {
    super.onWindowFocusChanged(hasFocus)
    if (hasFocus) {
      applySecureWindowFlags()
    }
  }

  // Prevent home button from removing app from foreground in non-device-owner mode
  override fun onUserLeaveHint() {
    // Intentionally empty — prevents system from treating this as a voluntary leave
  }

  // Re-enforce fullscreen when split-screen is triggered
  override fun onMultiWindowModeChanged(isInMultiWindowMode: Boolean, newConfig: Configuration) {
    super.onMultiWindowModeChanged(isInMultiWindowMode, newConfig)
    if (isInMultiWindowMode) {
      applySecureWindowFlags()
    }
  }

  // Re-enforce fullscreen when PiP is triggered
  override fun onPictureInPictureModeChanged(
    isInPictureInPictureMode: Boolean,
    newConfig: Configuration
  ) {
    super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
    if (isInPictureInPictureMode) {
      applySecureWindowFlags()
    }
  }

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "exitKiosk" -> {
          stopKioskIfPossible()
          result.success(true)
        }
        "enableKiosk" -> {
          enableKioskMode()
          result.success(true)
        }
        else -> result.notImplemented()
      }
    }
  }

  private fun applySecureWindowFlags() {
    window.addFlags(
      WindowManager.LayoutParams.FLAG_SECURE or
      WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
      WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD or
      WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED
    )

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      // Android 11+: modern API — hides status bar + navigation bar
      // BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE: bars appear briefly on edge-swipe then auto-hide
      window.setDecorFitsSystemWindows(false)
      window.insetsController?.let { controller ->
        controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
        controller.systemBarsBehavior =
          WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
      }
    } else {
      // Android 10 and below: legacy flags
      @Suppress("DEPRECATION")
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

        // Disable status bar (Android 9+)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
          devicePolicyManager.setStatusBarDisabled(adminComponent, true)
        }

        // --- Block communications ---
        devicePolicyManager.addUserRestriction(adminComponent, UserManager.DISALLOW_OUTGOING_CALLS)
        devicePolicyManager.addUserRestriction(adminComponent, UserManager.DISALLOW_SMS)
        devicePolicyManager.addUserRestriction(adminComponent, UserManager.DISALLOW_USB_FILE_TRANSFER)

        // --- Block system escape routes ---
        devicePolicyManager.addUserRestriction(adminComponent, UserManager.DISALLOW_SAFE_BOOT)
        devicePolicyManager.addUserRestriction(adminComponent, UserManager.DISALLOW_FACTORY_RESET)
        devicePolicyManager.addUserRestriction(adminComponent, UserManager.DISALLOW_ADD_USER)
        devicePolicyManager.addUserRestriction(adminComponent, UserManager.DISALLOW_INSTALL_APPS)
        devicePolicyManager.addUserRestriction(adminComponent, UserManager.DISALLOW_UNINSTALL_APPS)
        devicePolicyManager.addUserRestriction(adminComponent, UserManager.DISALLOW_MOUNT_PHYSICAL_MEDIA)

        // --- Block volume adjustment ---
        devicePolicyManager.addUserRestriction(adminComponent, UserManager.DISALLOW_ADJUST_VOLUME)

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
