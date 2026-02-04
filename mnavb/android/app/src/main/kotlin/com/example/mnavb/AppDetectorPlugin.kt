package com.example.mnavb

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class AppDetectorPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    // Lista de paquetes bancarios conocidos en Perú
    private val bankPackages = listOf(
        "com.bcp.bank.bcp",                    // Yape
        "pe.com.bcp.banco.bcp",                // BCP
        "com.bcp.mobile.app",                  // BCP Mobile
        "com.bbva.peru",                       // BBVA
        "com.bbva.nxt_peru",                   // BBVA App
        "pe.com.interbank.mobilebanking",      // Interbank
        "com.interbank.mobilebanking",         // Interbank App
        "pe.com.scotiabank.blpm",              // Scotiabank
        "com.scotiabank.pe",                   // Scotiabank Perú
        "com.plin.app",                        // Plin
        "com.tunki",                           // Tunki
        "pe.com.banbif.mobile",                // Banbif
        "com.banbif.mobile",                   // Banbif App
        "com.pichincha.mobile",                // Banco Pichincha
        "pe.com.bn.banca_movil",               // Banco de la Nación
        "com.mibanco.bancamovil",              // Mibanco
        "com.bancofalabella.pe",               // Banco Falabella
        "com.bancoripley.pe",                  // Banco Ripley
        "pe.com.bancoazteca.app",              // Banco Azteca
        "pe.com.financierooh.app",             // Crediscotia Financiero
        "com.kasnet",                          // Kasnet
        "com.niubiz.app",                      // Niubiz
        "com.izipay.pe",                       // Izipay
        "pe.com.safetypay.app"                 // SafetyPay
    )

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "app_detector")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getInstalledBankApps" -> {
                val installedApps = getInstalledBankApps()
                result.success(installedApps)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun getInstalledBankApps(): List<Map<String, String>> {
        val packageManager = context.packageManager
        val installedApps = mutableListOf<Map<String, String>>()

        for (packageName in bankPackages) {
            try {
                val appInfo = packageManager.getApplicationInfo(packageName, 0)
                val appName = packageManager.getApplicationLabel(appInfo).toString()
                
                installedApps.add(
                    mapOf(
                        "nombre" to appName,
                        "packageName" to packageName
                    )
                )
            } catch (e: PackageManager.NameNotFoundException) {
                // La app no está instalada, continuar
            }
        }

        return installedApps
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}
