package com.professorengineergit.caelum.ui

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.clipPath
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.drawscope.translate
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

/**
 * A small painted picture for each source — a telescope for Hubble, the golden mirror
 * for Webb, a dome under the Milky Way for ESO — instead of an abstract shape.
 * Drawn, not bitmaps: crisp at any size and no agency logos borrowed.
 */
@Composable
fun SourceEmblem(sourceId: String, accent: Color, modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val circle = Path().apply { addOval(Rect(Offset.Zero, size)) }
        clipPath(circle) {
            when (sourceId) {
                "apod" -> apod()
                "hubble" -> hubble()
                "webb" -> webb()
                "eso" -> eso()
                "deep" -> galaxy(accent)
                "earth" -> earth()
                "solar" -> saturn()
                "stations" -> rocket()
                "interstellar" -> blackHole()
                "artist-impressions" -> exoplanet(accent)
                else -> galaxy(accent)
            }
        }
    }
}

// MARK: - Shared pieces

private val Space = Color(0xFF070A1F)
private val SpaceBlue = Color(0xFF0E1B4D)

private fun DrawScope.sky(top: Color = SpaceBlue, bottom: Color = Space) {
    drawRect(Brush.verticalGradient(listOf(top, bottom)))
}

/** Deterministic stars, so the emblem doesn't twinkle between recompositions. */
private fun DrawScope.stars(seed: Int, count: Int = 18, maxRadius: Float = 0.018f) {
    val random = Random(seed)
    repeat(count) {
        val r = size.minDimension * maxRadius * (0.35f + random.nextFloat() * 0.65f)
        drawCircle(
            Color.White.copy(alpha = 0.45f + random.nextFloat() * 0.55f),
            radius = r,
            center = Offset(random.nextFloat() * size.width, random.nextFloat() * size.height),
        )
    }
}

private fun DrawScope.sparkle(center: Offset, radius: Float, color: Color = Color.White) {
    val path = Path().apply {
        moveTo(center.x, center.y - radius)
        quadraticTo(center.x, center.y, center.x + radius, center.y)
        quadraticTo(center.x, center.y, center.x, center.y + radius)
        quadraticTo(center.x, center.y, center.x - radius, center.y)
        quadraticTo(center.x, center.y, center.x, center.y - radius)
        close()
    }
    drawPath(path, color)
}

private val DrawScope.w get() = size.width
private val DrawScope.h get() = size.height

// MARK: - APOD: a deep-blue disc of stars, an orbit and a swoosh climbing to the upper right

private fun DrawScope.apod() {
    drawRect(Brush.radialGradient(listOf(Color(0xFF1F4BC2), Color(0xFF0B1F66), Space), center = center, radius = w * 0.7f))
    stars(seed = 1, count = 22)
    // The orbit, tilted.
    rotate(-25f) {
        drawOval(
            color = Color.White.copy(alpha = 0.9f),
            topLeft = Offset(w * 0.12f, h * 0.36f),
            size = Size(w * 0.76f, h * 0.28f),
            style = Stroke(width = w * 0.035f),
        )
    }
    // The swoosh: from the lower left, curving up and out to the right.
    val swoosh = Path().apply {
        moveTo(w * 0.08f, h * 0.80f)
        cubicTo(w * 0.35f, h * 0.62f, w * 0.55f, h * 0.46f, w * 0.98f, h * 0.20f)
        cubicTo(w * 0.62f, h * 0.52f, w * 0.38f, h * 0.70f, w * 0.18f, h * 0.86f)
        close()
    }
    drawPath(swoosh, Brush.linearGradient(listOf(Color(0xFFFF4D3D), Color(0xFFFF9A5E)), Offset(0f, h), Offset(w, 0f)))
    // A planet on the orbit.
    drawCircle(Color(0xFF5EE7FF), radius = w * 0.07f, center = Offset(w * 0.72f, h * 0.38f))
    sparkle(Offset(w * 0.30f, h * 0.30f), w * 0.07f)
}

// MARK: - Hubble: the telescope with its two solar wings, drifting over the stars

private fun DrawScope.hubble() {
    sky(Color(0xFF1A1450), Space)
    stars(seed = 2, count = 16)
    // Earth's limb below.
    drawCircle(
        Brush.verticalGradient(listOf(Color(0xFF4FA3FF), Color(0xFF0B3A7A)), startY = h * 0.78f, endY = h * 1.3f),
        radius = w * 0.9f,
        center = Offset(w * 0.5f, h * 1.62f),
    )
    rotate(-28f) {
        val bodyW = w * 0.22f
        val bodyH = h * 0.56f
        val left = center.x - bodyW / 2
        val top = center.y - bodyH / 2
        // Solar panels.
        val panelW = w * 0.20f
        val panelH = h * 0.36f
        for (side in listOf(-1, 1)) {
            val px = if (side < 0) left - panelW - w * 0.05f else left + bodyW + w * 0.05f
            val py = center.y - panelH / 2
            drawLine(Color(0xFFB8C0D0), Offset(px + panelW / 2, center.y), Offset(center.x, center.y), strokeWidth = w * 0.02f)
            drawRect(Brush.verticalGradient(listOf(Color(0xFF3B6FE0), Color(0xFF1B3A9A)), startY = py, endY = py + panelH), Offset(px, py), Size(panelW, panelH))
            for (i in 1..3) {
                val y = py + panelH * i / 4f
                drawLine(Color.White.copy(alpha = 0.35f), Offset(px, y), Offset(px + panelW, y), strokeWidth = w * 0.008f)
            }
            drawLine(Color.White.copy(alpha = 0.35f), Offset(px + panelW / 2, py), Offset(px + panelW / 2, py + panelH), strokeWidth = w * 0.008f)
        }
        // Body: a silver cylinder.
        drawRoundRect(
            Brush.horizontalGradient(listOf(Color(0xFF8C93A3), Color(0xFFF2F4F8), Color(0xFF9AA1B0)), startX = left, endX = left + bodyW),
            Offset(left, top),
            Size(bodyW, bodyH),
            CornerRadius(w * 0.03f),
        )
        // Bands on the body.
        for (f in listOf(0.38f, 0.62f)) {
            drawRect(Color(0xFF6B7282), Offset(left, top + bodyH * f), Size(bodyW, h * 0.018f))
        }
        // Open aperture door at the top.
        rotate(-35f, pivot = Offset(left + bodyW, top)) {
            drawRect(Color(0xFFD9DDE6), Offset(left, top - h * 0.03f), Size(bodyW, h * 0.03f))
        }
        drawOval(Color(0xFF2A2F3D), Offset(left + bodyW * 0.1f, top - h * 0.012f), Size(bodyW * 0.8f, h * 0.035f))
    }
}

// MARK: - Webb: the golden honeycomb mirror over its violet sunshield

private fun DrawScope.webb() {
    sky(Color(0xFF2A1240), Space)
    stars(seed = 3, count = 14)
    // Sunshield: stacked violet layers.
    for (i in 0..2) {
        val y = h * (0.72f + i * 0.05f)
        val path = Path().apply {
            moveTo(w * 0.05f, y + h * 0.06f)
            lineTo(w * 0.5f, y - h * 0.04f)
            lineTo(w * 0.95f, y + h * 0.06f)
            lineTo(w * 0.5f, y + h * 0.13f)
            close()
        }
        drawPath(path, Color(0xFFB57CFF).copy(alpha = 0.55f + i * 0.15f))
    }
    // The mirror: 18 hexagons around an empty centre.
    val r = w * 0.085f
    val cx = w * 0.5f
    val cy = h * 0.43f
    val dx = sqrt(3f) * r
    val dy = 1.5f * r
    val cells = listOf(
        // Axial coordinates (q, r) of the rings at distance 1 and 2.
        1 to 0, -1 to 0, 0 to 1, 0 to -1, 1 to -1, -1 to 1,
        2 to 0, -2 to 0, 0 to 2, 0 to -2, 2 to -2, -2 to 2,
        2 to -1, -2 to 1, 1 to 1, -1 to -1, 1 to -2, -1 to 2,
    )
    val gold = Brush.linearGradient(listOf(Color(0xFFFFE08A), Color(0xFFE0A030), Color(0xFFFFC85E)), Offset(cx - w * 0.3f, cy - h * 0.3f), Offset(cx + w * 0.3f, cy + h * 0.3f))
    for ((q, rr) in cells) {
        // Pointy-top hex layout.
        val x = cx + dx * (q + rr / 2f)
        val y = cy + dy * rr
        hexagon(Offset(x, y), r * 0.93f, gold)
    }
    // Secondary mirror on its struts.
    val tip = Offset(cx, cy - h * 0.36f)
    drawLine(Color(0xFFC9B27A), Offset(cx - dx * 1.6f, cy + dy * 0.6f), tip, strokeWidth = w * 0.012f)
    drawLine(Color(0xFFC9B27A), Offset(cx + dx * 1.6f, cy + dy * 0.6f), tip, strokeWidth = w * 0.012f)
    drawCircle(Color(0xFFFFE08A), radius = w * 0.03f, center = tip)
}

private fun DrawScope.hexagon(center: Offset, radius: Float, brush: Brush) {
    val path = Path()
    for (i in 0 until 6) {
        val a = (PI / 3 * i - PI / 2).toFloat()
        val p = Offset(center.x + radius * cos(a), center.y + radius * sin(a))
        if (i == 0) path.moveTo(p.x, p.y) else path.lineTo(p.x, p.y)
    }
    path.close()
    drawPath(path, brush)
}

// MARK: - ESO: an observatory dome on a mountain, its laser reaching for the Milky Way

private fun DrawScope.eso() {
    sky(Color(0xFF0E2C4A), Color(0xFF050814))
    // Milky Way band.
    rotate(-35f) {
        drawOval(
            Brush.verticalGradient(listOf(Color.Transparent, Color(0x55C9D8FF), Color.Transparent), startY = h * 0.3f, endY = h * 0.6f),
            Offset(-w * 0.2f, h * 0.3f),
            Size(w * 1.4f, h * 0.3f),
        )
    }
    stars(seed = 4, count = 26, maxRadius = 0.014f)
    // Laser guide star, from the dome's slit up into the sky.
    drawLine(
        Brush.linearGradient(listOf(Color(0xFFFFB45E), Color(0x00FFB45E)), Offset(w * 0.5f, h * 0.56f), Offset(w * 0.8f, h * 0.08f)),
        Offset(w * 0.5f, h * 0.56f),
        Offset(w * 0.8f, h * 0.08f),
        strokeWidth = w * 0.03f,
        cap = StrokeCap.Round,
    )
    // Mountain.
    val mountain = Path().apply {
        moveTo(0f, h * 0.80f)
        lineTo(w * 0.22f, h * 0.70f)
        lineTo(w * 0.5f, h * 0.72f)
        lineTo(w * 0.78f, h * 0.70f)
        lineTo(w, h * 0.76f)
        lineTo(w, h)
        lineTo(0f, h)
        close()
    }
    drawPath(mountain, Color(0xFF1A1420))
    // Dome on its drum, slit open.
    val domeW = w * 0.40f
    val left = w * 0.5f - domeW / 2
    drawRect(Color(0xFFC9CED8), Offset(left, h * 0.66f), Size(domeW, h * 0.10f))
    drawArc(
        Brush.horizontalGradient(listOf(Color(0xFFB8BEC9), Color.White, Color(0xFFC9CED8)), startX = left, endX = left + domeW),
        180f, 180f, true, Offset(left, h * 0.48f), Size(domeW, h * 0.36f),
    )
    drawRect(Color(0xFF1A1E2A), Offset(w * 0.475f, h * 0.50f), Size(w * 0.05f, h * 0.16f))
}

// MARK: - Deep Space: a spiral galaxy

private fun DrawScope.galaxy(accent: Color) {
    sky(Color(0xFF15123A), Space)
    stars(seed = 5, count = 14)
    drawCircle(Brush.radialGradient(listOf(Color.White, accent.copy(alpha = 0.6f), Color.Transparent), center = center, radius = w * 0.45f), radius = w * 0.45f)
    rotate(20f) {
        for (arm in 0 until 2) {
            val base = arm * PI.toFloat()
            for (i in 0 until 46) {
                val t = i / 45f
                val angle = base + t * 3.6f
                val radius = w * (0.05f + 0.38f * t)
                val p = Offset(center.x + radius * cos(angle), center.y + radius * sin(angle) * 0.62f)
                drawCircle(Color.White.copy(alpha = 0.85f * (1 - t) + 0.1f), radius = w * (0.035f * (1 - t) + 0.008f), center = p)
            }
        }
    }
    drawCircle(Color(0xFFFFF4D6), radius = w * 0.07f, center = center)
}

// MARK: - Earth from Space: the blue marble with its glowing limb

private fun DrawScope.earth() {
    sky(Color(0xFF050B1E), Color(0xFF02040C))
    stars(seed = 6, count = 12)
    val c = Offset(w * 0.56f, h * 0.6f)
    val r = w * 0.48f
    drawCircle(Color(0xFF5EE7FF).copy(alpha = 0.35f), radius = r * 1.07f, center = c)
    drawCircle(Brush.radialGradient(listOf(Color(0xFF3FA0FF), Color(0xFF0B3C8C)), center = c - Offset(r * 0.3f, r * 0.3f), radius = r * 1.3f), radius = r, center = c)
    clipPath(Path().apply { addOval(Rect(c, r)) }) {
        // Continents.
        drawOval(Color(0xFF3FBF7F), Offset(c.x - r * 0.7f, c.y - r * 0.5f), Size(r * 0.7f, r * 0.55f))
        drawOval(Color(0xFF3FBF7F), Offset(c.x + r * 0.05f, c.y - r * 0.1f), Size(r * 0.5f, r * 0.8f))
        drawOval(Color(0xFFD9C27A), Offset(c.x - r * 0.4f, c.y + r * 0.2f), Size(r * 0.35f, r * 0.25f))
        // Clouds.
        for (i in 0..2) {
            drawOval(Color.White.copy(alpha = 0.7f), Offset(c.x - r * 0.9f + i * r * 0.55f, c.y - r * 0.75f + i * r * 0.45f), Size(r * 0.6f, r * 0.1f))
        }
        // Night side.
        drawCircle(Brush.radialGradient(listOf(Color.Transparent, Color(0xCC020615)), center = c - Offset(r * 0.45f, r * 0.45f), radius = r * 1.9f), radius = r, center = c)
    }
}

// MARK: - Solar System: Saturn and its rings

private fun DrawScope.saturn() {
    sky(Color(0xFF1E1530), Space)
    stars(seed = 7, count = 14)
    val c = center
    val r = w * 0.24f
    val ringTilt = -18f
    rotate(ringTilt, c) {
        // Back half of the rings.
        drawArc(Color(0xFFE8C98A), 180f, 180f, false, Offset(c.x - r * 1.85f, c.y - r * 0.45f), Size(r * 3.7f, r * 0.9f), style = Stroke(w * 0.05f))
    }
    drawCircle(Brush.verticalGradient(listOf(Color(0xFFFFE2A0), Color(0xFFE0A050), Color(0xFFB07030)), startY = c.y - r, endY = c.y + r), radius = r, center = c)
    clipPath(Path().apply { addOval(Rect(c, r)) }) {
        for (i in -2..2) drawRect(Color(0x33FFFFFF), Offset(c.x - r, c.y + i * r * 0.35f), Size(r * 2, r * 0.08f))
    }
    rotate(ringTilt, c) {
        // Front half of the rings, over the planet.
        drawArc(Color(0xFFF5DCA8), 0f, 180f, false, Offset(c.x - r * 1.85f, c.y - r * 0.45f), Size(r * 3.7f, r * 0.9f), style = Stroke(w * 0.05f))
        drawArc(Color(0xFFC9A060), 0f, 180f, false, Offset(c.x - r * 1.55f, c.y - r * 0.32f), Size(r * 3.1f, r * 0.64f), style = Stroke(w * 0.02f))
    }
}

// MARK: - Spacecraft: a rocket climbing out of the atmosphere

private fun DrawScope.rocket() {
    sky(Color(0xFF3A1E3A), Space)
    stars(seed = 8, count = 14)
    rotate(35f) {
        val cx = w * 0.5f
        val top = h * 0.14f
        val bodyW = w * 0.2f
        // Flame.
        val flame = Path().apply {
            moveTo(cx - bodyW * 0.4f, h * 0.70f)
            quadraticTo(cx, h * 1.05f, cx + bodyW * 0.4f, h * 0.70f)
            close()
        }
        drawPath(flame, Brush.verticalGradient(listOf(Color(0xFFFFF2B0), Color(0xFFFF8A5E), Color.Transparent), startY = h * 0.70f, endY = h * 1.0f))
        // Fins.
        for (side in listOf(-1f, 1f)) {
            val fin = Path().apply {
                moveTo(cx + side * bodyW * 0.5f, h * 0.52f)
                lineTo(cx + side * bodyW * 1.05f, h * 0.72f)
                lineTo(cx + side * bodyW * 0.5f, h * 0.70f)
                close()
            }
            drawPath(fin, Color(0xFFFF6A5E))
        }
        // Body with a pointed nose.
        val body = Path().apply {
            moveTo(cx, top)
            cubicTo(cx + bodyW * 0.75f, top + h * 0.12f, cx + bodyW * 0.5f, h * 0.4f, cx + bodyW * 0.5f, h * 0.72f)
            lineTo(cx - bodyW * 0.5f, h * 0.72f)
            cubicTo(cx - bodyW * 0.5f, h * 0.4f, cx - bodyW * 0.75f, top + h * 0.12f, cx, top)
            close()
        }
        drawPath(body, Brush.horizontalGradient(listOf(Color(0xFFB8C0D0), Color.White, Color(0xFFC8CEDA)), startX = cx - bodyW / 2, endX = cx + bodyW / 2))
        drawCircle(Color(0xFF5EE7FF), radius = bodyW * 0.22f, center = Offset(cx, h * 0.38f))
        drawCircle(Color(0xFF2A3A5A), radius = bodyW * 0.22f, center = Offset(cx, h * 0.38f), style = Stroke(w * 0.015f))
    }
}

// MARK: - Sci-Fi: a black hole with its blazing disc

private fun DrawScope.blackHole() {
    drawRect(Color(0xFF04030A))
    stars(seed = 9, count = 20)
    val c = center
    val r = w * 0.17f
    // Lensed ring behind (the light bent over the top).
    drawOval(
        Brush.radialGradient(listOf(Color(0xFFFFE6B0), Color(0xFFFF9A3E), Color.Transparent), center = c, radius = r * 2f),
        Offset(c.x - r * 1.45f, c.y - r * 1.45f),
        Size(r * 2.9f, r * 2.9f),
    )
    drawCircle(Color.Black, radius = r * 1.05f, center = c)
    // Accretion disc in front.
    drawOval(
        Brush.horizontalGradient(listOf(Color.Transparent, Color(0xFFFF8A3E), Color(0xFFFFF0C8), Color(0xFFFF8A3E), Color.Transparent)),
        Offset(c.x - r * 2.9f, c.y - r * 0.28f),
        Size(r * 5.8f, r * 0.56f),
    )
    drawOval(Color.Black, Offset(c.x - r * 1.0f, c.y - r * 0.1f), Size(r * 2.0f, r * 0.2f))
    drawArc(Color.Black, 180f, 180f, true, Offset(c.x - r * 1.05f, c.y - r * 1.05f), Size(r * 2.1f, r * 2.1f))
}

// MARK: - Artist Impressions: an alien world caught in its star's light

private fun DrawScope.exoplanet(accent: Color) {
    sky(Color(0xFF2A0E3A), Space)
    stars(seed = 10, count = 14)
    // The star, top right.
    val star = Offset(w * 0.8f, h * 0.2f)
    drawCircle(Brush.radialGradient(listOf(Color.White, accent.copy(alpha = 0.7f), Color.Transparent), center = star, radius = w * 0.35f), radius = w * 0.35f, center = star)
    sparkle(star, w * 0.16f)
    // The planet, lit from the star's side.
    val c = Offset(w * 0.4f, h * 0.62f)
    val r = w * 0.3f
    drawCircle(Brush.linearGradient(listOf(Color(0xFFFFB0E8), accent, Color(0xFF3A0E4A)), star, c + Offset(-r, r)), radius = r, center = c)
    clipPath(Path().apply { addOval(Rect(c, r)) }) {
        translate(left = 0f) {
            for (i in -2..2) {
                drawOval(Color.White.copy(alpha = 0.15f), Offset(c.x - r * 1.2f, c.y + i * r * 0.38f), Size(r * 2.4f, r * 0.14f))
            }
        }
    }
}
