package kr.co.daram.nfc_project

import android.content.DialogInterface
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.nfc.NfcAdapter
import android.nfc.Tag
import android.nfc.tech.NfcA
import android.util.Log
import androidx.appcompat.app.AlertDialog
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayInputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "kr.co.daram.nfc_project"
    private var nfcAdapter: NfcAdapter? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nfcAdapter = NfcAdapter.getDefaultAdapter(this)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startNFCProcess" -> {
                    val imageData = call.argument<ByteArray>("imageData")
                    if (imageData == null) {
                        result.error("INVALID_ARGUMENT", "Image data is null", null)
                        return@setMethodCallHandler
                    }

                    if (nfcAdapter?.isEnabled == false) {
                        showNFCSettingsDialog()
                        result.error("NFC_DISABLED", "NFC is disabled", null)
                        return@setMethodCallHandler
                    }

                    nfcAdapter?.enableReaderMode(this, { tag ->
                        handleTag(tag, imageData, result)
                    }, NfcAdapter.FLAG_READER_NFC_A, null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun handleTag(tag: Tag?, imageData: ByteArray, result: MethodChannel.Result) {
        if (tag == null) {
            Log.e("NFC", "No tag detected")
            result.error("NFC_ERROR", "No NFC tag detected", null)
            return
        }

        try {
            val nfcLibrary = waveshare.feng.nfctag.activity.a()
            val nfcA = NfcA.get(tag)
            val initResponse = nfcLibrary.a(nfcA)

            if (initResponse != 1) {
                Log.e("NFC", "NFC initialization failed")
                result.error("NFC_ERROR", "Failed to initialize NFC", null)
                return
            }

            val bitmap = BitmapFactory.decodeStream(ByteArrayInputStream(imageData))
            if (bitmap == null) {
                result.error("BITMAP_ERROR", "Failed to decode image", null)
                return
            }

            val sendResponse = nfcLibrary.a(1, bitmap)
            if (sendResponse == 1) {
                Log.d("NFC", "Data sent successfully")
                result.success(true)
            } else {
                Log.e("NFC", "Failed to send data, response code: $sendResponse")
                result.error("NFC_ERROR", "Failed to send data", null)
            }
        } catch (e: Exception) {
            Log.e("NFC", "Error during NFC operation", e)
            result.error("NFC_ERROR", "Error: ${e.message}", null)
        }
    }

    private fun showNFCSettingsDialog() {
        AlertDialog.Builder(this)
            .setTitle("NFC Disabled")
            .setMessage("NFC is disabled. Please enable NFC in settings to continue.")
            .setPositiveButton("Open Settings") { _: DialogInterface, _: Int ->
                val intent = Intent(android.provider.Settings.ACTION_NFC_SETTINGS)
                startActivity(intent)
            }
            .setNegativeButton("Cancel", null)
            .show()
    }
}
