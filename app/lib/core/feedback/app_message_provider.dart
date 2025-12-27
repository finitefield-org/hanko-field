// ignore_for_file: public_member_api_docs

import 'package:app/core/feedback/app_message.dart';
import 'package:app/core/feedback/app_message_controller.dart';
import 'package:miniriverpod/miniriverpod.dart';

const appMessageSinkScope = Scope<AppMessageSink>.required('app.messageSink');

final appMessageSinkProvider = Provider<AppMessageSink>((ref) {
  try {
    return ref.scope(appMessageSinkScope);
  } on StateError {
    final controller = AppMessageController();
    ref.onDispose(controller.dispose);
    return controller;
  }
});
