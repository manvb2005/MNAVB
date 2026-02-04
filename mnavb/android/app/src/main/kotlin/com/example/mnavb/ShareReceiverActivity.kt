package com.example.mnavb

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

/**
 * Activity transparente que recibe vouchers compartidos desde otras apps
 * No muestra UI al usuario, solo encola el procesamiento en background
 */
class ShareReceiverActivity : Activity() {

    private val CHANNEL = "voucher_share"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Obtener el URI compartido
        val uri: Uri? = intent?.getParcelableExtra(Intent.EXTRA_STREAM)
        
        if (uri == null) {
            println("❌ ShareReceiverActivity: No se recibió URI")
            finish()
            return
        }

        println("📥 ShareReceiverActivity: Recibido URI: $uri")

        try {
            // Copiar el content:// URI a un archivo temporal accesible
            val tempFilePath = copyUriToTempFile(uri)
            println("📁 ShareReceiverActivity: Archivo copiado a: $tempFilePath")

            // Crear un engine de Flutter para comunicarnos con el lado Dart
            val engine = FlutterEngine(this)
            
            // Ejecutar el entrypoint de Dart
            engine.dartExecutor.executeDartEntrypoint(
                DartExecutor.DartEntrypoint.createDefault()
            )

            // Esperar un poco a que el engine esté listo
            Thread.sleep(500)

            // Enviar el path del archivo temporal al lado Flutter
            val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            channel.invokeMethod("enqueueVoucher", mapOf("uri" to "file://$tempFilePath"))

            println("✅ ShareReceiverActivity: URI enviado a Flutter")
        } catch (e: Exception) {
            println("❌ ShareReceiverActivity: Error - ${e.message}")
            e.printStackTrace()
        } finally {
            // Cerrar inmediatamente la activity (no mostrar UI)
            finish()
        }
    }

    /**
     * Copia el contenido de un content:// URI a un archivo temporal
     */
    private fun copyUriToTempFile(uri: Uri): String {
        val contentResolver = applicationContext.contentResolver
        val inputStream = contentResolver.openInputStream(uri)
            ?: throw Exception("No se pudo abrir el URI")

        // Crear archivo temporal en el directorio de caché
        val tempDir = applicationContext.cacheDir
        val tempFile = File(tempDir, "voucher_${System.currentTimeMillis()}.png")

        inputStream.use { input ->
            FileOutputStream(tempFile).use { output ->
                input.copyTo(output)
            }
        }

        println("📄 Archivo copiado: ${tempFile.absolutePath} (${tempFile.length()} bytes)")
        return tempFile.absolutePath
    }
}
