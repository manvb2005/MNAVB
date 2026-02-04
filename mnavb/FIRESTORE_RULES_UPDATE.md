# INSTRUCCIONES URGENTES - Actualizar Reglas de Firestore

## Problema
La app no puede escribir en la colección `parametros` porque las reglas de seguridad no lo permiten.

## Solución
Actualiza las reglas de Firestore manualmente desde Firebase Console:

### Pasos:
1. Ve a [Firebase Console](https://console.firebase.google.com/)
2. Selecciona tu proyecto
3. Ve a **Firestore Database** en el menú lateral
4. Click en la pestaña **Reglas** (Rules)
5. Reemplaza TODO el contenido con:

```javascript
rules_version = '2';

service cloud.firestore {
  match /databases/{database}/documents {
    
    // Regla por defecto: denegar todo
    match /{document=**} {
      allow read, write: if false;
    }
    
    // Reglas para usuarios autenticados
    match /usuarios/{userId} {
      // Permitir lectura/escritura solo al usuario propietario
      allow read, write: if request.auth != null && request.auth.uid == userId;
      
      // Colección de bancos
      match /bancos/{bancoId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      // Colección de gastos
      match /gastos/{gastoId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      // Colección de transferencias
      match /transferencias/{transferenciaId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      // Colección de préstamos
      match /prestamos/{prestamoId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
      
      // Colección de parámetros (NUEVA - CRÍTICO)
      match /parametros/{parametroDoc} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }
  }
}
```

6. Click en **Publicar** (Publish)
7. Espera unos segundos a que se apliquen
8. Prueba nuevamente la app

## ¿Por qué esto soluciona el error?
El error `PERMISSION_DENIED` aparece porque Firebase bloquea las escrituras en la colección `parametros` ya que no estaba incluida en las reglas de seguridad.

La nueva regla permite que cada usuario autenticado pueda leer y escribir SOLO en su propia subcolección de `parametros`.

## Después de actualizar
Una vez publicadas las reglas, reinicia la app y el botón "Activar Sistema" funcionará correctamente.
