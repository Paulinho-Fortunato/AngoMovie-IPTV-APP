package com.angomovie.angomovie_iptv

import com.angomovie.angomovie_iptv.data.local.LocalMediaChannelHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            LOCAL_MEDIA_CHANNEL,
        ).setMethodCallHandler(LocalMediaChannelHandler(applicationContext))
    }

    companion object {
        private const val LOCAL_MEDIA_CHANNEL = "com.angomovie.iptv/local_media"
    }
}
