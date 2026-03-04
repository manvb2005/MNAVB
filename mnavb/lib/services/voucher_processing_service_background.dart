import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../models/voucher_model.dart';

/// Servicio para procesar vouchers de pago usando OCR
class VoucherProcessingService {
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// Procesa una imagen de voucher y extrae la información
  Future<VoucherModel?> procesarVoucher(String imagePath) async {
    try {
      // Leer la imagen
      final inputImage = InputImage.fromFilePath(imagePath);
      
      // Procesar con OCR
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);
      
      // Extraer todo el texto (MANTENER ORIGINAL, no convertir a lowercase aquí)
      final texto = recognizedText.text;
      
      print('=== TEXTO EXTRAÍDO DEL VOUCHER ===');
      print(texto);
      print('===================================');
      
      // Detectar el tipo de transacción y banco
      final resultado = _analizarTexto(texto);
      
      return resultado;
    } catch (e) {
      print('Error procesando voucher: $e');
      return null;
    }
  }

  /// Procesa un voucher desde un URI compartido y lo guarda directamente en Firestore
  /// Esta función es usada desde el WorkManager (background)
  Future<VoucherProcessResult> processSharedUri(String uriString) async {
    try {
      // Convertir el URI a path de archivo
      String filePath;
      
      if (uriString.startsWith('file://')) {
        // Extraer el path del file:// URI
        final uri = Uri.parse(uriString);
        filePath = uri.toFilePath();
      } else {
        // Asumir que ya es un path directo
        filePath = uriString;
      }
      
      print('📁 Ruta del archivo: $filePath');
      
      // Verificar que el archivo existe
      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('El archivo del voucher no existe: $filePath');
      }
      
      print('✅ Archivo verificado: ${await file.length()} bytes');

      // Procesar el voucher con OCR
      final voucher = await procesarVoucher(filePath);
      
      if (voucher == null) {
        throw Exception('No se pudo leer la información del voucher');
      }

      // Preparar el resultado
      final result = VoucherProcessResult(
        tipo: voucher.esGasto ? 'gasto' : 'ingreso',
        monto: voucher.monto,
        descripcion: voucher.descripcion ?? 'Sin descripción',
        fecha: voucher.fecha ?? DateTime.now(),
        bancoNombre: voucher.banco, // Mantener formato original (Yape, Plin, etc.)
        bancoLogo: _obtenerLogoBanco(voucher.banco),
        tipoCuenta: 'ahorro', // Por defecto
      );

      return result;
    } catch (e) {
      print('Error procesando URI compartido: $e');
      rethrow;
    }
  }

  /// Obtiene el logo del banco según el nombre
  String _obtenerLogoBanco(String banco) {
    switch (banco.toLowerCase()) {
      case 'yape':
        return 'https://d1yjjnpx0p53s8.cloudfront.net/styles/logo-thumbnail/s3/032021/yape.png?nfeyt9DPqyQFYu7MebAfT.qYz11ytffk&itok=vkI2T5X4';
      case 'plin':
        return 'https://images.seeklogo.com/logo-png/38/2/plin-logo-png_seeklogo-386806.png';
      case 'bcp':
        return 'https://www.epsgrau.pe/webpage/oficinavirtual/oficinas-pago/img/bcp.png';
      case 'interbank':
        return 'https://www.fabritec.pe/assets/media/logo-banco/logo-inter.png';
      case 'bbva':
        return 'https://pps.services.adobe.com/api/profile/F1913DDA5A3BC47C0A495C08@AdobeID/image/b6c20c0d-0e3c-4e8e-9b60-c02ccf1cb54d/276';
      case 'scotiabank':
        return 'https://images.icon-icons.com/2699/PNG/512/scotiabank_logo_icon_170755.png';
      default:
        return 'https://cdn-icons-png.flaticon.com/512/2830/2830284.png'; // Icono genérico de banco
    }
  }

  /// Analiza el texto extraído y determina el tipo de transacción
  VoucherModel? _analizarTexto(String texto) {
    final textoLower = texto.toLowerCase();
    
    // Detectar si es Yape
    if (textoLower.contains('yape')) {
      return _procesarYape(texto);
    }
    // Detectar Scotiabank antes de Plin (porque puede contener "plin")
    else if (textoLower.contains('scotiabank')) {
      return _procesarScotiabank(texto);
    }
    // Aquí se pueden agregar más bancos: Plin, BCP, etc
    else if (textoLower.contains('plin')) {
      return _procesarPlin(texto);
    }
    
    return null;
  }

  /// Procesa específicamente vouchers de Yape
  VoucherModel? _procesarYape(String texto) {
    final textoLower = texto.toLowerCase();
    
    // Determinar si es gasto o ingreso
    bool esGasto = false;
    String tipoTransaccion = 'desconocido';
    
    if (textoLower.contains('yapeaste')) {
      esGasto = true;
      tipoTransaccion = 'yapeaste';
    } else if (textoLower.contains('te yapearon') || textoLower.contains('recibiste')) {
      esGasto = false;
      tipoTransaccion = 'te yapearon';
    }
    
    // Extraer monto
    final monto = _extraerMonto(texto);
    if (monto == null) {
      print('No se pudo extraer el monto');
      return null;
    }
    
    // Extraer fecha
    final fecha = _extraerFecha(texto);
    
    // Extraer descripción (si existe) - IMPORTANTE: usar texto original para mantener formato
    final descripcion = _extraerDescripcion(texto);
    if (descripcion != null) {
      print('✅ Descripción encontrada: "$descripcion"');
    }
    
    // Extraer número de operación
    final numeroOperacion = _extraerNumeroOperacion(texto);
    
    return VoucherModel(
      tipoTransaccion: tipoTransaccion,
      esGasto: esGasto,
      banco: 'YAPE', // IMPORTANTE: Usar MAYÚSCULAS para coincidir con bancos predefinidos
      monto: monto,
      fecha: fecha,
      descripcion: descripcion,
      numeroOperacion: numeroOperacion,
    );
  }

  /// Procesa específicamente vouchers de Plin
  VoucherModel? _procesarPlin(String texto) {
    final textoLower = texto.toLowerCase();
    
    // Similar lógica para Plin
    bool esGasto = textoLower.contains('enviaste') || textoLower.contains('pagaste');
    
    final monto = _extraerMonto(texto);
    if (monto == null) return null;
    
    final fecha = _extraerFecha(texto);
    final descripcion = _extraerDescripcion(texto);
    
    return VoucherModel(
      tipoTransaccion: esGasto ? 'enviaste' : 'recibiste',
      esGasto: esGasto,
      banco: 'PLIN', // IMPORTANTE: Usar MAYÚSCULAS para coincidir con bancos predefinidos
      monto: monto,
      fecha: fecha,
      descripcion: descripcion,
    );
  }

  /// Procesa vouchers de Scotiabank (gastos e ingresos)
  VoucherModel? _procesarScotiabank(String texto) {
    final textoNorm = _normalizarTextoOcr(texto);

    final esIngreso = _contieneAlgunPatron(textoNorm, [
      'recibiste con plin',
      'monto recibido',
      'mopto recibido',
      'abono recibido',
    ]);
    final esGasto = _contieneAlgunPatron(textoNorm, [
      'pagaste con plin',
      'pago de servicio',
      'monto pagado',
      'monto pago',
      'debito - compras',
      'debito compras',
      'importe',
      'imporie',
    ]);

    if (!esIngreso && !esGasto) {
      return null;
    }

    final monto = _extraerMontoScoti(texto) ?? _extraerMonto(texto);
    if (monto == null) {
      return null;
    }

    final fecha = _extraerFecha(texto);
    final descripcion = _extraerDescripcionScoti(texto) ?? _extraerDescripcion(texto);
    final numeroOperacion = _extraerNumeroOperacion(texto);

    return VoucherModel(
      tipoTransaccion: esIngreso ? 'recibiste con plin' : 'pago scotiabank',
      esGasto: !esIngreso,
      banco: 'Scotiabank',
      monto: monto,
      fecha: fecha,
      descripcion: descripcion,
      numeroOperacion: numeroOperacion,
    );
  }

  double? _extraerMontoScoti(String texto) {
    final lineas = texto.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty);
    for (final linea in lineas) {
      final lineaNorm = _normalizarTextoOcr(linea);
      final esLineaMonto = _contieneAlgunPatron(lineaNorm, [
        'monto recibido',
        'mopto recibido',
        'monto pagado',
        'monto pago',
        'importe',
        'imporie',
      ]);
      if (!esLineaMonto) continue;

      final tokens = RegExp(r'(\d[\d.,]*)').allMatches(linea).map((m) => m.group(1)).whereType<String>();
      for (final token in tokens) {
        final monto = _parseMonto(token, asumirCentimosSiNoSeparador: true);
        if (monto != null && monto > 0) return monto;
      }
    }

    final patterns = [
      RegExp(r'm(?:o|0)p?t?o\s+recibido\s*:\s*s/?\s*([\d.,]+)', caseSensitive: false),
      RegExp(r'm(?:o|0)nto\s+pagad[oa]\s*:\s*s/?\s*([\d.,]+)', caseSensitive: false),
      RegExp(r'imp(?:o|0)r(?:t|i)e?\s*:\s*s/?\s*([\d.,]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(texto);
      final montoStr = match?.group(1);
      if (montoStr == null) continue;
      final monto = _parseMonto(montoStr, asumirCentimosSiNoSeparador: true);
      if (monto != null && monto > 0) return monto;
    }

    return null;
  }

  /// Extrae el monto del texto usando expresiones regulares
  double? _extraerMonto(String texto) {
    // Patrones comunes: "S/ 50", "s/50", "50.00", etc
    final patterns = [
      RegExp(r's/?\s*(\d+(?:[.,]\d{2})?)', caseSensitive: false),
      RegExp(r'(\d+(?:[.,]\d{2})?)\s*soles?', caseSensitive: false),
      RegExp(r'monto[:\s]+s/?\s*(\d+(?:[.,]\d{2})?)', caseSensitive: false),
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(texto);
      if (match != null) {
        final montoStr = match.group(1);
        if (montoStr != null) {
          final monto = _parseMonto(montoStr);
          if (monto != null) {
            print('Monto extraído: $monto');
            return monto;
          }
        }
      }
    }
    
    return null;
  }

  /// Extrae la fecha del texto
  DateTime? _extraerFecha(String texto) {
    // Buscar patrones de fecha
    // Ejemplo: "01 feb. 2026" o "01 de febrero de 2026"
    final patterns = [
      // Formato: DD mes YYYY
      RegExp(r'(\d{1,2})\s+(?:de\s+)?(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)[a-z]*\.?\s+(?:de\s+)?(\d{4})', 
             caseSensitive: false),
      // Formato: DD mes. (sin año explícito)
      RegExp(r'(\d{1,2})\s+(?:de\s+)?(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)[a-z]*\.?\s*,?',
             caseSensitive: false),
      // Formato: DD/MM/YYYY
      RegExp(r'(\d{1,2})[/-](\d{1,2})[/-](\d{4})'),
    ];
    
    final mesesMap = {
      'ene': 1, 'enero': 1,
      'feb': 2, 'febrero': 2,
      'mar': 3, 'marzo': 3,
      'abr': 4, 'abril': 4,
      'may': 5, 'mayo': 5,
      'jun': 6, 'junio': 6,
      'jul': 7, 'julio': 7,
      'ago': 8, 'agosto': 8,
      'sep': 9, 'septiembre': 9,
      'oct': 10, 'octubre': 10,
      'nov': 11, 'noviembre': 11,
      'dic': 12, 'diciembre': 12,
    };
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(texto);
      if (match != null) {
        try {
          if (pattern == patterns[0]) {
            // Formato con nombre de mes
            final dia = int.parse(match.group(1)!);
            final mesStr = match.group(2)!.toLowerCase();
            final anio = int.parse(match.group(3)!);
            final mes = mesesMap[mesStr] ?? 1;
            
            // Buscar hora
            final hora = _extraerHora(texto);
            
            return DateTime(anio, mes, dia, hora?.$1 ?? 0, hora?.$2 ?? 0);
          } else if (pattern == patterns[1]) {
            final dia = int.parse(match.group(1)!);
            final mesStr = match.group(2)!.toLowerCase();
            final mes = mesesMap[mesStr] ?? 1;
            final anio = DateTime.now().year;

            final hora = _extraerHora(texto);
            return DateTime(anio, mes, dia, hora?.$1 ?? 0, hora?.$2 ?? 0);
          } else {
            // Formato DD/MM/YYYY
            final dia = int.parse(match.group(1)!);
            final mes = int.parse(match.group(2)!);
            final anio = int.parse(match.group(3)!);
            
            final hora = _extraerHora(texto);
            return DateTime(anio, mes, dia, hora?.$1 ?? 0, hora?.$2 ?? 0);
          }
        } catch (e) {
          print('Error parseando fecha: $e');
        }
      }
    }
    
    // Si no se encuentra fecha, usar la actual
    return DateTime.now();
  }

  /// Extrae la hora del texto
  (int, int)? _extraerHora(String texto) {
    // Buscar patrones de hora: "09:39 a. m." o "21:30"
    final patterns = [
      RegExp(r'(\d{1,2}):(\d{2})\s*(?:a\.?\s*m\.?|p\.?\s*m\.?)?', caseSensitive: false),
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(texto);
      if (match != null) {
        try {
          int hora = int.parse(match.group(1)!);
          final minuto = int.parse(match.group(2)!);
          
          // Verificar si es PM
          if (texto.contains(RegExp(r'${hora}:${minuto}.*?p\.?\s*m\.?', caseSensitive: false))) {
            if (hora != 12) hora += 12;
          } else if (texto.contains(RegExp(r'${hora}:${minuto}.*?a\.?\s*m\.?', caseSensitive: false))) {
            if (hora == 12) hora = 0;
          }
          
          return (hora, minuto);
        } catch (e) {
          print('Error parseando hora: $e');
        }
      }
    }
    
    return null;
  }

  /// Extrae la descripción/mensaje del voucher
  String? _extraerDescripcion(String texto) {
    final lineas = texto.split('\n').map((l) => l.trim()).toList();
    
    // --- PATRÓN 1: Mensaje de Yape (después de la fecha y antes de "CÓDIGO DE SEGURIDAD") ---
    // En Yape, el mensaje aparece después de la fecha/hora y antes de "código de seguridad"
    int indiceFecha = -1;
    int indiceCodigo = -1;
    
    // Buscar índice de la línea con fecha/hora (ej: "A 03 feb. 2026 IO 11:49 p. m.")
    for (int i = 0; i < lineas.length; i++) {
      final lineaLower = lineas[i].toLowerCase();
      if (RegExp(r'\d{1,2}\s+(ene|feb|mar|abr|may|jun|jul|ago|sep|oct|nov|dic)').hasMatch(lineaLower) ||
          RegExp(r'\d{1,2}:\d{2}\s*[ap]\.?\s*m\.?').hasMatch(lineaLower)) {
        indiceFecha = i;
      }
      
      // Buscar índice de "CÓDIGO DE SEGURIDAD" o "DATOS DE LA TRANSACCIÓN"
      if (lineaLower.contains('código') || lineaLower.contains('códig') || 
          lineaLower.contains('seguridad') || lineaLower.contains('datos')) {
        indiceCodigo = i;
        break;
      }
    }
    
    // Si encontramos ambos, el mensaje está entre ellos
    if (indiceFecha >= 0 && indiceCodigo >= 0 && indiceCodigo > indiceFecha + 1) {
      // Buscar la primera línea válida después de la fecha y antes del código
      for (int j = indiceFecha + 1; j < indiceCodigo; j++) {
        final candidato = lineas[j].trim();
        final candidatoLower = candidato.toLowerCase();
        
        // Ignorar líneas que sean solo números, asteriscos o información técnica
        if (candidato.isEmpty || 
            candidatoLower == 'yape' ||
            candidatoLower == 'destino' ||
            RegExp(r'^[\d\s\*\-\+\=]+$').hasMatch(candidato) ||
            RegExp(r'^\*+\s*\*+\s*\d+$').hasMatch(candidato)) {
          continue;
        }
        
        // Esta es la línea del mensaje
        print('📝 Descripción extraída (Yape): "$candidato"');
        return candidato;
      }
    }
    
    // --- PATRÓN 2: Palabras clave explícitas (para otros bancos) ---
    final patterns = [
      RegExp(r'descripci[oó]n[:\s]+([^\n]+)', caseSensitive: false),
      RegExp(r'concepto[:\s]+([^\n]+)', caseSensitive: false),
      RegExp(r'motivo[:\s]+([^\n]+)', caseSensitive: false),
      RegExp(r'referencia[:\s]+([^\n]+)', caseSensitive: false),
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(texto);
      if (match != null) {
        final desc = match.group(1)?.trim();
        if (desc != null && desc.isNotEmpty) {
          print('📝 Descripción extraída (patrón): "$desc"');
          return desc;
        }
      }
    }
    
    print('⚠️ No se pudo extraer descripción');
    return null;
  }

  String? _extraerDescripcionScoti(String texto) {
    final lineas = texto
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    for (int i = 0; i < lineas.length; i++) {
      if (lineas[i].toLowerCase().contains('scotiabank') && i + 1 < lineas.length) {
        final titulo = lineas[i + 1];
        if (!_esLineaTecnicaScoti(titulo)) {
          return titulo;
        }
      }
    }

    final patterns = [
      RegExp(r'detalle\s*/\s*nro\.\s*factura\s*:\s*([^\n]+)', caseSensitive: false),
      RegExp(r'descripci[oó]n\s+de\s+la\s+operaci[oó]n\s*:\s*([^\n]+)', caseSensitive: false),
      RegExp(r'servicio\s*:\s*([^\n]+)', caseSensitive: false),
      RegExp(r'empresa\s+o\s+instituci[oó]n\s*:\s*([^\n]+)', caseSensitive: false),
      RegExp(r'enviado\s+por\s*:\s*([^\n]+)', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(texto);
      final desc = match?.group(1)?.trim();
      if (desc != null && desc.isNotEmpty) return desc;
    }

    return null;
  }

  bool _esLineaTecnicaScoti(String texto) {
    final t = texto.toLowerCase();
    if (t.contains('número de operación') || t.contains('numero de operacion')) return true;
    if (t.contains('importe') || t.contains('monto')) return true;
    if (t.contains('detalle') || t.contains('sucursal')) return true;
    if (t.contains('tipo de operación') || t.contains('tipo de operacion')) return true;
    return false;
  }

  String _normalizarTextoOcr(String texto) {
    return texto
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('é', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('0', 'o');
  }

  bool _contieneAlgunPatron(String texto, List<String> patrones) {
    for (final patron in patrones) {
      if (texto.contains(patron)) return true;
    }
    return false;
  }

  double? _parseMonto(String valor, {bool asumirCentimosSiNoSeparador = false}) {
    var s = valor.replaceAll(RegExp(r'[^\d.,]'), '');
    if (s.isEmpty) return null;

    final lastDot = s.lastIndexOf('.');
    final lastComma = s.lastIndexOf(',');

    if (lastDot != -1 && lastComma != -1) {
      final decimalEsPunto = lastDot > lastComma;
      if (decimalEsPunto) {
        s = s.replaceAll(',', '');
      } else {
        s = s.replaceAll('.', '');
        s = s.replaceAll(',', '.');
      }
    } else if (lastComma != -1) {
      final decimales = s.length - lastComma - 1;
      if (decimales == 2) {
        s = s.replaceAll(',', '.');
      } else {
        s = s.replaceAll(',', '');
      }
    } else if (lastDot != -1) {
      final decimales = s.length - lastDot - 1;
      if (decimales != 2) {
        s = s.replaceAll('.', '');
      }
    } else if (asumirCentimosSiNoSeparador && s.length >= 3) {
      final entero = int.tryParse(s);
      if (entero != null) return entero / 100.0;
    }

    return double.tryParse(s);
  }

  /// Extrae el número de operación
  String? _extraerNumeroOperacion(String texto) {
    final patterns = [
      RegExp(r'n[úu]mero?\s+de\s+operaci[oó]n[:\s]+(\d+)', caseSensitive: false),
      RegExp(r'nro\.?\s+operaci[oó]n[:\s]+(\d+)', caseSensitive: false),
      RegExp(r'operaci[oó]n[:\s]+(\d+)', caseSensitive: false),
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(texto);
      if (match != null) {
        return match.group(1);
      }
    }
    
    return null;
  }

  /// Libera los recursos
  void dispose() {
    _textRecognizer.close();
  }
}

/// Resultado del procesamiento de un voucher
class VoucherProcessResult {
  final String tipo; // 'gasto' o 'ingreso'
  final double monto;
  final String descripcion;
  final DateTime fecha;
  final String bancoNombre;
  final String bancoLogo;
  final String tipoCuenta;
  
  // ID del banco en Firestore (se buscará o creará automáticamente)
  String? bancoId;

  VoucherProcessResult({
    required this.tipo,
    required this.monto,
    required this.descripcion,
    required this.fecha,
    required this.bancoNombre,
    required this.bancoLogo,
    required this.tipoCuenta,
    this.bancoId,
  });
}
