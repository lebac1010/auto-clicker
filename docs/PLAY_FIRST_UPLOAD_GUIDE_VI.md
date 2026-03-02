# Play Store First Upload Guide (VI)

Cap nhat: 2026-03-02

## 1) Ban can chuan bi gi

1. Tai khoan Google Play Console da dang ky.
2. Email support de hien thi tren listing.
3. URL Privacy Policy public (https).
4. App icon, screenshots, short description, full description.
5. Upload keystore (giu bi mat, backup an toan).

## 2) Tao upload keystore (Windows PowerShell)

Chay trong thu muc `app/android`:

```powershell
keytool -genkeypair -v `
  -keystore upload-keystore.jks `
  -storetype JKS `
  -keyalg RSA `
  -keysize 2048 `
  -validity 10000 `
  -alias upload
```

Luu y:
1. Khong commit file keystore len git.
2. Khong chia se `storePassword`/`keyPassword` qua chat.
3. Backup file `upload-keystore.jks` va mat khau o noi an toan.

## 3) Dien `key.properties`

1. Tao file `app/android/key.properties` tu `app/android/key.properties.example`.
2. Dien gia tri thuc:

```properties
storeFile=upload-keystore.jks
storePassword=YOUR_STORE_PASSWORD
keyAlias=upload
keyPassword=YOUR_KEY_PASSWORD
```

## 4) Build AAB release

Chay trong thu muc `app`:

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

Artifact de upload:
`app/build/app/outputs/bundle/release/app-release.aab`

## 5) Khai bao Play Console can lam

1. Accessibility declaration + video evidence.
2. Foreground service declaration (`specialUse`).
3. Exact alarm declaration.
4. Data Safety form.
5. Privacy Policy URL.

Xem mau khai bao:
`docs/PLAY_PRE_SUBMIT_PACK_VI.md`

