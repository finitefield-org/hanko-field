import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../fonts/app_fonts.dart';
import '../localization/app_locale_view_model.dart';

const _siteChromeCream = Color(0xFFFBF9F6);
const _siteChromeFooter = Color(0xFFEFEEEB);
const _siteChromeInk = Color(0xFF1B1C1A);
const _siteChromeMuted = Color(0xFF5F5E5E);
const _siteChromeAccent = Color(0xFF851217);
const _siteChromeLine = Color(0xFFD8CCBC);
const _siteChromeDivider = Color(0x339CA3AF);
const _siteChromeFooterBar = Color(0xFF851217);
const _siteChromeLogoAsset = 'assets/site-logo.png';

class AppSiteHeader extends StatelessWidget {
  const AppSiteHeader({
    super.key,
    required this.locale,
    required this.onSelectLocale,
    this.onBrandTap,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;
  final VoidCallback? onBrandTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth <= 960;
        final horizontalPadding = isCompact ? 16.0 : 24.0;

        return Container(
          color: _siteChromeCream,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1440),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      20,
                      horizontalPadding,
                      20,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _SiteBrand(onTap: onBrandTap),
                        const Spacer(),
                        _SiteLanguageButton(
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
                      decoration: BoxDecoration(color: _siteChromeDivider),
                    ),
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

class AppSiteFooter extends StatelessWidget {
  const AppSiteFooter({
    super.key,
    required this.locale,
    required this.onOpenLegalNotice,
    required this.onOpenTerms,
    this.onBrandTap,
  });

  final AppLocale locale;
  final VoidCallback onOpenLegalNotice;
  final VoidCallback onOpenTerms;
  final VoidCallback? onBrandTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 768;
        final horizontalPadding = isCompact ? 16.0 : 24.0;
        final verticalPadding = isCompact ? 48.0 : 64.0;
        final isEnglish = locale == AppLocale.en;
        final legalLabel = isEnglish ? 'LEGAL NOTICE' : '特商法に基づく表記';
        final termsLabel = isEnglish ? 'TERMS OF SERVICE' : '利用規約';
        final privacyLabel = isEnglish ? 'PRIVACY POLICY' : 'プライバシーポリシー';
        final companyLabel = isEnglish ? 'COMPANY' : '運営会社';

        final Widget links = Wrap(
          alignment: WrapAlignment.center,
          spacing: 48,
          runSpacing: 32,
          children: [
            _SiteFooterLink(label: legalLabel, onPressed: onOpenLegalNotice),
            _SiteFooterLink(label: termsLabel, onPressed: onOpenTerms),
            _SiteFooterLink(
              label: privacyLabel,
              url: privacyPolicyUrlForLocale(locale),
            ),
            _SiteFooterLink(
              label: companyLabel,
              url: 'https://finitefield.org/company/',
            ),
          ],
        );

        final copyright = Text(
          '© STONE SIGNATURE',
          textAlign: TextAlign.center,
          style: AppFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.2,
            color: _siteChromeMuted,
          ),
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              color: _siteChromeFooter,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1440),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      horizontalPadding,
                      verticalPadding,
                      horizontalPadding,
                      verticalPadding,
                    ),
                    child: isCompact
                        ? Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _SiteFooterBrand(onTap: onBrandTap),
                              const SizedBox(height: 32),
                              links,
                              const SizedBox(height: 32),
                              copyright,
                            ],
                          )
                        : Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _SiteFooterBrand(onTap: onBrandTap),
                              const SizedBox(width: 24),
                              Expanded(child: Center(child: links)),
                              const SizedBox(width: 24),
                              copyright,
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
                decoration: BoxDecoration(color: _siteChromeFooterBar),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _SiteBrand extends StatelessWidget {
  const _SiteBrand({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          _siteChromeLogoAsset,
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
                color: _siteChromeInk,
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
                color: _siteChromeAccent,
              ),
            ),
          ],
        ),
      ],
    );

    if (onTap == null) {
      return brand;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: brand),
    );
  }
}

class _SiteLanguageButton extends StatelessWidget {
  const _SiteLanguageButton({
    required this.locale,
    required this.onSelectLocale,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xC7FFFFFF),
      shape: const StadiumBorder(side: BorderSide(color: _siteChromeLine)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () => _openLanguageSheet(context),
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            Icons.language_outlined,
            color: _siteChromeAccent,
            size: 24,
          ),
        ),
      ),
    );
  }

  void _openLanguageSheet(BuildContext context) {
    final isEnglish = locale == AppLocale.en;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: _siteChromeCream,
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
                    color: _siteChromeInk,
                  ),
                ),
                const SizedBox(height: 14),
                ...AppLocale.values.map((candidate) {
                  final selected = candidate == locale;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(candidate.displayLabel),
                    trailing: selected
                        ? const Icon(Icons.check, color: _siteChromeAccent)
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

class _SiteFooterBrand extends StatelessWidget {
  const _SiteFooterBrand({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brand = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          _siteChromeLogoAsset,
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
            color: _siteChromeInk,
          ),
        ),
      ],
    );

    if (onTap == null) {
      return brand;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: brand),
    );
  }
}

class _SiteFooterLink extends StatelessWidget {
  const _SiteFooterLink({required this.label, this.url, this.onPressed})
    : assert(url != null || onPressed != null);

  final String label;
  final String? url;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed ?? () => _openUrl(context, url!),
      style: TextButton.styleFrom(
        foregroundColor: _siteChromeMuted,
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
