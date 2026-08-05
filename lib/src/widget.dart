import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ScrambleTextCycler
// ─────────────────────────────────────────────────────────────────────────────

/// Default scramble character pool.
const _kDefaultScrambleChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#\$%^&*<>[]{}';

/// A widget that cycles through [words], showing a rapid character-scramble
/// transition before locking each letter in progressively left-to-right.
///
/// ### Sequence per word
/// 1. **Hold** — displays the current word for [displayDuration].
/// 2. **Scramble** — random characters flash in sync with the display's refresh
///    rate for [scrambleDuration]; characters settle left-to-right following the
///    [scrambleCurve] easing function.
/// 3. Snaps to the next word and repeats in a loop.
///
/// ### Multi-line strings
/// Strings may contain `\n` to produce multiple lines. Newline characters are
/// treated as structural markers and are **never** scrambled — the line grid
/// is stable throughout the entire transition. Use a monospace font and set
/// `TextStyle.height` for consistent line spacing across words.
///
/// ### Stable height with mixed line counts
/// Set [maxLines] when entries have different numbers of lines. Words with
/// fewer lines are padded with empty trailing lines; words with more are
/// truncated. Either way every entry occupies the same vertical space, so
/// the widget height never shifts mid-cycle.
///
/// ```dart
/// ScrambleTextCycler(
///   words: [
///     'Build fast.\nShip faster.\nStay sharp.', // 3 lines
///     'Write once.\nRun anywhere.',              // 2 lines — padded to 3
///     'Act now.',                                // 1 line  — padded to 3
///   ],
///   maxLines: 3,
///   textStyle: TextStyle(fontFamily: 'monospace', fontSize: 24, height: 1.6),
/// )
/// ```
///
/// ### Single-line example
/// ```dart
/// ScrambleTextCycler(
///   words: ['Flutter', 'is', 'awesome'],
///   textStyle: TextStyle(fontSize: 32, fontFamily: 'monospace'),
/// )
/// ```
class ScrambleTextCycler extends StatefulWidget {
  /// The list of strings to cycle through. Must not be empty.
  final List<String> words;

  /// How long each word is displayed before the scramble begins.
  /// Defaults to 1 second.
  final Duration displayDuration;

  /// Total duration of the scramble animation between words.
  /// Defaults to 500 ms.
  final Duration scrambleDuration;

  /// How frequently the scramble characters update.
  /// Lower = faster chaos. Defaults to 45 ms.
  ///
  /// **Note**: The animation is driven by the display's vsync signal for
  /// smoothness. This interval controls *visual randomisation cadence* —
  /// the scramble glyphs change at most once per [scrambleTickInterval]
  /// rather than every single frame, which preserves the staccato aesthetic.
  final Duration scrambleTickInterval;

  /// Characters used during the scramble phase.
  /// Defaults to alphanumeric + symbols.
  final String scrambleChars;

  /// When set, every word is normalised to exactly this many lines:
  ///
  /// - **Fewer lines than [maxLines]**: padded with empty trailing lines so
  ///   the widget height stays constant across all entries.
  /// - **More lines than [maxLines]**: truncated at line [maxLines]; the
  ///   remainder is silently discarded.
  ///
  /// Leave `null` (the default) when all entries have the same line count
  /// and no clamping is needed.
  final int? maxLines;

  /// Easing curve applied to the character lock-in progression.
  ///
  /// Characters settle left-to-right following this curve, so an
  /// ease-in-out curve causes them to settle slowly at first, accelerate
  /// through the middle, and decelerate at the end — which looks natural.
  ///
  /// Defaults to [Curves.easeInOut].
  final Curve scrambleCurve;

  /// Text style applied to the displayed text.
  /// Falls back to a monospace 24 sp style if not provided.
  final TextStyle? textStyle;

  const ScrambleTextCycler({
    super.key,
    required this.words,
    this.displayDuration = const Duration(seconds: 1),
    this.scrambleDuration = const Duration(milliseconds: 500),
    this.scrambleTickInterval = const Duration(milliseconds: 45),
    this.scrambleChars = _kDefaultScrambleChars,
    this.maxLines,
    this.scrambleCurve = Curves.easeInOut,
    this.textStyle,
  });

  @override
  State<ScrambleTextCycler> createState() => _ScrambleTextCyclerState();
}

class _ScrambleTextCyclerState extends State<ScrambleTextCycler>
    with SingleTickerProviderStateMixin {
  final _rng = Random();

  int _currentIndex = 0;
  String _displayText = '';

  // ── Animation machinery ──────────────────────────────────────────────────
  late final AnimationController _controller;
  Timer? _holdTimer;

  // ── Per-scramble state (set once in _beginScramble, reused every frame) ──
  String _scrambleSource = ''; // normalised old word (the word we're leaving)
  String _scrambleTarget = ''; // normalised new word (the word we're going to)
  List<int> _scramblable = const []; // indices into _paddedTarget that may scramble
  late List<int> _buffer; // mutable codeunit buffer, reused across frames
  String _paddedTarget = ''; // target padded to max-width with spaces
  int _paddedLength = 0; // length of the padded target

  // Throttle: track the last tick time so we only regenerate random glyphs
  // at the user-specified cadence, not every vsync frame.
  Duration _lastTickElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addListener(_onFrame);
    _controller.addStatusListener(_onAnimationStatus);

    if (widget.words.isEmpty) return;
    _displayText = _maybeNormalize(widget.words.first);
    _scheduleHold();
  }

  @override
  void didUpdateWidget(ScrambleTextCycler old) {
    super.didUpdateWidget(old);
    // If the word list or maxLines changes externally, reset cleanly.
    if (old.words != widget.words || old.maxLines != widget.maxLines) {
      _holdTimer?.cancel();
      _controller.stop();
      _currentIndex = 0;
      if (widget.words.isNotEmpty) {
        setState(() => _displayText = _maybeNormalize(widget.words.first));
        _scheduleHold();
      }
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ── Line normalisation ──────────────────────────────────────────────────────

  /// Returns [text] normalised so it always occupies exactly [n] lines.
  ///
  /// - Fewer lines → pads with empty trailing lines (height stays constant).
  /// - More lines  → truncates at line [n] (overflow discarded).
  /// - Equal       → returns [text] unchanged (no allocation).
  ///
  /// Empty padding lines contain no characters, so the scramble engine has
  /// nothing to randomise there — they appear as blank rows throughout the
  /// entire transition, which is exactly the right behaviour.
  static String _normalizeLines(String text, int n) {
    final lines = text.split('\n');
    if (lines.length == n) return text;
    if (lines.length > n) return lines.take(n).join('\n');
    return [...lines, ...List.filled(n - lines.length, '')].join('\n');
  }

  /// Applies [_normalizeLines] when [maxLines] is set; otherwise no-op.
  String _maybeNormalize(String text) {
    final n = widget.maxLines;
    return n == null ? text : _normalizeLines(text, n);
  }

  // ── Timing helpers ──────────────────────────────────────────────────────────

  /// Waits [displayDuration], then starts the scramble phase.
  void _scheduleHold() {
    _holdTimer = Timer(widget.displayDuration, _beginScramble);
  }

  /// Sets up the per-scramble state and kicks off the [AnimationController].
  ///
  /// ### Multi-line handling
  /// Newline characters (`\n`) in the target are **structural**, not content —
  /// they must never be replaced with a random glyph or the line grid collapses
  /// mid-animation. This method pre-computes the ordered list of
  /// *scramblable positions* (every index that is NOT a `\n`) and drives the
  /// lock-in counter over that list only. Newline codepoints pass through
  /// unchanged on every tick, so the layout is perfectly stable throughout
  /// the transition regardless of how many lines the target string has.
  ///
  /// ### Width-stable transitions
  /// When the source and target have different lengths, the shorter one is
  /// space-padded to match the longer. This prevents an abrupt width jump on
  /// the first frame. As the animation progresses, trailing spaces that exceed
  /// the target length lock in and are trimmed on the final frame when the
  /// display snaps to the exact target string.
  void _beginScramble() {
    if (!mounted || widget.words.isEmpty) return;

    final nextIndex = (_currentIndex + 1) % widget.words.length;
    _scrambleSource = _maybeNormalize(widget.words[_currentIndex]);
    _scrambleTarget = _maybeNormalize(widget.words[nextIndex]);

    // ── Width-stable padding ──────────────────────────────────────────────
    // Pad the shorter string (on each line) so both occupy the same width.
    _paddedTarget = _padToMatch(_scrambleTarget, _scrambleSource);
    final paddedSource = _padToMatch(_scrambleSource, _scrambleTarget);
    _paddedLength = _paddedTarget.length;

    // Build the ordered list of indices that may be scrambled.
    // \n positions are intentionally excluded — they will always emit their
    // real codepoint, keeping the line structure intact from tick 1.
    _scramblable = <int>[
      for (int i = 0; i < _paddedLength; i++)
        if (_paddedTarget[i] != '\n' && (i < paddedSource.length ? paddedSource[i] != '\n' : true)) i,
    ];

    // Pre-allocate the mutable buffer once. We'll mutate it in-place on each
    // frame instead of allocating a new List<int> every vsync.
    _buffer = paddedSource.codeUnits.toList();

    // Reset throttle state.
    _lastTickElapsed = Duration.zero;

    // Configure and start the animation controller.
    _controller.duration = widget.scrambleDuration;
    _controller.forward(from: 0.0);
  }

  // ── Per-frame update (vsync-driven) ─────────────────────────────────────────

  /// Called on every vsync frame while the [AnimationController] is running.
  ///
  /// The scramble glyphs are only regenerated when enough time has elapsed
  /// since the last regeneration (governed by [scrambleTickInterval]). On
  /// in-between frames we still call [setState] with the latest lock-in count
  /// so the progression stays silky-smooth, but the random characters hold
  /// steady, preserving the staccato "hacker terminal" aesthetic.
  void _onFrame() {
    if (!mounted) return;

    final pool = widget.scrambleChars;
    final totalScramblable = _scramblable.length;

    // Apply easing curve to the raw linear progress.
    final double curvedProgress = widget.scrambleCurve.transform(_controller.value);
    final int lockedCount = (curvedProgress * totalScramblable).floor();

    // Determine whether we should regenerate random glyphs this frame.
    final elapsed = _controller.lastElapsedDuration ?? Duration.zero;
    final shouldRegenerateRandoms =
        (elapsed - _lastTickElapsed) >= widget.scrambleTickInterval;
    if (shouldRegenerateRandoms) {
      _lastTickElapsed = elapsed;
    }

    // ── Fill the buffer ────────────────────────────────────────────────────
    // Locked positions  → target character
    // Unlocked positions → random glyph (only regenerated on tick boundaries)
    // \n positions       → always '\n'
    for (int si = 0; si < totalScramblable; si++) {
      final idx = _scramblable[si];
      if (si < lockedCount) {
        // Locked: emit the target character (or space if beyond target length).
        _buffer[idx] = idx < _paddedLength
            ? _paddedTarget.codeUnitAt(idx)
            : 0x20; // space
      } else if (shouldRegenerateRandoms) {
        // Still chaotic: emit a fresh random character.
        _buffer[idx] = pool.codeUnitAt(_rng.nextInt(pool.length));
      }
      // else: keep the previous random glyph (no-op, buffer already holds it)
    }

    setState(() => _displayText = String.fromCharCodes(_buffer));
  }

  /// Called when the [AnimationController] completes (reaches 1.0).
  void _onAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    if (!mounted) return;

    final nextIndex = (_currentIndex + 1) % widget.words.length;
    setState(() {
      // Snap to the exact target string — no padding, no scramble artifacts.
      _displayText = _scrambleTarget;
      _currentIndex = nextIndex;
    });
    _scheduleHold();
  }

  // ── Width-stable padding helper ──────────────────────────────────────────────

  /// Pads [text] with trailing spaces on each line so it is at least as wide
  /// as the corresponding line in [reference].
  ///
  /// For single-line strings this simply pads to `max(text.length, ref.length)`.
  /// For multi-line strings each line is padded independently, so per-line
  /// widths stay stable even when individual lines differ in length.
  static String _padToMatch(String text, String reference) {
    final textLines = text.split('\n');
    final refLines = reference.split('\n');

    // Fast path: single-line strings.
    if (textLines.length == 1 && refLines.length == 1) {
      final maxLen = max(text.length, reference.length);
      return text.padRight(maxLen);
    }

    final maxLineCount = max(textLines.length, refLines.length);
    final buf = StringBuffer();
    for (int i = 0; i < maxLineCount; i++) {
      if (i > 0) buf.write('\n');
      final tLine = i < textLines.length ? textLines[i] : '';
      final rLine = i < refLines.length ? refLines[i] : '';
      buf.write(tLine.padRight(max(tLine.length, rLine.length)));
    }
    return buf.toString();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Text(
      _displayText,
      // overflow.clip is a last-resort safety net. With maxLines set,
      // normalisation should prevent overflow entirely; without it the
      // caller is responsible for giving the widget enough space.
      overflow: TextOverflow.clip,
      style: widget.textStyle ?? const TextStyle(fontFamily: 'monospace', fontSize: 24),
    );
  }
}
