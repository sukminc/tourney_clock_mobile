# Tourney Clock Mobile

A simple and intuitive timer app designed for tournament play, built with Flutter.

## Features

- Easy-to-use timer interface
- Customizable timer settings
- Sound notifications
- Pause, resume, and reset functionality
- Supports multiple platforms (iOS, Android, macOS)

## Tech

- Flutter
- Dart

## Project Structure

```
/lib
  /models        # Data models
  /screens       # UI Screens
  /widgets       # Reusable widgets
  /services      # Business logic and services
/assets
  /sounds        # Audio files
```

## Prerequisites

- Flutter SDK installed
- Dart SDK installed
- Compatible IDE (VSCode, Android Studio, etc.)

## Getting Started

1. Clone the repository:
   ```
   git clone https://github.com/chrisyoon/tourney_clock_mobile.git
   ```
2. Navigate to the project directory:
   ```
   cd tourney_clock_mobile
   ```
3. Get dependencies:
   ```
   flutter pub get
   ```
4. Run the app:
   ```
   flutter run
   ```

## Sounds

The app uses custom sound files located in the `/assets/sounds` directory. These sounds play on timer events like start, pause, and end.

## Using the App

- Set your desired timer duration.
- Start the timer to begin counting down.
- Use pause and resume controls as needed.
- Reset the timer to start over.

## Common Commands

- `flutter run` - Run the app on connected device or emulator
- `flutter build` - Build the app for release
- `flutter analyze` - Analyze the project for issues
- `flutter test` - Run tests

## Troubleshooting

- Ensure Flutter and Dart SDKs are properly installed and configured.
- Run `flutter clean` if you encounter build issues.
- Check for dependency conflicts in `pubspec.yaml`.

## Roadmap

- Add support for multiple timers
- Implement customizable themes
- Add notification integration

## Contributing

Contributions are welcome! Please open an issue or submit a pull request.

## License

This project is licensed under the MIT License. See the LICENSE file for details.