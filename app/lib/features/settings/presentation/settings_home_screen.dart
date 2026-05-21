import 'package:declarative_nav/declarative_nav.dart';
import 'package:flutter/material.dart';

import '../../../app/localization/app_localization.dart';
import '../../../app/theme/app_theme.dart';
import '../../../core/widgets/core_widgets.dart';

class SettingsHomeScreen extends StatelessWidget {
  const SettingsHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const SettingsScreen();
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _rootPage = PageEntry(
    key: 'COM-004-settings-root',
    name: '/settings',
  );

  var _pages = const <PageEntry>[_rootPage];

  void _openDestination(_SettingsDestination destination) {
    setState(() {
      _pages = [
        _rootPage,
        PageEntry(
          key: destination.pageKey,
          name: destination.routeName,
          data: destination,
        ),
      ];
    });
  }

  void _popDestination() {
    if (_pages.length <= 1) {
      return;
    }
    setState(() => _pages = const [_rootPage]);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        if (_pages.length > 1) {
          _popDestination();
          return;
        }
        widget.onClose?.call();
      },
      child: DeclarativePagesNavigator(
        pages: _pages,
        buildPage: (context, page) {
          final destination = page.data;
          if (destination is _SettingsDestination) {
            return _SettingsDetailPage(
              destination: destination,
              onBack: _popDestination,
            );
          }

          return _SettingsMenuPage(
            onOpenDestination: _openDestination,
            onClose: widget.onClose,
          );
        },
        onPopTop: _popDestination,
      ),
    );
  }
}

class _SettingsMenuPage extends StatelessWidget {
  const _SettingsMenuPage({
    required this.onOpenDestination,
    required this.onClose,
  });

  final ValueChanged<_SettingsDestination> onOpenDestination;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _SettingsPageFrame(
      title: l10n.settings,
      trailing: onClose == null
          ? null
          : IconButton(
              onPressed: onClose,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              icon: const Icon(Icons.close),
              color: HankoColors.gold,
            ),
      children: [
        HankoSurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: 8),
          radius: HankoRadii.md,
          child: Column(
            children: [
              _SettingsRow(
                destination: _SettingsDestination.language,
                onTap: onOpenDestination,
              ),
              _SettingsRow(
                destination: _SettingsDestination.about,
                onTap: onOpenDestination,
              ),
              _SettingsRow(
                destination: _SettingsDestination.faq,
                onTap: onOpenDestination,
              ),
              _SettingsRow(
                destination: _SettingsDestination.privacy,
                onTap: onOpenDestination,
              ),
              _SettingsRow(
                destination: _SettingsDestination.terms,
                onTap: onOpenDestination,
              ),
              _SettingsRow(
                destination: _SettingsDestination.contact,
                onTap: onOpenDestination,
              ),
              _SettingsRow(
                destination: _SettingsDestination.version,
                onTap: onOpenDestination,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.destination, required this.onTap});

  final _SettingsDestination destination;
  final ValueChanged<_SettingsDestination> onTap;

  @override
  Widget build(BuildContext context) {
    final label = destination.title(context.l10n);

    return Semantics(
      button: true,
      child: SizedBox(
        height: 52,
        child: InkWell(
          onTap: () => onTap(destination),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Icon(destination.icon, color: HankoColors.gold, size: 22),
                const SizedBox(width: 14),
                Expanded(child: Text(label, style: HankoTextStyles.label)),
                const Icon(
                  Icons.chevron_right,
                  color: HankoColors.gold,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SettingsDetailPage extends StatelessWidget {
  const _SettingsDetailPage({required this.destination, required this.onBack});

  final _SettingsDestination destination;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return _SettingsPageFrame(
      title: destination.title(l10n),
      leading: IconButton(
        onPressed: onBack,
        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        icon: const Icon(Icons.arrow_back_ios_new),
        color: HankoColors.gold,
      ),
      children: [
        if (destination == _SettingsDestination.language)
          const _LanguageSettingsContent()
        else if (destination == _SettingsDestination.version)
          const _VersionSettingsContent()
        else
          HankoStateView.empty(
            title: l10n.settingsContentPendingTitle,
            message: destination.pendingMessage(l10n),
          ),
      ],
    );
  }
}

class _LanguageSettingsContent extends StatelessWidget {
  const _LanguageSettingsContent();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HankoStateView.empty(
          title: l10n.settingsLanguageTitle,
          message: l10n.settingsLanguageMessage,
        ),
        const SizedBox(height: HankoSpacing.md),
        HankoSurfaceCard(
          padding: const EdgeInsets.symmetric(vertical: HankoSpacing.xs),
          radius: HankoRadii.md,
          child: Column(
            children: [
              _LanguageOptionRow(label: l10n.settingsLanguageEnglish),
              _LanguageOptionRow(label: l10n.settingsLanguageJapanese),
            ],
          ),
        ),
      ],
    );
  }
}

class _LanguageOptionRow extends StatelessWidget {
  const _LanguageOptionRow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            const Icon(Icons.translate, color: HankoColors.gold, size: 20),
            const SizedBox(width: 14),
            Expanded(child: Text(label, style: HankoTextStyles.label)),
          ],
        ),
      ),
    );
  }
}

class _VersionSettingsContent extends StatelessWidget {
  const _VersionSettingsContent();

  static const _displayVersion = String.fromEnvironment(
    'HANKO_APP_VERSION',
    defaultValue: '1.0.4+10',
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return HankoSurfaceCard(
      padding: const EdgeInsets.all(HankoSpacing.lg),
      radius: HankoRadii.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.tag_outlined, color: HankoColors.gold, size: 32),
          const SizedBox(height: HankoSpacing.md),
          Text(l10n.settingsVersionTitle, style: HankoTextStyles.sectionTitle),
          const SizedBox(height: HankoSpacing.sm),
          Text(
            l10n.settingsVersionMessage(_displayVersion),
            style: HankoTextStyles.body,
          ),
        ],
      ),
    );
  }
}

class _SettingsPageFrame extends StatelessWidget {
  const _SettingsPageFrame({
    required this.title,
    required this.children,
    this.leading,
    this.trailing,
  });

  final String title;
  final List<Widget> children;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: HankoColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(26, 48, 26, HankoSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (leading != null) ...[
                    SizedBox.square(dimension: 48, child: leading),
                    const SizedBox(width: HankoSpacing.sm),
                  ],
                  Expanded(
                    child: Text(title, style: HankoTextStyles.pageTitle),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: HankoSpacing.sm),
                    SizedBox.square(dimension: 48, child: trailing),
                  ],
                ],
              ),
              if (children.isNotEmpty) const SizedBox(height: HankoSpacing.lg),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

enum _SettingsDestination {
  language,
  about,
  faq,
  privacy,
  terms,
  contact,
  version;

  String get pageKey {
    return switch (this) {
      _SettingsDestination.language => 'COM-004-language',
      _SettingsDestination.about => 'COM-005-about',
      _SettingsDestination.faq => 'COM-007-faq',
      _SettingsDestination.privacy => 'COM-009-privacy',
      _SettingsDestination.terms => 'COM-010-terms',
      _SettingsDestination.contact => 'COM-008-contact',
      _SettingsDestination.version => 'COM-004-version',
    };
  }

  String get routeName {
    return switch (this) {
      _SettingsDestination.language => '/settings/language',
      _SettingsDestination.about => '/settings/about',
      _SettingsDestination.faq => '/settings/faq',
      _SettingsDestination.privacy => '/settings/privacy',
      _SettingsDestination.terms => '/settings/terms',
      _SettingsDestination.contact => '/settings/contact',
      _SettingsDestination.version => '/settings/version',
    };
  }

  IconData get icon {
    return switch (this) {
      _SettingsDestination.language => Icons.language,
      _SettingsDestination.about => Icons.info_outline,
      _SettingsDestination.faq => Icons.help_outline,
      _SettingsDestination.privacy => Icons.privacy_tip_outlined,
      _SettingsDestination.terms => Icons.description_outlined,
      _SettingsDestination.contact => Icons.mail_outline,
      _SettingsDestination.version => Icons.tag_outlined,
    };
  }

  String title(HankoLocalizations l10n) {
    return switch (this) {
      _SettingsDestination.language => l10n.language,
      _SettingsDestination.about => l10n.about,
      _SettingsDestination.faq => l10n.faq,
      _SettingsDestination.privacy => l10n.privacy,
      _SettingsDestination.terms => l10n.terms,
      _SettingsDestination.contact => l10n.contact,
      _SettingsDestination.version => l10n.version,
    };
  }

  String pendingMessage(HankoLocalizations l10n) {
    return switch (this) {
      _SettingsDestination.about => l10n.settingsAboutPendingMessage,
      _SettingsDestination.faq => l10n.settingsFaqPendingMessage,
      _SettingsDestination.privacy => l10n.settingsPrivacyPendingMessage,
      _SettingsDestination.terms => l10n.settingsTermsPendingMessage,
      _SettingsDestination.contact => l10n.settingsContactPendingMessage,
      _SettingsDestination.language ||
      _SettingsDestination.version => l10n.settingsContentPendingMessage,
    };
  }
}
