package com.example.YOLOIntegration

/*
 * MultiFingerYOLOAnalyzer — drop-in replacement for YOLOv8Analyzer that returns
 * EVERY detected finger instead of only processedBitmap[0].
 *
 * WHAT CHANGED vs the original yolo-analyzer.kt:
 *   1. Callback type:  (Bitmap, List<DetectionResult>)  ->  (List<Bitmap>, List<DetectionResult>)
 *   2. analyze():       removed the hardcoded `val pB = processedBitmap[0]`.
 *   3. drawDetectionResult(): added BOUNDS CLAMPING so an edge finger never
 *      crashes Bitmap.createBitmap (this does NOT touch the box formulas).
 *
 * WHAT DID NOT CHANGE — the bounding-box math in interpretResults() is copied
 * verbatim (the (x - w/2)*b ... lines). Per the constraint, those formulas are
 * untouched; only loops and data structures around them changed.
 */

import android.graphics.*
import android.graphics.ImageDecoder
import android.os.Build
import android.util.Log
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import org.tensorflow.lite.Interpreter
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.exp

class MultiFingerYOLOAnalyzer(
    private val tflite: Interpreter,
    // CHANGED: now returns a list of crops (one per finger), not a single bitmap.
    private val onAnalysisResult: (List<Bitmap>, List<DetectionResult>) -> Unit
) : ImageAnalysis.Analyzer {

    companion object {
        private const val TAG = "MultiFingerYOLO"
        private const val INPUT_SIZE = 800
        private const val NUM_CLASSES = 1
        private const val CONFIDENCE_THRESHOLD = 0.7f
    }

    override fun analyze(image: ImageProxy) {
        val bitmap = image.toBitmapp()
        val p = bitmap.height
        val q = bitmap.width
        val resizedBitmap = Bitmap.createScaledBitmap(bitmap, INPUT_SIZE, INPUT_SIZE, true)

        val inputBuffer = preprocess(resizedBitmap)
        val outputBuffer = Array(1) { Array(8) { FloatArray(13125) } }

        tflite.run(inputBuffer, outputBuffer)
        val results = interpretResults(p, q, outputBuffer[0])

        // CHANGED: keep ALL crops instead of processedBitmap[0].
        val crops = drawDetectionResult(bitmap, results)
        Log.d(TAG, "Detected ${results.size} fingers, produced ${crops.size} crops")
        onAnalysisResult(crops, results)

        resizedBitmap.recycle()   // free the scaled copy promptly
        image.close()
    }

    private fun ImageProxy.toBitmapp(): Bitmap {
        val buffer = planes[0].buffer
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val source = ImageDecoder.createSource(bytes)
            ImageDecoder.decodeBitmap(source) { decoder, _, _ -> decoder.isMutableRequired = true }
        } else {
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        }
    }

    private fun preprocess(bitmap: Bitmap): ByteBuffer {
        val inputBuffer = ByteBuffer.allocateDirect(4 * INPUT_SIZE * INPUT_SIZE * 3)
        inputBuffer.order(ByteOrder.nativeOrder())
        val intValues = IntArray(INPUT_SIZE * INPUT_SIZE)
        bitmap.getPixels(intValues, 0, INPUT_SIZE, 0, 0, INPUT_SIZE, INPUT_SIZE)
        for (pixelValue in intValues) {
            inputBuffer.putFloat((pixelValue shr 16 and 0xFF) / 255.0f)
            inputBuffer.putFloat((pixelValue shr 8 and 0xFF) / 255.0f)
            inputBuffer.putFloat((pixelValue and 0xFF) / 255.0f)
        }
        return inputBuffer
    }

    private fun interpretResults(a: Int, b: Int, output: Array<FloatArray>): List<DetectionResult> {
        val results = mutableListOf<DetectionResult>()
        val num_boxes = output[0].size

        for (i in 0 until num_boxes) {
            val confidence = output[6][i]
            if (confidence > CONFIDENCE_THRESHOLD) {
                val x = output[0][i]
                val y = output[1][i]
                val w = output[2][i]
                val h = output[3][i]

                // ─── DO NOT ALTER: bounding-box formulas (verbatim) ───
                val left = (x - w / 2) * b
                val top = (y - h / 2) * a
                val right = (x + w / 2) * b
                val bottom = (y + h / 2) * a
                // ──────────────────────────────────────────────────────

                results.add(
                    DetectionResult(RectF(left, top, right, bottom), "Fingerprint", confidence)
                )
            }
        }
        return nms(results, 0.3f)
    }

    private fun sigmoid(x: Float): Float = 1.0f / (1.0f + exp(-x))

    private fun nms(boxes: List<DetectionResult>, iouThreshold: Float): List<DetectionResult> {
        val sortedBoxes = boxes.sortedByDescending { it.confidence }
        val selectedBoxes = mutableListOf<DetectionResult>()
        for (box in sortedBoxes) {
            var shouldSelect = true
            for (selectedBox in selectedBoxes) {
                if (calculateIoU(box.boundingBox, selectedBox.boundingBox) > iouThreshold) {
                    shouldSelect = false; break
                }
            }
            if (shouldSelect) selectedBoxes.add(box)
        }
        // Sort left -> right so callers can label fingers in slap order.
        return selectedBoxes.sortedBy { it.boundingBox.centerX() }
    }

    private fun calculateIoU(box1: RectF, box2: RectF): Float {
        val intersectionArea = RectF().apply { setIntersect(box1, box2) }
            .let { if (it.isEmpty) 0f else it.width() * it.height() }
        val unionArea = box1.width() * box1.height() + box2.width() * box2.height() - intersectionArea
        return intersectionArea / unionArea
    }

    // CHANGED: loops over ALL results (unchanged) + clamps the crop rect to the
    // bitmap bounds so edge fingers don't throw IllegalArgumentException.
    private fun drawDetectionResult(bitmap: Bitmap, results: List<DetectionResult>): List<Bitmap> {
        val croppedBitmaps = mutableListOf<Bitmap>()
        for (result in results) {
            val bb = result.boundingBox
            val left = bb.left.toInt().coerceIn(0, bitmap.width - 1)
            val top = bb.top.toInt().coerceIn(0, bitmap.height - 1)
            var width = bb.width().toInt()
            var height = bb.height().toInt()
            if (left + width > bitmap.width) width = bitmap.width - left
            if (top + height > bitmap.height) height = bitmap.height - top
            if (width <= 0 || height <= 0) continue
            croppedBitmaps.add(Bitmap.createBitmap(bitmap, left, top, width, height))
        }
        return croppedBitmaps
    }

    data class DetectionResult(val boundingBox: RectF, val label: String, val confidence: Float)
}
