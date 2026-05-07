import 'package:flutter/material.dart';

import '../../../app/fonts/app_fonts.dart';
import '../../../app/localization/app_locale_view_model.dart';
import '../../../app/widgets/app_site_chrome.dart';

const _aboutPageCream = Color(0xFFFBF9F6);
const _aboutPageInk = Color(0xFF1B1C1A);
const _aboutPageMuted = Color(0xFF5F5E5E);
const _aboutPageAccent = Color(0xFF851217);
const _aboutPageLine = Color(0xFFD8CCBC);
const _aboutPageHeroImageAsset = 'assets/top-hero.png';

class AboutPage extends StatelessWidget {
  const AboutPage({
    super.key,
    required this.locale,
    required this.onSelectLocale,
    required this.onBackToDesign,
    required this.onOpenAbout,
    required this.onOpenLegalNotice,
    required this.onOpenTerms,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;
  final VoidCallback onBackToDesign;
  final VoidCallback onOpenAbout;
  final VoidCallback onOpenLegalNotice;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _aboutPageCream,
      body: SafeArea(
        child: Column(
          children: [
            AppSiteHeader(
              locale: locale,
              onSelectLocale: onSelectLocale,
              onBrandTap: onBackToDesign,
            ),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _AboutHero(locale: locale, onStartDesign: onBackToDesign),
                    _AboutStory(locale: locale),
                    AppSiteFooter(
                      locale: locale,
                      onOpenAbout: onOpenAbout,
                      onOpenLegalNotice: onOpenLegalNotice,
                      onOpenTerms: onOpenTerms,
                      onBrandTap: onBackToDesign,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutHero extends StatelessWidget {
  const _AboutHero({required this.locale, required this.onStartDesign});

  final AppLocale locale;
  final VoidCallback onStartDesign;

  @override
  Widget build(BuildContext context) {
    final isEnglish = locale == AppLocale.en;
    final title = isEnglish ? 'Your seal, made from gemstone' : '宝石でつくる、あなたの印鑑';
    final copy = isEnglish
        ? 'Choose a stone, design the seal impression, and place your order'
        : '石を選び、印影をデザインして注文できます';
    final buttonLabel = isEnglish ? 'Design' : 'デザインする';

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width < 720;
        final heroHeight = isCompact ? 520.0 : 560.0;
        final titleSize = isCompact ? 34.0 : 48.0;

        return SizedBox(
          height: heroHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.7162,
                  0.1216,
                  0.0122,
                  0,
                  0,
                  0.0362,
                  0.8016,
                  0.0122,
                  0,
                  0,
                  0.0362,
                  0.1216,
                  0.6922,
                  0,
                  0,
                  0,
                  0,
                  0,
                  1,
                  0,
                ]),
                child: Image.asset(
                  _aboutPageHeroImageAsset,
                  fit: BoxFit.cover,
                  alignment: Alignment.center,
                  filterQuality: FilterQuality.high,
                  errorBuilder: (context, error, stackTrace) {
                    return const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFFF5EBDD), Color(0xFFE7D8CA)],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const DecoratedBox(
                decoration: BoxDecoration(color: Color(0x66000000)),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 840),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 20 : 32,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'About STONE SIGNATURE',
                          textAlign: TextAlign.center,
                          style: AppFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                            letterSpacing: 0,
                            color: const Color(0xFFEBD8D2),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: AppFonts.notoSerifJp(
                            fontSize: titleSize,
                            fontWeight: FontWeight.w300,
                            height: 1.22,
                            letterSpacing: 0,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          copy,
                          textAlign: TextAlign.center,
                          style: AppFonts.manrope(
                            fontSize: isCompact ? 13 : 15,
                            fontWeight: FontWeight.w400,
                            height: 1.7,
                            letterSpacing: 0,
                            color: const Color(0xE6FFFFFF),
                          ),
                        ),
                        const SizedBox(height: 32),
                        _AboutCtaButton(
                          label: buttonLabel,
                          onPressed: onStartDesign,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AboutCtaButton extends StatefulWidget {
  const _AboutCtaButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  State<_AboutCtaButton> createState() => _AboutCtaButtonState();
}

class _AboutCtaButtonState extends State<_AboutCtaButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  void _setHovered(bool value) {
    if (_isHovered == value) {
      return;
    }
    setState(() => _isHovered = value);
  }

  void _setPressed(bool value) {
    if (_isPressed == value) {
      return;
    }
    setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 720;

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 148),
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: ClipRect(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
            color: _isHovered ? const Color(0xFF8A181D) : _aboutPageAccent,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: widget.onPressed,
                onHover: _setHovered,
                onHighlightChanged: _setPressed,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: IgnorePointer(
                        child: AnimatedSlide(
                          offset: _isHovered ? Offset.zero : const Offset(0, 1),
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(color: Color(0x1AFFFFFF)),
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 32 : 48,
                        vertical: isCompact ? 16 : 20,
                      ),
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        style: AppFonts.notoSerifJp(
                          fontSize: isCompact ? 16 : 20,
                          fontWeight: FontWeight.w700,
                          height: 1,
                          letterSpacing: 0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AboutStory extends StatelessWidget {
  const _AboutStory({required this.locale});

  final AppLocale locale;

  @override
  Widget build(BuildContext context) {
    final isEnglish = locale == AppLocale.en;
    final heading = isEnglish
        ? 'An easier way to choose a gemstone seal.'
        : '宝石印鑑を、もっと選びやすく。';
    final body = isEnglish
        ? 'STONE SIGNATURE is a service for choosing a gemstone seal online, designing the seal impression, and placing an order.\nReview the material and one-of-a-kind stone listings as you find the seal that fits you.'
        : 'STONE SIGNATUREは、宝石を使った印鑑をオンラインで選び、印影をデザインして注文できるサービスです。\n素材や一点物の個体を確認しながら、自分に合った印鑑を見つけられます。';

    final points = isEnglish
        ? const [
            _AboutPointData(
              title: 'Gemstone',
              body:
                  'Choose the seal material while reviewing the colors and patterns unique to natural stone.',
            ),
            _AboutPointData(
              title: 'Seal design',
              body:
                  'Move through the order while checking the carved text and the mood of the seal impression.',
            ),
            _AboutPointData(
              title: 'One of a kind',
              body:
                  'Even stones of the same type differ in color and pattern. Choose the piece you like and order it.',
            ),
          ]
        : const [
            _AboutPointData(title: '宝石', body: '天然石ならではの色や模様を見ながら、印鑑の素材を選べます。'),
            _AboutPointData(
              title: '印影デザイン',
              body: '彫る文字や印影の雰囲気を確認しながら、注文を進められます。',
            ),
            _AboutPointData(
              title: '一点物',
              body: '同じ石でも色や模様は少しずつ異なります。気に入った一本を選んで注文できます。',
            ),
          ];

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1152),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 72, 24, 80),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 780),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heading,
                      style: AppFonts.notoSerifJp(
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                        letterSpacing: 0,
                        color: _aboutPageInk,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      body,
                      style: AppFonts.manrope(
                        fontSize: 15,
                        fontWeight: FontWeight.w400,
                        height: 1.85,
                        letterSpacing: 0,
                        color: _aboutPageMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 44),
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 760;
                  if (isCompact) {
                    return Column(
                      children: points
                          .map(
                            (point) => Padding(
                              padding: const EdgeInsets.only(bottom: 18),
                              child: _AboutPoint(point: point),
                            ),
                          )
                          .toList(growable: false),
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: points
                        .map(
                          (point) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 18),
                              child: _AboutPoint(point: point),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutPointData {
  const _AboutPointData({required this.title, required this.body});

  final String title;
  final String body;
}

class _AboutPoint extends StatelessWidget {
  const _AboutPoint({required this.point});

  final _AboutPointData point;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _aboutPageLine)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              point.title,
              style: AppFonts.notoSerifJp(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 1.3,
                letterSpacing: 0,
                color: _aboutPageAccent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              point.body,
              style: AppFonts.manrope(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.75,
                letterSpacing: 0,
                color: _aboutPageMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
