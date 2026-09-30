import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

class ImageUploadService {
  static const String _workerUrl =
      'https://pipisgram-media.burmaldat199.workers.dev';

  static Future<String?> uploadImage(List<int> imageBytes) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) return null;

      final uri = Uri.parse('$_workerUrl/upload').replace(
        queryParameters: {'filename': 'image.jpg'},
      );

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'image/jpeg',
              'Authorization': 'Bearer $token',
            },
            body: imageBytes,
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw TimeoutException(
                'Загрузка заняла слишком много времени',
              );
            },
          );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (data['ok'] != true || data['key'] is! String) {
        return null;
      }

      return Uri.parse('$_workerUrl/file').replace(
        queryParameters: {
          'key': data['key'] as String,
        },
      ).toString();
    } catch (e) {
      return null;
    }
  }
}