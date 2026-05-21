import 'package:declarative_nav/declarative_nav.dart';
import 'package:flutter/material.dart';

import '../features/design/design.dart';
import '../features/my_seals/my_seals.dart';
import '../features/stones/stones.dart';
import 'navigation/app_navigation_shell.dart';

class HankoApp extends StatelessWidget {
  const HankoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'STONE SIGNATURE',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: _Com003Colors.background,
        fontFamily: 'Manrope',
        colorScheme: ColorScheme.fromSeed(
          seedColor: _Com003Colors.red,
          surface: _Com003Colors.background,
        ),
      ),
      home: const BottomNavigationShell(),
    );
  }
}

class BottomNavigationShell extends StatefulWidget {
  const BottomNavigationShell({super.key});

  @override
  State<BottomNavigationShell> createState() => _BottomNavigationShellState();
}

class _BottomNavigationShellState extends State<BottomNavigationShell> {
  static const _navigationTabs = [
    HankoTabDefinition(
      tab: HankoAppTab.design,
      rootKey: 'COM-003-design-root',
      rootName: '/design',
    ),
    HankoTabDefinition(
      tab: HankoAppTab.mySeals,
      rootKey: 'COM-003-my-seals-root',
      rootName: '/my-seals',
    ),
    HankoTabDefinition(
      tab: HankoAppTab.stones,
      rootKey: 'COM-003-stones-root',
      rootName: '/stones',
    ),
  ];

  static const _tabItems = [
    _TabItem('Design', _TabIcon.design),
    _TabItem('My Seals', _TabIcon.mySeals),
    _TabItem('Stones', _TabIcon.stones),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _Com003Colors.background,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 432),
          child: HankoTabNavigationShell(
            tabs: _navigationTabs,
            buildPage: _buildTabPage,
            buildBottomNavigation: (context, selectedIndex, onSelected) {
              return _BottomTabs(
                selectedIndex: selectedIndex,
                tabs: _tabItems,
                onSelected: onSelected,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTabPage(BuildContext context, HankoAppTab tab, PageEntry _) {
    return switch (tab) {
      HankoAppTab.design => const DesignHomeScreen(),
      HankoAppTab.mySeals => const MySealsHomeScreen(),
      HankoAppTab.stones => const StonesHomeScreen(),
    };
  }
}

class _BottomTabs extends StatelessWidget {
  const _BottomTabs({
    required this.selectedIndex,
    required this.tabs,
    required this.onSelected,
  });

  final int selectedIndex;
  final List<_TabItem> tabs;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / tabs.length;
          return DecoratedBox(
            decoration: const BoxDecoration(
              color: _Com003Colors.background,
              border: Border(
                top: BorderSide(color: _Com003Colors.navBorder, width: 0.7),
              ),
            ),
            child: Stack(
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOutCubic,
                  top: 0,
                  left: tabWidth * selectedIndex + (tabWidth / 2) - 25,
                  width: 50,
                  height: 4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: _Com003Colors.red,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var index = 0; index < tabs.length; index++)
                      Expanded(
                        child: _BottomTabButton(
                          item: tabs[index],
                          isSelected: selectedIndex == index,
                          onTap: () => onSelected(index),
                        ),
                      ),
                  ],
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 8,
                  child: Center(child: _HomeIndicator()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _BottomTabButton extends StatelessWidget {
  const _BottomTabButton({
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  final _TabItem item;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? _Com003Colors.red : _Com003Colors.ink;
    return InkResponse(
      onTap: onTap,
      containedInkWell: true,
      highlightShape: BoxShape.rectangle,
      child: Padding(
        padding: const EdgeInsets.only(top: 21, bottom: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CustomPaint(
              size: const Size.square(31),
              painter: _TabIconPainter(item.icon, color),
            ),
            const SizedBox(height: 7),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1,
                letterSpacing: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeIndicator extends StatelessWidget {
  const _HomeIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 136,
      height: 5,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _TabIconPainter extends CustomPainter {
  const _TabIconPainter(this.icon, this.color);

  final _TabIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    switch (icon) {
      case _TabIcon.design:
        final stem = Path()
          ..moveTo(size.width * 0.61, size.height * 0.04)
          ..lineTo(size.width * 0.32, size.height * 0.61);
        canvas.drawPath(stem, paint);
        final brush = Path()
          ..moveTo(size.width * 0.65, size.height * 0.03)
          ..quadraticBezierTo(
            size.width * 0.79,
            size.height * 0.16,
            size.width * 0.68,
            size.height * 0.30,
          )
          ..lineTo(size.width * 0.42, size.height * 0.66)
          ..quadraticBezierTo(
            size.width * 0.33,
            size.height * 0.59,
            size.width * 0.31,
            size.height * 0.54,
          )
          ..lineTo(size.width * 0.56, size.height * 0.20)
          ..quadraticBezierTo(
            size.width * 0.59,
            size.height * 0.10,
            size.width * 0.65,
            size.height * 0.03,
          );
        canvas.drawPath(brush, paint);
        final plate = Path()
          ..moveTo(size.width * 0.18, size.height * 0.61)
          ..quadraticBezierTo(
            size.width * 0.34,
            size.height * 0.80,
            size.width * 0.17,
            size.height * 0.84,
          )
          ..quadraticBezierTo(
            size.width * 0.42,
            size.height * 1.02,
            size.width * 0.72,
            size.height * 0.76,
          );
        canvas.drawPath(plate, paint);
        canvas.drawOval(
          Rect.fromLTWH(
            size.width * 0.03,
            size.height * 0.69,
            size.width * 0.65,
            size.height * 0.25,
          ),
          paint,
        );
        break;
      case _TabIcon.mySeals:
        final shield = Path()
          ..moveTo(size.width * 0.50, size.height * 0.07)
          ..lineTo(size.width * 0.84, size.height * 0.20)
          ..lineTo(size.width * 0.79, size.height * 0.61)
          ..quadraticBezierTo(
            size.width * 0.74,
            size.height * 0.80,
            size.width * 0.50,
            size.height * 0.93,
          )
          ..quadraticBezierTo(
            size.width * 0.26,
            size.height * 0.80,
            size.width * 0.21,
            size.height * 0.61,
          )
          ..lineTo(size.width * 0.16, size.height * 0.20)
          ..close();
        canvas.drawPath(shield, paint);
        canvas.drawCircle(
          Offset(size.width * 0.50, size.height * 0.51),
          size.width * 0.045,
          fillPaint,
        );
        final sparkle = Path()
          ..moveTo(size.width * 0.50, size.height * 0.34)
          ..lineTo(size.width * 0.54, size.height * 0.47)
          ..lineTo(size.width * 0.67, size.height * 0.51)
          ..lineTo(size.width * 0.54, size.height * 0.55)
          ..lineTo(size.width * 0.50, size.height * 0.68)
          ..lineTo(size.width * 0.46, size.height * 0.55)
          ..lineTo(size.width * 0.33, size.height * 0.51)
          ..lineTo(size.width * 0.46, size.height * 0.47)
          ..close();
        canvas.drawPath(sparkle, fillPaint);
        break;
      case _TabIcon.stones:
        final path = Path()
          ..moveTo(size.width * 0.50, size.height * 0.94)
          ..lineTo(size.width * 0.09, size.height * 0.35)
          ..lineTo(size.width * 0.27, size.height * 0.12)
          ..lineTo(size.width * 0.73, size.height * 0.12)
          ..lineTo(size.width * 0.91, size.height * 0.35)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawLine(
          Offset(size.width * 0.09, size.height * 0.35),
          Offset(size.width * 0.91, size.height * 0.35),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.27, size.height * 0.12),
          Offset(size.width * 0.50, size.height * 0.94),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.73, size.height * 0.12),
          Offset(size.width * 0.50, size.height * 0.94),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.40, size.height * 0.12),
          Offset(size.width * 0.31, size.height * 0.35),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.60, size.height * 0.12),
          Offset(size.width * 0.69, size.height * 0.35),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _TabIconPainter oldDelegate) {
    return oldDelegate.icon != icon || oldDelegate.color != color;
  }
}

class _TabItem {
  const _TabItem(this.label, this.icon);

  final String label;
  final _TabIcon icon;
}

enum _TabIcon { design, mySeals, stones }

abstract final class _Com003Colors {
  static const background = Color(0xFFFBF8F3);
  static const navBorder = Color(0xFFE8DED3);
  static const red = Color(0xFF9D1F22);
  static const ink = Color(0xFF202629);
}
