import 'package:flutter/material.dart';

enum ButtonType { normal, helper, operator, equals }

class CalcButton extends StatelessWidget {
  final String text;
  final ButtonType type;
  final int flex;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;

  const CalcButton(
      this.text, {
        super.key,
        this.type = ButtonType.normal,
        this.flex = 1,
        this.onPressed,
        this.onLongPress,
      });

  @override
  Widget build(BuildContext context) {
    final bool isOperator = type == ButtonType.operator || type == ButtonType.equals;

    final Color base = switch (type) {
      ButtonType.normal => const Color(0xFF2A2A2A),
      ButtonType.helper => const Color(0xFF3A3A3A),
      ButtonType.operator => const Color(0xFFFB8C00), // オレンジ
      ButtonType.equals => const Color(0xFF2962FF),   // ブルー強調
    };

    final TextStyle labelStyle = TextStyle(
      fontSize: 24,
      fontWeight: isOperator ? FontWeight.w700 : FontWeight.w600,
      color: Colors.white,
    );

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.all(6.0),
        child: SizedBox(
          height: 64,
          child: ElevatedButton(
            onPressed: onPressed,
            onLongPress: onLongPress,
            style: ElevatedButton.styleFrom(
              backgroundColor: base,
              foregroundColor: Colors.white,
              shadowColor: Colors.black.withOpacity(0.4),
              elevation: 1,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 0),
            ),
            child: Text(text, style: labelStyle),
          ),
        ),
      ),
    );
  }
}