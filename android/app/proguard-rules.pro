# Flutter wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep the application class
-keep class com.construction.management.app.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# OkHttp (used internally by some Flutter plugins)
-dontwarn okhttp3.**
-dontwarn okio.**

# Dart/Flutter reflection
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
