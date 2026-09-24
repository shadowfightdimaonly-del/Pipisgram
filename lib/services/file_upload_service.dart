import 'package:http/http.dart' as http;

class FileUploadService {
  static const String _uploadUrl = 'https://catbox.moe/user/api.php';

  static Future<String?> uploadFile(
    String filePath,
    String fileName,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(_uploadUrl),
      );

      request.fields['reqtype'] = 'fileupload';

      request.files.add(
        await http.MultipartFile.fromPath(
          'fileToUpload',
          filePath,
          filename: fileName,
        ),
      );

      final response = await request.send().timeout(
        const Duration(seconds: 60),
      );

      final body = await response.stream
          .bytesToString()
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final url = body.trim();

        if (url.startsWith('https://')) {
          return url;
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }
}