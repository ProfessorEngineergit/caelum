package com.professorengineergit.caelum.core

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.delay
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.Request
import java.io.IOException
import java.util.concurrent.TimeUnit

const val USER_AGENT = "Caelum/1.0 (Android; +https://github.com/ProfessorEngineergit/caelum)"

/** Fetches text bodies, retrying once on 5xx, 429 and connection errors. */
class HttpClient(
    private val client: OkHttpClient = defaultClient(),
    private val attempts: Int = 2,
) {
    suspend fun fetchText(url: String): String = withContext(Dispatchers.IO) {
        var attempt = 1
        var body: String? = null
        while (body == null) {
            val last = attempt >= attempts
            body = try {
                attemptOnce(url, last)
            } catch (e: IOException) {
                if (last) throw e
                null
            }
            if (body == null) {
                delay(600L * attempt)
                attempt++
            }
        }
        body
    }

    /** The body, or null when a transient failure should be retried. */
    private fun attemptOnce(url: String, last: Boolean): String? {
        val request = Request.Builder()
            .url(url)
            .header("User-Agent", USER_AGENT)
            .header("Accept", "application/json, application/rss+xml, */*")
            .build()
        client.newCall(request).execute().use { response ->
            val transient = response.code >= 500 || response.code == 429
            if (transient && !last) return null
            if (!response.isSuccessful) throw SourceException("Network error (HTTP ${response.code}).")
            return response.body?.string().orEmpty()
        }
    }

    companion object {
        fun defaultClient(): OkHttpClient = OkHttpClient.Builder()
            .connectTimeout(15, TimeUnit.SECONDS)
            .readTimeout(15, TimeUnit.SECONDS)
            .build()
    }
}
