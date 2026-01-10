// ignore_for_file: public_member_api_docs

import 'dart:convert';

import 'package:app/core/routing/navigation_controller.dart';
import 'package:app/features/howto/data/models/howto_models.dart';
import 'package:app/features/howto/view_model/howto_view_model.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:app/theme/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:miniriverpod/miniriverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

class HowtoVideoPlayerPage extends ConsumerStatefulWidget {
  const HowtoVideoPlayerPage({
    super.key,
    required this.video,
    required this.ccLangPref,
  });

  final HowtoVideo video;
  final String ccLangPref;

  @override
  ConsumerState<HowtoVideoPlayerPage> createState() =>
      _HowtoVideoPlayerPageState();
}

class _HowtoVideoPlayerPageState extends ConsumerState<HowtoVideoPlayerPage> {
  late final WebViewController _controller;
  bool _sentStarted = false;
  bool _sentCompleted = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel(
        'Howto',
        onMessageReceived: (message) {
          final data = message.message.trim().toLowerCase();
          if (data == 'playing' && !_sentStarted) {
            _sentStarted = true;
            ref.invoke(howtoViewModel.trackVideoStarted(video: widget.video));
          }
          if (data == 'ended' && !_sentCompleted) {
            _sentCompleted = true;
            ref.invoke(howtoViewModel.trackVideoCompleted(video: widget.video));
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) return NavigationDecision.prevent;
            if (uri.host.endsWith('youtube.com') ||
                uri.host.endsWith('youtu.be')) {
              return NavigationDecision.navigate;
            }
            _openExternal(uri);
            return NavigationDecision.prevent;
          },
        ),
      );

    final videoId = _extractYoutubeVideoId(widget.video.youtubeUrl);
    if (videoId == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final uri = Uri.tryParse(widget.video.youtubeUrl.trim());
        if (uri != null && uri.hasScheme) {
          _openExternal(uri);
        }
        if (mounted) context.pop();
      });
      return;
    }

    _controller.loadHtmlString(
      _youtubePlayerHtml(videoId: videoId, ccLangPref: widget.ccLangPref),
      baseUrl: 'https://www.youtube.com',
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = DesignTokensTheme.of(context);
    final gates = ref.watch(appExperienceGatesProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.video.title(prefersEnglish: gates.prefersEnglish)),
        leading: IconButton(
          tooltip: gates.prefersEnglish ? 'Back' : '戻る',
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Expanded(child: WebViewWidget(controller: _controller)),
          Container(
            width: double.infinity,
            color: tokens.colors.surface,
            padding: EdgeInsets.all(tokens.spacing.lg),
            child: Text(
              widget.video.summary(prefersEnglish: gates.prefersEnglish),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternal(Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Ignore: external navigation should be best-effort.
    }
  }
}

String? _extractYoutubeVideoId(String url) {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;

  if (uri.host == 'youtu.be') {
    final id = uri.pathSegments.isEmpty ? null : uri.pathSegments.first;
    return (id == null || id.isEmpty) ? null : id;
  }

  if (uri.host.endsWith('youtube.com')) {
    final v = uri.queryParameters['v'];
    if (v != null && v.isNotEmpty) return v;
    final segments = uri.pathSegments;
    final embedIndex = segments.indexOf('embed');
    if (embedIndex != -1 && embedIndex + 1 < segments.length) {
      final id = segments[embedIndex + 1];
      return id.isEmpty ? null : id;
    }
  }

  return null;
}

String _youtubePlayerHtml({
  required String videoId,
  required String ccLangPref,
}) {
  final safeId = jsonEncode(videoId);
  final safeCc = jsonEncode(ccLangPref);
  return '''
<!DOCTYPE html>
<html>
  <head>
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
      html, body { margin: 0; padding: 0; background: #000; height: 100%; }
      #player { position: absolute; top: 0; left: 0; right: 0; bottom: 0; }
    </style>
  </head>
  <body>
    <div id="player"></div>
    <script src="https://www.youtube.com/iframe_api"></script>
    <script>
      var player;
      function onYouTubeIframeAPIReady() {
        player = new YT.Player('player', {
          height: '100%',
          width: '100%',
          videoId: $safeId,
          playerVars: {
            'playsinline': 1,
            'cc_load_policy': 1,
            'cc_lang_pref': $safeCc,
            'rel': 0,
            'modestbranding': 1
          },
          events: {
            'onStateChange': onPlayerStateChange
          }
        });
      }
      function onPlayerStateChange(event) {
        if (event.data === YT.PlayerState.PLAYING) {
          Howto.postMessage('playing');
        }
        if (event.data === YT.PlayerState.ENDED) {
          Howto.postMessage('ended');
        }
      }
    </script>
  </body>
</html>
''';
}
