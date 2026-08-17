# ============================================================
# ProGuard / R8 Rules for Calligro App
# ============================================================

# --- Google Sign-In & Credential Manager ---
-keep class com.google.android.gms.auth.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.android.gms.tasks.** { *; }
-keep class com.google.android.gms.internal.** { *; }
-keep class com.google.android.libraries.identity.** { *; }
-keep class com.google.android.libraries.credential.** { *; }

# Keep the Google Sign-In Flutter Plugin
-keep class io.flutter.plugins.googlesignin.** { *; }

# Keep Credential Manager (used by google_sign_in ^7.x)
-keep class androidx.credentials.** { *; }
-keep class androidx.credentials.provider.** { *; }
-keep class com.google.android.libraries.identity.googleid.** { *; }

# --- Firebase Auth ---
-keep class com.google.firebase.auth.** { *; }
-keep class com.google.android.gms.auth.api.** { *; }
-keep class com.google.android.gms.auth.api.identity.** { *; }
-keep class com.google.android.gms.auth.api.signin.** { *; }

# --- Firebase Core & Firestore ---
-keep class com.google.firebase.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# --- Flutter ---
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# --- General: Keep all classes with native methods ---
-keepclasseswithmembernames class * {
    native <methods>;
}

# --- Keep Parcelable implementations (used by Google services) ---
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# --- Keep Serializable classes ---
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# --- Play Services Auth (legacy + new) ---
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**

# --- Play Core (Flutter deferred components - not used but referenced) ---
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**



# --- OkHttp (used by Jitsi for network calls) ---
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep class okio.** { *; }
