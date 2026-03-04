import 'dart:convert';

import 'package:http/http.dart' as http;

import 'finance_backend.dart';

class ApiFinanceBackend implements FinanceBackend {
  final String baseUrl;
  final String? token;
  final http.Client _client;

  ApiFinanceBackend({required this.baseUrl, this.token, http.Client? client})
    : _client = client ?? http.Client();

  Map<String, String> _headers() {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null && token!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Uri _uri(String path) {
    final normalized = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final finalPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalized$finalPath');
  }

  @override
  Future<String> findOrCreateBank({
    required String userId,
    required BankIdentity bank,
  }) async {
    final response = await _client.post(
      _uri('/users/$userId/banks/resolve'),
      headers: _headers(),
      body: jsonEncode({
        'nombre': bank.nombre,
        'logo': bank.logo,
        'tipoCuenta': bank.tipoCuenta,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error API al resolver banco (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final id = body['id'] as String?;
    if (id == null || id.isEmpty) {
      throw Exception('La API externa no devolvio un id de banco valido');
    }

    return id;
  }

  @override
  Future<void> registerIngreso({required MovementRecordInput movement}) async {
    final response = await _client.post(
      _uri('/users/${movement.userId}/income'),
      headers: _headers(),
      body: jsonEncode({
        'bancoId': movement.bancoId,
        'bancoNombre': movement.bancoNombre,
        'bancoLogo': movement.bancoLogo,
        'tipoCuenta': movement.tipoCuenta,
        'categoria': movement.categoria,
        'descripcion': movement.descripcion,
        'monto': movement.monto,
        'fecha': movement.fecha.toIso8601String(),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Error API al registrar ingreso (${response.statusCode})',
      );
    }
  }

  @override
  Future<void> registerGasto({required MovementRecordInput movement}) async {
    if ((movement.categoriaPrincipalId ?? '').isEmpty ||
        (movement.subcategoriaId ?? '').isEmpty) {
      throw Exception(
        'Faltan categoriaPrincipalId y subcategoriaId para API externa',
      );
    }

    final response = await _client.post(
      _uri('/voucher/gasto'),
      headers: _headers(),
      body: jsonEncode({
        'monto': movement.monto,
        'categoriaPrincipalId': movement.categoriaPrincipalId,
        'subcategoriaId': movement.subcategoriaId,
        'descripcion': movement.descripcion,
        'moneda': movement.moneda,
        'fecha': _asDateOnly(movement.fecha),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error API al registrar gasto (${response.statusCode})');
    }
  }

  String _asDateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
