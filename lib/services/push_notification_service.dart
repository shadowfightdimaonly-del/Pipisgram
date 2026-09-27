import 'dart:convert';
import 'package:http/http.dart' as http;

/// Отправляет push-уведомление через OneSignal REST API.
/// ВАЖНО: ключ встроен в клиент — компромисс для закрытого круга
/// пользователей (см. обсуждение рисков). Для публичного продукта
/// это нужно переносить на сервер.
class PushNotificationService {
  static const String _restApiKey =
      'os_v2_app_ufy267ljybaodbnpwtp4x5t2agu4egun7h7ebff66rk3fj2qcod63665nenhx4uko5jo4eow3vcm6ahm5q62gel53hhxk3ny57hc53i';
  static const String _appId = 'a171af7d-69c0-40e1-85af-b4dfcbf67a01';
  static const String _apiUrl = 'https://onesignal.com/api/v1/notifications';

  /// Отправляет пуш конкретному пользователю по его Firebase UID.
  /// Firebase UID привязан к OneSignal через OneSignal.login().
  static Future<void> sendToUser({
    required String targetUid,
    required String title,
    required String body,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'include_aliases': {
            'external_id': [targetUid],
          },
          'target_channel': 'push',
          'headings': {'en': title},
          'contents': {'en': body},
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // OneSignal отклонил запрос. Не мешаем отправке сообщения.
      }
    } catch (_) {
      // Push — не критичная функция.
    }
  }

  /// Отправляет пуш всем участникам группы, кроме отправителя.
  static Future<void> sendToGroup({
    required List<String> participantUids,
    required String excludeUid,
    required String title,
    required String body,
  }) async {
    final targets = participantUids.where((uid) => uid != excludeUid).toList();
    if (targets.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Basic $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'include_aliases': {
            'external_id': targets,
          },
          'target_channel': 'push',
          'headings': {'en': title},
          'contents': {'en': body},
        }),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        // OneSignal отклонил запрос. Не мешаем отправке сообщения.
      }
    } catch (_) {
      // Push — не критичная функция.
    }
  }
}
