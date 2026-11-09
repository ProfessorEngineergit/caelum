package com.professorengineergit.caelum.core

/** Every source in display order, the same as `SourceRegistry.swift`. APOD is always first. */
class SourceRegistry(http: HttpClient = HttpClient()) {
    val all: List<ImageSource> = listOf(
        ApodSource(http),
        DjangoplicitySource.hubble(http),
        DjangoplicitySource.webb(http),
        DjangoplicitySource.eso(http),
    ) + GallerySource.bundled()

    fun byId(id: String?): ImageSource = all.firstOrNull { it.id == id } ?: all.first()
}
