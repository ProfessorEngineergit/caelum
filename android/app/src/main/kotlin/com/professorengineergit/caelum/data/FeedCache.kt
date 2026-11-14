package com.professorengineergit.caelum.data

import android.content.Context
import com.professorengineergit.caelum.core.CosmicImage
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.builtins.ListSerializer
import kotlinx.serialization.json.Json
import java.io.File

/**
 * The last list each source returned, kept on disk. The app shows it instantly on
 * start and while a slow server (esahubble.org, at times) is still answering — or
 * when it doesn't answer at all.
 */
class FeedCache(context: Context) {
    private val dir = File(context.filesDir, "feeds")
    private val json = Json { ignoreUnknownKeys = true }
    private val serializer = ListSerializer(CosmicImage.serializer())

    suspend fun read(sourceId: String): List<CosmicImage>? = withContext(Dispatchers.IO) {
        runCatching { json.decodeFromString(serializer, file(sourceId).readText()) }.getOrNull()?.takeIf { it.isNotEmpty() }
    }

    suspend fun write(sourceId: String, images: List<CosmicImage>) = withContext(Dispatchers.IO) {
        runCatching {
            dir.mkdirs()
            val tmp = File(dir, "$sourceId.json.tmp")
            tmp.writeText(json.encodeToString(serializer, images))
            tmp.renameTo(file(sourceId))
        }
    }

    private fun file(sourceId: String) = File(dir, "${sourceId.replace(Regex("[^a-zA-Z0-9_-]"), "_")}.json")
}
