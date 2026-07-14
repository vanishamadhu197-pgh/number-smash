Place your sound effect files here (MP3/OGG/WAV). Recommended filenames used by the app:

- start.mp3   # played when a roll starts
- win.mp3     # played on a win
- lose.mp3    # played on a regular loss
- close.mp3   # played on a close miss
- select.mp3  # played when selecting a level

After adding files, run:

```bash
flutter pub get
flutter run -d chrome
```

Note: Web browsers may block autoplay until user interaction occurs. Sounds should play after user taps/clicks.
