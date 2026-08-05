# Changelog

All notable changes to this project will be documented in this file.

## 1.0.0

### 🎉 Initial Release

- **`ScrambleTextCycler` widget** — cycles through a list of strings with a character-scramble transition that settles left-to-right.
- **Vsync-synchronized animation** — powered by `AnimationController` and `Ticker` for smooth, jank-free 60 fps+ rendering.
- **Easing curves** — configurable `scrambleCurve` (defaults to `Curves.easeInOut`) for natural-feeling lock-in progression.
- **Multi-line support** — embed `\n` in strings for multi-line layouts; newline characters are structural and never scrambled.
- **Stable height** — `maxLines` parameter pads shorter entries with empty trailing lines so the widget height stays constant across all entries.
- **Custom character pool** — `scrambleChars` parameter lets you swap the default alphanumeric+symbols pool for anything (binary `01`, katakana, emoji, etc.).
- **Width-stable transitions** — shorter words are space-padded during scramble to prevent abrupt width jumps.
- **Zero runtime dependencies** — only depends on the Flutter SDK.
