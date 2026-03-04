import 'package:shared_preferences/shared_preferences.dart';

import '../../models/backend_type.dart';
import '../firebase_service.dart';
import 'api_finance_backend.dart';
import 'finance_backend.dart';
import 'firebase_finance_backend.dart';

class FinanceBackendResolver {
  static const _savedBackendType = 'saved_backend_type';
  static const _defaultExternalApiBaseUrl = 'https://mnavb.free.beeceptor.com';

  static Future<void> cacheBackendType({
    required String userId,
    required BackendType backendType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('backend_type_$userId', backendType.storageValue);
    await prefs.setString(_savedBackendType, backendType.storageValue);
  }

  static Future<BackendType> resolveBackendType(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('backend_type_$userId');
    if (cached != null && cached.isNotEmpty) {
      return backendTypeFromStorage(cached);
    }

    final fallback = prefs.getString(_savedBackendType);
    if (fallback != null && fallback.isNotEmpty) {
      return backendTypeFromStorage(fallback);
    }

    final firebaseService = FirebaseService();
    final backendType = await firebaseService.getBackendTypeForUser(userId);
    await cacheBackendType(userId: userId, backendType: backendType);
    return backendType;
  }

  static Future<FinanceBackend> resolveForUser(String userId) async {
    final backendType = await resolveBackendType(userId);
    switch (backendType) {
      case BackendType.externalApi:
        final prefs = await SharedPreferences.getInstance();
        final baseUrl =
            prefs.getString('external_api_base_url')?.trim() ??
            _defaultExternalApiBaseUrl;
        final token =
            prefs.getString('external_api_token_$userId') ??
            prefs.getString('external_api_token');

        return ApiFinanceBackend(baseUrl: baseUrl, token: token);
      case BackendType.firebase:
        return FirebaseFinanceBackend();
    }
  }
}
