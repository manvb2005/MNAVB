# Sistema de Procesamiento de Vouchers en Segundo Plano

## 🎯 Funcionamiento

Este sistema permite procesar vouchers compartidos **SIN abrir la aplicación**, ejecutando todo en segundo plano con notificaciones del sistema.

### Flujo del usuario:

1. **Yapeas o te yapean** → Recibes captura del voucher
2. **Compartes la imagen** con "Control Finanzas"
3. **NO se abre la app** → Solo ves notificación: "⏳ Procesando voucher..."
4. **Esperas unos segundos** mientras se lee el OCR
5. **Recibes notificación final**:
   - ✅ "Gasto registrado: S/ 50.00"
   - ✅ "Ingreso registrado: S/ 100.00"
   - ❌ "Error procesando voucher: [mensaje]"
6. **Abres la app cuando quieras** y ya está registrado en Firestore

---

## 🏗️ Arquitectura Técnica

### 1. **ShareReceiverActivity** (Android - Kotlin)
- Activity **transparente** que recibe el Intent de "Compartir"
- Captura el URI de la imagen
- Lo envía a Flutter vía MethodChannel
- Se cierra inmediatamente (< 1 segundo)

**Ubicación**: `android/app/src/main/kotlin/com/example/mnavb/ShareReceiverActivity.kt`

### 2. **ShareEnqueueService** (Flutter)
- Recibe el URI desde el MethodChannel
- Encola un trabajo en **WorkManager**
- No bloquea la UI

**Ubicación**: `lib/services/share_enqueue_service.dart`

### 3. **WorkManager** (Background)
- Ejecuta el procesamiento en un **isolate separado**
- Inicializa Firebase en background
- Llama al **callbackDispatcher** en `main.dart`

### 4. **Callback Dispatcher** (main.dart)
- Procesa el voucher con OCR (ML Kit)
- Obtiene UID del usuario desde SharedPreferences
- Registra en Firestore usando métodos especiales con `userId` explícito
- Lanza notificaciones del sistema

---

## 📦 Componentes Nuevos

### Archivos creados:

```
lib/
├── utils/
│   └── system_notifications.dart          # Manejo de notificaciones del sistema
├── services/
│   ├── share_enqueue_service.dart         # Encolar trabajos en WorkManager
│   └── voucher_processing_service_background.dart  # OCR adaptado para background

android/
└── app/src/main/kotlin/com/example/mnavb/
    └── ShareReceiverActivity.kt           # Activity transparente
```

### Archivos modificados:

```
✅ pubspec.yaml                             # Agregado workmanager
✅ lib/main.dart                            # Callback dispatcher + inicialización
✅ lib/services/firebase_service.dart       # Métodos con userId explícito
✅ lib/viewmodels/remember_session_provider.dart  # Guardar UID
✅ lib/views/login_view.dart                # Guardar UID al iniciar sesión
✅ android/app/src/main/AndroidManifest.xml # ShareReceiverActivity + permisos
✅ android/app/src/main/res/values/styles.xml # Tema transparente
```

---

## 🔑 Cómo Funciona la Sesión en Background

### Problema:
En background, `FirebaseAuth.currentUser` puede estar `null` porque no hay sesión activa de UI.

### Solución:
1. Al hacer **login exitoso**, se guarda el `userId` en **SharedPreferences**:
   ```dart
   await remember.saveUserId(userId);
   ```

2. En background, el **callbackDispatcher** lee el UID:
   ```dart
   final prefs = await SharedPreferences.getInstance();
   final userId = prefs.getString('saved_uid');
   ```

3. Se usan métodos especiales de FirebaseService que aceptan `userId` explícito:
   - `registrarGastoConUserId(...)`
   - `registrarIngresoConUserId(...)`
   - `getBancosListConUserId(...)`

---

## 🔔 Sistema de Notificaciones

### Tipos de notificaciones:

1. **Procesando** (ongoing, no se puede descartar):
   ```dart
   SystemNotifications.showProcessing(notifId);
   ```

2. **Éxito**:
   ```dart
   SystemNotifications.showSuccess(notifId, 'Gasto registrado: S/ 50.00');
   ```

3. **Error**:
   ```dart
   SystemNotifications.showError(notifId, 'No se pudo leer el monto');
   ```

---

## 📋 Permisos Android

### AndroidManifest.xml:
```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.WAKE_LOCK" />
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.INTERNET" />
```

### Permiso en tiempo de ejecución:
En Android 13+ (API 33), debes pedir permiso de notificaciones la primera vez que el usuario abre la app:

```dart
import 'package:permission_handler/permission_handler.dart';

// En algún lugar de tu app (ej: splash screen o login)
if (await Permission.notification.isDenied) {
  await Permission.notification.request();
}
```

---

## 🧪 Cómo Probar

1. **Compilar la app**:
   ```bash
   cd mnavb
   flutter build apk --debug
   # o
   flutter run
   ```

2. **Iniciar sesión** en la app (esto guarda el UID)

3. **Yapear o recibir un Yape**

4. **Compartir la captura**:
   - En Galería/Fotos → Seleccionar imagen → Compartir → "Control Finanzas"

5. **Observar**:
   - ✅ NO se abre la app
   - ✅ Aparece notificación "Procesando voucher..."
   - ✅ Después de unos segundos: "Gasto/Ingreso registrado"

6. **Abrir la app** → Verificar que está en Firestore

---

## 🐛 Debugging

### Ver logs del WorkManager:

En `main.dart`, cambiar:
```dart
await Workmanager().initialize(
  callbackDispatcher,
  isInDebugMode: true,  // ← Cambiar a true
);
```

### Ver logs en Android Studio:
```
Logcat → Filtrar por "voucher" o "WorkManager"
```

### Logs importantes:
- `📥 Recibido URI de voucher:`
- `✅ Tarea encolada correctamente en WorkManager`
- `📱 WorkManager: Iniciando tarea de procesamiento`
- `✅ Voucher procesado: gasto - S/ 50.0`
- `💾 Transacción guardada en Firestore`

---

## ⚠️ Limitaciones

1. **Requiere conexión a internet**: WorkManager tiene constraint de red
2. **Requiere login previo**: El UID debe estar guardado en SharedPreferences
3. **Android 8.0+**: WorkManager no funciona en versiones anteriores
4. **Saldo negativo**: En background, si no hay saldo suficiente para un gasto, se permite igual (puedes cambiarlo)

---

## 🔄 Mejoras Futuras

- [ ] Soporte para más bancos (Plin, BCP, Interbank, etc.)
- [ ] Reconocer automáticamente el banco del voucher
- [ ] Permitir configurar el banco de destino desde la app
- [ ] Caché de OCR para vouchers duplicados
- [ ] Historial de vouchers procesados
- [ ] Reintentar automáticamente si falla

---

## 🆘 Problemas Comunes

### "Usuario no autenticado"
**Causa**: No has iniciado sesión en la app  
**Solución**: Abre la app e inicia sesión una vez

### "No se pudo leer la información del voucher"
**Causa**: OCR no pudo detectar texto claro  
**Solución**: Asegúrate de que la imagen sea clara y legible

### "Banco no encontrado"
**Causa**: El banco del voucher no existe en tu lista de bancos  
**Solución**: Se creará automáticamente un banco nuevo con saldo 0

### No aparecen notificaciones
**Causa**: Permiso de notificaciones denegado  
**Solución**: Configuración → Apps → Control Finanzas → Notificaciones → Activar

---

## 📚 Dependencias Principales

```yaml
workmanager: ^0.6.0                    # Ejecución en background
flutter_local_notifications: ^18.0.1   # Notificaciones del sistema
google_mlkit_text_recognition: ^0.15.0 # OCR
firebase_core: ^4.4.0                  # Firebase
firebase_auth: ^6.1.4                  # Autenticación
cloud_firestore: ^6.1.2                # Base de datos
shared_preferences: ^2.5.4             # Persistencia local
```

---

**Desarrollado con ❤️ para Control Finanzas**
