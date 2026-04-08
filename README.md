# SMEKDA MOBILE TEST

Flutter Android app berbasis WebView untuk menjalankan:

- `https://smekda-mobile-test.vercel.app/`

## 🚀 Build Otomatis

Aplikasi ini menggunakan GitHub Actions untuk build APK dan IPA otomatis setiap push ke branch `main`.

### Download APK (Android)
1. Pergi ke tab **Actions** di repository GitHub
2. Klik workflow **Build Android APK and iOS IPA** terbaru
3. Scroll ke bagian **Artifacts**
4. Download file `smekda-exam-apk.zip`
5. Extract dan install file `smekda_exam.apk` (universal untuk semua device Android)

### Download IPA (iOS)
1. Pergi ke tab **Actions** di repository GitHub
2. Klik workflow **Build Android APK and iOS IPA** terbaru
3. Scroll ke bagian **Artifacts**
4. Download file `smekda-exam-ipa.zip`
5. Extract file `smekda_exam.ipa`
6. Install menggunakan Xcode atau iTunes untuk testing (tidak untuk production)

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

### Android
- APK universal: `build/app/outputs/flutter-apk/smekda_exam.apk`
- APK debug: `build/app/outputs/flutter-apk/app-debug.apk`
- AAB release: `build/app/outputs/bundle/release/app-release.aab`

### iOS
- IPA: `build/ios/iphoneos/smekda_exam.ipa`
- App bundle: `build/ios/iphoneos/Runner.app`

## 📁 File Penting untuk Release

- `android/app/keystore/smekda-mobile-upload-keystore.jks`
- `android/key.properties`
- `android/key.properties.example`

## 🛠️ Build Manual

### Android
```bash
flutter pub get
flutter build apk --release
flutter build appbundle --release
```

### iOS (macOS dengan Xcode)
```bash
flutter pub get
flutter build ios --release --no-codesign
cd build/ios/iphoneos
mkdir Payload
cp -r Runner.app Payload/
zip -r smekda_exam.ipa Payload
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

## 🔐 Cara Rahasia Keluar dari Aplikasi

Aplikasi sekarang memiliki area rahasia di sudut kiri atas layar.

- Ketuk area tersembunyi sebanyak **7 kali** dalam 2 detik
- Masukkan kode: `4411`
- Jika benar, aplikasi akan keluar dari mode ujian

## ⚠️ Catatan Keamanan

- Fitur keamanan maksimal membutuhkan device owner privileges (Android)
- Untuk testing, gunakan emulator atau device development
- Production deployment membutuhkan MDM setup
- iOS build dari GitHub Actions tidak signed, hanya untuk testing
- Untuk production iOS, gunakan Apple Developer Program dan code signing yang proper
