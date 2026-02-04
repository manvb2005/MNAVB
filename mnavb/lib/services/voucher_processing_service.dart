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
      
      // Extraer todo el texto
      final texto = recognizedText.text.toLowerCase();
      
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

  /// Analiza el texto extraído y determina el tipo de transacción
  VoucherModel? _analizarTexto(String texto) {
    // Detectar si es Yape
    if (texto.contains('yape')) {
      return _procesarYape(texto);
    }
    // Aquí se pueden agregar más bancos: Plin, BCP, etc
    else if (texto.contains('plin')) {
      return _procesarPlin(texto);
    }
    
    return null;
  }

  /// Procesa específicamente vouchers de Yape
  VoucherModel? _procesarYape(String texto) {
    // Determinar si es gasto o ingreso
    bool esGasto = false;
    String tipoTransaccion = 'desconocido';
    
    if (texto.contains('yapeaste')) {
      esGasto = true;
      tipoTransaccion = 'yapeaste';
    } else if (texto.contains('te yapearon') || texto.contains('recibiste')) {
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
    
    // Extraer descripción (si existe)
    final descripcion = _extraerDescripcion(texto);
    
    // Extraer número de operación
    final numeroOperacion = _extraerNumeroOperacion(texto);
    
    return VoucherModel(
      tipoTransaccion: tipoTransaccion,
      esGasto: esGasto,
      banco: 'Yape',
      monto: monto,
      fecha: fecha,
      descripcion: descripcion,
      numeroOperacion: numeroOperacion,
    );
  }

  /// Procesa específicamente vouchers de Plin
  VoucherModel? _procesarPlin(String texto) {
    // Similar lógica para Plin
    bool esGasto = texto.contains('enviaste') || texto.contains('pagaste');
    
    final monto = _extraerMonto(texto);
    if (monto == null) return null;
    
    final fecha = _extraerFecha(texto);
    final descripcion = _extraerDescripcion(texto);
    
    return VoucherModel(
      tipoTransaccion: esGasto ? 'enviaste' : 'recibiste',
      esGasto: esGasto,
      banco: 'Plin',
      monto: monto,
      fecha: fecha,
      descripcion: descripcion,
    );
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
        final montoStr = match.group(1)?.replaceAll(',', '.');
        if (montoStr != null) {
          final monto = double.tryParse(montoStr);
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

  /// Extrae la descripción si existe
  String? _extraerDescripcion(String texto) {
    // Buscar después de palabras clave como "descripción", "concepto", "mensaje"
    final patterns = [
      RegExp(r'descripci[oó]n[:\s]+([^\n]+)', caseSensitive: false),
      RegExp(r'concepto[:\s]+([^\n]+)', caseSensitive: false),
      RegExp(r'mensaje[:\s]+([^\n]+)', caseSensitive: false),
    ];
    
    for (var pattern in patterns) {
      final match = pattern.firstMatch(texto);
      if (match != null) {
        final desc = match.group(1)?.trim();
        if (desc != null && desc.isNotEmpty) {
          return desc;
        }
      }
    }
    
    return null;
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
