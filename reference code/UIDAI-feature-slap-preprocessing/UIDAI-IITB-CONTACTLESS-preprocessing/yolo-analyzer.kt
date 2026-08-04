package com.example.YOLOIntegration

import android.graphics.*
import android.graphics.ImageDecoder
import android.os.Build
import android.util.Log
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.ImageProxy
import org.tensorflow.lite.Interpreter
import java.io.ByteArrayOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.exp
import com.example.YOLOIntegration.YOLOv8Analyzer.DetectionResult
import kotlin.math.pow
import kotlin.math.sqrt


class YOLOv8Analyzer(
    private val tflite: Interpreter,
    private val onAnalysisResult: (Bitmap, List<DetectionResult>) -> Unit
) : ImageAnalysis.Analyzer {

    companion object {
        private const val TAG = "YOLOv8Analyzer"
        private const val INPUT_SIZE = 800
        private const val NUM_BOXES = 13125  // Changed to match model output
        private const val NUM_CLASSES = 1  // Assuming only one class (fingerprint)
        private const val CONFIDENCE_THRESHOLD = 0.7f  // Set this very low for testing
    }

    override fun analyze(image: ImageProxy) {
        Log.d(TAG, "Starting image analysis. Image format: ${image.format}")
        val bitmap = image.toBitmapp()
        val p = bitmap.height
        val q = bitmap.width
        val resizedBitmap = Bitmap.createScaledBitmap(bitmap, INPUT_SIZE, INPUT_SIZE, true)

        val inputBuffer = preprocess(resizedBitmap)
        val outputBuffer = Array(1) { Array(8) { FloatArray(13125) } }  // Changed to match model output

        tflite.run(inputBuffer, outputBuffer)
        Log.d(TAG, "Model output shape: ${outputBuffer.size} x ${outputBuffer[0].size} x ${outputBuffer[0][0].size}")
        Log.d(TAG, "bitmap :->  ${resizedBitmap}")
        val results = interpretResults(p,q,outputBuffer[0])
        val processedBitmap = drawDetectionResult(bitmap, results)
       val pB = processedBitmap[0]
        onAnalysisResult(pB, results)
        image.close()
    }


    private fun ImageProxy.toBitmapp(): Bitmap {
        val buffer = planes[0].buffer
        val bytes = ByteArray(buffer.remaining())
        buffer.get(bytes)

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val source = ImageDecoder.createSource(bytes)
            ImageDecoder.decodeBitmap(source) { decoder, _, _ ->
                decoder.isMutableRequired = true
            }
        } else {
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
        }
    }

    private fun preprocess(bitmap: Bitmap): ByteBuffer {
        val inputBuffer = ByteBuffer.allocateDirect(4 * INPUT_SIZE * INPUT_SIZE * 3)
        inputBuffer.order(ByteOrder.nativeOrder())

        val intValues = IntArray(INPUT_SIZE * INPUT_SIZE)
        bitmap.getPixels(intValues, 0, INPUT_SIZE, 0, 0, INPUT_SIZE, INPUT_SIZE)

//        val mean_r = 0.485f
//        val mean_g = 0.456f
//        val mean_b = 0.406f
//        val std_r = 0.229f
//        val std_g = 0.224f
//        val std_b = 0.225f

        for (pixelValue in intValues) {
            val r = (pixelValue shr 16 and 0xFF) / 255.0f
            val g = (pixelValue shr 8 and 0xFF) / 255.0f
            val b = (pixelValue and 0xFF) / 255.0f

//            inputBuffer.putFloat((r - mean_r) / std_r)
//            inputBuffer.putFloat((g - mean_g) / std_g)
//            inputBuffer.putFloat((b - mean_b) / std_b)
            inputBuffer.putFloat(r)
            inputBuffer.putFloat(g)
            inputBuffer.putFloat(b)
        }

        return inputBuffer
    }

//    private fun interpretResults(output: Array<FloatArray>): List<DetectionResult> {
//
//        val results = mutableListOf<DetectionResult>()
//        val numClasses = 1
//        val numBoxes = output[0].size / (numClasses + 5)
//
//        var maxConfidence = Float.MIN_VALUE
//        var minConfidence = Float.MAX_VALUE
//
//        Log.d(TAG, "Raw output size: ${output.size} x ${output[0].size}")
//        Log.d(TAG, "First few elements: ${output[0].take(10)}")
//
//        for (i in 0 until numBoxes) {
//            val offset = i * (numClasses + 5)
//            val confidence = output[4][offset + 4]
//            maxConfidence = maxOf(maxConfidence, confidence)
//            minConfidence = minOf(minConfidence, confidence)
//            Log.d(TAG, "Box $i: x=${output[0][i]}, y=${output[1][i]}, w=${output[2][i]}, h=${output[3][i]}, conf=$confidence")
//            if (confidence > CONFIDENCE_THRESHOLD) {
//                val x = output[0][offset]
//                val y = output[1][offset]
//                val w = output[2][offset]
//                val h = output[3][offset]
//                results.add(
//                    DetectionResult(
//                        RectF(
//                            (x - w/2) * INPUT_SIZE,
//                            (y - h/2) * INPUT_SIZE,
//                            (x + w/2) * INPUT_SIZE,
//                            (y + h/2) * INPUT_SIZE
//                        ),
//                        "Fingerprint",
//                        confidence
//                    )
//                )
//            }
//        }
//
//        Log.d(TAG, "Max confidence: $maxConfidence")
//        Log.d(TAG, "Min confidence: $minConfidence")
//        Log.d(TAG, "Total detections before NMS: ${results.size}")
//        val nmsResults = nms(results, 0.5f)
//        Log.d(TAG, "Total detections after NMS: ${nmsResults.size}")
//        return nmsResults
//    }

    private fun interpretResults(a: Int, b: Int,output: Array<FloatArray>): List<DetectionResult> {
        val results = mutableListOf<DetectionResult>()
        Log.d(TAG, "Output size: ${output.size}")
        Log.d(TAG, "Rows: ${output[0].size}")
        val num_boxes = output[0].size
        // val rows = output[0].size / (NUM_CLASSES + 7)  // 5 for x, y, w, h, confidence
        // Log.d(TAG, "Rows: ${rows}")
        // Chose the value 7 everywhere because NUM_CLASSES here is 1 and total dimensions per box in the model output is 8
        // So to loop over all outputs, we need to divide it in rows of 8, i.e. NUM_CLASSES + 7

        for (i in 0 until num_boxes) {
            val confidence = output[6][i] //val confidence = output[6][i * (NUM_CLASSES + 7) + 6]
//            Log.d(TAG, "Box $i: x=${output[0][i]}, y=${output[1][i]}, w=${output[2][i]}, h=${output[3][i]}, conf=$confidence")
            if (confidence > CONFIDENCE_THRESHOLD) {
//                val x = output[0][i * (NUM_CLASSES + 5) + 0]
//                val y = output[0][i * (NUM_CLASSES + 5) + 1]
//                val w = output[0][i * (NUM_CLASSES + 5) + 2]
//                val h = output[0][i * (NUM_CLASSES + 5) + 3]
                val x = output[0][i]
                val y = output[1][i]
                val w = output[2][i]
                val h = output[3][i]


                val left = (x - w / 2) * b
                val top = (y - h / 2) * a
                val right = (x + w / 2) * b
                val bottom = (y + h / 2) * a
//                val height = h* INPUT_SIZE
//                val width = w* INPUT_SIZE

                results.add(
                    DetectionResult(
                        RectF(left, top, right, bottom),
                        "Fingerprint",
                        confidence
                    )
                )
            }
        }

        return nms(results, 0.3f) // iouThreshold
    }

    private fun sigmoid(x: Float): Float {
        return 1.0f / (1.0f + exp(-x))
    }

    private fun nms(boxes: List<DetectionResult>, iouThreshold: Float): List<DetectionResult> {
        val sortedBoxes = boxes.sortedByDescending { it.confidence }
        val selectedBoxes = mutableListOf<DetectionResult>()

        for (box in sortedBoxes) {
            var shouldSelect = true
            for (selectedBox in selectedBoxes) {
                if (calculateIoU(box.boundingBox, selectedBox.boundingBox) > iouThreshold) {
                    shouldSelect = false
                    break
                }
            }
            if (shouldSelect) selectedBoxes.add(box)
        }

        return selectedBoxes
    }

    private fun calculateIoU(box1: RectF, box2: RectF): Float {
        val intersectionArea = RectF().apply {
            setIntersect(box1, box2)
        }.let { if (it.isEmpty) 0f else it.width() * it.height() }

        val box1Area = box1.width() * box1.height()
        val box2Area = box2.width() * box2.height()
        val unionArea = box1Area + box2Area - intersectionArea

        return intersectionArea / unionArea
    }

    private fun drawDetectionResult(bitmap: Bitmap, results: List<DetectionResult>): List<Bitmap> {
        val croppedBitmaps = mutableListOf<Bitmap>()

        for (result in results) {
            val boundingBox = result.boundingBox
            val croppedBitmap = Bitmap.createBitmap(
                bitmap,
                boundingBox.left.toInt(),
                boundingBox.top.toInt(),
                boundingBox.width().toInt(),
                boundingBox.height().toInt()
            )
            croppedBitmaps.add(croppedBitmap)
        }

        return croppedBitmaps
    }


    data class DetectionResult(val boundingBox: RectF, val label: String, val confidence: Float)
}