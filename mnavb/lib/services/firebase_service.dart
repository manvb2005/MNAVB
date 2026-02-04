import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> createUserDocument(UserModel user) async {
    await _db.collection('Users').doc(user.id).set(user.toMap());
  }

  Future<UserModel?> getUser(String id) async {
    final doc = await _db.collection('Users').doc(id).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  User? get currentUser => _auth.currentUser;

  String? get currentUserId => _auth.currentUser?.uid;

  // ===================== BANCOS =====================
  
  /// Obtiene todos los bancos del usuario actual
  Stream<List<Map<String, dynamic>>> getBancosStream() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Agrega un nuevo banco
  Future<void> agregarBanco({
    required String nombre,
    required String logo,
    required String tipoCuenta,
    String? alias,
    required double saldo,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    await _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .add({
      'nombre': nombre,
      'logo': logo,
      'tipoCuenta': tipoCuenta,
      'alias': alias,
      'saldo': saldo,
      'fechaCreacion': FieldValue.serverTimestamp(),
    });
  }

  /// Actualiza un banco existente
  Future<void> actualizarBanco({
    required String bancoId,
    required String nombre,
    required String logo,
    required String tipoCuenta,
    String? alias,
    required double saldo,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    await _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .doc(bancoId)
        .update({
      'nombre': nombre,
      'logo': logo,
      'tipoCuenta': tipoCuenta,
      'alias': alias,
      'saldo': saldo,
    });
  }

  /// Elimina un banco
  Future<void> eliminarBanco(String bancoId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    await _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .doc(bancoId)
        .delete();
  }

  // ===================== INGRESOS =====================
  
  /// Obtiene todos los ingresos del usuario actual
  Stream<List<Map<String, dynamic>>> getIngresosStream() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _db
        .collection('Users')
        .doc(userId)
        .collection('Ingresos')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Registra un nuevo ingreso
  Future<void> registrarIngreso({
    required String bancoId,
    required String bancoNombre,
    required String bancoLogo,
    required String tipoCuenta,
    required String categoria,
    String? descripcion,
    required double monto,
    required DateTime fecha,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    if (monto <= 0) throw Exception('El monto debe ser mayor a cero');

    await _db
        .collection('Users')
        .doc(userId)
        .collection('Ingresos')
        .add({
      'bancoId': bancoId,
      'bancoNombre': bancoNombre,
      'bancoLogo': bancoLogo,
      'tipoCuenta': tipoCuenta,
      'categoria': categoria,
      'descripcion': descripcion,
      'monto': monto,
      'fecha': Timestamp.fromDate(fecha),
      'fechaCreacion': FieldValue.serverTimestamp(),
    });

    // Actualizar saldo del banco
    await _actualizarSaldoBanco(bancoId, monto, sumar: true);
  }

  // ===================== GASTOS =====================
  
  /// Obtiene todos los gastos del usuario actual
  Stream<List<Map<String, dynamic>>> getGastosStream() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _db
        .collection('Users')
        .doc(userId)
        .collection('Gastos')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Registra un nuevo gasto
  Future<void> registrarGasto({
    required String bancoId,
    required String bancoNombre,
    required String bancoLogo,
    required String tipoCuenta,
    required String categoria,
    String? descripcion,
    required double monto,
    required DateTime fecha,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    if (monto <= 0) throw Exception('El monto debe ser mayor a cero');

    // Verificar saldo suficiente
    final bancoDoc = await _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .doc(bancoId)
        .get();

    if (!bancoDoc.exists) throw Exception('Banco no encontrado');

    final saldoActual = (bancoDoc.data()?['saldo'] as num?)?.toDouble() ?? 0.0;
    if (saldoActual < monto) {
      throw Exception('Saldo insuficiente. Saldo actual: S/ ${saldoActual.toStringAsFixed(2)}');
    }

    await _db
        .collection('Users')
        .doc(userId)
        .collection('Gastos')
        .add({
      'bancoId': bancoId,
      'bancoNombre': bancoNombre,
      'bancoLogo': bancoLogo,
      'tipoCuenta': tipoCuenta,
      'categoria': categoria,
      'descripcion': descripcion,
      'monto': monto,
      'fecha': Timestamp.fromDate(fecha),
      'fechaCreacion': FieldValue.serverTimestamp(),
    });

    // Actualizar saldo del banco
    await _actualizarSaldoBanco(bancoId, monto, sumar: false);
  }

  /// Actualiza el saldo de un banco (privado)
  Future<void> _actualizarSaldoBanco(String bancoId, double monto, {required bool sumar}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    await _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .doc(bancoId)
        .update({
      'saldo': FieldValue.increment(sumar ? monto : -monto),
    });
  }

  // ===================== TRANSFERENCIAS =====================
  
  /// Obtiene todas las transferencias del usuario actual
  Stream<List<Map<String, dynamic>>> getTransferenciasStream() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _db
        .collection('Users')
        .doc(userId)
        .collection('Transferencias')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Registra una nueva transferencia
  Future<void> registrarTransferencia({
    required String bancoOrigenId,
    required String bancoOrigenNombre,
    required String bancoOrigenLogo,
    String? bancoOrigenAlias,
    required String bancoDestinoId,
    required String bancoDestinoNombre,
    required String bancoDestinoLogo,
    String? bancoDestinoAlias,
    required String descripcion,
    required double monto,
    required DateTime fecha,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    if (monto <= 0) throw Exception('El monto debe ser mayor a cero');

    if (bancoOrigenId == bancoDestinoId) {
      throw Exception('No puedes transferir al mismo banco');
    }

    // Verificar saldo suficiente en banco origen
    final bancoOrigenDoc = await _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .doc(bancoOrigenId)
        .get();

    if (!bancoOrigenDoc.exists) throw Exception('Banco de origen no encontrado');

    final saldoOrigen = (bancoOrigenDoc.data()?['saldo'] as num?)?.toDouble() ?? 0.0;
    if (saldoOrigen < monto) {
      throw Exception('Saldo insuficiente en $bancoOrigenNombre. Saldo actual: S/ ${saldoOrigen.toStringAsFixed(2)}');
    }

    // Verificar que banco destino existe
    final bancoDestinoDoc = await _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .doc(bancoDestinoId)
        .get();

    if (!bancoDestinoDoc.exists) throw Exception('Banco de destino no encontrado');

    // Registrar transferencia
    await _db
        .collection('Users')
        .doc(userId)
        .collection('Transferencias')
        .add({
      'bancoOrigenId': bancoOrigenId,
      'bancoOrigenNombre': bancoOrigenNombre,
      'bancoOrigenLogo': bancoOrigenLogo,
      'bancoOrigenAlias': bancoOrigenAlias,
      'bancoDestinoId': bancoDestinoId,
      'bancoDestinoNombre': bancoDestinoNombre,
      'bancoDestinoLogo': bancoDestinoLogo,
      'bancoDestinoAlias': bancoDestinoAlias,
      'descripcion': descripcion,
      'monto': monto,
      'fecha': Timestamp.fromDate(fecha),
      'fechaCreacion': FieldValue.serverTimestamp(),
    });

    // Actualizar saldos: restar de origen, sumar a destino
    await _actualizarSaldoBanco(bancoOrigenId, monto, sumar: false);
    await _actualizarSaldoBanco(bancoDestinoId, monto, sumar: true);
  }

  // ===================== PRÉSTAMOS =====================
  
  /// Obtiene todos los préstamos del usuario actual
  Stream<List<Map<String, dynamic>>> getPrestamosStream() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _db
        .collection('Users')
        .doc(userId)
        .collection('Prestamos')
        .orderBy('fecha', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => {'id': doc.id, ...doc.data()})
            .toList());
  }

  /// Registra un nuevo préstamo
  Future<void> registrarPrestamo({
    required String bancoId,
    required String bancoNombre,
    required String bancoLogo,
    required String tipoCuenta,
    required String nombrePrestatario,
    required String descripcion,
    required double monto,
    required DateTime fecha,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    if (monto <= 0) throw Exception('El monto debe ser mayor a cero');

    // Verificar saldo suficiente
    final bancoDoc = await _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .doc(bancoId)
        .get();

    if (!bancoDoc.exists) throw Exception('Banco no encontrado');

    final saldoActual = (bancoDoc.data()?['saldo'] as num?)?.toDouble() ?? 0.0;
    if (saldoActual < monto) {
      throw Exception('Saldo insuficiente. Saldo actual: S/ ${saldoActual.toStringAsFixed(2)}');
    }

    await _db
        .collection('Users')
        .doc(userId)
        .collection('Prestamos')
        .add({
      'bancoId': bancoId,
      'bancoNombre': bancoNombre,
      'bancoLogo': bancoLogo,
      'tipoCuenta': tipoCuenta,
      'nombrePrestatario': nombrePrestatario,
      'descripcion': descripcion,
      'monto': monto,
      'fecha': Timestamp.fromDate(fecha),
      'fechaCreacion': FieldValue.serverTimestamp(),
    });

    // Actualizar saldo del banco (se resta porque se presta dinero)
    await _actualizarSaldoBanco(bancoId, monto, sumar: false);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }
}
