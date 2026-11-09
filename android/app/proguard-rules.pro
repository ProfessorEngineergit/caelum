# kotlinx.serialization: keep the generated serializers of the gallery models in :core.
-keepclassmembers class com.professorengineergit.caelum.core.** {
    *** Companion;
}
-keepclasseswithmembers class com.professorengineergit.caelum.core.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class com.professorengineergit.caelum.core.**$$serializer { *; }
