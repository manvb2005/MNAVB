import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/backend_type.dart';
import '../models/user_model.dart';
import '../utils/currency_formatter.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> loginWithEmail({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
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

  Future<void> updateUserProfile({
    required String name,
    required String username,
    String? phone,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    final cleanName = name.trim();
    final cleanUsername = username.trim();
    final cleanPhone = phone?.trim();

    if (cleanName.isEmpty || cleanUsername.isEmpty) {
      throw Exception('Nombre y usuario son obligatorios');
    }

    if (cleanPhone != null &&
        cleanPhone.isNotEmpty &&
        !RegExp(r'^\d{9}$').hasMatch(cleanPhone)) {
      throw Exception('El telefono debe tener 9 digitos');
    }

    await _db.collection('Users').doc(userId).update({
      'name': cleanName,
      'username': cleanUsername,
      'phone': (cleanPhone == null || cleanPhone.isEmpty) ? null : cleanPhone,
    });
  }

  Future<BackendType> getBackendTypeForUser(String userId) async {
    final doc = await _db.collection('Users').doc(userId).get();
    if (!doc.exists) return BackendType.firebase;

    final data = doc.data();
    return backendTypeFromStorage(data?['backendType'] as String?);
  }

  Future<BackendType> getCurrentUserBackendType() async {
    final userId = currentUserId;
    if (userId == null) return BackendType.firebase;
    return getBackendTypeForUser(userId);
  }

  User? get currentUser => _auth.currentUser;

  String? get currentUserId => _auth.currentUser?.uid;

  static const double _epsilon = 0.000001;

  void _validarMontoPositivo(double monto, {String campo = 'monto'}) {
    if (!monto.isFinite || monto <= 0) {
      throw Exception('El $campo debe ser mayor a cero');
    }
  }

  void _validarSaldoNoNegativo(double saldo) {
    if (!saldo.isFinite || saldo < 0) {
      throw Exception('El saldo inicial no puede ser negativo');
    }
  }

  double _sanitizarSaldo(num? raw) {
    final value = raw?.toDouble() ?? 0.0;
    if (!value.isFinite || value < 0) return 0.0;
    return value;
  }

  double _sanitizarMonto(num? raw) {
    final value = raw?.toDouble() ?? 0.0;
    if (!value.isFinite) return 0.0;
    return value.abs();
  }

  Map<String, dynamic> _sanitizarBancoData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    sanitized['saldo'] = _sanitizarSaldo(sanitized['saldo'] as num?);
    return sanitized;
  }

  Map<String, dynamic> _sanitizarMovimientoData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    if (sanitized.containsKey('monto')) {
      sanitized['monto'] = _sanitizarMonto(sanitized['monto'] as num?);
    }
    return sanitized;
  }

  Map<String, dynamic> _sanitizarTarjetaData(Map<String, dynamic> data) {
    final sanitized = Map<String, dynamic>.from(data);
    sanitized['lineaCredito'] = _sanitizarSaldo(sanitized['lineaCredito'] as num?);
    sanitized['deudaActual'] = _sanitizarSaldo(sanitized['deudaActual'] as num?);
    sanitized['pagoMinimo'] = _sanitizarSaldo(sanitized['pagoMinimo'] as num?);
    return sanitized;
  }

  // ===================== BANCOS =====================

  // ===================== TARJETAS CREDITO =====================

  Stream<List<Map<String, dynamic>>> getTarjetasCreditoStream() {
    final userId = currentUserId;
    if (userId == null) return Stream.value([]);

    return _db
        .collection('Users')
        .doc(userId)
        .collection('TarjetasCredito')
        .orderBy('fechaCreacion', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ..._sanitizarTarjetaData(doc.data())})
              .toList(),
        );
  }

  Future<void> agregarTarjetaCredito({
    required String bancoNombre,
    required String bancoLogo,
    required String numeroTarjeta,
    required String cvv,
    required String fechaCaducidad,
    required String nombreTitular,
    required String dniTitular,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    final cleanNumber = numeroTarjeta.replaceAll(RegExp(r'\D'), '');
    final cleanCvv = cvv.replaceAll(RegExp(r'\D'), '');
    final cleanName = nombreTitular.trim();
    final cleanDni = dniTitular.replaceAll(RegExp(r'\D'), '');
    final cleanExpiry = fechaCaducidad.trim();

    if (cleanNumber.length < 13 || cleanNumber.length > 19) {
      throw Exception('Numero de tarjeta invalido');
    }
    if (cleanCvv.length < 3 || cleanCvv.length > 4) {
      throw Exception('CVV invalido');
    }
    if (!RegExp(r'^(0[1-9]|1[0-2])\/\d{2}$').hasMatch(cleanExpiry)) {
      throw Exception('Fecha de caducidad invalida');
    }
    if (cleanName.isEmpty) {
      throw Exception('Nombre del titular es obligatorio');
    }
    if (!RegExp(r'^\d{8}$').hasMatch(cleanDni)) {
      throw Exception('DNI invalido');
    }

    await _db.collection('Users').doc(userId).collection('TarjetasCredito').add({
      'bancoNombre': bancoNombre,
      'bancoLogo': bancoLogo,
      'numeroTarjeta': cleanNumber,
      'cvv': cleanCvv,
      'fechaCaducidad': cleanExpiry,
      'nombreTitular': cleanName,
      'dniTitular': cleanDni,
      'diaCorte': null,
      'diaPago': null,
      'lineaCredito': 0.0,
      'deudaActual': 0.0,
      'pagoMinimo': 0.0,
      'fechaCreacion': FieldValue.serverTimestamp(),
      'fechaActualizacion': FieldValue.serverTimestamp(),
    });
  }

  Future<void> actualizarInfoTarjetaCredito({
    required String tarjetaId,
    int? diaCorte,
    int? diaPago,
    required double lineaCredito,
    required double deudaActual,
    required double pagoMinimo,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    if (diaCorte != null && (diaCorte < 1 || diaCorte > 31)) {
      throw Exception('Dia de corte invalido');
    }
    if (diaPago != null && (diaPago < 1 || diaPago > 31)) {
      throw Exception('Dia de pago invalido');
    }
    _validarSaldoNoNegativo(lineaCredito);
    _validarSaldoNoNegativo(deudaActual);
    _validarSaldoNoNegativo(pagoMinimo);

    await _db
        .collection('Users')
        .doc(userId)
        .collection('TarjetasCredito')
        .doc(tarjetaId)
        .update({
          'diaCorte': diaCorte,
          'diaPago': diaPago,
          'lineaCredito': _sanitizarSaldo(lineaCredito),
          'deudaActual': _sanitizarSaldo(deudaActual),
          'pagoMinimo': _sanitizarSaldo(pagoMinimo),
          'fechaActualizacion': FieldValue.serverTimestamp(),
        });
  }

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
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ..._sanitizarBancoData(doc.data())})
              .toList(),
        );
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
    _validarSaldoNoNegativo(saldo);

    await _db.collection('Users').doc(userId).collection('Bancos').add({
      'nombre': nombre,
      'logo': logo,
      'tipoCuenta': tipoCuenta,
      'alias': alias,
      'saldo': _sanitizarSaldo(saldo),
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
    _validarSaldoNoNegativo(saldo);

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
          'saldo': _sanitizarSaldo(saldo),
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
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  ..._sanitizarMovimientoData(doc.data()),
                },
              )
              .toList(),
        );
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

    _validarMontoPositivo(monto);

    await _db.collection('Users').doc(userId).collection('Ingresos').add({
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
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  ..._sanitizarMovimientoData(doc.data()),
                },
              )
              .toList(),
        );
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

    _validarMontoPositivo(monto);

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
      throw Exception(
        'Saldo insuficiente. Saldo actual: ${formatMoney(saldoActual)}',
      );
    }

    await _db.collection('Users').doc(userId).collection('Gastos').add({
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

  /// Elimina un ingreso y revierte su efecto en el saldo del banco
  Future<void> eliminarIngreso({required String ingresoId}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    final ingresoRef = _db
        .collection('Users')
        .doc(userId)
        .collection('Ingresos')
        .doc(ingresoId);

    final ingresoDoc = await ingresoRef.get();
    if (!ingresoDoc.exists) throw Exception('Ingreso no encontrado');

    final data = ingresoDoc.data()!;
    final bancoId = data['bancoId'] as String?;
    final monto = (data['monto'] as num?)?.toDouble();

    if (bancoId == null || monto == null) {
      throw Exception('Datos del ingreso incompletos');
    }

    await ingresoRef.delete();
    await _actualizarSaldoBanco(bancoId, monto, sumar: false);
  }

  /// Elimina un gasto y revierte su efecto en el saldo del banco
  Future<void> eliminarGasto({required String gastoId}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    final gastoRef = _db
        .collection('Users')
        .doc(userId)
        .collection('Gastos')
        .doc(gastoId);

    final gastoDoc = await gastoRef.get();
    if (!gastoDoc.exists) throw Exception('Gasto no encontrado');

    final data = gastoDoc.data()!;
    final bancoId = data['bancoId'] as String?;
    final monto = (data['monto'] as num?)?.toDouble();

    if (bancoId == null || monto == null) {
      throw Exception('Datos del gasto incompletos');
    }

    await gastoRef.delete();
    await _actualizarSaldoBanco(bancoId, monto, sumar: true);
  }

  /// Actualiza el saldo de un banco (privado)
  Future<void> _actualizarSaldoBanco(
    String bancoId,
    double monto, {
    required bool sumar,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');
    _validarMontoPositivo(monto);

    final bancoRef = _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .doc(bancoId);

    await _db.runTransaction((tx) async {
      final bancoDoc = await tx.get(bancoRef);
      if (!bancoDoc.exists) throw Exception('Banco no encontrado');

      final saldoActual = _sanitizarSaldo((bancoDoc.data()?['saldo'] as num?));
      final saldoCalculado = sumar
          ? (saldoActual + monto)
          : (saldoActual - monto);

      if (saldoCalculado < -_epsilon) {
        throw Exception(
          'Operación no permitida: el saldo no puede quedar negativo',
        );
      }

      final saldoFinal = saldoCalculado < 0 ? 0.0 : saldoCalculado;
      tx.update(bancoRef, {'saldo': saldoFinal});
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
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  ..._sanitizarMovimientoData(doc.data()),
                },
              )
              .toList(),
        );
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

    _validarMontoPositivo(monto);

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

    if (!bancoOrigenDoc.exists)
      throw Exception('Banco de origen no encontrado');

    final saldoOrigen =
        (bancoOrigenDoc.data()?['saldo'] as num?)?.toDouble() ?? 0.0;
    if (saldoOrigen < monto) {
      throw Exception(
        'Saldo insuficiente en $bancoOrigenNombre. Saldo actual: ${formatMoney(saldoOrigen)}',
      );
    }

    // Verificar que banco destino existe
    final bancoDestinoDoc = await _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .doc(bancoDestinoId)
        .get();

    if (!bancoDestinoDoc.exists)
      throw Exception('Banco de destino no encontrado');

    // Registrar transferencia
    await _db.collection('Users').doc(userId).collection('Transferencias').add({
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

  /// Elimina una transferencia y revierte el movimiento en ambos bancos
  Future<void> eliminarTransferencia({required String transferenciaId}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    final transferenciaRef = _db
        .collection('Users')
        .doc(userId)
        .collection('Transferencias')
        .doc(transferenciaId);

    final transferenciaDoc = await transferenciaRef.get();
    if (!transferenciaDoc.exists)
      throw Exception('Transferencia no encontrada');

    final data = transferenciaDoc.data()!;
    final bancoOrigenId = data['bancoOrigenId'] as String?;
    final bancoDestinoId = data['bancoDestinoId'] as String?;
    final monto = (data['monto'] as num?)?.toDouble();

    if (bancoOrigenId == null || bancoDestinoId == null || monto == null) {
      throw Exception('Datos de la transferencia incompletos');
    }

    final bancoOrigenRef = _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .doc(bancoOrigenId);
    final bancoDestinoRef = _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .doc(bancoDestinoId);

    await _db.runTransaction((tx) async {
      final origenDoc = await tx.get(bancoOrigenRef);
      final destinoDoc = await tx.get(bancoDestinoRef);

      if (!origenDoc.exists || !destinoDoc.exists) {
        throw Exception('Banco origen o destino no encontrado');
      }

      final saldoDestino = _sanitizarSaldo(
        (destinoDoc.data()?['saldo'] as num?),
      );
      final saldoDestinoFinal = saldoDestino - monto;
      if (saldoDestinoFinal < -_epsilon) {
        throw Exception(
          'No se puede eliminar la transferencia: el saldo destino quedaría negativo',
        );
      }

      final saldoOrigen = _sanitizarSaldo((origenDoc.data()?['saldo'] as num?));
      tx.update(bancoOrigenRef, {'saldo': saldoOrigen + monto});
      tx.update(bancoDestinoRef, {
        'saldo': saldoDestinoFinal < 0 ? 0.0 : saldoDestinoFinal,
      });
      tx.delete(transferenciaRef);
    });
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
        .map(
          (snapshot) => snapshot.docs
              .map(
                (doc) => {
                  'id': doc.id,
                  ..._sanitizarMovimientoData(doc.data()),
                },
              )
              .toList(),
        );
  }

  /// Registra un nuevo préstamo
  Future<void> registrarPrestamo({
    String? bancoId,
    String? bancoNombre,
    String? bancoLogo,
    String? tipoCuenta,
    required String nombrePrestatario,
    required String descripcion,
    required double monto,
    required DateTime fecha,
    bool descontarSaldo = true,
    String tipoRegistro = 'reciente',
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    _validarMontoPositivo(monto);

    if (descontarSaldo) {
      if (bancoId == null ||
          bancoNombre == null ||
          bancoLogo == null ||
          tipoCuenta == null) {
        throw Exception(
          'Faltan datos del banco para registrar el préstamo reciente',
        );
      }

      // Verificar saldo suficiente
      final bancoDoc = await _db
          .collection('Users')
          .doc(userId)
          .collection('Bancos')
          .doc(bancoId)
          .get();

      if (!bancoDoc.exists) throw Exception('Banco no encontrado');

      final saldoActual =
          (bancoDoc.data()?['saldo'] as num?)?.toDouble() ?? 0.0;
      if (saldoActual < monto) {
        throw Exception(
          'Saldo insuficiente. Saldo actual: ${formatMoney(saldoActual)}',
        );
      }
    }

    await _db.collection('Users').doc(userId).collection('Prestamos').add({
      'bancoId': bancoId,
      'bancoNombre': bancoNombre,
      'bancoLogo': bancoLogo,
      'tipoCuenta': tipoCuenta,
      'nombrePrestatario': nombrePrestatario,
      'descripcion': descripcion,
      'monto': monto,
      'fecha': Timestamp.fromDate(fecha),
      'fechaCreacion': FieldValue.serverTimestamp(),
      'tipoRegistro': tipoRegistro,
    });

    if (descontarSaldo && bancoId != null) {
      // Actualizar saldo del banco (se resta porque se presta dinero)
      await _actualizarSaldoBanco(bancoId, monto, sumar: false);
    }
  }

  /// Elimina un préstamo y revierte saldo solo si era reciente
  Future<void> eliminarPrestamo({required String prestamoId}) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Usuario no autenticado');

    final prestamoRef = _db
        .collection('Users')
        .doc(userId)
        .collection('Prestamos')
        .doc(prestamoId);

    final prestamoDoc = await prestamoRef.get();
    if (!prestamoDoc.exists) throw Exception('Préstamo no encontrado');

    final data = prestamoDoc.data()!;
    final tipoRegistro = (data['tipoRegistro'] as String?) ?? 'reciente';
    final bancoId = data['bancoId'] as String?;
    final monto = (data['monto'] as num?)?.toDouble();

    if (monto == null) {
      throw Exception('Datos del préstamo incompletos');
    }

    await prestamoRef.delete();

    if (tipoRegistro != 'antiguo' && bancoId != null && bancoId.isNotEmpty) {
      await _actualizarSaldoBanco(bancoId, monto, sumar: true);
    }
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  // ===================== MÉTODOS PARA BACKGROUND (con userId explícito) =====================

  /// Obtiene la lista de bancos del usuario (no stream)
  Future<List<Map<String, dynamic>>> getBancosListConUserId(
    String userId,
  ) async {
    final snapshot = await _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .get();

    return snapshot.docs
        .map((doc) => {'id': doc.id, ..._sanitizarBancoData(doc.data())})
        .toList();
  }

  /// Agrega un banco con userId explícito (para background)
  Future<String> agregarBancoConUserId({
    required String userId,
    required String nombre,
    required String logo,
    required String tipoCuenta,
    String? alias,
    required double saldo,
  }) async {
    _validarSaldoNoNegativo(saldo);

    final docRef = await _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .add({
          'nombre': nombre,
          'logo': logo,
          'tipoCuenta': tipoCuenta,
          'alias': alias,
          'saldo': _sanitizarSaldo(saldo),
          'fechaCreacion': FieldValue.serverTimestamp(),
        });

    return docRef.id;
  }

  /// Registra un ingreso con userId explícito (para background)
  Future<void> registrarIngresoConUserId({
    required String userId,
    required String bancoId,
    required String bancoNombre,
    required String bancoLogo,
    required String tipoCuenta,
    required String categoria,
    String? descripcion,
    required double monto,
    required DateTime fecha,
  }) async {
    _validarMontoPositivo(monto);

    await _db.collection('Users').doc(userId).collection('Ingresos').add({
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
    await _actualizarSaldoBancoConUserId(userId, bancoId, monto, sumar: true);
  }

  /// Registra un gasto con userId explícito (para background)
  Future<void> registrarGastoConUserId({
    required String userId,
    required String bancoId,
    required String bancoNombre,
    required String bancoLogo,
    required String tipoCuenta,
    required String categoria,
    String? descripcion,
    required double monto,
    required DateTime fecha,
  }) async {
    _validarMontoPositivo(monto);

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
      throw Exception(
        'Saldo insuficiente. Saldo actual: ${formatMoney(saldoActual)}',
      );
    }

    await _db.collection('Users').doc(userId).collection('Gastos').add({
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
    await _actualizarSaldoBancoConUserId(userId, bancoId, monto, sumar: false);
  }

  /// Actualiza el saldo de un banco con userId explícito
  Future<void> _actualizarSaldoBancoConUserId(
    String userId,
    String bancoId,
    double monto, {
    required bool sumar,
  }) async {
    _validarMontoPositivo(monto);

    final bancoRef = _db
        .collection('Users')
        .doc(userId)
        .collection('Bancos')
        .doc(bancoId);

    await _db.runTransaction((tx) async {
      final bancoDoc = await tx.get(bancoRef);
      if (!bancoDoc.exists) throw Exception('Banco no encontrado');

      final saldoActual = _sanitizarSaldo((bancoDoc.data()?['saldo'] as num?));
      final saldoCalculado = sumar
          ? (saldoActual + monto)
          : (saldoActual - monto);

      if (saldoCalculado < -_epsilon) {
        throw Exception(
          'Operación no permitida: el saldo no puede quedar negativo',
        );
      }

      final saldoFinal = saldoCalculado < 0 ? 0.0 : saldoCalculado;
      tx.update(bancoRef, {'saldo': saldoFinal});
    });
  }
}
