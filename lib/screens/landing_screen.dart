import 'dart:math';
import 'package:flutter/material.dart';
import '../main.dart';
import 'count_input_screen.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 40, end: 0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Animated background orbs
          ...List.generate(5, (i) => _buildOrb(i)),
          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: AnimatedBuilder(
                animation: _fadeAnim,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnim.value,
                    child: Transform.translate(
                      offset: Offset(0, _slideAnim.value),
                      child: child,
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Icon
                      Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                              blurRadius: 30,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.grid_view_rounded,
                            size: 44, color: Colors.white),
                      ),
                      const SizedBox(height: 32),
                      // Title
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                        ).createShader(bounds),
                        child: const Text(
                          'Mosaic Maker',
                          style: TextStyle(
                            fontSize: 38,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Transform your photos into\nstunning text mosaics',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.5),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 56),
                      // Start button
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final scale =
                              1.0 + (_pulseController.value * 0.03);
                          return Transform.scale(scale: scale, child: child);
                        },
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                                context, createFadeRoute(const CountInputScreen()));
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF8B5CF6), Color(0xFFD946EF)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5CF6)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 24,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Text(
                              'Get Started',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrb(int index) {
    final rng = Random(index * 42);
    final size = 150.0 + rng.nextDouble() * 200;
    final top = rng.nextDouble() * 800 - 100;
    final left = rng.nextDouble() * 500 - 100;
    final colors = [
      [const Color(0xFF8B5CF6), const Color(0xFF6D28D9)],
      [const Color(0xFFD946EF), const Color(0xFFA855F7)],
      [const Color(0xFF06B6D4), const Color(0xFF0284C7)],
      [const Color(0xFFEC4899), const Color(0xFFBE185D)],
      [const Color(0xFF8B5CF6), const Color(0xFFD946EF)],
    ];

    return Positioned(
      top: top,
      left: left,
      child: AnimatedBuilder(
        animation: _pulseController,
        builder: (context, child) {
          final offset = sin(_pulseController.value * pi * 2 + index) * 10;
          return Transform.translate(
            offset: Offset(offset, offset * 0.5),
            child: child,
          );
        },
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                colors[index][0].withValues(alpha: 0.12),
                colors[index][1].withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
