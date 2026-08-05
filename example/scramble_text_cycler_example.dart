import 'package:flutter/material.dart';
import 'package:scramble_text_cycler/scramble_text_cycler.dart';

void main() => runApp(const _ScrambleDemo());

class _ScrambleDemo extends StatelessWidget {
  const _ScrambleDemo();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(debugShowCheckedModeBanner: false, theme: ThemeData.dark(), home: const _DemoPage());
  }
}

class _DemoPage extends StatelessWidget {
  const _DemoPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1117),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Single-line demo ────────────────────────────────────────────
              const Text(
                'We craft',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 18, letterSpacing: 3, fontFamily: 'monospace'),
              ),
              const SizedBox(height: 6),
              ScrambleTextCycler(
                words: const ['Flutter Apps', 'Swift Packages', 'gRPC Services', 'Great Products'],
                displayDuration: const Duration(milliseconds: 1200),
                scrambleDuration: const Duration(milliseconds: 600),
                scrambleTickInterval: const Duration(milliseconds: 40),
                scrambleCurve: Curves.easeInOut,
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 38,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF58A6FF),
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 36),
              const Divider(color: Color(0xFF21262D)),
              const SizedBox(height: 24),

              // ── Multi-line + maxLines demo ──────────────────────────────────
              // Words have 1, 2, or 3 lines. maxLines: 3 pads shorter entries
              // with empty trailing lines so the widget height never changes.
              const Text(
                'Multi-line, mixed counts (maxLines: 3):',
                style: TextStyle(color: Color(0xFF8B949E), fontSize: 13),
              ),
              const SizedBox(height: 10),
              ScrambleTextCycler(
                words: const [
                  'Build fast.\nShip faster.\nStay sharp.', // 3 lines
                  'Write once.\nRun anywhere.', // 2 lines → padded
                  'Act now.', // 1 line  → padded
                ],
                maxLines: 3,
                displayDuration: const Duration(milliseconds: 1400),
                scrambleDuration: const Duration(milliseconds: 700),
                scrambleTickInterval: const Duration(milliseconds: 40),
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFE6EDF3),
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 32),
              const Divider(color: Color(0xFF21262D)),
              const SizedBox(height: 24),

              // ── Binary / single-line custom chars ───────────────────────────
              const Text('Binary pool, shorter cadence:', style: TextStyle(color: Color(0xFF8B949E), fontSize: 13)),
              const SizedBox(height: 8),
              ScrambleTextCycler(
                words: const ['ERROR', 'RETRY', 'OK', 'WAIT'],
                scrambleChars: r'01',
                displayDuration: const Duration(milliseconds: 800),
                scrambleDuration: const Duration(milliseconds: 350),
                scrambleTickInterval: const Duration(milliseconds: 30),
                textStyle: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 22,
                  color: Color(0xFF3FB950),
                  letterSpacing: 4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
