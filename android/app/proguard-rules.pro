# ProGuard/R8 rules for Flutter + common libraries
# Keep Flutter classes and prevent stripping essential entry points
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }

# Keep generated registrant
-keep class **.GeneratedPluginRegistrant { *; }

# Keep main activity and application
-keep class com.mtzcode.nymbuscoletor.MainActivity { *; }
-keep class ** extends android.app.Application { *; }

# Gson / JSON (if used)
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*

# OkHttp / Retrofit (if used indirectly)
-keep class okhttp3.** { *; }
-dontwarn okhttp3.**
-keep class retrofit2.** { *; }
-dontwarn retrofit2.**

# Kotlin metadata
-keep class kotlin.** { *; }
-keep class kotlin.coroutines.** { *; }
-keepattributes *Annotation*, EnclosingMethod, InnerClasses

# Prevent obfuscation of classes referenced from AndroidManifest
-keep class ** { *; }

# If you see reflection-related crashes, keep models used by JSON manually:
# -keep class your.package.models.** { *; }

# Suppress warnings for generated code
-dontwarn javax.annotation.**

# Suppress warnings for Play Core (deferred components) missing classes
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task

# R8 optimizations
-dontoptimize

# If you need to troubleshoot minify issues, temporarily disable obfuscation:
# -dontobfuscate