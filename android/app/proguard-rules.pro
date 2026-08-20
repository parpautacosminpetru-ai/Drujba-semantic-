# The Flutter plugin exposes optional recognizers for these scripts. Drujba
# Semantica instantiates only TextRecognitionScript.latin, so the corresponding
# native artifacts are intentionally absent from the APK.
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**
