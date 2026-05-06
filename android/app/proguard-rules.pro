# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# For Riverpod and other Dart-only packages, R8 generally doesn't affect them
# as Dart is compiled to AOT C++ binaries.

# Keep any classes that might be accessed via reflection by plugins
-dontwarn **
