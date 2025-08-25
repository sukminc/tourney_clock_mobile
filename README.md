# Tourney Clock Mobile — Step‑by‑Step Guide

A simple Flutter app to run a poker tournament clock. This document provides a **complete step‑by‑step guide** (development, execution, build, troubleshooting).

---

## 🧭 Quick Start (5 Steps)
1. Install **Flutter** and run `flutter doctor` until all checks pass.
2. Clone the repository → `cd tourney_clock_mobile`
3. Run `flutter pub get`
4. (Optional) Verify sound assets path
5. Run `flutter run` (on emulator or physical device)

---

## 0) Prerequisites
- **Flutter SDK** (3.x recommended) and **Dart SDK**
- **Git**
- IDE: VS Code or Android Studio
- Platform tools:
  - **Android**: Android Studio + Android SDK + AVD (emulator) or a real device with developer mode enabled
  - **iOS (macOS only)**: Xcode (CocoaPods may be required)

Check your setup:
```bash
flutter doctor
```
All items should be ✅ before continuing.

---

## 1) Clone the Project
```bash
git clone https://github.com/chrisyoon/tourney_clock_mobile.git
cd tourney_clock_mobile
```

---

## 2) Install Dependencies
```bash
flutter pub get
```

---

## 3) Verify Asset Configuration
The app uses sound files in `/assets/sounds`. Ensure `pubspec.yaml` includes:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/sounds/
```
> Skip this if already configured.

---

## 4) Prepare a Target Device
### Android
- Create and start an emulator from Android Studio’s **AVD Manager**  
- Or connect a real device with **USB debugging** enabled

### iOS (macOS only)
- Start an iOS Simulator from Xcode  
- Or connect a registered iOS device

List available devices:
```bash
flutter devices
```

---

## 5) Run the App
```bash
flutter run
```
- The first build may take several minutes
- If multiple devices are connected, Flutter will prompt you to choose

---

## 6) Using the App (Step‑by‑Step)
1. Launch the app → the main timer screen appears  
2. Select or set **blind levels** and **level duration**  
3. Tap **Start** to begin the countdown  
4. Tap **Pause/Resume** to control the timer  
5. Tap **Reset** to restore the current level’s full duration  
6. At the end of a level, the clock automatically advances to the next level  
7. Optional sounds/vibrations play for key events (start/pause/level change)

> MVP functionality: start/pause/reset, auto‑advance levels, simple alerts.

---

## 7) Project Structure
```
/lib
  /models        # Data models
  /screens       # UI screens
  /widgets       # Reusable widgets
  /services      # Business logic & services
/assets
  /sounds        # Audio files
```

---

## 8) Testing & Static Analysis
Run unit tests:
```bash
flutter test
```
Run static analysis:
```bash
flutter analyze
```

---

## 9) Build (Release)
### Android
- **APK build**
  ```bash
  flutter build apk --release
  ```
  Output: `build/app/outputs/flutter-apk/app-release.apk`

- **AAB build** (Play Store upload)
  ```bash
  flutter build appbundle --release
  ```
  Output: `build/app/outputs/bundle/release/app-release.aab`

### iOS (macOS only)
```bash
flutter build ipa --release
```
> Actual App Store/TestFlight distribution requires signing in Xcode.

---

## 10) Troubleshooting (Step‑by‑Step)
1. **Check SDK setup**
   ```bash
   flutter doctor -v
   ```
2. **Clean and reinstall dependencies**
   ```bash
   flutter clean && flutter pub get
   ```
3. **iOS CocoaPods issues** (macOS)
   ```bash
   cd ios && pod repo update && pod install && cd -
   ```
4. **Device not detected**
   - Confirm it appears in `flutter devices`
   - Android: check USB debugging, drivers, permissions
   - iOS: register the device and select it in Xcode
5. **Build extremely slow**
   - Restart emulator/IDE, disable unnecessary plugins
6. **Dependency conflicts**
   - Review `pubspec.yaml` version ranges, adjust conservatively

---

## 11) Common Commands (Summary)
- `flutter run` — Run the app
- `flutter build` — Build release
- `flutter analyze` — Static analysis
- `flutter test` — Run tests

---

## 12) Roadmap
- [ ] Multi‑timer support
- [ ] Customizable themes
- [ ] Local/system notifications
- [ ] Enhanced preset save/load UI
- [ ] Accessibility improvements (contrast/voice feedback)

---

## 13) Contributing
1. Open an issue  
2. Create a feature branch  
3. Submit a pull request  
4. Code review  
5. Merge  

Bug reports and feature requests are welcome!

---

## 14) License
MIT License. See the `LICENSE` file for details.