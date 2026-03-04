import 'dart:convert';

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
  static const _defaultBaseUrl = 'https://mnavb.free.beeceptor.com';
  static const _legacyBaseUrl = 'https://mnavb.beeceptor.com';

  final http.Client _client;

  ExternalApiVoucherService({http.Client? client})
    : _client = client ?? http.Client();

  Future<List<String>> _candidateBaseUrls() async {
    final prefs = await SharedPreferences.getInstance();
    final configuredRaw = prefs.getString('external_api_base_url')?.trim();

    final urls = <String>[];
    if (configuredRaw != null && configuredRaw.isNotEmpty) {
      final withScheme =
          configuredRaw.startsWith('http://') ||
              configuredRaw.startsWith('https://')
          ? configuredRaw
          : 'https://$configuredRaw';

      try {
        final parsed = Uri.parse(withScheme);
        if (parsed.hasAuthority) {
          urls.add(parsed.origin);
        }
      } catch (_) {
        urls.add(withScheme);
      }
    }

    if (!urls.contains(_defaultBaseUrl)) {
      urls.add(_defaultBaseUrl);
    }

    if (!urls.contains(_legacyBaseUrl)) {
      urls.add(_legacyBaseUrl);
    }

    return urls;
  }

  Uri _uri(String base, String path) {
    final normalized = base.endsWith('/')
        ? base.substring(0, base.length - 1)
        : base;
    final finalPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$normalized$finalPath');
  }

  Future<http.Response> _get(String path) async {
    final urls = await _candidateBaseUrls();
    Object? lastError;
    for (final base in urls) {
      for (var attempt = 0; attempt < 2; attempt++) {
        try {
          return await _client
              .get(_uri(base, path))
              .timeout(const Duration(seconds: 15));
        } catch (e) {
          lastError = e;
          if (attempt == 0) {
            await Future<void>.delayed(const Duration(milliseconds: 600));
          }
        }
      }
    }

    throw Exception(
      'No se pudo conectar con la API externa. Verifica internet y URL ($lastError)',
    );
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

    throw Exception(
      'No se pudo conectar con la API externa. Verifica internet y URL ($lastError)',
    );
  }

  Future<ExternalApiBalance> getBalance() async {
    final response = await _get('/balance');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error consultando balance (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final saldo = (body['saldoTotal'] as num?)?.toDouble() ?? 0.0;
    final moneda = (body['moneda'] as String?) ?? 'PEN';
    return ExternalApiBalance(saldoTotal: saldo, moneda: moneda);
  }

  Future<List<ExternalApiCategoria>> getCategorias() async {
    final response = await _get('/categorias');
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error consultando categorias (${response.statusCode})');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final categoriasRaw = (body['categorias'] as List?) ?? const [];

    return categoriasRaw
        .map((e) {
          final map = e as Map<String, dynamic>;
          final subs = (map['subcategorias'] as List?) ?? const [];
          return ExternalApiCategoria(
            id: (map['id'] as String?) ?? '',
            nombre: (map['nombre'] as String?) ?? '',
            subcategorias: subs
                .map((s) {
                  final sm = s as Map<String, dynamic>;
                  return ExternalApiSubcategoria(
                    id: (sm['id'] as String?) ?? '',
                    nombre: (sm['nombre'] as String?) ?? '',
                  );
                })
                .where((s) => s.id.isNotEmpty)
                .toList(),
          );
        })
        .where((c) => c.id.isNotEmpty)
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
    final response = await _post(
      '/voucher/gasto',
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'monto': monto,
        'categoriaPrincipalId': categoriaPrincipalId,
        'subcategoriaId': subcategoriaId,
        'descripcion': descripcion,
        'moneda': moneda,
        'fecha': _asDateOnly(fecha),
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Error enviando voucher gasto (${response.statusCode})');
    }
  }

  String _asDateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
