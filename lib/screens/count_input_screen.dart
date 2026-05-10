import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import 'name_input_screen.dart';

class CountInputScreen extends StatefulWidget {
  const CountInputScreen({super.key});

  @override
  State<CountInputScreen> createState() => _CountInputScreenState();
}

class _CountInputScreenState extends State<CountInputScreen>
    with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _next() {
    final count = int.tryParse(_controller.text.trim());
    if (count == null || count < 1 || count > 500) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Enter a number between 1 and 500'),
          backgroundColor: const Color(0xFF8B5CF6),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }
    Navigator.push(context, createFadeRoute(NameInputScreen(imageCount: count)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                _buildBackAndStep(context, 1),
                const SizedBox(height: 60),
                // Heading
                const Text(
                  'How many\nimages?',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enter the total number of images\nyou want in your mosaic',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.white.withValues(alpha: 0.45),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 40),
                // Input
                TextField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                  decoration: const InputDecoration(
                    hintText: '50',
                  ),
                  onSubmitted: (_) => _next(),
                ),
                const SizedBox(height: 100),
                // Next button
                _buildNextButton(_next),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Shared widgets for step screens
Widget _buildBackAndStep(BuildContext context, int step) {
  return Row(
    children: [
      GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Colors.white.withValues(alpha: 0.06),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: const Icon(Icons.arrow_back_rounded,
              color: Colors.white70, size: 20),
        ),
      ),
      const Spacer(),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
          border: Border.all(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
        ),
        child: Text(
          'Step $step of 3',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF8B5CF6),
          ),
        ),
      ),
    ],
  );
}

Widget _buildNextButton(VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
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
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Continue',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          SizedBox(width: 8),
          Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
        ],
      ),
    ),
  );
}
