package com.joker.jokerstreet

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// ---------------------------------------------------------------
// MainActivity — WebView file-upload bridge (Joker Street)
// ---------------------------------------------------------------
// Dependency-free WebView file upload. The site's <input type="file">
// triggers the WebView's file selector, which hops here over the
// MethodChannel and returns picked content:// URIs to the WebView.
// No file_picker plugin — see gray_part_pitfalls.md §1.
//
// [FINGERPRINT] The channel name is project-unique ("joker/media_pick")
// and MUST match `_uploadChannel` in lib/carnival/web_scene.dart.
// pickRequest is a per-project short int, chosen to avoid collisions
// with other MethodChannels the app might add later.
// ---------------------------------------------------------------
class MainActivity : FlutterActivity() {
    private val mediaChannelName = "joker/media_pick"
    private val pickRequestCode = 0x5A17
    private var pendingCall: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannelName)
            .setMethodCallHandler { call, reply ->
                when (call.method) {
                    "pick" -> {
                        val multi = call.argument<Boolean>("multiple") ?: false
                        val mimes = call.argument<List<String>>("mimeTypes") ?: emptyList()
                        launchChooser(multi, mimes, reply)
                    }
                    else -> reply.notImplemented()
                }
            }
    }

    private fun launchChooser(
        multi: Boolean,
        mimes: List<String>,
        reply: MethodChannel.Result,
    ) {
        // Any request that never got a result gets an empty answer so
        // the WebView finalises its pending FileSelector future.
        pendingCall?.success(emptyList<String>())
        pendingCall = reply

        val filtered = mimes.filter { it.contains("/") }
        val chooserIntent = Intent(Intent.ACTION_GET_CONTENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, multi)
            when {
                filtered.isEmpty() -> type = "*/*"
                filtered.size == 1 -> type = filtered[0]
                else -> {
                    type = "*/*"
                    putExtra(Intent.EXTRA_MIME_TYPES, filtered.toTypedArray())
                }
            }
        }

        try {
            startActivityForResult(
                Intent.createChooser(chooserIntent, null),
                pickRequestCode,
            )
        } catch (e: Exception) {
            pendingCall = null
            reply.success(emptyList<String>())
        }
    }

    override fun onActivityResult(
        requestCode: Int,
        resultCode: Int,
        data: Intent?,
    ) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != pickRequestCode) return

        val reply = pendingCall
        pendingCall = null
        if (reply == null) return

        if (resultCode != Activity.RESULT_OK || data == null) {
            reply.success(emptyList<String>())
            return
        }

        val uris = ArrayList<String>()
        val clip = data.clipData
        if (clip != null) {
            for (index in 0 until clip.itemCount) {
                uris.add(clip.getItemAt(index).uri.toString())
            }
        } else {
            data.data?.let { uris.add(it.toString()) }
        }
        reply.success(uris)
    }
}
