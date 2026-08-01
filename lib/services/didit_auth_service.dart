import 'package:cloud_functions/cloud_functions.dart';

class DiditAuthService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  static Future<void> sendOTP(String phone) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('sendTwilioOtp');
      await callable.call(<String, dynamic>{
        'phone': phone,
      });
    } catch (e) {
      throw Exception('Failed to send OTP via Twilio: $e');
    }
  }

  static Future<String> verifyOTP(String phone, String code) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('verifyTwilioOtp');
      final response = await callable.call(<String, dynamic>{
        'phone': phone,
        'code': code,
      });

      if (response.data['success'] == true) {
        return response.data['customToken'];
      } else {
        throw Exception('Invalid OTP code.');
      }
    } catch (e) {
      throw Exception('Failed to verify OTP via Twilio: $e');
    }
  }
}
