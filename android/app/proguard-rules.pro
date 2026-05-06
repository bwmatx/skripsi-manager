# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# flutter_local_notifications — CRITICAL: keep all receivers so R8 doesn't strip them
# Without this, scheduled notifications will NEVER fire in release builds
-keep class com.dexterous.** { *; }
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepclassmembers class com.dexterous.flutterlocalnotifications.** { *; }

# timezone package — keep timezone data classes
-keep class org.threeten.** { *; }

# Keep any classes that might be accessed via reflection by plugins
-dontwarn **
