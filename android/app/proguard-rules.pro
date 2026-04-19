# flutter_local_notifications v18 — Gson + scheduled notification cache (release / R8).
# See: https://github.com/MaikuB/flutter_local_notifications/blob/master/flutter_local_notifications/example/android/app/proguard-rules.pro

## Gson rules
-keepattributes Signature
-keepattributes *Annotation*

-dontwarn sun.misc.**

-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
