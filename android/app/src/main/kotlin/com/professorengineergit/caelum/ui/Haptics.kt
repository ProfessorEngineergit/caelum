package com.professorengineergit.caelum.ui

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.HapticFeedbackConstants
import android.view.View
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView

/**
 * Playful haptics for the whole app. Each moment has its own little pattern, built
 * from the rich "primitives" of modern vibration motors (Android 11+; ColorOS's
 * O-Haptics and Pixel motors both have them) and falling back to waveforms or
 * plain system feedback on older or simpler devices.
 */
class Haptics(context: Context, private val view: View) {
    var enabled: Boolean = true

    private val vibrator: Vibrator? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
        context.getSystemService(VibratorManager::class.java)?.defaultVibrator
    } else {
        @Suppress("DEPRECATION")
        context.getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
    }

    private val hasMotor: Boolean = vibrator?.hasVibrator() == true

    /** A step of a composition: which primitive, how strong (0–1), and the pause before it in ms. */
    private data class Step(val primitive: Int, val scale: Float, val delay: Int = 0)

    // MARK: - The vocabulary

    /** The lightest touch: scrolling past an item, a carousel snap. */
    fun tick(strength: Float = 0.5f) = play(
        listOf(Step(PRIM_LOW_TICK, strength)),
        fallback = HapticFeedbackConstants.CLOCK_TICK,
    )

    /** A firm press on a button. */
    fun click() = play(
        listOf(Step(PRIM_CLICK, 0.75f)),
        fallback = HapticFeedbackConstants.VIRTUAL_KEY,
    )

    /** Picking something: a little rise that snaps into place. */
    fun select() = play(
        listOf(Step(PRIM_QUICK_RISE, 0.45f), Step(PRIM_CLICK, 0.9f, 25)),
        fallback = HapticFeedbackConstants.CONTEXT_CLICK,
        waveform = longArrayOf(0, 18, 30, 12) to intArrayOf(0, 90, 0, 220),
    )

    /** Switching to another source — it spins into orbit. */
    fun orbit() = play(
        listOf(Step(PRIM_SPIN, 0.55f), Step(PRIM_TICK, 0.5f, 40), Step(PRIM_CLICK, 0.85f, 30)),
        fallback = HapticFeedbackConstants.CONTEXT_CLICK,
        waveform = longArrayOf(0, 25, 25, 10, 30, 14) to intArrayOf(0, 80, 0, 120, 0, 230),
    )

    fun toggle(on: Boolean) = if (on) {
        play(
            listOf(Step(PRIM_QUICK_RISE, 0.6f), Step(PRIM_CLICK, 1f, 15)),
            fallback = HapticFeedbackConstants.VIRTUAL_KEY,
        )
    } else {
        play(
            listOf(Step(PRIM_QUICK_FALL, 0.55f), Step(PRIM_TICK, 0.4f, 10)),
            fallback = HapticFeedbackConstants.VIRTUAL_KEY_RELEASE,
        )
    }

    /** A sheet or a screen opening. */
    fun open() = play(
        listOf(Step(PRIM_SLOW_RISE, 0.35f), Step(PRIM_TICK, 0.6f, 20)),
        fallback = HapticFeedbackConstants.CONTEXT_CLICK,
    )

    /** Going back or closing. */
    fun close() = play(
        listOf(Step(PRIM_QUICK_FALL, 0.4f)),
        fallback = HapticFeedbackConstants.CLOCK_TICK,
    )

    /** Pressed and held. */
    fun longPress() = play(
        listOf(Step(PRIM_THUD, 0.6f), Step(PRIM_SLOW_RISE, 0.3f, 10)),
        fallback = HapticFeedbackConstants.LONG_PRESS,
    )

    /** Ignition: the warp drive spools up. */
    fun ignite() = play(
        listOf(Step(PRIM_SLOW_RISE, 0.5f), Step(PRIM_QUICK_RISE, 0.8f, 40), Step(PRIM_CLICK, 0.6f, 20)),
        fallback = HapticFeedbackConstants.CONFIRM,
        waveform = longArrayOf(0, 60, 20, 40) to intArrayOf(0, 60, 0, 200),
    )

    /** One beat of the engine while in warp; [intensity] climbs from 0 to 1. */
    fun warpPulse(intensity: Float) = play(
        listOf(Step(PRIM_TICK, 0.25f + 0.6f * intensity), Step(PRIM_LOW_TICK, 0.2f + 0.5f * intensity, 30)),
        fallback = HapticFeedbackConstants.CLOCK_TICK,
    )

    /** Arrival: a deep thud, then the shockwave rings out. */
    fun land() = play(
        listOf(
            Step(PRIM_THUD, 1f),
            Step(PRIM_CLICK, 0.8f, 70),
            Step(PRIM_TICK, 0.55f, 60),
            Step(PRIM_TICK, 0.35f, 70),
            Step(PRIM_LOW_TICK, 0.2f, 80),
        ),
        fallback = HapticFeedbackConstants.CONFIRM,
        waveform = longArrayOf(0, 45, 60, 18, 60, 12, 70, 8) to intArrayOf(0, 255, 0, 180, 0, 110, 0, 60),
    )

    /** Something went wrong: two dull knocks. */
    fun error() = play(
        listOf(Step(PRIM_THUD, 0.5f), Step(PRIM_THUD, 0.35f, 90), Step(PRIM_QUICK_FALL, 0.4f, 40)),
        fallback = HapticFeedbackConstants.REJECT,
        waveform = longArrayOf(0, 40, 90, 40) to intArrayOf(0, 160, 0, 110),
    )

    // MARK: - Playing

    private fun play(steps: List<Step>, fallback: Int, waveform: Pair<LongArray, IntArray>? = null) {
        if (!enabled) return
        val vib = vibrator
        if (vib != null && hasMotor && Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val supported = steps.filter { primitiveSupported(vib, it.primitive) }
            if (supported.isNotEmpty()) {
                runCatching {
                    val composition = VibrationEffect.startComposition()
                    supported.forEach { composition.addPrimitive(it.primitive, it.scale.coerceIn(0f, 1f), it.delay) }
                    vib.vibrate(composition.compose())
                }.onSuccess { return }
            }
        }
        if (vib != null && hasMotor && waveform != null && vib.hasAmplitudeControl()) {
            runCatching { vib.vibrate(VibrationEffect.createWaveform(waveform.first, waveform.second, -1)) }
                .onSuccess { return }
        }
        view.performHapticFeedback(fallback)
    }

    private val supportCache = HashMap<Int, Boolean>()

    private fun primitiveSupported(vib: Vibrator, primitive: Int): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) return false
        if (primitive == PRIM_SPIN || primitive == PRIM_THUD || primitive == PRIM_LOW_TICK) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return false
        }
        return supportCache.getOrPut(primitive) { vib.areAllPrimitivesSupported(primitive) }
    }

    private companion object {
        // The values of VibrationEffect.Composition.PRIMITIVE_*; plain ints so they can be
        // named on any API level (each is only used where the platform has it).
        const val PRIM_CLICK = 1
        const val PRIM_THUD = 2
        const val PRIM_SPIN = 3
        const val PRIM_QUICK_RISE = 4
        const val PRIM_SLOW_RISE = 5
        const val PRIM_QUICK_FALL = 6
        const val PRIM_TICK = 7
        const val PRIM_LOW_TICK = 8
    }
}

val LocalHaptics = staticCompositionLocalOf<Haptics> { error("No Haptics provided") }

@Composable
fun ProvideHaptics(enabled: Boolean, content: @Composable () -> Unit) {
    val context = LocalContext.current
    val view = LocalView.current
    val haptics = remember(view) { Haptics(context, view) }
    haptics.enabled = enabled
    CompositionLocalProvider(LocalHaptics provides haptics, content = content)
}
