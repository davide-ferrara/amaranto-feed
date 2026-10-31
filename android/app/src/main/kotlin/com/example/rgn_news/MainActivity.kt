package com.example.rgn_news

import android.content.res.Configuration
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val dark = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && dark) {
            splashScreen.setOnExitAnimationListener { splash ->
                // The OS entry frame only supports a solid color. Once handed
                // to us, use the same generated gradient as the app background.
                splash.setBackgroundResource(R.drawable.brand_launch_background)
                splash.animate().alpha(0f).setDuration(180L)
                    .withEndAction { splash.remove() }.start()
            }
        }
    }
}
