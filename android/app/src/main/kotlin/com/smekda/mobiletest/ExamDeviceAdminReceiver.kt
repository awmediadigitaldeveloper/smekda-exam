package com.smekda.mobiletest

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent
import android.widget.Toast

class ExamDeviceAdminReceiver : DeviceAdminReceiver() {
  override fun onEnabled(context: Context, intent: Intent) {
    Toast.makeText(context, "Device admin aktif untuk mode ujian.", Toast.LENGTH_LONG).show()
  }

  override fun onDisabled(context: Context, intent: Intent) {
    Toast.makeText(context, "Device admin dinonaktifkan.", Toast.LENGTH_LONG).show()
  }
}
