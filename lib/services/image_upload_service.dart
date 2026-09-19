import 'dart:convert';
import 'package:http/http.dart' as http;

/// Загружает изображения на imgBB и возвращает прямую ссылку.
class ImageUploadService {
  static const String _apiKey = '3f193a8a167fda9a821ecf1ecaaae2fc';
  static const String _uploadUrl = 'https://api.imgbb.com/1/upload';

  /// Принимает байты картинки, возвращает URL загруженного изображения
  /// или null при ошибке.
  static Future<String?> uploadImage(List<int> imageBytes) async {
    try {
      final base64Image = base64Encode(imageBytes);

      final response = await http.post(
        Uri.parse(_uploadUrl),
        body: {
          'key': _apiKey,
          'image': base64Image,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          return data['data']['url'] as String;
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}