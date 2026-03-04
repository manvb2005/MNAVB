package com.example.mnavb

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
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
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class VoucherOverlayService : Service() {
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
        descriptionEdit.setText(if (data.descripcion == "Sin descripción") "" else data.descripcion)

        closeBtn.setOnClickListener { stopSelf() }
        sendBtn.isEnabled = false

        loadCategorias(
            onSuccess = { list ->
                categorias = list
                if (categorias.isEmpty()) {
                    toast("La API no devolvio categorias")
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
                        if (data.descripcion == "Sin descripción") "Sin descripcion" else data.descripcion
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
                val body = getFromApi("/categorias")
                val root = JSONObject(body)
                val arr = root.optJSONArray("categorias") ?: JSONArray()
                val result = mutableListOf<Categoria>()
                for (i in 0 until arr.length()) {
                    val c = arr.optJSONObject(i) ?: continue
                    val id = c.optString("id")
                    val nombre = c.optString("nombre")
                    val subsArr = c.optJSONArray("subcategorias") ?: JSONArray()
                    val subs = mutableListOf<Subcategoria>()
                    for (j in 0 until subsArr.length()) {
                        val s = subsArr.optJSONObject(j) ?: continue
                        val sid = s.optString("id")
                        val sn = s.optString("nombre")
                        if (sid.isNotBlank()) subs.add(Subcategoria(sid, sn))
                    }
                    if (id.isNotBlank()) result.add(Categoria(id, nombre, subs))
                }
                Handler(Looper.getMainLooper()).post { onSuccess(result) }
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    onError("No se pudo cargar categorias: ${e.message}")
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
                    put("monto", pending.monto)
                    put("categoriaPrincipalId", categoriaPrincipalId)
                    put("subcategoriaId", subcategoriaId)
                    put("descripcion", descripcion)
                    put("moneda", pending.moneda)
                    put("fecha", pending.fecha.take(10))
                }

                postToApi("/voucher/gasto", payload.toString())
                Handler(Looper.getMainLooper()).post(onSuccess)
            } catch (e: Exception) {
                Handler(Looper.getMainLooper()).post {
                    onError("Error enviando voucher: ${e.message}")
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
                    val conn = URL(base + path).openConnection() as HttpURLConnection
                    conn.requestMethod = "GET"
                    conn.connectTimeout = 15000
                    conn.readTimeout = 15000
                    conn.connect()
                    val code = conn.responseCode
                    val stream = if (code in 200..299) conn.inputStream else conn.errorStream
                    val body = BufferedReader(InputStreamReader(stream)).use { it.readText() }
                    if (code !in 200..299) throw Exception("HTTP $code")
                    return body
                } catch (e: Exception) {
                    lastError = e
                    if (attempt == 0) Thread.sleep(600)
                }
            }
        }
        throw lastError ?: Exception("Error de conexion")
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
                    conn.setRequestProperty("Content-Type", "application/json")
                    OutputStreamWriter(conn.outputStream).use { it.write(jsonBody) }
                    val code = conn.responseCode
                    val stream = if (code in 200..299) conn.inputStream else conn.errorStream
                    val body = BufferedReader(InputStreamReader(stream)).use { it.readText() }
                    if (code !in 200..299) throw Exception("HTTP $code")
                    return body
                } catch (e: Exception) {
                    lastError = e
                    if (attempt == 0) Thread.sleep(600)
                }
            }
        }
        throw lastError ?: Exception("Error de conexion")
    }

    private fun candidateBaseUrls(): List<String> {
        val prefs = getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val configured = prefs.getString("flutter.external_api_base_url", "")?.trim().orEmpty()
        val result = mutableListOf<String>()

        if (configured.isNotEmpty()) {
            val withScheme = if (configured.startsWith("http://") || configured.startsWith("https://")) {
                configured
            } else {
                "https://$configured"
            }

            try {
                val uri = Uri.parse(withScheme)
                val origin = uri.scheme + "://" + uri.authority
                if (origin.contains("//")) result.add(origin)
            } catch (_: Exception) {
                result.add(withScheme)
            }
        }

        if (!result.contains("https://mnavb.free.beeceptor.com")) {
            result.add("https://mnavb.free.beeceptor.com")
        }
        if (!result.contains("https://mnavb.beeceptor.com")) {
            result.add("https://mnavb.beeceptor.com")
        }

        return result
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
}
