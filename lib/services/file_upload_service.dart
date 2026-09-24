import 'dart:async';
import 'package:http/http.dart' as http;

/// Загружает файлы (видео, аудио, документы) на catbox.moe — бесплатный
/// хостинг файлов без регистрации и API-ключа. Возвращает прямую ссылку.
class FileUploadService {
  static const String _uploadUrl = 'https://catbox.moe/user/api.php';

  static Future<String?> uploadFile(String filePath, String fileName) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));
      request.fields['reqtype'] = 'fileupload';
      request.files.add(
        await http.MultipartFile.fromPath('fileToUpload', filePath,
            filename: fileName),
      );

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw TimeoutException('Загрузка заняла слишком много времени');
        },
      );
      final body = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200 && body.startsWith('https://')) {
        return body.trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}