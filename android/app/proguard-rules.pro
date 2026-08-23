# R8 keep rules for Emberdelve release builds (issue #94).
# Flutter's gradle plugin already keeps io.flutter.** and the generated
# plugin registrant; rules below cover reflection-heavy plugins.

# --- Google Play Billing (in_app_purchase_android) ---
# Billing client uses reflection over its own classes; without this,
# purchases can fail only in minified release builds.
-keep class com.android.billingclient.** { *; }
-keep class com.android.vending.billing.** { *; }

# --- Play Games Services (games_services plugin) ---
-keep class com.google.android.gms.games.** { *; }

# --- flutter_local_notifications ---
# Uses Gson-style reflection to (de)serialize scheduled notification details.
-keep class com.dexterous.flutterlocalnotifications.** { *; }
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

# Generic: keep enums used via valueOf reflection (Gson deserialization).
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# --- Firebase (firebase_core / firebase_analytics) ---
# Firebase ships consumer rules with its AARs; nothing extra needed, but
# silence warnings from optional transitive references.
-dontwarn com.google.firebase.**

# --- Play Core deferred-components stubs referenced by Flutter engine ---
-dontwarn com.google.android.play.core.**
