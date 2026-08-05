# scramble_text_cycler

**A hacker-terminal-style text scramble animation widget for Flutter.**

[![pub version](https://img.shields.io/pub/v/scramble_text_cycler.svg)](https://pub.dev/packages/scramble_text_cycler)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![flutter](https://img.shields.io/badge/flutter-%E2%89%A51.17-blue.svg)](https://flutter.dev)

Cycle through a list of strings with characters that scramble randomly, then lock in left-to-right — like a Hollywood terminal cracking a password. Vsync-driven, zero-dependency, and buttery smooth.

---

## Demo

<p align="center">
  <img src="https://raw.githubusercontent.com/k-arindam/scramble_text_cycler/main/media/demo.gif" alt="ScrambleTextCycler demo" width="400" />
</p>

---

## Features

- 🎬 **Scramble → lock-in animation** — characters randomise then settle left-to-right into the next word
- ⚡ **Vsync-synchronised** — uses `AnimationController`, not `Timer.periodic`, for silky 60 fps+
- 📐 **Width-stable transitions** — shorter words are space-padded during scramble to prevent layout popping
- 📝 **Multi-line support** — newlines are structural and never scrambled; use `maxLines` for stable height
- 🎛️ **Fully configurable** — custom character pool, easing curve, timing, and text style
- 📦 **Zero runtime dependencies** — only the Flutter SDK

---

## Installation

```bash
flutter pub add scramble_text_cycler
```

---

## Quick Start

```dart
import 'package:scramble_text_cycler/scramble_text_cycler.dart';

ScrambleTextCycler(words: const ['Flutter', 'Dart', 'Widgets'])
```

Drop it into any widget tree and it starts cycling immediately.

---

## Examples

### Single-line cycling

```dart
ScrambleTextCycler(
  words: const ['Hello', 'World', 'Flutter'],
  displayDuration: const Duration(seconds: 2),
  scrambleDuration: const Duration(milliseconds: 600),
  textStyle: const TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: Colors.white,
    fontFamily: 'monospace',
  ),
)
```

### Multi-line with stable height

Use `\n` for line breaks and set `maxLines` to keep layout height consistent across entries with different line counts.

```dart
ScrambleTextCycler(
  words: const [
    'Line one\nLine two',
    'Single line',
    'Three\nseparate\nlines',
  ],
  maxLines: 3,
  textStyle: const TextStyle(fontSize: 20, fontFamily: 'monospace'),
)
```

### Custom character pool

Use a binary character pool for a data-stream aesthetic.

```dart
ScrambleTextCycler(
  words: const ['ENCRYPT', 'DECRYPT', 'TRANSMIT'],
  scrambleChars: '01',
  scrambleDuration: const Duration(milliseconds: 800),
  scrambleCurve: Curves.easeOut,
)
```

---

## API Reference

| Parameter | Type | Default | Description |
|---|---|---|---|
| `words` | `List<String>` | **required** | Strings to cycle through. |
| `displayDuration` | `Duration` | `1 s` | How long each word is held before the next scramble begins. |
| `scrambleDuration` | `Duration` | `500 ms` | Total duration of the scramble → lock-in animation. |
| `scrambleTickInterval` | `Duration` | `45 ms` | Visual randomisation cadence — how often scramble characters refresh. |
| `scrambleChars` | `String` | `A-Z a-z 0-9 !@#…` | Character pool from which scramble glyphs are drawn. |
| `maxLines` | `int?` | `null` | Normalise all entries to this many lines for stable height. |
| `scrambleCurve` | `Curve` | `Curves.easeInOut` | Easing curve that controls the left-to-right lock-in progression. |
| `textStyle` | `TextStyle?` | monospace 24 sp | Text style applied to the rendered string. |

---

## How It Works

The widget runs a continuous **hold → scramble → snap → repeat** loop driven by a single `AnimationController`. During the scramble phase, an easing curve determines how many characters (left-to-right) have "locked in" to their target values; unlocked positions are filled with random glyphs from the `scrambleChars` pool on each tick. Shorter words are space-padded to the length of the longer word during transition, so the layout width stays rock-solid. Once every character has locked in, the widget snaps to the final string, holds for `displayDuration`, and advances to the next word.

---

## Contributing

Contributions are welcome! Please open an [issue](https://github.com/k-arindam/scramble_text_cycler/issues) or submit a [pull request](https://github.com/k-arindam/scramble_text_cycler/pulls) on GitHub.

---

## License

MIT — see the [LICENSE](LICENSE) file for details.
