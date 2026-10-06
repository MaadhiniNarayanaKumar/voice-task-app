import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../config/config.dart';

class FunctionsClient {
  static Future<http.Response> postJson(
    String functionName,
    String body, {
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final token = await FirebaseAuth.instance.currentUser?.getIdToken();
    return http
        .post(
          Uri.parse('${AppConfig.functionsUrl}/$functionName'),
          headers: {
            'Content-Type': 'application/json',
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: body,
        )
        .timeout(timeout);
  }
}
