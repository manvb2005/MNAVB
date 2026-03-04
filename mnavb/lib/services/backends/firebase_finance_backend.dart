import '../firebase_service.dart';
import 'finance_backend.dart';

class FirebaseFinanceBackend implements FinanceBackend {
  final FirebaseService _firebaseService;

  FirebaseFinanceBackend({FirebaseService? firebaseService})
    : _firebaseService = firebaseService ?? FirebaseService();

  @override
  Future<String> findOrCreateBank({
    required String userId,
    required BankIdentity bank,
  }) async {
    final bancos = await _firebaseService.getBancosListConUserId(userId);
    for (final banco in bancos) {
      if (banco['nombre'].toString().toLowerCase() ==
          bank.nombre.toLowerCase()) {
        return banco['id'] as String;
      }
    }

    return _firebaseService.agregarBancoConUserId(
      userId: userId,
      nombre: bank.nombre,
      logo: bank.logo,
      tipoCuenta: bank.tipoCuenta,
      saldo: 0.0,
    );
  }

  @override
  Future<void> registerIngreso({required MovementRecordInput movement}) {
    return _firebaseService.registrarIngresoConUserId(
      userId: movement.userId,
      bancoId: movement.bancoId,
      bancoNombre: movement.bancoNombre,
      bancoLogo: movement.bancoLogo,
      tipoCuenta: movement.tipoCuenta,
      categoria: movement.categoria,
      descripcion: movement.descripcion,
      monto: movement.monto,
      fecha: movement.fecha,
    );
  }

  @override
  Future<void> registerGasto({required MovementRecordInput movement}) {
    return _firebaseService.registrarGastoConUserId(
      userId: movement.userId,
      bancoId: movement.bancoId,
      bancoNombre: movement.bancoNombre,
      bancoLogo: movement.bancoLogo,
      tipoCuenta: movement.tipoCuenta,
      categoria: movement.categoria,
      descripcion: movement.descripcion,
      monto: movement.monto,
      fecha: movement.fecha,
    );
  }
}
