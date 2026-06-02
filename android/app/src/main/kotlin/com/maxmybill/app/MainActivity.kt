package com.maxmybill.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.app.Activity
import android.net.Uri
import java.io.OutputStream

class MainActivity : FlutterActivity() {
	private val CHANNEL = "maxbillup/storage"
	private val CREATE_FILE_REQUEST_CODE = 42424

	private var pendingBytes: ByteArray? = null
	private var pendingFileName: String? = null
	private var pendingMimeType: String? = null
	private var pendingResult: MethodChannel.Result? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
			if (call.method == "saveFile") {
				val args = call.arguments as Map<String, Any>
				val fileName = args["fileName"] as String
				val mimeType = args["mimeType"] as String
				val bytes = args["bytes"] as ByteArray

				// store pending data and launch SAF create document
				pendingBytes = bytes
				pendingFileName = fileName
				pendingMimeType = mimeType
				pendingResult = result

				val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
					addCategory(Intent.CATEGORY_OPENABLE)
					type = mimeType
					putExtra(Intent.EXTRA_TITLE, fileName)
				}

				startActivityForResult(intent, CREATE_FILE_REQUEST_CODE)
			} else if (call.method == "saveToMediaStore") {
				val args = call.arguments as Map<String, Any>
				val fileName = args["fileName"] as String
				val mimeType = args["mimeType"] as String
				val subFolder = args["subFolder"] as? String
				val bytes = args["bytes"] as ByteArray

				try {
					// Use MediaStore to insert into Downloads collection so file is visible
					val values = android.content.ContentValues().apply {
						put(android.provider.MediaStore.MediaColumns.DISPLAY_NAME, fileName)
						put(android.provider.MediaStore.MediaColumns.MIME_TYPE, mimeType)
						if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
							val rel = if (!subFolder.isNullOrEmpty())
								"${android.os.Environment.DIRECTORY_DOWNLOADS}/${subFolder}"
							else
								android.os.Environment.DIRECTORY_DOWNLOADS
							put(android.provider.MediaStore.MediaColumns.RELATIVE_PATH, rel)
						}
					}

					val resolver = contentResolver
					val collection = android.provider.MediaStore.Downloads.getContentUri(android.provider.MediaStore.VOLUME_EXTERNAL_PRIMARY)
					val uri = resolver.insert(collection, values)
					if (uri != null) {
						val out: OutputStream? = resolver.openOutputStream(uri)
						out?.write(bytes)
						out?.flush()
						out?.close()
						result.success(uri.toString())
					} else {
						result.error("save_failed", "Could not create MediaStore entry", null)
					}
				} catch (e: Exception) {
					result.error("save_failed", e.message, null)
				}
			} else {
				result.notImplemented()
			}
		}
	}

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)

		if (requestCode == CREATE_FILE_REQUEST_CODE) {
			val result = pendingResult
			if (resultCode == Activity.RESULT_OK && data != null) {
				val uri: Uri? = data.data
				try {
					if (uri != null && pendingBytes != null) {
						val out: OutputStream? = contentResolver.openOutputStream(uri)
						out?.write(pendingBytes)
						out?.flush()
						out?.close()
						// return the content uri string to Dart
						result?.success(uri.toString())
					} else {
						result?.error("save_failed", "No URI or data", null)
					}
				} catch (e: Exception) {
					result?.error("save_failed", e.message, null)
				}
			} else {
				// user cancelled
				result?.success(null)
			}

			// clear pending
			pendingBytes = null
			pendingFileName = null
			pendingMimeType = null
			pendingResult = null
		}
	}
}

