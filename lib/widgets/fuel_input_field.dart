import 'dart:math' as math;
import 'package:flutter/material.dart';

class FuelInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final TextInputAction? textInputAction;

  const FuelInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
    this.onFieldSubmitted,
    this.textInputAction,
  });

  @override
  State<FuelInputField> createState() => _FuelInputFieldState();
}

class _FuelInputFieldState extends State<FuelInputField> with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;
  double _fillLevel = 0;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
    widget.controller.addListener(_updateFill);
  }

  void _updateFill() {
    final length = widget.controller.text.length;
    // Fill level rises with text length, capped at 1.0 around 20 characters.
    final target = (length / 20).clamp(0.0, 1.0);
    if (target != _fillLevel) {
      setState(() => _fillLevel = target);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_updateFill);
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(widget.label, style: theme.textTheme.bodySmall),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Wave fill background
              AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _WavePainter(
                      fillLevel: _fillLevel,
                      wavePhase: _waveController.value * 2 * math.pi,
                      color: theme.colorScheme.primary.withValues(alpha: 0.18),
                    ),
                    child: const SizedBox(height: 56, width: double.infinity),
                  );
                },
              ),
              // Actual text field on top
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.25)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextFormField(
                  controller: widget.controller,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  textInputAction: widget.textInputAction,
                  validator: widget.validator,
                  onFieldSubmitted: widget.onFieldSubmitted,
                  decoration: InputDecoration(
                    prefixIcon: Icon(widget.icon),
                    suffixIcon: widget.suffixIcon,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WavePainter extends CustomPainter {
  final double fillLevel; // 0.0 to 1.0
  final double wavePhase;
  final Color color;

  _WavePainter({required this.fillLevel, required this.wavePhase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (fillLevel <= 0) return;

    final paint = Paint()..color = color;
    final waveHeight = 4.0;
    final baseY = size.height * (1 - fillLevel);

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, baseY);

    for (double x = 0; x <= size.width; x++) {
      final y = baseY + math.sin((x / size.width * 2 * math.pi) + wavePhase) * waveHeight;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.fillLevel != fillLevel || oldDelegate.wavePhase != wavePhase;
  }
}
