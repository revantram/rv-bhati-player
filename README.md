# RV Bhati Player - Setup Guide

Package: `com.rvbhati.player`  |  App name: **RV Bhati Player**

## Project structure

```
pubspec.yaml
.github/workflows/build.yml        <- APK build (GitHub Actions)
android_overrides/
  AndroidManifest.xml              <- permissions + background audio service
  MainActivity.kt                  <- package com.rvbhati.player
assets/icon/app_icon.png           <- placeholder icon (apna 1024x1024 PNG se replace karein)
lib/
  main.dart
  models/media_file.dart
  services/media_scanner.dart      <- permissions + .mp4/.mkv/.mp3 scan
  services/audio_controller.dart   <- single global audio player (background play)
  widgets/liquid_glass_container.dart  <- LiquidGlassContainer + LiquidGlassButton
  widgets/liquid_background.dart
  widgets/glass_bars.dart          <- floating top capsule + bottom nav capsule
  widgets/glass_seek_bar.dart
  widgets/art_box.dart
  utils/format.dart
  screens/home_screen.dart
  screens/video_player_screen.dart
  screens/audio_player_screen.dart
```

`android/` folder repo me nahi hai. GitHub Actions usse khud generate karta hai
(`flutter create`) aur `android_overrides/` wali files lagakar package name
`com.rvbhati.player` set kar deta hai.

## Custom app icon (flutter_launcher_icons)

1. Apna icon **1024x1024 PNG** banayein aur `assets/icon/app_icon.png` se replace karein.
2. `pubspec.yaml` me config pehle se hai:
   ```yaml
   flutter_launcher_icons:
     android: true
     ios: false
     image_path: "assets/icon/app_icon.png"
     min_sdk_android: 21
     adaptive_icon_background: "#0B0F1E"
     adaptive_icon_foreground: "assets/icon/app_icon.png"
   ```
3. PC par ho to: `dart run flutter_launcher_icons`
4. Mobile/GitHub Actions par: kuch nahi karna, workflow khud chalata hai.

Tip: adaptive icon me edges crop ho sakte hain, isliye logo ko center ke ~66% area me rakhein.

## Bina PC ke APK banana (sirf mobile se)

**Step 1 - Repo banayein**
GitHub (browser ya app) me naya repository banayein, e.g. `rv-bhati-player`.

**Step 2 - Files upload karein (sabse aasan tarika)**
1. Repo me **Add file -> Upload files** se `project.zip` upload karein (root me), commit karein.
2. Phir **Add file -> Create new file**, naam me yeh path likhein:
   `.github/workflows/build.yml`
   (slash type karte hi folders ban jaate hain) aur `build.yml` ka poora text paste karke commit karein.

Workflow `project.zip` ko khud unzip karke poora project taiyar kar leta hai.
(Agar aap sabhi files alag-alag upload/create karna chahein to bhi chalega - zip optional hai.)

**Step 3 - Build dekhein**
Repo ke **Actions** tab me "Build RV Bhati Player APK" chalega (~5-8 min).
Khatam hone par run kholein -> neeche **Artifacts** me `RV-Bhati-Player-APK` download karein,
zip kholkar `app-release.apk` install karein
(Settings me "Install unknown apps" allow karna padega).

Dobara build: Actions -> workflow -> **Run workflow**.

## Notes / limitations

- **Permissions**: Android 13+ par READ_MEDIA_VIDEO + READ_MEDIA_AUDIO, Android 12 aur purane par READ_EXTERNAL_STORAGE. Notification permission background-audio notification ke liye maangi jaati hai.
- **Background audio**: sirf MP3 (just_audio_background). Notification + lock-screen controls milte hain. Video app minimize par pause ho jata hai.
- **Album art**: MP3 ke andar ka embedded cover read nahi hota; har song ka colourful generated cover + blurred reflection dikhta hai. Real cover ke liye baad me ek metadata plugin add kiya ja sakta hai.
- **Performance**: har glass card me BackdropFilter (blur 15) hai. Bahut purane phone par lambi list me scroll thoda heavy ho sakta hai; `LiquidGlassContainer(blur: ...)` kam kar sakte hain.
- **MKV**: playback ExoPlayer par hota hai; kuch rare codecs (jaise kuch DTS/HEVC combos) kuch devices par support nahi honge.
- `chewie` use nahi kiya: saare controls custom Liquid Glass hain, isliye zarurat nahi thi.
- APK debug key se sign hota hai (personal use ke liye theek). Play Store ke liye release keystore chahiye.
