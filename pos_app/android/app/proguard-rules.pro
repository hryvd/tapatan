# Keep TFLite Flutter + GPU delegate
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.lite.gpu.GpuDelegateFactory$Options

# Keep Firebase
-keep class com.google.firebase.** { *; }

# Keep SQLite / sqflite
-keep class io.flutter.plugins.** { *; }
-keep class com.tekartik.sqflite.** { *; }

# Keep Flutter core
-keep class io.flutter.** { *; }
-dontwarn io.flutter.embedding.**

# Keep Google Sign-In / GMS
-keep class com.google.android.gms.** { *; }

# Keep mobile_scanner / ZXing
-keep class com.google.zxing.** { *; }

# Dart/Flutter entry points
-keep class io.flutter.app.** { *; }
