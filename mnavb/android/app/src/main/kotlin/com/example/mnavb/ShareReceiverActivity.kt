package com.example.mnavb

import android.app.Activity
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Handler
import android.os.Looper
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
    private val MAX_RETRIES = 12
    private val RETRY_DELAY_MS = 250L

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

            // Enviar el path al lado Flutter con reintentos cortos hasta que el handler esté listo
            enqueueWithRetry(engine, tempFilePath, 0)
        } catch (e: Exception) {
            println("❌ ShareReceiverActivity: Error - ${e.message}")
            e.printStackTrace()
            finish()
        }
    }

    private fun enqueueWithRetry(engine: FlutterEngine, tempFilePath: String, attempt: Int) {
        val channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        channel.invokeMethod(
            "enqueueVoucher",
            mapOf("uri" to "file://$tempFilePath"),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    println("✅ ShareReceiverActivity: enqueueVoucher OK (intento ${attempt + 1})")
                    finishWithEngine(engine)
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    println("❌ ShareReceiverActivity: enqueueVoucher error $errorCode - $errorMessage")
                    retryOrFinish(engine, tempFilePath, attempt)
                }

                override fun notImplemented() {
                    println("⏳ ShareReceiverActivity: handler no listo (intento ${attempt + 1})")
                    retryOrFinish(engine, tempFilePath, attempt)
                }
            }
        )
    }

    private fun retryOrFinish(engine: FlutterEngine, tempFilePath: String, attempt: Int) {
        if (attempt + 1 >= MAX_RETRIES) {
            println("❌ ShareReceiverActivity: no se pudo encolar tras $MAX_RETRIES intentos")
            finishWithEngine(engine)
            return
        }

        Handler(Looper.getMainLooper()).postDelayed({
            enqueueWithRetry(engine, tempFilePath, attempt + 1)
        }, RETRY_DELAY_MS)
    }

    private fun finishWithEngine(engine: FlutterEngine) {
        try {
            engine.destroy()
        } catch (_: Exception) {
        }
        finish()
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
