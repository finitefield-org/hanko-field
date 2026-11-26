import 'package:flutter/widgets.dart';

import '../../app/theme/app_theme.dart';

/// Shared page-edge spacing.
///
/// The app shell keeps every page below the status bar, so a screen only adds
/// a small gap above its header. At the bottom, a page that is not covered by
/// the tab bar extends under the system gesture area and adds that inset to
/// its scroll padding.
abstract final class HankoPageInsets {
  /// Gap above a page that opens with a large, start-aligned title.
  static const titleTop = 16.0;

  /// Gap above a page whose header is a back button with a centered title.
  static const headerTop = 8.0;

  /// Bottom scroll padding that clears the system gesture area when the page
  /// reaches the bottom edge of the screen.
  static double bottom(BuildContext context) {
    final inset = MediaQuery.paddingOf(context).bottom;
    return inset > 0 ? inset + HankoSpacing.md : HankoSpacing.xl;
  }
}
