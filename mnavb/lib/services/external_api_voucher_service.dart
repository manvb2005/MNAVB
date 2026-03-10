import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ExternalApiBalance {
  final double saldoTotal;
  final String moneda;

  const ExternalApiBalance({required this.saldoTotal, required this.moneda});
}

class ExternalApiSubcategoria {
  final String id;
  final String nombre;

  const ExternalApiSubcategoria({required this.id, required this.nombre});
}

class ExternalApiCategoria {
  final String id;
  final String nombre;
  final List<ExternalApiSubcategoria> subcategorias;

  const ExternalApiCategoria({
    required this.id,
    required this.nombre,
    required this.subcategorias,
  });
}

class ExternalApiVoucherService {
  static const _defaultBaseUrl = 'http://52.6.118.38/sicuba/public';
  static const _defaultApiKey = 'MI_API_KEY_123';
  static const _defaultChannel = 'mobile';
  static const _txtOperationId = 801;

  final http.Client _client;

  ExternalApiVoucherService({http.Client? client})
    : _client = client ?? http.Client();

  Future<List<String>> _candidateBaseUrls() async {
    return const [_defaultBaseUrl];
  }

  Uri _uri(String base, String path) {
    final normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final finalPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalized$finalPath');
  }

  Future<Map<String, String>> _defaultGetHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final configuredApiKey = prefs.getString('external_api_key')?.trim();
    final configuredChannel = prefs.getString('external_api_channel')?.trim();

    return {
      'Accept': 'application/json',
      'X-API-KEY':
          configuredApiKey == null || configuredApiKey.isEmpty
          ? _defaultApiKey
          : configuredApiKey,
      'Channel':
          configuredChannel == null || configuredChannel.isEmpty
          ? _defaultChannel
          : configuredChannel,
    };
  }

  Future<Map<String, String>> _defaultJsonHeaders() async {
    final headers = await _defaultGetHeaders();
    return {
      ...headers,
      'Content-Type': 'application/json',
    };
  }

  Future<http.Response> _get(String path) async {
    final urls = await _candidateBaseUrls();
    final headers = await _defaultGetHeaders();
    Object? lastError;
    for (final base in urls) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          return await _client
              .get(_uri(base, path), headers: headers)
              .timeout(const Duration(seconds: 15));
        } catch (e) {
          lastError = e;
          if (attempt == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 600));
          }
        }
      }
    }

    throw Exception(_networkErrorMessage(lastError, 'consultar la API'));
  }

  Future<http.Response> _post(
    String path, {
    required Map<String, String> headers,
    required String body,
  }) async {
    final urls = await _candidateBaseUrls();
    Object? lastError;
    for (final base in urls) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          return await _client
              .post(_uri(base, path), headers: headers, body: body)
              .timeout(const Duration(seconds: 15));
        } catch (e) {
          lastError = e;
          if (attempt == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 600));
          }
        }
      }
    }

    throw Exception(_networkErrorMessage(lastError, 'enviar el voucher'));
  }

  Future<ExternalApiBalance> getBalance() async {
    final response = await _get('/balance');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _httpErrorMessage(response, action: 'consultar el balance'),
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final saldo = (body['saldoTotal'] as num?)?.toDouble() ?? 0.0;
    final moneda = (body['moneda'] as String?) ?? 'PEN';
    return ExternalApiBalance(saldoTotal: saldo, moneda: moneda);
  }

  Future<List<ExternalApiCategoria>> getCategorias() async {
    final response = await _get('/api/v1/masters');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _httpErrorMessage(response, action: 'consultar categorias'),
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final allItems = ((body['data'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();

    return allItems
        .map((map) {
          final id = (map['id_master'] as String?)?.trim() ?? '';
          final nombre = (map['master_name'] as String?)?.trim() ?? '';
          final masterCode = (map['master_code'] as String?)?.trim() ?? '';
          final masterType = (map['master_type'] as String?)?.trim() ?? '';

          if (id.isEmpty || masterCode != '0' || masterType.toLowerCase() != 'expense') {
            return null;
          }

          final subcategorias = allItems
              .where((item) => ((item['master_code'] as String?)?.trim() ?? '') == id)
              .map((item) {
                final subId = (item['id_master'] as String?)?.trim() ?? '';
                final subNombre = (item['master_name'] as String?)?.trim() ?? '';
                return ExternalApiSubcategoria(id: subId, nombre: subNombre);
              })
              .where((s) => s.id.isNotEmpty)
              .toList();

          return ExternalApiCategoria(
            id: id,
            nombre: nombre,
            subcategorias: subcategorias,
          );
        })
        .whereType<ExternalApiCategoria>()
        .toList();
  }

  Future<void> sendVoucherGasto({
    required double monto,
    required String categoriaPrincipalId,
    required String subcategoriaId,
    required String descripcion,
    required DateTime fecha,
    String moneda = 'PEN',
  }) async {
    final categoria = int.tryParse(categoriaPrincipalId) ?? categoriaPrincipalId;
    final subcategoria = int.tryParse(subcategoriaId) ?? subcategoriaId;

    final response = await _post(
      '/api/v1/detail',
      headers: await _defaultJsonHeaders(),
      body: jsonEncode({
        'txtOperationId': _txtOperationId,
        'tblDetail': [
          {
            'category': categoria,
            'subCategory': subcategoria,
            'desc': descripcion.trim(),
            'amount': monto,
          },
        ],
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _httpErrorMessage(response, action: 'enviar el voucher'),
      );
    }
  }

  String _networkErrorMessage(Object? error, String action) {
    if (error is SocketException) {
      return 'No se pudo conectar con la API. Verifica internet y el servidor.';
    }
    if (error is HttpException) {
      return 'Hubo un problema de red al $action. Intenta nuevamente.';
    }
    if (error is HandshakeException) {
      return 'Fallo de seguridad SSL/TLS al conectar con la API.';
    }
    return 'No se pudo $action por un problema de conexion.';
  }

  String _httpErrorMessage(http.Response response, {required String action}) {
    final statusCode = response.statusCode;
    final apiMessage = _extractApiMessage(response.body);
    switch (statusCode) {
      case 400:
        return apiMessage ?? 'Solicitud invalida al $action.';
      case 401:
        return apiMessage ??
            'La API rechazo la autenticacion (401). Verifica API Key y Channel.';
      case 403:
        return apiMessage ?? 'No tienes permisos para esta operacion (403).';
      case 404:
        return apiMessage ?? 'No se encontro el endpoint solicitado (404).';
      case 408:
        return 'Tiempo de espera agotado al $action.';
      case 422:
        return apiMessage ?? 'Datos invalidos para $action (422).';
      case 429:
        return apiMessage ?? 'Demasiadas solicitudes. Intenta en unos segundos.';
      default:
        if (statusCode >= 500) {
          return apiMessage ??
              'La API esta con problemas internos ($statusCode). Intenta mas tarde.';
        }
        return apiMessage ?? 'Error HTTP $statusCode al $action.';
    }
  }

  String? _extractApiMessage(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        final message = (decoded['message'] as String?)?.trim();
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
    } catch (_) {
      return null;
    }
    return null;
  }

}
