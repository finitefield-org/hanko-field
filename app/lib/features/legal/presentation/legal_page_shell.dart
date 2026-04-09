import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../app/fonts/app_fonts.dart';
import '../../../app/localization/app_locale_view_model.dart';
import '../../../app/widgets/app_site_chrome.dart';

const _legalPageInk = Color(0xFF1B1C1A);
const _legalPageMuted = Color(0xFF5F5E5E);
const _legalPageAccent = Color(0xFF851217);
const _legalPageLine = Color.fromRGBO(140, 113, 110, 0.1);
const _legalPageButtonLine = Color(0xFFD8CCBC);
const _legalPageNotesBg = Color(0xFFF5F3F0);
const _legalPageBackground = Color(0xFFFBF9F6);

class LegalPageScaffold extends StatelessWidget {
  const LegalPageScaffold({
    super.key,
    required this.locale,
    required this.onSelectLocale,
    required this.onBack,
    required this.onOpenLegalNotice,
    required this.onOpenTerms,
    required this.title,
    required this.body,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onSelectLocale;
  final VoidCallback onBack;
  final VoidCallback onOpenLegalNotice;
  final VoidCallback onOpenTerms;
  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _legalPageBackground,
      body: Stack(
        children: [
          const Positioned.fill(child: _LegalPageBackground()),
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _LegalPageMain(title: title, body: body),
                  AppSiteFooter(
                    locale: locale,
                    onBrandTap: onBack,
                    onOpenLegalNotice: onOpenLegalNotice,
                    onOpenTerms: onOpenTerms,
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: AppSiteHeader(
                locale: locale,
                onSelectLocale: onSelectLocale,
                onBrandTap: onBack,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalPageMain extends StatelessWidget {
  const _LegalPageMain({required this.title, required this.body});

  final String title;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isCompact = width <= 640;
        final horizontalPadding = width <= 960 ? 16.0 : 24.0;
        final topPadding = isCompact
            ? 100.0
            : width <= 960
            ? 104.0
            : 112.0;
        final bottomPadding = width <= 960 ? 48.0 : 64.0;
        final titleSize = (width * 0.04).clamp(32.0, 52.0).toDouble();
        final leadGap = isCompact ? 32.0 : 48.0;

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1152),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                topPadding,
                horizontalPadding,
                bottomPadding,
              ),
              child: SizedBox(
                width: double.infinity,
                child: DefaultTextStyle(
                  style: AppFonts.manrope(
                    fontSize: 15,
                    height: 1.8,
                    color: _legalPageInk,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppFonts.notoSerifJp(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                          letterSpacing: 0.02,
                          color: _legalPageInk,
                        ),
                      ),
                      SizedBox(height: leadGap),
                      SizedBox(width: double.infinity, child: body),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LegalPageBackground extends StatelessWidget {
  const _LegalPageBackground();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(color: _legalPageBackground);
  }
}

class LegalSection extends StatelessWidget {
  const LegalSection({
    super.key,
    required this.index,
    required this.title,
    required this.child,
  });

  final String index;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.sizeOf(context).width <= 640 ? 48 : 64,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final titleSize = (constraints.maxWidth * 0.02)
                  .clamp(17.0, 23.2)
                  .toDouble();
              return Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      index,
                      style: AppFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: _legalPageAccent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: AppFonts.notoSerifJp(
                          fontSize: titleSize,
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                          color: _legalPageInk,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          child,
        ],
      ),
    );
  }
}

@immutable
class LegalDefinitionRowData {
  const LegalDefinitionRowData({required this.term, required this.description});

  final String term;
  final Widget description;
}

class LegalDefinitionList extends StatelessWidget {
  const LegalDefinitionList({super.key, required this.rows});

  final List<LegalDefinitionRowData> rows;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _legalPageLine),
          bottom: BorderSide(color: _legalPageLine),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++)
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: _LegalDefinitionRow(row: rows[i]),
                ),
                if (i != rows.length - 1)
                  const Divider(height: 1, color: _legalPageLine),
              ],
            ),
        ],
      ),
    );
  }
}

class _LegalDefinitionRow extends StatelessWidget {
  const _LegalDefinitionRow({required this.row});

  final LegalDefinitionRowData row;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 768;
        final termStyle = AppFonts.manrope(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _legalPageMuted,
        );
        final descStyle = AppFonts.manrope(
          fontSize: 15,
          height: 1.7,
          color: _legalPageInk,
        );

        if (isCompact) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.term, style: termStyle),
                const SizedBox(height: 7),
                DefaultTextStyle(style: descStyle, child: row.description),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 176, child: Text(row.term, style: termStyle)),
              Expanded(
                child: DefaultTextStyle(
                  style: descStyle,
                  child: row.description,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

@immutable
class LegalNoteData {
  const LegalNoteData({required this.label, required this.text});

  final String label;
  final Widget text;
}

class LegalNoteGrid extends StatelessWidget {
  const LegalNoteGrid({super.key, required this.notes});

  final List<LegalNoteData> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _legalPageNotesBg,
      padding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 768;
          final labelStyle = AppFonts.manrope(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.16,
            color: _legalPageMuted,
          );
          final textStyle = AppFonts.manrope(
            fontSize: 15,
            height: 1.7,
            color: _legalPageInk,
          );

          Widget buildNote(LegalNoteData note) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(note.label, style: labelStyle),
                const SizedBox(height: 8),
                DefaultTextStyle(style: textStyle, child: note.text),
              ],
            );
          }

          if (notes.isEmpty) {
            return const SizedBox.shrink();
          }

          if (isWide && notes.length >= 2) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: buildNote(notes[0])),
                const SizedBox(width: 24),
                Expanded(child: buildNote(notes[1])),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < notes.length; i++) ...[
                buildNote(notes[i]),
                if (i != notes.length - 1) const SizedBox(height: 24),
              ],
            ],
          );
        },
      ),
    );
  }
}

class LegalBulletList extends StatelessWidget {
  const LegalBulletList({super.key, required this.items});

  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == items.length - 1 ? 0 : 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text(
                    '•',
                    style: TextStyle(
                      fontSize: 18,
                      height: 1.4,
                      color: _legalPageInk,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DefaultTextStyle(
                    style: AppFonts.manrope(
                      fontSize: 15,
                      height: 1.7,
                      color: _legalPageInk,
                    ),
                    child: items[i],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class LegalActionButtons extends StatelessWidget {
  const LegalActionButtons({
    super.key,
    required this.primaryLabel,
    required this.primaryOnPressed,
    required this.secondaryLabel,
    required this.secondaryOnPressed,
  });

  final String primaryLabel;
  final VoidCallback primaryOnPressed;
  final String secondaryLabel;
  final VoidCallback secondaryOnPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _LegalButton(
          label: primaryLabel,
          onPressed: primaryOnPressed,
          backgroundColor: _legalPageAccent,
          borderColor: _legalPageAccent,
          foregroundColor: Colors.white,
        ),
        _LegalButton(
          label: secondaryLabel,
          onPressed: secondaryOnPressed,
          backgroundColor: Colors.white,
          borderColor: _legalPageButtonLine,
          foregroundColor: _legalPageInk,
        ),
      ],
    );
  }
}

class _LegalButton extends StatelessWidget {
  const _LegalButton({
    required this.label,
    required this.onPressed,
    required this.backgroundColor,
    required this.borderColor,
    required this.foregroundColor,
  });

  final String label;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color borderColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
            child: Center(
              child: Text(
                label,
                style: AppFonts.manrope(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.15,
                  color: foregroundColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
