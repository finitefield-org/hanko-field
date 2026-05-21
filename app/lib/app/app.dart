import 'package:declarative_nav/declarative_nav.dart';
import 'package:flutter/material.dart';

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

  Widget _buildTabPage(BuildContext context, HankoAppTab tab, PageEntry page) {
    return switch (tab) {
      HankoAppTab.design => const _DesignTab(),
      HankoAppTab.mySeals => const _PlaceholderTab(title: 'My Seals'),
      HankoAppTab.stones => const _PlaceholderTab(title: 'Stones'),
    };
  }
}

class _DesignTab extends StatelessWidget {
  const _DesignTab();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final horizontalPadding = width < 410 ? 14.0 : 16.0;
        final cardGap = width < 410 ? 12.0 : 14.0;
        final heroHeight = width < 410 ? 372.0 : 386.0;
        final featureCardHeight = width < 410 ? 252.0 : 260.0;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                48,
                horizontalPadding,
                31,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _DesignHeader(),
                  const SizedBox(height: 17),
                  _HeroDesignCard(height: heroHeight),
                  const SizedBox(height: 23),
                  Row(
                    children: [
                      Expanded(
                        child: _FeatureCard(
                          title: 'Saved Seals',
                          body: 'View and manage your\nsaved seal designs.',
                          assetPath: 'assets/design/com003_saved_seal.png',
                          icon: _FeatureIcon.saved,
                          imageTop: 31,
                          imageRight: -2,
                          imageWidth: 108,
                          height: featureCardHeight,
                        ),
                      ),
                      SizedBox(width: cardGap),
                      Expanded(
                        child: _FeatureCard(
                          title: 'Browse Stones',
                          body: 'Explore our collection of\nnatural gemstones.',
                          assetPath: 'assets/design/com003_gemstones.png',
                          icon: _FeatureIcon.diamond,
                          imageTop: 26,
                          imageRight: 0,
                          imageWidth: 123,
                          height: featureCardHeight,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _DesignHeader extends StatelessWidget {
  const _DesignHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text(
            'Design',
            style: TextStyle(
              color: _Com003Colors.red,
              fontFamily: 'Noto Serif',
              fontSize: 38,
              fontWeight: FontWeight.w500,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
        IconButton(
          onPressed: () {},
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          color: _Com003Colors.gold,
          iconSize: 34,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 48, height: 48),
        ),
      ],
    );
  }
}

class _HeroDesignCard extends StatelessWidget {
  const _HeroDesignCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      height: height,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: 28,
            right: -4,
            width: 198,
            child: _FadedAssetImage(
              assetPath: 'assets/design/com003_hero_seal.png',
            ),
          ),
          const Positioned(
            left: 26,
            top: 67,
            width: 246,
            child: Text(
              'Create your\ncustom seal',
              softWrap: false,
              style: TextStyle(
                color: _Com003Colors.ink,
                fontFamily: 'Noto Serif',
                fontSize: 36,
                fontWeight: FontWeight.w500,
                height: 1.12,
                letterSpacing: 0,
              ),
            ),
          ),
          const Positioned(left: 26, top: 174, child: _DividerMark()),
          const Positioned(
            left: 27,
            top: 205,
            width: 215,
            child: Text(
              'Turn your name into a\npersonalized gemstone seal.',
              style: TextStyle(
                color: _Com003Colors.body,
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                height: 1.95,
                letterSpacing: 0,
              ),
            ),
          ),
          Positioned(
            left: 26,
            top: 282,
            width: 172,
            height: 52,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: _Com003Colors.red,
                borderRadius: BorderRadius.circular(8),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x26961B1D),
                    blurRadius: 18,
                    offset: Offset(0, 9),
                  ),
                ],
              ),
              child: TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Start Designing',
                          style: TextStyle(
                            fontFamily: 'Noto Serif',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            height: 1,
                            letterSpacing: 0,
                          ),
                        ),
                      ),
                    ),
                    Icon(Icons.arrow_forward, size: 23),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DividerMark extends StatelessWidget {
  const _DividerMark();

  @override
  Widget build(BuildContext context) {
    return const Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _GoldLine(),
        SizedBox(width: 10),
        _OutlinedDiamond(size: 10),
        SizedBox(width: 10),
        _GoldLine(),
      ],
    );
  }
}

class _GoldLine extends StatelessWidget {
  const _GoldLine();

  @override
  Widget build(BuildContext context) {
    return Container(width: 58, height: 1, color: _Com003Colors.gold);
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.body,
    required this.assetPath,
    required this.icon,
    required this.imageTop,
    required this.imageRight,
    required this.imageWidth,
    required this.height,
  });

  final String title;
  final String body;
  final String assetPath;
  final _FeatureIcon icon;
  final double imageTop;
  final double imageRight;
  final double imageWidth;
  final double height;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      height: height,
      radius: 15,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned(
            top: imageTop,
            right: imageRight,
            width: imageWidth,
            child: _FadedAssetImage(assetPath: assetPath),
          ),
          Positioned(
            left: 28,
            top: 29,
            width: 64,
            height: 64,
            child: _IconMedallion(icon: icon),
          ),
          Positioned(
            left: 20,
            right: 13,
            top: 141,
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _Com003Colors.ink,
                fontFamily: 'Noto Serif',
                fontSize: 21.5,
                fontWeight: FontWeight.w500,
                height: 1.05,
                letterSpacing: 0,
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 17,
            top: 177,
            child: Text(
              body,
              style: const TextStyle(
                color: _Com003Colors.body,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                height: 1.62,
                letterSpacing: 0,
              ),
            ),
          ),
          const Positioned(
            right: 24,
            bottom: 25,
            child: Icon(
              Icons.chevron_right,
              size: 31,
              color: _Com003Colors.gold,
            ),
          ),
        ],
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    required this.height,
    this.radius = 17,
  });

  final Widget child;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: _Com003Colors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _Com003Colors.border, width: 0.7),
        boxShadow: const [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 22,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: child,
      ),
    );
  }
}

class _FadedAssetImage extends StatelessWidget {
  const _FadedAssetImage({required this.assetPath});

  final String assetPath;

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          stops: const [0, 0.16, 1],
          colors: const [Colors.transparent, Colors.white, Colors.white],
        ).createShader(bounds);
      },
      child: Image.asset(assetPath, fit: BoxFit.contain),
    );
  }
}

class _IconMedallion extends StatelessWidget {
  const _IconMedallion({required this.icon});

  final _FeatureIcon icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: _Com003Colors.medallion,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: CustomPaint(
          size: const Size.square(34),
          painter: _FeatureIconPainter(icon),
        ),
      ),
    );
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

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title});

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
            color: _Com003Colors.red,
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

class _OutlinedDiamond extends StatelessWidget {
  const _OutlinedDiamond({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.7853981634,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border.all(color: _Com003Colors.gold, width: 1.5),
        ),
      ),
    );
  }
}

class _FeatureIconPainter extends CustomPainter {
  const _FeatureIconPainter(this.icon);

  final _FeatureIcon icon;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _Com003Colors.gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (icon) {
      case _FeatureIcon.saved:
        final book = RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.13, size.height * 0.13, 22, 26),
          const Radius.circular(2.5),
        );
        canvas.drawRRect(book, paint);
        canvas.drawLine(
          Offset(size.width * 0.26, size.height * 0.33),
          Offset(size.width * 0.13, size.height * 0.33),
          paint,
        );
        final bookmark = Path()
          ..moveTo(size.width * 0.70, size.height * 0.48)
          ..lineTo(size.width * 0.89, size.height * 0.48)
          ..lineTo(size.width * 0.89, size.height * 0.90)
          ..lineTo(size.width * 0.79, size.height * 0.82)
          ..lineTo(size.width * 0.70, size.height * 0.90)
          ..close();
        canvas.drawPath(bookmark, paint);
        break;
      case _FeatureIcon.diamond:
        final path = Path()
          ..moveTo(size.width * 0.50, size.height * 0.91)
          ..lineTo(size.width * 0.08, size.height * 0.35)
          ..lineTo(size.width * 0.25, size.height * 0.12)
          ..lineTo(size.width * 0.75, size.height * 0.12)
          ..lineTo(size.width * 0.92, size.height * 0.35)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawLine(
          Offset(size.width * 0.08, size.height * 0.35),
          Offset(size.width * 0.92, size.height * 0.35),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.25, size.height * 0.12),
          Offset(size.width * 0.50, size.height * 0.91),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.75, size.height * 0.12),
          Offset(size.width * 0.50, size.height * 0.91),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.39, size.height * 0.12),
          Offset(size.width * 0.30, size.height * 0.35),
          paint,
        );
        canvas.drawLine(
          Offset(size.width * 0.61, size.height * 0.12),
          Offset(size.width * 0.70, size.height * 0.35),
          paint,
        );
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _FeatureIconPainter oldDelegate) {
    return oldDelegate.icon != icon;
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

enum _FeatureIcon { saved, diamond }

abstract final class _Com003Colors {
  static const background = Color(0xFFFBF8F3);
  static const card = Color(0xFFFEFCF9);
  static const border = Color(0xFFEDE3D7);
  static const navBorder = Color(0xFFE8DED3);
  static const medallion = Color(0xFFF1EAE2);
  static const red = Color(0xFF9D1F22);
  static const gold = Color(0xFFB47B2C);
  static const ink = Color(0xFF202629);
  static const body = Color(0xFF64686B);
}
