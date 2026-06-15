# ═══════════════════════════════════════════════════════════════════════════════
# PROGUARD RULES - TABU APP (VERSÃO FINAL)
# ═══════════════════════════════════════════════════════════════════════════════

# ═══════════════════════════════════════════════════════════════════════════════
# 🔥 FIX CRÍTICO: Firebase + Pigeon (Channel Communication)
# ═══════════════════════════════════════════════════════════════════════════════

# Pigeon - NUNCA REMOVER
-keep class io.flutter.plugins.** { *; }
-keep class dev.flutter.pigeon.** { *; }
-keep interface dev.flutter.pigeon.** { *; }
-keepclassmembers class * {
    @dev.flutter.pigeon.* <methods>;
}

# Firebase Core - CRÍTICO
-keep class io.flutter.plugins.firebase.** { *; }
-keep class io.flutter.plugins.firebase.core.** { *; }
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-keep interface com.google.firebase.** { *; }
-keep interface com.google.android.gms.** { *; }
-keepnames class com.google.firebase.** { *; }
-keepnames class com.google.android.gms.** { *; }

# Firebase Options (arquivo gerado pelo FlutterFire CLI)
-keep class com.arcanjotclub.app.firebase_options.** { *; }
-keep class com.arcanjotclub.app.FirebaseOptions { *; }
-keepclassmembers class com.arcanjotclub.app.firebase_options.** { *; }

# Firebase - NUNCA OBFUSCAR
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses

# Firebase Auth
-keep class com.google.firebase.auth.** { *; }
-keep interface com.google.firebase.auth.** { *; }

# Firebase Database
-keep class com.google.firebase.database.** { *; }
-keep interface com.google.firebase.database.** { *; }

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }
-keep interface com.google.firebase.messaging.** { *; }

# Firebase Storage
-keep class com.google.firebase.storage.** { *; }
-keep interface com.google.firebase.storage.** { *; }

# Google Play Services
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**
-dontwarn io.grpc.**

# ═══════════════════════════════════════════════════════════════════════════════
# Flutter Core
# ═══════════════════════════════════════════════════════════════════════════════

-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.embedding.android.** { *; }
-keep class io.flutter.embedding.engine.** { *; }

# Method Channels (comunicação Flutter ↔ Native)
-keep class io.flutter.plugin.common.** { *; }
-keep class io.flutter.plugin.common.MethodChannel { *; }
-keep class io.flutter.plugin.common.EventChannel { *; }
-keep class io.flutter.plugin.common.BasicMessageChannel { *; }
-keep class io.flutter.plugin.common.BinaryMessenger { *; }

# Flutter Activity
-keep class io.flutter.embedding.android.FlutterActivity { *; }
-keep class io.flutter.embedding.android.FlutterFragmentActivity { *; }
-keep class io.flutter.embedding.engine.FlutterEngine { *; }

# ═══════════════════════════════════════════════════════════════════════════════
# Play Core / Deferred Components
# ═══════════════════════════════════════════════════════════════════════════════

-keep class com.google.android.play.core.** { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
-dontwarn com.google.android.play.core.**

# ═══════════════════════════════════════════════════════════════════════════════
# Kotlin
# ═══════════════════════════════════════════════════════════════════════════════

-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keep class org.jetbrains.kotlin.** { *; }
-dontwarn kotlin.**
-keepclassmembers class **$WhenMappings {
    <fields>;
}
-keepclassmembers class kotlin.Metadata {
    public <methods>;
}

# ═══════════════════════════════════════════════════════════════════════════════
# AndroidX
# ═══════════════════════════════════════════════════════════════════════════════

-keep class androidx.** { *; }
-keep interface androidx.** { *; }
-keep class com.google.android.material.** { *; }
-dontwarn androidx.**
-dontwarn com.google.android.material.**

# ═══════════════════════════════════════════════════════════════════════════════
# Gson / JSON
# ═══════════════════════════════════════════════════════════════════════════════

-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer
-keepattributes Signature
-keepattributes *Annotation*
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}
-dontwarn sun.misc.**

# ═══════════════════════════════════════════════════════════════════════════════
# OkHttp / Retrofit (se usar dio, http, etc)
# ═══════════════════════════════════════════════════════════════════════════════

-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# ═══════════════════════════════════════════════════════════════════════════════
# Provider / ChangeNotifier
# ═══════════════════════════════════════════════════════════════════════════════

-keep class * extends androidx.lifecycle.ViewModel { *; }
-keep class * extends java.lang.Object {
    void notifyListeners();
}
-keepclassmembers class * extends androidx.lifecycle.ViewModel {
    <init>(...);
}
-keepclassmembers class * {
    void notifyListeners();
}

# ═══════════════════════════════════════════════════════════════════════════════
# Seus Controllers/Providers (Dart → Java)
# ═══════════════════════════════════════════════════════════════════════════════

-keep class com.arcanjotclub.app.controllers.** { *; }
-keep class com.arcanjotclub.app.core.** { *; }
-keep class com.arcanjotclub.app.services.** { *; }
-keep class com.arcanjotclub.app.utils.** { *; }
-keep class com.arcanjotclub.app.models.** { *; }

# ═══════════════════════════════════════════════════════════════════════════════
# Preservar Estruturas Básicas
# ═══════════════════════════════════════════════════════════════════════════════

# Enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# Parcelable
-keep class * implements android.os.Parcelable {
  public static final android.os.Parcelable$Creator *;
}

# Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# Métodos Nativos
-keepclasseswithmembernames,includedescriptorclasses class * {
    native <methods>;
}

# ═══════════════════════════════════════════════════════════════════════════════
# Reflection (usado por plugins)
# ═══════════════════════════════════════════════════════════════════════════════

-keepattributes SourceFile,LineNumberTable
-keep class * extends java.util.ListResourceBundle {
    protected Object[][] getContents();
}

# ═══════════════════════════════════════════════════════════════════════════════
# Remover Logs em Produção (OPCIONAL - comentar se quiser manter logs)
# ═══════════════════════════════════════════════════════════════════════════════

# -assumenosideeffects class android.util.Log {
#     public static *** d(...);
#     public static *** v(...);
#     public static *** i(...);
#     public static *** w(...);
# }

# ═══════════════════════════════════════════════════════════════════════════════
# VIDEO PLAYER — ExoPlayer / Media3
# Sem estas regras o R8 remove classes usadas por reflexão em runtime,
# causando tela cinza e player silenciosamente inativo em release.
# ═══════════════════════════════════════════════════════════════════════════════

# Media3 (video_player >= 2.7.0 usa androidx.media3)
-keep class androidx.media3.** { *; }
-keep interface androidx.media3.** { *; }
-keepclassmembers class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# ExoPlayer legado (video_player < 2.7.0 usa com.google.android.exoplayer2)
-keep class com.google.android.exoplayer2.** { *; }
-keep interface com.google.android.exoplayer2.** { *; }
-keepclassmembers class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# Plugin Flutter do video_player
-keep class io.flutter.plugins.videoplayer.** { *; }
-keep interface io.flutter.plugins.videoplayer.** { *; }
-keepclassmembers class io.flutter.plugins.videoplayer.** { *; }

# Codecs e MediaSession do Android usados pelo ExoPlayer/Media3
-keep class android.media.MediaCodec { *; }
-keep class android.media.MediaFormat { *; }
-keep class android.media.MediaExtractor { *; }
-keep class android.media.MediaDrm { *; }
-keep class android.media.MediaCrypto { *; }
-keep class android.media.session.** { *; }

# DataSource / cache interno do ExoPlayer (carregamento de rede)
-keep class com.google.android.exoplayer2.upstream.** { *; }
-keep class androidx.media3.datasource.** { *; }
-keep class androidx.media3.datasource.cache.** { *; }

# Registros de extensões (decodificadores opcionais carregados por reflexão)
-keep class com.google.android.exoplayer2.ext.** { *; }
-keep class androidx.media3.decoder.** { *; }