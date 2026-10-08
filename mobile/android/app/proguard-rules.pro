# Proguard / R8 rules for SecureVault AI

# Google ML Kit Text Recognition optional language packs
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
-dontwarn com.google.mlkit.vision.text.**
-dontwarn com.google.mlkit.vision.face.**

# Keep ML Kit components
-keep class com.google.mlkit.vision.** { *; }
-keep interface com.google.mlkit.vision.** { *; }
-keep class com.google_mlkit_text_recognition.** { *; }
-keep class com.google_mlkit_face_detection.** { *; }
