import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class PendingExternalVoucher {
  final int notificationId;
  final double monto;
  final String descripcion;
  final DateTime fecha;
  final String moneda;
  final String bancoNombre;

  const PendingExternalVoucher({
    required this.notificationId,
    required this.monto,
    required this.descripcion,
    required this.fecha,
    required this.moneda,
    required this.bancoNombre,
  });

  Map<String, dynamic> toMap() {
    return {
      'notificationId': notificationId,
      'monto': monto,
      'descripcion': descripcion,
      'fecha': fecha.toIso8601String(),
      'moneda': moneda,
      'bancoNombre': bancoNombre,
    };
  }

  factory PendingExternalVoucher.fromMap(Map<String, dynamic> map) {
    return PendingExternalVoucher(
      notificationId: (map['notificationId'] as num?)?.toInt() ?? 9999,
      monto: (map['monto'] as num?)?.toDouble() ?? 0,
      descripcion: (map['descripcion'] as String?) ?? '',
      fecha:
          DateTime.tryParse((map['fecha'] as String?) ?? '') ?? DateTime.now(),
      moneda: (map['moneda'] as String?) ?? 'PEN',
      bancoNombre: (map['bancoNombre'] as String?) ?? '',
    );
  }
}

class PendingExternalVoucherService {
  static const _key = 'pending_external_voucher';
  static const _openOverlayKey = 'pending_external_voucher_open_overlay';

  Future<void> save(PendingExternalVoucher voucher) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(voucher.toMap()));
    await prefs.setBool(_openOverlayKey, true);
  }

  Future<PendingExternalVoucher?> get() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    final map = jsonDecode(raw) as Map<String, dynamic>;
    return PendingExternalVoucher.fromMap(map);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
    await prefs.remove(_openOverlayKey);
  }

  Future<void> markOpenOverlayRequested() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_openOverlayKey, true);
  }

  Future<bool> consumeOpenOverlayRequested() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getBool(_openOverlayKey) ?? false;
    if (value) {
      await prefs.remove(_openOverlayKey);
    }
    return value;
  }
}
