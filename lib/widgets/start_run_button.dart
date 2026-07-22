import 'package:flutter/material.dart';
import 'hover_button.dart';

class StartRunButton extends StatelessWidget {
  final Color accentColor;
  final VoidCallback onPressed;

  const StartRunButton({
    super.key,
    required this.accentColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 60,
      child: HoverButton(
        builder: (context, progress) => ElevatedButton.icon(
        icon: Icon(
          Icons.play_arrow_rounded,
          size: 30,
          color: Color.lerp(Colors.black, accentColor, progress),
        ),
        label: Text(
          'MULAI BERLARI',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
            color: Color.lerp(Colors.black, accentColor, progress),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Color.lerp(accentColor, Colors.transparent, progress),
          foregroundColor: Color.lerp(Colors.black, accentColor, progress),
          elevation: progress > 0 ? 0 : 5,
          shadowColor: accentColor.withValues(alpha: 0.5),
          side: BorderSide(
            color: Color.lerp(Colors.transparent, Colors.white, progress)!,
            width: 2.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        onPressed: onPressed,
      ),
      ),
    );
  }
}
