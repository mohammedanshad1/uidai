import 'package:flutter/material.dart';

class AuthSuccessScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback? onContinue;

  const AuthSuccessScreen({
    super.key,
    this.title = 'Authentication successful',
    this.subtitle = 'The capture completed successfully and the result is ready for cloud matching.',
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF07131E), Color(0xFF10314A), Color(0xFF0A1C2D)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 112,
                  height: 112,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: Colors.greenAccent.withOpacity(0.35)),
                  ),
                  child: const Icon(Icons.check_circle_rounded, size: 62, color: Colors.greenAccent),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.76),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onContinue ?? () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: const Text('Continue'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
