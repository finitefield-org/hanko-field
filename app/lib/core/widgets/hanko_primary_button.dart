import 'package:flutter/material.dart';

import '../../app/theme/app_theme.dart';

class HankoPrimaryButton extends StatelessWidget {
  const HankoPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward,
    this.height = 52,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final double height;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: enabled ? HankoColors.red : HankoColors.surfaceBorder,
          borderRadius: BorderRadius.circular(HankoRadii.sm),
          boxShadow: enabled
              ? const [
                  BoxShadow(
                    color: Color(0x26961B1D),
                    blurRadius: 18,
                    offset: Offset(0, 9),
                  ),
                ]
              : const [],
        ),
        child: TextButton(
          onPressed: onPressed,
          style: TextButton.styleFrom(
            foregroundColor: enabled ? Colors.white : HankoColors.body,
            disabledForegroundColor: HankoColors.body,
            padding: padding,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HankoRadii.sm),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(label, style: HankoTextStyles.buttonLabel),
                ),
              ),
              if (icon != null) Icon(icon, size: 23),
            ],
          ),
        ),
      ),
    );
  }
}
