# 📱 Cómo Usar el Procesamiento de Vouchers en Segundo Plano

## ✨ Nueva Funcionalidad

Ahora puedes compartir tus vouchers de Yape/Plin directamente a Control Finanzas **sin necesidad de abrir la aplicación**. Todo se procesa en segundo plano y recibes notificaciones cuando está listo.

---

## 🚀 Pasos para Usar

### 1️⃣ Primera Vez (Solo una vez)

1. **Abre Control Finanzas**
2. **Inicia sesión** con tu cuenta
3. **Concede permisos de notificaciones** (si Android 13+)
4. ¡Listo! Ya puedes cerrar la app

---

### 2️⃣ Cada vez que Yapeas o te Yapean

#### Opción A: Desde Yape directamente

1. **Yapeas o recibes un Yape** → Se genera el voucher
2. En Yape, presiona el botón **"Compartir"** del voucher
3. Selecciona **"Control Finanzas"**
4. **Espera las notificaciones**:
   - ⏳ "Procesando voucher..." (aparece inmediatamente)
   - ✅ "Gasto/Ingreso registrado: S/ XX.XX" (después de unos segundos)

#### Opción B: Desde tu Galería

1. **Abre tu Galería** de fotos
2. **Selecciona la captura** del voucher de Yape/Plin
3. Presiona **"Compartir"**
4. Selecciona **"Control Finanzas"**
5. **Espera las notificaciones**

---

## 🔔 Tipos de Notificaciones

### ⏳ Procesando
```
Título: "⏳ Procesando voucher"
Mensaje: "Leyendo información del voucher..."
```
Esta notificación permanece hasta que termine el proceso.

### ✅ Éxito - Gasto
```
Título: "✅ Voucher procesado"
Mensaje: "Gasto registrado: S/ 50.00"
```

### ✅ Éxito - Ingreso
```
Título: "✅ Voucher procesado"
Mensaje: "Ingreso registrado: S/ 100.00"
```

### ❌ Error
```
Título: "❌ Error procesando voucher"
Mensaje: [Descripción del error]
```

---

## ⚠️ Errores Comunes y Soluciones

### "Usuario no autenticado. Inicia sesión en la app."
**Problema**: No has iniciado sesión en Control Finanzas  
**Solución**: Abre la app e inicia sesión al menos una vez

### "No se pudo leer la información del voucher"
**Problema**: La imagen del voucher no es clara  
**Solución**: 
- Asegúrate de que la captura sea legible
- Verifica que contenga el monto, fecha y tipo de transacción
- Intenta con otra captura más clara

### "No se pudo obtener o crear el banco"
**Problema**: Problemas con la conexión a internet  
**Solución**: Verifica que tengas conexión estable y vuelve a intentar

### No aparecen notificaciones
**Problema**: Permisos de notificaciones desactivados  
**Solución**: 
1. Ve a **Configuración** de Android
2. **Apps** → **Control Finanzas**
3. **Notificaciones** → Activar todas

---

## 📊 Verifica tus Transacciones

Después de recibir la notificación de éxito:

1. **Abre Control Finanzas**
2. Ve a la pestaña **"Gastos"** o **"Ingresos"**
3. Verás tu transacción registrada automáticamente con:
   - ✅ Monto correcto
   - ✅ Fecha y hora
   - ✅ Banco (Yape/Plin)
   - ✅ Descripción (si había en el voucher)

---

## 💡 Consejos

### Para mejores resultados:

✅ **Usa capturas claras**: Evita imágenes borrosas o recortadas  
✅ **Conexión estable**: El proceso requiere internet para guardar en la nube  
✅ **Mantén sesión activa**: Inicia sesión al menos una vez después de instalar  
✅ **Revisa tus datos**: Abre la app periódicamente para verificar

### Bancos soportados actualmente:

- 💸 **Yape** (BCP)
- 📱 **Plin** (Interbank + otros)
- 🏦 Más bancos próximamente...

---

## 🎯 Ventajas de esta Funcionalidad

| Antes | Ahora |
|-------|-------|
| Compartir voucher | ✅ Compartir voucher |
| ❌ Esperar que abra la app | ✅ Notificación inmediata |
| ❌ Iniciar sesión | ✅ Sin login |
| ❌ Ver proceso en pantalla | ✅ Todo en background |
| ❌ Quedarse en la app | ✅ Seguir usando tu celular |
| Resultado en app | ✅ Resultado en app |

---

## 🆘 ¿Necesitas Ayuda?

Si tienes problemas:

1. **Revisa los errores comunes** arriba
2. **Verifica los permisos** de la app
3. **Cierra y vuelve a abrir** Control Finanzas
4. **Inicia sesión de nuevo** si hace mucho que no lo haces

---

## 🔐 Privacidad y Seguridad

- ✅ Tus vouchers se procesan **localmente** en tu dispositivo
- ✅ Solo se envía la información extraída a la nube (monto, fecha, banco)
- ✅ La imagen original **NO se guarda** en ningún servidor
- ✅ Todo está protegido por tu **sesión de Firebase**

---

**¡Disfruta de tu nueva experiencia sin fricciones! 🎉**
