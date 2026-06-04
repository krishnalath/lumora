import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// Full-screen immersive crisis mode with guided breathing and
/// automatic escalation to an emergency helpline.
class CrisisModeScreen extends StatefulWidget {
  const CrisisModeScreen({super.key});

  @override
  State<CrisisModeScreen> createState() => _CrisisModeScreenState();
}

class _CrisisModeScreenState extends State<CrisisModeScreen>
    with TickerProviderStateMixin {
  // ── Breathing animation ──────────────────────────────────────
  late AnimationController _breathController;
  late Animation<double> _breathScale;

  // Breathing phases: inhale 4s → hold 4s → exhale 6s → hold 2s = 16s
  static const _inhaleDuration = 4;
  static const _holdAfterInhale = 4;
  static const _exhaleDuration = 6;
  static const _holdAfterExhale = 2;
  static const _totalCycleSeconds =
      _inhaleDuration + _holdAfterInhale + _exhaleDuration + _holdAfterExhale;

  String _phaseLabel = 'Breathe In';
  int _cycleCount = 0;

  int _elapsedSeconds = 0;
  Timer? _sessionTimer;
  bool _showEscalation = true; // Always show the slider immediately

  // ── Glow ring animation ──────────────────────────────────────
  late AnimationController _glowController;

  @override
  void initState() {
    super.initState();

    // Breathing animation — drives the circle scale
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _totalCycleSeconds),
    );

    // Custom tween: expand during inhale, hold, shrink during exhale, hold
    _breathScale = TweenSequence<double>([
      // Inhale: 0.6 → 1.0
      TweenSequenceItem(
        tween: Tween(begin: 0.6, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: _inhaleDuration.toDouble(),
      ),
      // Hold at 1.0
      TweenSequenceItem(
        tween: ConstantTween(1.0),
        weight: _holdAfterInhale.toDouble(),
      ),
      // Exhale: 1.0 → 0.6
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 0.6)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: _exhaleDuration.toDouble(),
      ),
      // Hold at 0.6
      TweenSequenceItem(
        tween: ConstantTween(0.6),
        weight: _holdAfterExhale.toDouble(),
      ),
    ]).animate(_breathController);

    _breathController.addListener(_updatePhaseLabel);
    _breathController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _cycleCount++;
        _breathController.forward(from: 0);
      }
    });

    // Glow ring
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Start everything
    _breathController.forward();
    _startSessionTimer();
  }

  void _updatePhaseLabel() {
    final progress = _breathController.value * _totalCycleSeconds;
    String newLabel;
    if (progress < _inhaleDuration) {
      newLabel = 'Breathe In';
    } else if (progress < _inhaleDuration + _holdAfterInhale) {
      newLabel = 'Hold';
    } else if (progress <
        _inhaleDuration + _holdAfterInhale + _exhaleDuration) {
      newLabel = 'Breathe Out';
    } else {
      newLabel = 'Hold';
    }
    if (newLabel != _phaseLabel && mounted) {
      setState(() => _phaseLabel = newLabel);
    }
  }

  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _elapsedSeconds++;
      });
    });
  }

  Future<void> _callHelpline() async {
    final Uri url = Uri.parse('tel:14416');
    if (!await launchUrl(url)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch dialer')),
        );
      }
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    _glowController.dispose();
    _sessionTimer?.cancel();
    super.dispose();
  }

  String _formatTime(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0F14),
      body: SafeArea(
        child: Stack(
          children: [
            // ── Background particles ──
            ...List.generate(12, (i) {
              final rng = Random(i);
              return Positioned(
                left: rng.nextDouble() * MediaQuery.of(context).size.width,
                top: rng.nextDouble() * MediaQuery.of(context).size.height,
                child: Container(
                  width: 4 + rng.nextDouble() * 4,
                  height: 4 + rng.nextDouble() * 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05 + rng.nextDouble() * 0.05),
                    shape: BoxShape.circle,
                  ),
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .fadeIn(duration: Duration(seconds: 2 + rng.nextInt(3)))
                    .fadeOut(duration: Duration(seconds: 2 + rng.nextInt(3))),
              );
            }),

            // ── Main content ──
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Timer
                  Text(
                    _formatTime(_elapsedSeconds),
                    style: GoogleFonts.outfit(
                      color: Colors.white24,
                      fontSize: 16,
                      letterSpacing: 4,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── Breathing circle ──
                  AnimatedBuilder(
                    animation: Listenable.merge([_breathScale, _glowController]),
                    builder: (context, child) {
                      final scale = _breathScale.value;
                      final glowOpacity = 0.15 + _glowController.value * 0.15;
                      return SizedBox(
                        width: 280,
                        height: 280,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer glow ring
                            Container(
                              width: 260 * scale,
                              height: 260 * scale,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF00E5FF)
                                      .withOpacity(glowOpacity),
                                  width: 2,
                                ),
                              ),
                            ),
                            // Second glow ring
                            Container(
                              width: 230 * scale,
                              height: 230 * scale,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF9B8CF0)
                                      .withOpacity(glowOpacity * 0.6),
                                  width: 1.5,
                                ),
                              ),
                            ),
                            // Main circle
                            Container(
                              width: 200 * scale,
                              height: 200 * scale,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    const Color(0xFF00E5FF).withOpacity(0.25),
                                    const Color(0xFF9B8CF0).withOpacity(0.15),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.6, 1.0],
                                ),
                              ),
                            ),
                            // Text layer overlaid on top
                            Text(
                              _phaseLabel,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // Cycle count
                  Text(
                    'Cycle $_cycleCount',
                    style: GoogleFonts.dmSans(
                      color: Colors.white30,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 60),

                  // ── Escalation section ──
                  if (_showEscalation) ...[
                    Text(
                      'Still feeling overwhelmed?',
                      style: GoogleFonts.outfit(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ).animate().fadeIn(duration: 600.ms),
                    const SizedBox(height: 16),
                    _EscalationSlider(onConfirm: _callHelpline),
                  ],

                  const SizedBox(height: 20),

                  // ── "I feel better" exit ──
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'I feel better',
                      style: GoogleFonts.dmSans(
                        color: const Color(0xFF00C9A7),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Back button ──
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white38, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A "slide to call" widget that appears after the escalation threshold.
class _EscalationSlider extends StatefulWidget {
  final VoidCallback onConfirm;
  const _EscalationSlider({required this.onConfirm});

  @override
  State<_EscalationSlider> createState() => _EscalationSliderState();
}

class _EscalationSliderState extends State<_EscalationSlider> {
  double _dragPosition = 0;
  static const _trackWidth = 260.0;
  static const _thumbSize = 56.0;
  bool _confirmed = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _trackWidth,
      height: _thumbSize,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_thumbSize / 2),
        color: Colors.redAccent.withOpacity(0.15),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Stack(
        children: [
          // Label
          Center(
            child: Text(
              _confirmed ? 'Calling...' : 'Slide to call 14416 →',
              style: GoogleFonts.dmSans(
                color: Colors.redAccent.withOpacity(0.7),
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          // Draggable thumb
          Positioned(
            left: _dragPosition,
            child: GestureDetector(
              onHorizontalDragUpdate: (details) {
                setState(() {
                  _dragPosition += details.delta.dx;
                  _dragPosition = _dragPosition.clamp(
                      0.0, _trackWidth - _thumbSize);
                });
              },
              onHorizontalDragEnd: (details) {
                if (_dragPosition >= _trackWidth - _thumbSize - 10) {
                  setState(() => _confirmed = true);
                  widget.onConfirm();
                } else {
                  setState(() => _dragPosition = 0);
                }
              },
              child: Container(
                width: _thumbSize,
                height: _thumbSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withOpacity(0.4),
                      blurRadius: 12,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.phone_in_talk,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 800.ms).slideY(begin: 0.3);
  }
}
