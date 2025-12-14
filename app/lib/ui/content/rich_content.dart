// ignore_for_file: public_member_api_docs

import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:url_launcher/url_launcher.dart';

class AppRichContent extends StatelessWidget {
  const AppRichContent({super.key, required this.content, this.onTapUrl});

  final String content;
  final Future<bool> Function(String url)? onTapUrl;

  @override
  Widget build(BuildContext context) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return const SizedBox.shrink();
    }

    final tokens = DesignTokensTheme.of(context);
    final theme = Theme.of(context);
    final baseTextStyle = theme.textTheme.bodyMedium ?? const TextStyle();

    final resolvedTap = onTapUrl ?? (url) => _openExternalUrl(url);

    if (_looksLikeHtml(trimmed)) {
      return HtmlWidget(
        trimmed,
        textStyle: baseTextStyle,
        onTapUrl: (url) async => resolvedTap(url),
      );
    }

    return MarkdownBody(
      data: trimmed,
      selectable: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        p: baseTextStyle,
        a: baseTextStyle.copyWith(
          color: tokens.colors.primary,
          decoration: TextDecoration.underline,
        ),
        blockquoteDecoration: BoxDecoration(
          color: tokens.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(tokens.radii.sm),
        ),
        codeblockDecoration: BoxDecoration(
          color: tokens.colors.surfaceVariant,
          borderRadius: BorderRadius.circular(tokens.radii.sm),
        ),
      ),
      onTapLink: (text, href, title) async {
        if (href == null || href.trim().isEmpty) return;
        await resolvedTap(href);
      },
      sizedImageBuilder: (config) {
        final url = config.uri.toString();
        return Padding(
          padding: EdgeInsets.symmetric(vertical: tokens.spacing.sm),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(tokens.radii.md),
            child: Image.network(
              url,
              fit: BoxFit.cover,
              width: config.width,
              height: config.height,
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: tokens.colors.surfaceVariant,
                alignment: Alignment.center,
                child: Icon(
                  Icons.broken_image_outlined,
                  color: tokens.colors.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

bool _looksLikeHtml(String content) {
  final tag = RegExp(r'<[a-zA-Z][^>]*>');
  return tag.hasMatch(content);
}

Future<bool> _openExternalUrl(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  return launchUrl(uri, mode: LaunchMode.externalApplication);
}
