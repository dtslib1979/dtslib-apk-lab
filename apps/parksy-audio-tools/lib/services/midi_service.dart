import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

class MidiService {
  // Basic Pitch server endpoint
  static const _baseUrl = 'https://midi-converter-XXXXXX-uc.a.run.app';
  
  static final _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 3),
  ));

  /// Convert MP3 to MIDI via server
  static Future<String> convert(String mp3Path) async {
    final file = File(mp3Path);
    if (!await file.exists()) {
      throw Exception('MP3 file not found');
    }

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        mp3Path,
        filename: 'audio.mp3',
      ),
    });

    try {
      final response = await _dio.post(
        '$_baseUrl/convert',
        data: formData,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode != 200) {
        throw Exception('Server error: ${response.statusCode}');
      }

      // Save MIDI file
      final dir = await getApplicationDocumentsDirectory();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final midiPath = '${dir.path}/output_$ts.mid';

      await File(midiPath).writeAsBytes(response.data);
      return midiPath;
    } on DioException catch (e) {
      throw Exception('Network error: ${e.message}');
    }
  }
}
