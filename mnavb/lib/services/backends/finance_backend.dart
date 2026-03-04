class BankIdentity {
  final String nombre;
  final String logo;
  final String tipoCuenta;

  const BankIdentity({
    required this.nombre,
    required this.logo,
    required this.tipoCuenta,
  });
}

class MovementRecordInput {
  final String userId;
  final String bancoId;
  final String bancoNombre;
  final String bancoLogo;
  final String tipoCuenta;
  final String categoria;
  final String? descripcion;
  final String? categoriaPrincipalId;
  final String? subcategoriaId;
  final String moneda;
  final double monto;
  final DateTime fecha;

  const MovementRecordInput({
    required this.userId,
    required this.bancoId,
    required this.bancoNombre,
    required this.bancoLogo,
    required this.tipoCuenta,
    required this.categoria,
    required this.descripcion,
    this.categoriaPrincipalId,
    this.subcategoriaId,
    this.moneda = 'PEN',
    required this.monto,
    required this.fecha,
  });
}

abstract class FinanceBackend {
  Future<String> findOrCreateBank({
    required String userId,
    required BankIdentity bank,
  });

  Future<void> registerIngreso({required MovementRecordInput movement});

  Future<void> registerGasto({required MovementRecordInput movement});
}
