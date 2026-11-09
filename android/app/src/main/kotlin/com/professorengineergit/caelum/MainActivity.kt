package com.professorengineergit.caelum

import android.os.Bundle
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
        setContent { CaelumRoot(viewModel) }
    }
}
