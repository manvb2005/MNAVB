# 📱 Sistema de Procesamiento Automático de Vouchers

## 🎯 Funcionalidad Principal

Esta aplicación ahora puede **procesar automáticamente vouchers de Yape** (y otras apps de pago) cuando los compartes desde esas aplicaciones.

### ✨ ¿Cómo funciona?

1. **Realiza un Yape** desde la app de Yape
2. **Comparte el voucher** usando el botón de compartir de Yape
3. **Selecciona MNAVB** como destino
4. **¡Listo!** La app automáticamente:
   - ✅ Detecta si es "Yapeaste" (gasto) o "Te Yapearon" (ingreso)
   - ✅ Extrae el monto (ej: S/ 50.00)
   - ✅ Extrae la fecha y hora
   - ✅ Extrae la descripción (si existe)
   - ✅ Guarda el registro automáticamente en tu banco Yape

### 📋 Requisitos Previos

**IMPORTANTE**: Para que funcione correctamente, debes:

1. **Tener un banco llamado "Yape" registrado** en la sección "Bancos" de la app
   - Nombre: "Yape" (exacto)
   - Tipo de cuenta: El que prefieras (Digital, Efectivo, etc.)
   - Logo: El que prefieras

2. **Permitir permisos** cuando la app los solicite (primera vez)

### 🚀 Uso Paso a Paso

#### 1️⃣ Primera vez - Configuración

```
1. Abre MNAVB
2. Ve a "Bancos"
3. Crea un nuevo banco:
   - Nombre: Yape
   - Tipo: Digital (recomendado)
   - Saldo inicial: Tu saldo actual
```

#### 2️⃣ Compartir un Voucher

```
1. Realiza un Yape normal
2. En la pantalla de confirmación, toca "Compartir"
3. Selecciona "MNAVB" de la lista
4. ¡Espera la notificación de éxito! ✅
```

### 🔍 Información Extraída

La app extrae automáticamente:

| Dato | Descripción | Ejemplo |
|------|-------------|---------|
| **Tipo** | Si es gasto o ingreso | "Yapeaste" = Gasto |
| **Monto** | Cantidad transferida | S/ 50.00 |
| **Fecha** | Fecha y hora de la operación | 01 feb. 2026, 09:39 a.m. |
| **Descripción** | Mensaje opcional | "Comida", "Propina", etc. |
| **Nro. Operación** | Código de referencia | 05954000 |

### 📱 Apps Soportadas

Actualmente soporta:
- ✅ **Yape** (completo)
- 🔄 **Plin** (en desarrollo)
- 🔄 **BCP, Interbank, etc.** (próximamente)

### 🛠️ Tecnología Utilizada

- **OCR**: Google ML Kit Text Recognition
- **Procesamiento**: Expresiones regulares personalizadas
- **Integración**: Android Share Intent
- **Notificaciones**: SnackBar con estado de proceso

### ⚠️ Notas Importantes

1. **Conexión a Internet**: Necesaria para guardar en Firebase
2. **Banco Registrado**: Debe existir un banco "Yape" en tu lista
3. **Calidad de Imagen**: Mejores resultados con vouchers claros
4. **Solo Android**: Por ahora solo funciona en Android (no iOS)

### 🐛 Solución de Problemas

#### ❌ "No tienes un banco Yape registrado"
**Solución**: Ve a Bancos → Agregar → Nombre: "Yape"

#### ❌ "No se pudo procesar el voucher"
**Causas posibles**:
- Imagen borrosa o cortada
- No es un voucher de Yape válido
- Problema de OCR

**Solución**: Vuelve a compartir con mejor calidad de imagen

#### ❌ No aparece MNAVB al compartir
**Solución**: 
1. Asegúrate que la app esté instalada
2. Reinicia la app de Yape
3. Reinicia el teléfono

### 🔐 Privacidad

- ✅ Las imágenes se procesan localmente
- ✅ Solo se guarda información financiera necesaria
- ✅ No se comparte con terceros
- ✅ Las imágenes no se almacenan permanentemente

### 🎓 Ejemplo de Uso Real

```
1. Yapeas S/ 50 a un amigo para "Comida"
2. En el voucher aparece:
   - "¡Yapeaste!" 
   - "S/ 50"
   - "01 feb. 2026 | 09:39 a. m."
   - Descripción: "Comida"

3. Compartes → MNAVB

4. La app crea automáticamente:
   ✅ Tipo: Gasto
   ✅ Banco: Yape
   ✅ Monto: S/ 50.00
   ✅ Categoría: "Comida"
   ✅ Fecha: 01/02/2026 09:39
```

### 📊 Ventajas

- ⚡ **Rapidez**: Sin escritura manual
- 🎯 **Precisión**: OCR elimina errores humanos
- 🔄 **Automático**: Funciona en segundo plano
- 📈 **Control Real**: Registros inmediatos
- 💡 **Fácil**: Un solo tap para guardar

### 🔮 Próximas Mejoras

- [ ] Soporte para más bancos (BCP, Interbank, Scotiabank)
- [ ] Detección de categorías inteligente (IA)
- [ ] Procesamiento por lotes
- [ ] Sincronización automática con SMS bancarios
- [ ] Modo offline con cola de procesamiento

---

## 👨‍💻 Para Desarrolladores

### Arquitectura

```
lib/
├── models/
│   └── voucher_model.dart          # Modelo de datos del voucher
├── services/
│   ├── voucher_processing_service.dart   # OCR y procesamiento
│   └── shared_media_service.dart         # Manejo de intents
├── viewmodels/
│   └── voucher_provider.dart        # Estado y lógica de negocio
└── widgets/
    └── voucher_notification_listener.dart  # UI feedback
```

### Flujo de Procesamiento

```
1. Android Share Intent → SharedMediaService
2. SharedMediaService → VoucherProcessingService (OCR)
3. VoucherProcessingService → VoucherModel
4. VoucherProvider → FirebaseService (guardado)
5. VoucherNotificationListener → SnackBar (feedback)
```

### Agregar Soporte para Nuevo Banco

Edita `voucher_processing_service.dart`:

```dart
VoucherModel? _analizarTexto(String texto) {
  if (texto.contains('yape')) {
    return _procesarYape(texto);
  } else if (texto.contains('nuevo_banco')) {
    return _procesarNuevoBanco(texto);  // Implementar
  }
  return null;
}
```

---

**Creado con ❤️ para automatizar tus finanzas**
