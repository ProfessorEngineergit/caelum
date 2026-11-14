package com.professorengineergit.caelum.ui

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import coil3.compose.AsyncImage
import com.professorengineergit.caelum.core.CosmicImage

/**
 * The small thumbnail first (usually already cached from the lists), the sharp
 * preview over it as soon as it arrives — so a picture never waits on a blank box.
 */
@Composable
fun ProgressiveImage(image: CosmicImage, modifier: Modifier = Modifier, contentDescription: String? = image.title) {
    Box(modifier) {
        val thumb = image.thumbnailUrl()
        if (thumb != image.previewUrl) {
            AsyncImage(
                model = thumb,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        }
        AsyncImage(
            model = image.previewUrl,
            contentDescription = contentDescription,
            contentScale = ContentScale.Crop,
            modifier = Modifier.fillMaxSize(),
        )
    }
}
