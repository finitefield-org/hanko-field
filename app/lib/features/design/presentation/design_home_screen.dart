import 'package:flutter/material.dart';

class DesignHomeScreen extends StatelessWidget {
  const DesignHomeScreen({super.key, this.onOpenSettings});

  final VoidCallback? onOpenSettings;

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
                  _DesignHeader(onOpenSettings: onOpenSettings),
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
  const _DesignHeader({required this.onOpenSettings});

  final VoidCallback? onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Text(
            'Design',
            style: TextStyle(
              color: _DesignHomeColors.red,
              fontFamily: 'Noto Serif',
              fontSize: 38,
              fontWeight: FontWeight.w500,
              height: 1,
              letterSpacing: 0,
            ),
          ),
        ),
        IconButton(
          onPressed: onOpenSettings ?? () {},
          tooltip: 'Settings',
          icon: const Icon(Icons.settings_outlined),
          color: _DesignHomeColors.gold,
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
                color: _DesignHomeColors.ink,
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
                color: _DesignHomeColors.body,
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
                color: _DesignHomeColors.red,
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
    return Container(width: 58, height: 1, color: _DesignHomeColors.gold);
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
                color: _DesignHomeColors.ink,
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
                color: _DesignHomeColors.body,
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
              color: _DesignHomeColors.gold,
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
        color: _DesignHomeColors.card,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _DesignHomeColors.border, width: 0.7),
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
        color: _DesignHomeColors.medallion,
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
          border: Border.all(color: _DesignHomeColors.gold, width: 1.5),
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
      ..color = _DesignHomeColors.gold
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

enum _FeatureIcon { saved, diamond }

abstract final class _DesignHomeColors {
  static const card = Color(0xFFFEFCF9);
  static const border = Color(0xFFEDE3D7);
  static const medallion = Color(0xFFF1EAE2);
  static const red = Color(0xFF9D1F22);
  static const gold = Color(0xFFB47B2C);
  static const ink = Color(0xFF202629);
  static const body = Color(0xFF64686B);
}
