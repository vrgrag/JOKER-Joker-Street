# Flutter's own Gradle plugin already keeps everything the engine needs.
# The rules below just guard the plugins this app relies on.

# webview_flutter / Android WebView
-keepclassmembers class * extends android.webkit.WebViewClient { *; }
-keepclassmembers class * extends android.webkit.WebChromeClient { *; }
-keep class androidx.webkit.** { *; }

# shared_preferences
-keep class androidx.preference.** { *; }
