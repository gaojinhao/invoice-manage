package com.example.invoice_app

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val pdfChannel = "invoice_app/pdf_renderer"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, pdfChannel).setMethodCallHandler { call, result ->
            if (call.method != "renderPdf") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            try {
                val pdfPath = call.argument<String>("pdfPath")
                val outputDir = call.argument<String>("outputDir")
                if (pdfPath.isNullOrBlank() || outputDir.isNullOrBlank()) {
                    result.error("bad_args", "pdfPath and outputDir are required", null)
                    return@setMethodCallHandler
                }
                result.success(renderPdf(pdfPath, outputDir))
            } catch (e: Exception) {
                result.error("render_failed", e.message, null)
            }
        }
    }

    private fun renderPdf(pdfPath: String, outputDir: String): List<String> {
        val outDir = File(outputDir).apply { mkdirs() }
        val result = mutableListOf<String>()
        val pdfFile = File(pdfPath)
        val descriptor = ParcelFileDescriptor.open(pdfFile, ParcelFileDescriptor.MODE_READ_ONLY)
        PdfRenderer(descriptor).use { renderer ->
            for (index in 0 until renderer.pageCount) {
                renderer.openPage(index).use { page ->
                    val targetWidth = 1600
                    val targetHeight = (targetWidth.toFloat() / page.width * page.height).toInt()
                    val bitmap = Bitmap.createBitmap(targetWidth, targetHeight, Bitmap.Config.ARGB_8888)
                    bitmap.eraseColor(Color.WHITE)
                    page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_PRINT)

                    val file = File(outDir, "${pdfFile.nameWithoutExtension}_${index + 1}.png")
                    FileOutputStream(file).use { stream ->
                        bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                    }
                    bitmap.recycle()
                    result.add(file.absolutePath)
                }
            }
        }
        descriptor.close()
        return result
    }
}
