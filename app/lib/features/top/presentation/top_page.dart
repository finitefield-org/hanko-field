import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/fonts/app_fonts.dart';
import '../../../app/localization/app_locale_view_model.dart';

const _topPageCream = Color(0xFFFBF9F6);
const _topPageFooter = Color(0xFFEFEEEB);
const _topPageInk = Color(0xFF1B1C1A);
const _topPageMuted = Color(0xFF5F5E5E);
const _topPageAccent = Color(0xFF851217);
const _topPageLine = Color(0xFFD8CCBC);
const _topPageDivider = Color(0x339CA3AF);
const _topPageFooterBar = Color(0xFF851217);
const _topPageHeroImageAsset = 'assets/top-hero.png';
const _topPageLogoAsset = 'assets/site-logo.png';

class TopPage extends StatelessWidget {
  const TopPage({
    super.key,
    required this.locale,
    required this.onSelectLocale,
    required this.onStartDesign,
    required this.onOpenLegalNotice,
    required this.onOpenTerms,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;
  final VoidCallback onStartDesign;
  final VoidCallback onOpenLegalNotice;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _topPageCream,
      body: Stack(
        children: [
          const Positioned.fill(child: _TopBackground()),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _TopHeader(
                    locale: locale,
                    onSelectLocale: onSelectLocale,
                  ),
                ),
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: Center(
                          child: _TopHero(
                            locale: locale,
                            onStartDesign: onStartDesign,
                          ),
                        ),
                      ),
                      _TopFooter(
                        locale: locale,
                        onOpenLegalNotice: onOpenLegalNotice,
                        onOpenTerms: onOpenTerms,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 18,
            bottom: 18,
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.46,
                child: Image.asset(
                  _topPageLogoAsset,
                  width: 24,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBackground extends StatelessWidget {
  const _TopBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(color: _topPageCream)),
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
            _topPageHeroImageAsset,
            fit: BoxFit.cover,
            alignment: Alignment.center,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return const _TopFallbackBackground();
            },
          ),
        ),
        Container(color: const Color(0x33000000)),
      ],
    );
  }
}

class _TopFallbackBackground extends StatelessWidget {
  const _TopFallbackBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF5EBDD), Color(0xFFE7D8CA)],
            ),
          ),
        ),
        Positioned(left: -120, top: -120, child: _FallbackShape(angle: 0.42)),
        Positioned(
          right: -120,
          bottom: -120,
          child: _FallbackShape(angle: 0.34),
        ),
      ],
    );
  }
}

class _FallbackShape extends StatelessWidget {
  const _FallbackShape({required this.angle});

  final double angle;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: angle,
      child: Container(
        width: 280,
        height: 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: const Color(0xFFCC9E8D).withValues(alpha: 0.25),
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _TopHeader extends StatelessWidget {
  const _TopHeader({required this.locale, required this.onSelectLocale});

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _topPageCream,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const _TopBrand(),
                    const Spacer(),
                    _TopLanguageButton(
                      locale: locale,
                      onSelectLocale: onSelectLocale,
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 1,
                width: double.infinity,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: _topPageDivider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBrand extends StatelessWidget {
  const _TopBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Image.asset(
          _topPageLogoAsset,
          width: 32,
          height: 32,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(width: 32, height: 32);
          },
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'STONE SIGNATURE',
              style: AppFonts.notoSerifJp(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: 0.05,
                color: _topPageInk,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '印鑑フィールド',
              style: AppFonts.notoSerifJp(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1,
                letterSpacing: 0.3,
                color: _topPageAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TopLanguageButton extends StatelessWidget {
  const _TopLanguageButton({
    required this.locale,
    required this.onSelectLocale,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xC7FFFFFF),
      shape: const StadiumBorder(side: BorderSide(color: _topPageLine)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _openLanguageSheet(context),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.language_outlined, color: _topPageAccent, size: 22),
        ),
      ),
    );
  }

  void _openLanguageSheet(BuildContext context) {
    final isEnglish = locale == AppLocale.en;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _topPageCream,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEnglish ? 'Language' : '言語',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _topPageInk,
                  ),
                ),
                const SizedBox(height: 14),
                ...AppLocale.values.map((candidate) {
                  final selected = candidate == locale;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(candidate.displayLabel),
                    trailing: selected
                        ? const Icon(Icons.check, color: _topPageAccent)
                        : null,
                    onTap: () {
                      if (selected) {
                        return;
                      }
                      Navigator.of(sheetContext).pop();
                      onSelectLocale(candidate);
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TopHero extends StatelessWidget {
  const _TopHero({required this.locale, required this.onStartDesign});

  final AppLocale locale;
  final VoidCallback onStartDesign;

  @override
  Widget build(BuildContext context) {
    final isEnglish = locale == AppLocale.en;
    final title = isEnglish
        ? 'A gemstone seal made just for you.'
        : 'あなただけの宝石印鑑';
    final copy = 'Authentic Hand-Carved Gemstone Seals from the Orient';
    final buttonLabel = isEnglish ? 'Start designing' : 'デザインする';
    final width = MediaQuery.sizeOf(context).width;
    final titleSize = width < 380 ? 30.0 : 36.0;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppFonts.notoSerifJp(
                fontSize: titleSize,
                fontWeight: FontWeight.w300,
                height: 1.25,
                letterSpacing: 0.1,
                color: Colors.white,
                shadows: const [
                  Shadow(
                    color: Color(0x52000000),
                    offset: Offset(0, 10),
                    blurRadius: 24,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              copy,
              textAlign: TextAlign.center,
              style: AppFonts.manrope(
                fontSize: 12,
                fontWeight: FontWeight.w300,
                height: 1.8,
                letterSpacing: 0.2,
                color: const Color(0xE6FFFFFF),
              ),
            ),
            const SizedBox(height: 28),
            _StartDesignButton(label: buttonLabel, onPressed: onStartDesign),
          ],
        ),
      ),
    );
  }
}

class _StartDesignButton extends StatelessWidget {
  const _StartDesignButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Material(
        color: _topPageAccent,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: AppFonts.notoSerifJp(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    letterSpacing: 0.3,
                    color: Colors.white,
                  ),
                ),
                const Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0x14FFFFFF), Color(0x00FFFFFF)],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopFooter extends StatelessWidget {
  const _TopFooter({
    required this.locale,
    required this.onOpenLegalNotice,
    required this.onOpenTerms,
  });

  final AppLocale locale;
  final VoidCallback onOpenLegalNotice;
  final VoidCallback onOpenTerms;

  @override
  Widget build(BuildContext context) {
    final isEnglish = locale == AppLocale.en;
    final legalLabel = isEnglish ? 'Legal Notice' : '特商法に基づく表記';
    final termsLabel = isEnglish ? 'Terms of Service' : '利用規約';
    final privacyLabel = isEnglish ? 'Privacy Policy' : 'プライバシーポリシー';
    final companyLabel = isEnglish ? 'Company' : '運営会社';

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          color: _topPageFooter,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 40, 20, 40),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _TopFooterBrand(),
                    const SizedBox(height: 28),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 28,
                      runSpacing: 14,
                      children: [
                        _TopFooterLink(
                          label: legalLabel,
                          onPressed: onOpenLegalNotice,
                        ),
                        _TopFooterLink(
                          label: termsLabel,
                          onPressed: onOpenTerms,
                        ),
                        _TopFooterLink(
                          label: privacyLabel,
                          url: privacyPolicyUrlForLocale(locale),
                        ),
                        _TopFooterLink(
                          label: companyLabel,
                          url: 'https://finitefield.org/company/',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '© STONE SIGNATURE',
                      textAlign: TextAlign.center,
                      style: AppFonts.manrope(
                        fontSize: 10,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.2,
                        color: _topPageMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(
          height: 4,
          width: double.infinity,
          child: DecoratedBox(
            decoration: BoxDecoration(color: _topPageFooterBar),
          ),
        ),
      ],
    );
  }
}

class _TopFooterBrand extends StatelessWidget {
  const _TopFooterBrand();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          _topPageLogoAsset,
          width: 28,
          height: 28,
          errorBuilder: (context, error, stackTrace) {
            return const SizedBox(width: 28, height: 28);
          },
        ),
        const SizedBox(width: 10),
        Text(
          'STONE SIGNATURE',
          style: AppFonts.notoSerifJp(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1,
            letterSpacing: 0.15,
            color: _topPageInk,
          ),
        ),
      ],
    );
  }
}

class _TopFooterLink extends StatelessWidget {
  const _TopFooterLink({required this.label, this.url, this.onPressed})
    : assert(url != null || onPressed != null);

  final String label;
  final String? url;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed ?? () => _openUrl(context, url!),
      style: TextButton.styleFrom(
        foregroundColor: _topPageMuted,
        padding: EdgeInsets.zero,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        label,
        style: AppFonts.manrope(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
      ),
    );
  }
}

Future<void> _openUrl(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
    return;
  }

  final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!launched && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Could not open the link.')));
  }
}
