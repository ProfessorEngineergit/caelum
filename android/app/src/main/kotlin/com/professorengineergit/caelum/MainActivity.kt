package com.professorengineergit.caelum

import android.graphics.Color
import android.graphics.drawable.ColorDrawable
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import com.professorengineergit.caelum.ui.CaelumRoot
import com.professorengineergit.caelum.ui.MainViewModel

class MainActivity : ComponentActivity() {
    private val viewModel: MainViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        val splash = installSplashScreen()
        super.onCreate(savedInstanceState)
        // Hold the splash until the stored source is known, so the first frame is the right one.
        splash.setKeepOnScreenCondition { !viewModel.state.value.loaded }
        enableEdgeToEdge()
        setContent { CaelumRoot(viewModel, onShowSystemWallpaper = ::showSystemWallpaper) }
    }

    /**
     * Lets the real system wallpaper show through wherever the app draws nothing — used
     * to reveal the freshly set wallpaper, and by the live preview's "compare" gesture.
     */
    private fun showSystemWallpaper(show: Boolean) {
        if (show) {
            window.setBackgroundDrawable(ColorDrawable(Color.TRANSPARENT))
            window.addFlags(WindowManager.LayoutParams.FLAG_SHOW_WALLPAPER)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SHOW_WALLPAPER)
            window.setBackgroundDrawable(ColorDrawable(getColor(R.color.obsidian)))
        }
    }
}
