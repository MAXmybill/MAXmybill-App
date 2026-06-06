## Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

## UCrop - Image Cropper
-dontwarn com.yalantis.ucrop**
-keep class com.yalantis.ucrop** { *; }
-keep interface com.yalantis.ucrop** { *; }

## Google Play Core - Fix for R8 missing classes
-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
-keep class com.google.android.play.core.** { *; }

## Keep Flutter embedding classes
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.android.** { *; }
-keep class io.flutter.embedding.engine.** { *; }

## Razorpay SDK - Keep all classes and methods
-keepattributes *Annotation*
-dontwarn com.razorpay.**
-keep class com.razorpay.** { *; }
-keepclassmembers class com.razorpay.** { *; }
-keep class com.razorpay.AnalyticsUtil { *; }
-keep class com.razorpay.LifecycleContext { *; }
-keep class com.razorpay.PerformanceUtil { *; }
-keep class com.razorpay.BaseCheckoutActivity { *; }
-keep class com.razorpay.CheckoutActivity { *; }
-keep class proguard.annotation.Keep { *; }
-keep class proguard.annotation.KeepClassMembers { *; }
-optimizations !method/inlining/*
-keepclasseswithmembers class * {
  public void onPayment*(...);
}

## OkHttp (used by Razorpay)
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

## Retrofit (if used by Razorpay)
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Signature
-keepattributes Exceptions

## Firebase App Check - Critical for PlayIntegrity Provider
-keep class com.google.firebase.appcheck.** { *; }
-keep class com.google.firebase.appcheck.playintegrity.** { *; }
-keep interface com.google.firebase.appcheck.** { *; }
-keep interface com.google.firebase.appcheck.playintegrity.** { *; }
-dontwarn com.google.firebase.appcheck.**

## Play Integrity API - Required for App Check PlayIntegrity
-keep class com.google.android.gms.playintegrity.** { *; }
-keep interface com.google.android.gms.playintegrity.** { *; }
-dontwarn com.google.android.gms.playintegrity.**

## Google Play Services - Critical for bundles
-keep class com.google.android.gms.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-keep interface com.google.android.gms.** { *; }
-keep interface com.google.android.gms.internal.** { *; }
-dontwarn com.google.android.gms.**

## Firebase Core - Ensure initialization works
-keep class com.google.firebase.** { *; }
-keep interface com.google.firebase.** { *; }
-keep class com.google.firebase.internal.** { *; }
-keepclassmembers class ** {
  public static final long serialVersionUID;
}

## Crashlytics - If used
-keep class com.google.firebase.crashlytics.** { *; }
-dontwarn com.google.firebase.crashlytics.**

## Google Analytics
-keep class com.google.analytics.** { *; }
-dontwarn com.google.analytics.**

## Hive - Local database
-keep class com.hive.** { *; }
-keep int com.hive.** { *; }
-dontwarn com.hive.**

## In-App Update library
-keep class com.google.android.play.core.tasks.** { *; }
-keep class com.google.android.play.core.install.** { *; }
-keep class com.google.android.play.core.appupdate.** { *; }
-keep interface com.google.android.play.core.tasks.** { *; }
-keep interface com.google.android.play.core.install.** { *; }
-keep interface com.google.android.play.core.appupdate.** { *; }
-dontwarn com.google.android.play.core.**

## Firebase Messaging - FCM
-keep class com.google.firebase.messaging.** { *; }
-keep interface com.google.firebase.messaging.** { *; }
-dontwarn com.google.firebase.messaging.**

## AndroidX - Core library support
-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-dontwarn androidx.**

## AppCompat (used by UCrop)
-keep class androidx.appcompat.** { *; }
-keep interface androidx.appcompat.** { *; }

## Image loading and processing
-keep class com.bumptech.glide.** { *; }
-dontwarn com.bumptech.glide.**

## Serialization - Keep model classes
-keepclassmembers class * implements java.io.Serializable {
  static final long serialVersionUID;
  private static final java.io.ObjectStreamField[] serialPersistentFields;
  private void writeObject(java.io.ObjectOutputStream);
  private void readObject(java.io.ObjectInputStream);
  java.lang.Object writeReplace();
  java.lang.Object readResolve();
}

## Hive Adapters - Keep all Hive-generated adapters
-keep class **.g.dart.* { *; }
-keep @com.hive.TypeAdapter class ** { *; }
-keep class * extends com.hive.TypeAdapter { *; }

## Keep native methods and their signatures
-keepclasseswithmembernames class * {
    native <methods>;
}

## Keep enum constants
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

