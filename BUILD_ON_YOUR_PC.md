# Build TileWise on your PC

`flutter analyze` clean and all tests green on the build machine.
Gradle/APK compilation happens on YOUR PC (the sandbox cannot do it).

## 1. Extract

Extract this zip so you get a `tilewise/` folder, e.g. `D:\Games Build\tilewise\`.

## 2. Your own upload key (ONE per app — never reuse another app's key)

Open a terminal in `D:\Games Build\tilewise\` and create the keystore
**yourself** (the key must never leave your PC):

```
cd android\app
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 9125 -alias upload
```

Then create `android\key.properties` (same folder as this file's example):

```
storePassword=YOUR_PASSWORD
keyPassword=YOUR_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```

A ready-made `android/app/build.gradle.kts` that reads `key.properties`
and signs the release build is already in this project. Back up
`upload-keystore.jks` + the passwords somewhere safe — they are this app's
permanent Play Store identity.

## 3. Get packages and run

```
flutter pub get
flutter analyze        # should be clean
flutter test           # all engine tests should pass
flutter run            # debug on your phone
```

## 4. Release build

```
flutter build appbundle --release
```

The `.aab` lands in `build\app\outputs\bundle\release\`.

## Notes

- Package id: `com.rocky.tilewise`, app name: `TileWise`, version `1.0.0+1`.
- The dictionary (`assets/words.txt`, ~359k words) is bundled — the game is
  100% offline, no internet permission needed.
- Sounds in `assets/sounds/` are synthesized by `tooling/make_sounds.py`
  (zero licensing issues). Re-run the script any time to regenerate them.
- The computer opponent runs in a background isolate, so the UI never
  freezes while it thinks.
