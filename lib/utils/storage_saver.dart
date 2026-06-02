import 'dart:typed_data';
import 'package:flutter/services.dart';

class StorageSaver {
  static const MethodChannel _channel = MethodChannel('maxbillup/storage');

  /// Save bytes to a user-selected location (SAF) on Android. Returns the
  /// content URI string when saved, or null if the user cancels.
  static Future<String?> saveFile({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
  }) async {
    try {
      final result = await _channel.invokeMethod<String?>('saveFile', {
        'fileName': fileName,
        'mimeType': mimeType,
        'bytes': bytes,
      });
      return result;
    } on PlatformException catch (e) {
      print('StorageSaver: PlatformException: ${e.message}');
      return null;
    } catch (e) {
      print('StorageSaver: Error: $e');
      return null;
    }
  }

  /// Save bytes directly to MediaStore Downloads (no user prompt) on Android.
  /// Returns the content URI string on success, or null on failure.
  static Future<String?> saveToMediaStore({
    required Uint8List bytes,
    required String fileName,
    String mimeType = 'application/octet-stream',
    String subFolder = 'MAXmybill',
  }) async {
    try {
      final result = await _channel.invokeMethod<String?>(
        'saveToMediaStore',
        {
          'fileName': fileName,
          'mimeType': mimeType,
          'subFolder': subFolder,
          'bytes': bytes,
        },
      );
      return result;
    } on PlatformException catch (e) {
      print('StorageSaver.saveToMediaStore: PlatformException: ${e.message}');
      return null;
    } catch (e) {
      print('StorageSaver.saveToMediaStore: Error: $e');
      return null;
    }
  }

  /// Return a user-facing message describing where the file was saved.
  /// If [savedPath] is a content:// URI (MediaStore/SAF) we return a message
  /// indicating the user-selected location. Otherwise we return [fallbackMessage].
  static String locationMessageForPath(String? savedPath, {required String fallbackMessage}) {
    if (savedPath == null) return 'No file saved';
    final trimmed = savedPath.trim();
    if (trimmed.startsWith('content://')) {
      return 'Saved to the Downloads/MAXmybill';
    }
    if (trimmed.startsWith('/')) {
      return fallbackMessage;
    }
    return 'Saved successfully';
  }
}

