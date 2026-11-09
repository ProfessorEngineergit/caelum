package com.professorengineergit.caelum.core

private val ENTITIES = mapOf(
    "amp" to "&", "lt" to "<", "gt" to ">", "quot" to "\"", "apos" to "'",
    "nbsp" to " ", "mdash" to "—", "ndash" to "–", "hellip" to "…",
)

private val ENTITY = Regex("&(#x[0-9a-f]+|#[0-9]+|[a-z]+);", RegexOption.IGNORE_CASE)
private val BLOCK_END = Regex("<(?:br|/p|/div|/li)[^>]*>", RegexOption.IGNORE_CASE)
private val TAG = Regex("<[^>]+>")
private val WHITESPACE = Regex("\\s+")

fun decodeEntities(s: String): String = ENTITY.replace(s) { match ->
    val code = match.groupValues[1]
    if (code.startsWith("#")) {
        val n = if (code.length > 1 && (code[1] == 'x' || code[1] == 'X')) {
            code.substring(2).toIntOrNull(16)
        } else {
            code.substring(1).toIntOrNull()
        }
        if (n != null && Character.isValidCodePoint(n)) String(Character.toChars(n)) else match.value
    } else {
        ENTITIES[code.lowercase()] ?: match.value
    }
}

/** HTML fragment → single-line plain text. */
fun plainText(html: String?): String {
    if (html.isNullOrEmpty()) return ""
    val stripped = TAG.replace(BLOCK_END.replace(html, " "), "")
    return WHITESPACE.replace(decodeEntities(stripped), " ").trim()
}

internal fun isHttp(s: String?): Boolean =
    s != null && s.trim().let { it.startsWith("http://", true) || it.startsWith("https://", true) }
