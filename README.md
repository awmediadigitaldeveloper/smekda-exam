# SMEKDA MOBILE TEST

Flutter Android app berbasis WebView untuk menjalankan:

- `https://smekda-mobile-test.vercel.app/`

## 🚀 Build Otomatis

Aplikasi ini menggunakan GitHub Actions untuk build APK otomatis setiap push ke branch `main`.

### Download APK
1. Pergi ke tab **Actions** di repository GitHub
2. Klik workflow **Build Android APK** terbaru
3. Scroll ke bagian **Artifacts**
4. Download file `smekda-exam-apk.zip`
5. Extract dan install APK yang sesuai dengan arsitektur device:
   - `smekda_exam-arm64-v8a.apk` (untuk device modern)
   - `smekda_exam-armeabi-v7a.apk` (untuk device lama)
   - `smekda_exam-x86_64.apk` (untuk emulator)

## 🔒 Fitur Keamanan Enterprise

Aplikasi ini dilengkapi dengan fitur keamanan tingkat enterprise untuk mencegah kecurangan saat ujian:

### Android Security Features
- **Anti-Screenshot**: Menggunakan `FLAG_SECURE` untuk mencegah screenshot
- **Kiosk Mode**: Mendukung lock task mode untuk device owner
- **Immersive Fullscreen**: Layar penuh tanpa navigasi sistem
- **Device Admin**: Receiver untuk manajemen perangkat enterprise
- **Screen Lock**: Otomatis lock saat aplikasi kehilangan fokus

### WebView Security
- **Keyboard Protection**: Blokir Ctrl+C/V/X, F12, dan shortcut berbahaya
- **Context Menu**: Disable right-click dan context menu
- **Navigation Control**: Hanya izinkan domain yang diizinkan
- **Lifecycle Monitoring**: Deteksi saat aplikasi keluar fokus
- **Security Overlay**: Tampilkan overlay lock saat ada aktivitas mencurigakan

### iOS Security Features
- **Screenshot Detection**: Deteksi percobaan screenshot
- **Security Overlay**: Overlay hitam saat screen capture terdeteksi

## 📋 Status Project

- Nama aplikasi: `SMEKDA MOBILE TEST`
- Android package: `com.smekda.mobiletest`
- Launcher icon: custom dari logo sekolah
- Release signing: sudah dikonfigurasi

## 🏗️ Output Build

- APK debug: `build/app/outputs/flutter-apk/app-debug.apk`
- APK release: `build/app/outputs/flutter-apk/app-release.apk`
- AAB release: `build/app/outputs/bundle/release/app-release.aab`

## 📁 File Penting untuk Release

- `android/app/keystore/smekda-mobile-upload-keystore.jks`
- `android/key.properties`
- `android/key.properties.example`

## 🛠️ Build Manual

```bash
flutter pub get
flutter build apk --release
flutter build appbundle --release
```

## 📱 Setup Device untuk Kiosk Mode

Untuk fitur keamanan enterprise penuh:

1. **Device Owner Setup** (menggunakan ADB):
   ```bash
   adb shell dpm set-device-owner com.smekda.mobiletest/.ExamDeviceAdminReceiver
   ```

2. **Whitelist Lock Task**:
   - Device akan otomatis terdaftar saat device owner aktif

3. **MDM Integration**:
   - Gunakan Microsoft Intune, Jamf, atau MDM lainnya
   - Deploy sebagai managed app dengan kiosk policy

## ⚠️ Catatan Keamanan

- Fitur keamanan maksimal membutuhkan device owner privileges
- Untuk testing, gunakan emulator atau device development
- Production deployment membutuhkan MDM setup
