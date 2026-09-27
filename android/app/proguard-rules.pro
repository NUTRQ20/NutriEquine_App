# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Dart/Flutter specific
-keep class **.R
-keep class **.R$* {
    <fields>;
}

# Keep BuildConfig
-keep class **.BuildConfig { *; }

# Prevent obfuscation of exception names (helps with crash reporting)
-keepattributes *Annotation*
-keepattributes SourceFile,LineNumberTable
-keep public class * extends java.lang.Exception

# Facebook Auth
-keep class com.facebook.** { *; }

# Google Sign In
-keep class com.google.android.gms.auth.** { *; }

# Mobile Scanner
-keep class com.google.mlkit.** { *; }

# Don't warn about missing classes from third-party SDKs
-dontwarn com.google.**
-dontwarn com.facebook.**
-dontwarn io.flutter.**
