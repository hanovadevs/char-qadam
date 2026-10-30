package com.stepsy.run

import androidx.activity.result.contract.ActivityResultContracts
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/** User-selected document destination; no broad filesystem permission. */
class PdfSaveHandler(private val activity: FlutterFragmentActivity) {
    private var pending: MethodChannel.Result? = null
    private var bytes: ByteArray? = null
    private val launcher = activity.registerForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")) { uri ->
        val result = pending ?: return@registerForActivityResult
        val data = bytes
        if (uri == null || data == null) {
            finish(result, false)
        } else {
            Thread {
                try {
                    val stream = activity.contentResolver.openOutputStream(uri)
                        ?: throw java.io.IOException("Destination unavailable")
                    stream.use { it.write(data) }
                    activity.runOnUiThread { finish(result, true) }
                } catch (_: Exception) {
                    activity.runOnUiThread {
                        if (pending === result) {
                            pending = null
                            bytes = null
                            result.error("PDF_SAVE_FAILED", "The PDF could not be saved to that destination.", null)
                        }
                    }
                }
            }.start()
        }
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "savePdf") { result.notImplemented(); return }
        if (pending != null) { result.error("PDF_SAVE_BUSY", "Finish the current PDF save first.", null); return }
        val data = call.argument<ByteArray>("bytes")
        val filename = call.argument<String>("filename")
        if (data == null || data.size > 20 * 1024 * 1024 || data.size < 5 ||
            String(data.copyOfRange(0, 5), Charsets.US_ASCII) != "%PDF-" ||
            filename == null || !filename.matches(Regex("[A-Za-z0-9_.-]{1,160}\\.pdf"))) {
            result.error("INVALID_PDF", "The downloaded PDF is invalid.", null); return
        }
        pending = result
        bytes = data
        try { launcher.launch(filename) }
        catch (_: Exception) {
            pending = null; bytes = null
            result.error("PDF_SAVE_UNAVAILABLE", "No document saving app is available.", null)
        }
    }

    private fun finish(result: MethodChannel.Result, saved: Boolean) {
        if (pending !== result) return
        pending = null; bytes = null
        result.success(saved)
    }
}
