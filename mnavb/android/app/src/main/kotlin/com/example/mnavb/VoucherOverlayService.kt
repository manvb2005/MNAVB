package com.example.mnavb

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.ArrayAdapter
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.Spinner
import android.widget.TextView
import android.widget.Toast
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.io.OutputStreamWriter
import java.net.ConnectException
import java.net.HttpURLConnection
import java.net.SocketTimeoutException
import java.net.UnknownHostException
import java.net.URL
import kotlin.concurrent.thread

class VoucherOverlayService : Service() {
    private val tag = "VoucherOverlayService"
    private val apiBaseUrl = "http://52.6.118.38/sicuba/public"
    private val apiKey = "MI_API_KEY_123"
    private val apiChannel = "mobile"
    private val txtOperationId = 801

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null

    private var pending: PendingVoucher? = null
    private var categorias: List<Categoria> = emptyList()

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (!Settings.canDrawOverlays(this)) {
            toast("Permiso de superposicion no concedido")
            stopSelf()
            return START_NOT_STICKY
        }

        if (overlayView != null) return START_NOT_STICKY

        pending = readPendingVoucher()
        if (pending == null) {
            toast("No hay voucher pendiente")
            stopSelf()
            return START_NOT_STICKY
        }

        showOverlay()
        return START_NOT_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        removeOverlay()
    }

    private fun showOverlay() {
        val inflater = getSystemService(LAYOUT_INFLATER_SERVICE) as LayoutInflater
        val card = inflater.inflate(R.layout.overlay_voucher_confirm, null)

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(0x88000000.toInt())
            gravity = Gravity.CENTER
            addView(card, LinearLayout.LayoutParams(
                resources.displayMetrics.widthPixels - dp(24),
                LinearLayout.LayoutParams.WRAP_CONTENT
            ))
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                WindowManager.LayoutParams.TYPE_PHONE,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL,
            PixelFormat.TRANSLUCENT
        )

        params.gravity = Gravity.CENTER
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        overlayView = root
        windowManager?.addView(root, params)

        bindDataAndActions(card)
    }

    private fun bindDataAndActions(card: View) {
        val amountView = card.findViewById<TextView>(R.id.tvAmount)
        val dateView = card.findViewById<TextView>(R.id.tvDate)
        val categorySpinner = card.findViewById<Spinner>(R.id.spCategory)
        val subcategorySpinner = card.findViewById<Spinner>(R.id.spSubcategory)
        val descriptionEdit = card.findViewById<EditText>(R.id.etDescription)
        val closeBtn = card.findViewById<Button>(R.id.btnClose)
        val sendBtn = card.findViewById<Button>(R.id.btnSend)

        val data = pending ?: return
        amountView.text = "Monto: ${data.moneda} ${"%.2f".format(data.monto)}"
        dateView.text = "Fecha: ${data.fecha}"
        val descripcionInicial = data.descripcion.trim()
        val esPlaceholderDescripcion = descripcionInicial.equals("Sin descripcion", ignoreCase = true) ||
            descripcionInicial.equals("Sin descripción", ignoreCase = true)
        descriptionEdit.setText(if (esPlaceholderDescripcion) "" else descripcionInicial)

        closeBtn.setOnClickListener { stopSelf() }
        sendBtn.isEnabled = false

        loadCategorias(
            onSuccess = { list ->
                categorias = list
                if (categorias.isEmpty()) {
                    toast("No hay categorias principales disponibles en la API")
                    return@loadCategorias
                }

                val catAdapter = ArrayAdapter(
                    this,
                    android.R.layout.simple_spinner_item,
                    categorias.map { it.nombre }
                )
                catAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
                categorySpinner.adapter = catAdapter

                fun bindSubs(index: Int) {
                    val subs = categorias.getOrNull(index)?.subcategorias ?: emptyList()
                    val subAdapter = ArrayAdapter(
                        this,
                        android.R.layout.simple_spinner_item,
                        subs.map { it.nombre }
                    )
                    subAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
                    subcategorySpinner.adapter = subAdapter
                    sendBtn.isEnabled = subs.isNotEmpty()
                }

                bindSubs(0)
                categorySpinner.setOnItemSelectedListener(object : android.widget.AdapterView.OnItemSelectedListener {
                    override fun onItemSelected(parent: android.widget.AdapterView<*>?, view: View?, position: Int, id: Long) {
                        bindSubs(position)
                    }

                    override fun onNothingSelected(parent: android.widget.AdapterView<*>?) {}
                })

                sendBtn.setOnClickListener {
                    val cat = categorias.getOrNull(categorySpinner.selectedItemPosition)
                    val sub = cat?.subcategorias?.getOrNull(subcategorySpinner.selectedItemPosition)
                    if (cat == null || sub == null) {
                        toast("Selecciona categoria y subcategoria")
                        return@setOnClickListener
                    }

                    val descripcion = descriptionEdit.text?.toString()?.trim().orEmpty().ifEmpty {
                        if (esPlaceholderDescripcion) "" else data.descripcion.trim()
                    }

                    sendBtn.isEnabled = false
                    sendVoucher(
                        pending = data,
                        categoriaPrincipalId = cat.id,
                        subcategoriaId = sub.id,
                        descripcion = descripcion,
                        onSuccess = {
                            clearPending()
                            notifyResult("Voucher enviado", "Gasto enviado a API externa")
                            stopSelf()
                        },
                        onError = { error ->
                            sendBtn.isEnabled = true
                            toast(error)
                            notifyResult("Error voucher", error)
                        }
                    )
                }
            },
            onError = { error ->
                toast(error)
            }
        )
    }

    private fun removeOverlay() {
        if (overlayView != null) {
            try {
                windowManager?.removeView(overlayView)
            } catch (_: Exception) {
            }
            overlayView = null
        }
    }

    private fun loadCategorias(onSuccess: (List<Categoria>) -> Unit, onError: (String) -> Unit) {
        thread {
            try {
                Log.i(tag, "GET categorias -> $apiBaseUrl/api/v1/masters")
                val body = getFromApi("/api/v1/masters")
                Log.i(tag, "GET categorias body (primeros 300): ${body.take(300)}")
                val root = JSONObject(body)
                val arr = root.optJSONArray("data") ?: JSONArray()
                val result = mutableListOf<Categoria>()

                val allItems = mutableListOf<JSONObject>()
                for (i in 0 until arr.length()) {
                    val c = arr.optJSONObject(i) ?: continue
                    allItems.add(c)
                }

                for (c in allItems) {
                    val id = c.optString("id_master").trim()
                    val nombre = c.optString("master_name").trim()
                    val masterCode = c.optString("master_code").trim()
                    val masterType = c.optString("master_type").trim().lowercase()

                    if (id.isBlank()) continue
                    if (masterCode != "0") continue
                    if (masterType != "expense") continue

                    val subs = mutableListOf<Subcategoria>()
                    for (s in allItems) {
                        val sid = s.optString("id_master").trim()
                        val sn = s.optString("master_name").trim()
                        val scode = s.optString("master_code").trim()
                        if (scode != id) continue
                        if (sid.isNotBlank()) subs.add(Subcategoria(sid, sn))
                    }

                    if (id.isNotBlank()) result.add(Categoria(id, nombre, subs))
                }
                Log.i(tag, "Categorias padre filtradas: ${result.size}")
                Handler(Looper.getMainLooper()).post { onSuccess(result) }
            } catch (e: Exception) {
                Log.e(tag, "Error cargando categorias", e)
                Handler(Looper.getMainLooper()).post {
                    onError(resolveUserMessage(e, "consultar categorias"))
                }
            }
        }
    }

    private fun sendVoucher(
        pending: PendingVoucher,
        categoriaPrincipalId: String,
        subcategoriaId: String,
        descripcion: String,
        onSuccess: () -> Unit,
        onError: (String) -> Unit
    ) {
        thread {
            try {
                val payload = JSONObject().apply {
                    put("txtOperationId", txtOperationId)
                    put("tblDetail", JSONArray().apply {
                        put(JSONObject().apply {
                            put("category", categoriaPrincipalId.toIntOrNull() ?: categoriaPrincipalId)
                            put("subCategory", subcategoriaId.toIntOrNull() ?: subcategoriaId)
                            put("desc", descripcion)
                            put("amount", pending.monto)
                        })
                    })
                }

                postToApi("/api/v1/detail", payload.toString())
                Handler(Looper.getMainLooper()).post(onSuccess)
            } catch (e: Exception) {
                Log.e(tag, "Error enviando voucher", e)
                Handler(Looper.getMainLooper()).post {
                    onError(resolveUserMessage(e, "enviar el voucher"))
                }
            }
        }
    }

    private fun getFromApi(path: String): String {
        val urls = candidateBaseUrls()
        var lastError: Exception? = null
        for (base in urls) {
            repeat(2) { attempt ->
                try {
                    Log.i(tag, "Intento GET ${attempt + 1} -> $base$path")
                    val conn = URL(base + path).openConnection() as HttpURLConnection
                    conn.requestMethod = "GET"
                    conn.connectTimeout = 15000
                    conn.readTimeout = 15000
                    conn.setRequestProperty("Accept", "application/json")
                    conn.setRequestProperty("X-API-KEY", apiKey)
                    conn.setRequestProperty("Channel", apiChannel)
                    conn.connect()
                    val code = conn.responseCode
                    val stream = if (code in 200..299) conn.inputStream else conn.errorStream
                    val body = BufferedReader(InputStreamReader(stream)).use { it.readText() }
                    Log.i(tag, "GET $base$path -> HTTP $code")
                    if (code !in 200..299) {
                        throw ApiUserException(httpErrorMessage(code, body, "consultar categorias"))
                    }
                    return body
                } catch (e: Exception) {
                    lastError = e
                    Log.e(tag, "Fallo GET $base$path (intento ${attempt + 1})", e)
                    if (attempt == 0) Thread.sleep(600)
                }
            }
        }
        throw ApiUserException(resolveNetworkMessage(lastError, "consultar categorias"), lastError)
    }

    private fun postToApi(path: String, jsonBody: String): String {
        val urls = candidateBaseUrls()
        var lastError: Exception? = null
        for (base in urls) {
            repeat(2) { attempt ->
                try {
                    val conn = URL(base + path).openConnection() as HttpURLConnection
                    conn.requestMethod = "POST"
                    conn.connectTimeout = 15000
                    conn.readTimeout = 15000
                    conn.doOutput = true
                    conn.setRequestProperty("Accept", "application/json")
                    conn.setRequestProperty("X-API-KEY", apiKey)
                    conn.setRequestProperty("Channel", apiChannel)
                    conn.setRequestProperty("Content-Type", "application/json")
                    OutputStreamWriter(conn.outputStream).use { it.write(jsonBody) }
                    val code = conn.responseCode
                    val stream = if (code in 200..299) conn.inputStream else conn.errorStream
                    val body = BufferedReader(InputStreamReader(stream)).use { it.readText() }
                    Log.i(tag, "POST $base$path -> HTTP $code")
                    if (code !in 200..299) {
                        throw ApiUserException(httpErrorMessage(code, body, "enviar el voucher"))
                    }
                    return body
                } catch (e: Exception) {
                    lastError = e
                    Log.e(tag, "Fallo POST $base$path (intento ${attempt + 1})", e)
                    if (attempt == 0) Thread.sleep(600)
                }
            }
        }
        throw ApiUserException(resolveNetworkMessage(lastError, "enviar el voucher"), lastError)
    }

    private fun candidateBaseUrls(): List<String> {
        return listOf(apiBaseUrl)
    }

    private fun resolveUserMessage(error: Exception, action: String): String {
        if (error is ApiUserException) return error.userMessage
        return "No se pudo $action. Intenta nuevamente."
    }

    private fun resolveNetworkMessage(error: Exception?, action: String): String {
        return when (error) {
            is SocketTimeoutException -> "Tiempo de espera agotado al $action. Revisa tu conexion e intenta nuevamente."
            is UnknownHostException, is ConnectException -> "No se pudo conectar con la API. Verifica internet o la URL del servidor."
            else -> "No se pudo $action por un problema de conexion."
        }
    }

    private fun httpErrorMessage(statusCode: Int, body: String, action: String): String {
        val apiMessage = extractApiMessage(body)
        return when (statusCode) {
            400 -> apiMessage ?: "Solicitud invalida al $action."
            401 -> apiMessage ?: "La API rechazo la autenticacion (401). Verifica API Key y Channel."
            403 -> apiMessage ?: "No tienes permisos para esta operacion (403)."
            404 -> apiMessage ?: "No se encontro el endpoint solicitado (404)."
            408 -> "Tiempo de espera agotado al $action."
            422 -> apiMessage ?: "Datos invalidos para $action (422)."
            429 -> apiMessage ?: "Demasiadas solicitudes. Intenta en unos segundos."
            in 500..599 -> apiMessage ?: "La API esta con problemas internos ($statusCode). Intenta mas tarde."
            else -> apiMessage ?: "Error HTTP $statusCode al $action."
        }
    }

    private fun extractApiMessage(body: String): String? {
        return try {
            val json = JSONObject(body)
            val message = json.optString("message").trim()
            when {
                message.isNotEmpty() -> message
                else -> null
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun readPendingVoucher(): PendingVoucher? {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val raw = prefs.getString("flutter.pending_external_voucher", null) ?: return null
        return try {
            val obj = JSONObject(raw)
            PendingVoucher(
                notificationId = obj.optInt("notificationId", 9999),
                monto = obj.optDouble("monto", 0.0),
                descripcion = obj.optString("descripcion", "Sin descripcion"),
                fecha = obj.optString("fecha", ""),
                moneda = obj.optString("moneda", "PEN")
            )
        } catch (_: Exception) {
            null
        }
    }

    private fun clearPending() {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        prefs.edit()
            .remove("flutter.pending_external_voucher")
            .remove("flutter.pending_external_voucher_open_overlay")
            .apply()
    }

    private fun notifyResult(title: String, message: String) {
        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "voucher_channel"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Procesamiento de Vouchers",
                NotificationManager.IMPORTANCE_HIGH
            )
            nm.createNotificationChannel(channel)
        }
        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .build()
        nm.notify((System.currentTimeMillis() % 100000).toInt(), notification)
    }

    private fun toast(msg: String) {
        Handler(Looper.getMainLooper()).post {
            Toast.makeText(this, msg, Toast.LENGTH_SHORT).show()
        }
    }

    private fun dp(value: Int): Int {
        val density = resources.displayMetrics.density
        return (value * density).toInt()
    }

    data class PendingVoucher(
        val notificationId: Int,
        val monto: Double,
        val descripcion: String,
        val fecha: String,
        val moneda: String
    )

    data class Categoria(
        val id: String,
        val nombre: String,
        val subcategorias: List<Subcategoria>
    )

    data class Subcategoria(
        val id: String,
        val nombre: String
    )

    private class ApiUserException(
        val userMessage: String,
        cause: Throwable? = null
    ) : Exception(userMessage, cause)
}
