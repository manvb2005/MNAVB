/// Modelo para representar un voucher procesado desde una imagen
class VoucherModel {
  final String tipoTransaccion; // 'yapeaste', 'te yapearon', 'plin', etc
  final bool esGasto; // true = gasto, false = ingreso
  final String banco; // 'Yape', 'Plin', 'BCP', etc
  final double monto;
  final DateTime? fecha;
  final String? descripcion;
  final String? numeroOperacion;
  final String? destinatario;

  VoucherModel({
    required this.tipoTransaccion,
    required this.esGasto,
    required this.banco,
    required this.monto,
    this.fecha,
    this.descripcion,
    this.numeroOperacion,
    this.destinatario,
  });

  @override
  String toString() {
    return 'VoucherModel('
        'tipo: $tipoTransaccion, '
        'esGasto: $esGasto, '
        'banco: $banco, '
        'monto: $monto, '
        'fecha: $fecha, '
        'descripcion: $descripcion'
        ')';
  }

  Map<String, dynamic> toMap() {
    return {
      'tipoTransaccion': tipoTransaccion,
      'esGasto': esGasto,
      'banco': banco,
      'monto': monto,
      'fecha': fecha?.toIso8601String(),
      'descripcion': descripcion,
      'numeroOperacion': numeroOperacion,
      'destinatario': destinatario,
    };
  }
}
