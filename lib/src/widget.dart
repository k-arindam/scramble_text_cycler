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
/// 2. **Scramble** — random characters flash at [scrambleTickInterval]
///    intervals for [scrambleDuration]; characters settle left-to-right.
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
    this.textStyle,
  });

  @override
  State<ScrambleTextCycler> createState() => _ScrambleTextCyclerState();
}

class _ScrambleTextCyclerState extends State<ScrambleTextCycler> {
  final _rng = Random();

  int _currentIndex = 0;
  String _displayText = '';

  Timer? _holdTimer;
  Timer? _scrambleTimer;

  @override
  void initState() {
    super.initState();
    if (widget.words.isEmpty) return;
    _displayText = _maybeNormalize(widget.words.first);
    _scheduleTransition();
  }

  @override
  void didUpdateWidget(ScrambleTextCycler old) {
    super.didUpdateWidget(old);
    // If the word list or maxLines changes externally, reset cleanly.
    if (old.words != widget.words || old.maxLines != widget.maxLines) {
      _holdTimer?.cancel();
      _scrambleTimer?.cancel();
      _currentIndex = 0;
      if (widget.words.isNotEmpty) {
        setState(() => _displayText = _maybeNormalize(widget.words.first));
        _scheduleTransition();
      }
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _scrambleTimer?.cancel();
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
  void _scheduleTransition() {
    _holdTimer = Timer(widget.displayDuration, _beginScramble);
  }

  /// Animates a character-by-character scramble toward the next word,
  /// then schedules the next transition.
  ///
  /// ### Multi-line handling
  /// Newline characters (`\n`) in the target are **structural**, not content —
  /// they must never be replaced with a random glyph or the line grid collapses
  /// mid-animation. This method pre-computes the ordered list of
  /// *scramblable positions* (every index that is NOT a `\n`) and drives the
  /// lock-in counter over that list only. Newline codepoints pass through
  /// unchanged on every tick, so the layout is perfectly stable throughout
  /// the transition regardless of how many lines the target string has.
  void _beginScramble() {
    final nextIndex = (_currentIndex + 1) % widget.words.length;
    // Normalise BEFORE computing scramblable indices so that padded \n
    // positions are already baked into `target` and excluded from scrambling.
    final target = _maybeNormalize(widget.words[nextIndex]);
    final pool = widget.scrambleChars;

    // Build the ordered list of indices that may be scrambled.
    // \n positions are intentionally excluded — they will always emit their
    // real codepoint, keeping the line structure intact from tick 1.
    final scramblable = <int>[
      for (int i = 0; i < target.length; i++)
        if (target[i] != '\n') i,
    ];
    final totalScramblable = scramblable.length;

    int tick = 0;
    final totalTicks = (widget.scrambleDuration.inMilliseconds / widget.scrambleTickInterval.inMilliseconds)
        .ceil()
        .clamp(1, 9999);

    _scrambleTimer = Timer.periodic(widget.scrambleTickInterval, (timer) {
      tick++;

      // ── Final tick: snap to the normalised word and start the next cycle ──
      if (tick >= totalTicks) {
        timer.cancel();
        if (!mounted) return;
        setState(() {
          _displayText = target; // already normalised above
          _currentIndex = nextIndex;
        });
        _scheduleTransition();
        return;
      }

      // ── Intermediate ticks ──────────────────────────────────────────────
      //
      // `lockedCount` grows from 0 → totalScramblable over the animation.
      // scramblable[0..lockedCount-1] → settled (emit target char)
      // scramblable[lockedCount..]    → still chaotic (emit random char)
      // any \n index                  → always emit '\n'
      final double progress = tick / totalTicks;
      final int lockedCount = (progress * totalScramblable).floor();

      // Start from a mutable copy of the target's codepoints.
      // \n positions are already correct; we only overwrite the unscrambled
      // non-newline positions with random chars from the pool.
      final codes = target.codeUnits.toList();
      for (int si = lockedCount; si < totalScramblable; si++) {
        codes[scramblable[si]] = pool.codeUnitAt(_rng.nextInt(pool.length));
      }

      if (!mounted) return;
      setState(() => _displayText = String.fromCharCodes(codes));
    });
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
