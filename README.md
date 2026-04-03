# SMEKDA MOBILE TEST

Flutter Android app berbasis WebView untuk menjalankan:

- `https://smekda-mobile-test.vercel.app/`

Status project:

- Nama aplikasi: `SMEKDA MOBILE TEST`
- Android package: `com.smekda.mobiletest`
- Launcher icon: custom dari logo sekolah
- Release signing: sudah dikonfigurasi

Output build utama:

- APK debug: `build/app/outputs/flutter-apk/app-debug.apk`
- APK release: `build/app/outputs/flutter-apk/app-release.apk`
- AAB release: `build/app/outputs/bundle/release/app-release.aab`

File penting untuk release:

- `android/app/keystore/smekda-mobile-upload-keystore.jks`
- `android/key.properties`
- `android/key.properties.example`

Build command:

```bash
flutter pub get
flutter build apk --release
flutter build appbundle --release
```
# ari_smekda_test
