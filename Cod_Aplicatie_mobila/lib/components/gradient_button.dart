import 'package:flutter/material.dart';

class GradientButton extends StatelessWidget {
  final String text;
  final Future<void> Function()? onPressed;
  final bool enabled;

  const GradientButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.enabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled && onPressed != null ? () => onPressed!() : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1.0 : 0.6,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: enabled
                  ? [Color(0xFF2196F3), Color(0xFF21CBF3)]
                  : [Colors.grey.shade400, Colors.grey.shade400],
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }
}
