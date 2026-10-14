import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:todo_and_lock/models/todo_model.dart';

/// Native journal is shared by the main and overlay engines. Only the main
/// engine writes Hive; billing records a verified outcome before closing UI.
class LockBridge {
  static const channel = MethodChannel('todolock/lock');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static const productId = String.fromEnvironment(
    'GIVE_UP_PRODUCT_ID',
    defaultValue: 'give_up_unlock',
  );
  static const publicKey = String.fromEnvironment('PLAY_BILLING_PUBLIC_KEY');

  static String sessionId(Todo todo) =>
      '${todo.id}|${todo.checkTime!.millisecondsSinceEpoch}';
  static Future<void> begin(Todo todo) async {
    await channel.invokeMethod<void>('setSession', {
      'session': sessionId(todo),
      'id': todo.id,
      'contents': todo.content,
      'date': todo.date.toIso8601String().substring(0, 10),
      'duration': todo.duration.inSeconds,
      'checkTime': todo.checkTime!.toIso8601String(),
      'endTime': todo.checkTime!.add(todo.duration).millisecondsSinceEpoch,
    });
  }

  static Future<Map<String, dynamic>?> current() async {
    if (!supported) return null;
    final data = await channel.invokeMapMethod<String, dynamic>('getSession');
    return data;
  }

  static Future<String> purchase(String session) async {
    return await channel.invokeMethod<String>('purchaseUnlock', {
          'session': session,
          'productId': productId,
          'publicKey': publicKey,
        }) ??
        'error';
  }

  static Future<void> finish(String session) =>
      channel.invokeMethod<void>('finishSession', {'session': session});
  static Future<void> rollback(String session) =>
      channel.invokeMethod<void>('rollbackSession', {'session': session});
  static Future<Map<String, dynamic>> outcomes() async {
    if (!supported) return {};
    return await channel.invokeMapMethod<String, dynamic>('getOutcomes') ?? {};
  }

  static Future<void> acknowledge(String session) =>
      channel.invokeMethod<void>('ackOutcome', {'session': session});
}
