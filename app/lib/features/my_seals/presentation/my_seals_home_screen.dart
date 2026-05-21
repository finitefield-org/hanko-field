import 'package:flutter/material.dart';

class MySealsHomeScreen extends StatelessWidget {
  const MySealsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _FeatureHeadingScreen(title: 'My Seals');
  }
}

class _FeatureHeadingScreen extends StatelessWidget {
  const _FeatureHeadingScreen({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 48, 26, 0),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          title,
          style: const TextStyle(
            color: _MySealsColors.red,
            fontFamily: 'Noto Serif',
            fontSize: 38,
            fontWeight: FontWeight.w500,
            height: 1,
            letterSpacing: 0,
          ),
        ),
      ),
    );
  }
}

abstract final class _MySealsColors {
  static const red = Color(0xFF9D1F22);
}
