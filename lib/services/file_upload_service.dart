import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

/// Загружает видео, аудио и документы через Cloudflare Worker в Filebase.
/// Возвращает URL Worker, по которому файл можно скачать.
class FileUploadService {
  static const String _workerUrl =
      'https://pipisgram-media.burmaldat199.workers.dev';

  static Future<String?> uploadFile(String filePath, String fileName) async {
    try {
      final bytes = await File(filePath).readAsBytes();
      final contentType = _contentType(fileName);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return null;

      final token = await user.getIdToken(true);
      if (token == null || token.isEmpty) return null;

      final uri = Uri.parse('$_workerUrl/upload').replace(
        queryParameters: {'filename': fileName},
      );

      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': contentType,
              'Authorization': 'Bearer $token',
            },
            body: bytes,
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () {
              throw TimeoutException('Загрузка заняла слишком много времени');
            },
          );

      if (response.statusCode != 200) return null;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['ok'] != true || data['key'] is! String) return null;

      return Uri.parse('$_workerUrl/file').replace(
        queryParameters: {'key': data['key'] as String},
      ).toString();
    } catch (e) {
      return null;
    }
  }

  static String _contentType(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;

    const types = {
      'mp4': 'video/mp4',
      'mov': 'video/quicktime',
      'webm': 'video/webm',
      'mkv': 'video/x-matroska',
      'mp3': 'audio/mpeg',
      'm4a': 'audio/mp4',
      'wav': 'audio/wav',
      'ogg': 'audio/ogg',
      'flac': 'audio/flac',
      'pdf': 'application/pdf',
      'txt': 'text/plain',
      'json': 'application/json',
      'zip': 'application/zip',
      'rar': 'application/vnd.rar',
      '7z': 'application/x-7z-compressed',
      'doc': 'application/msword',
      'docx':
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx':
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    };

    return types[extension] ?? 'application/octet-stream';
  }
}
