# Keep just_audio and just_audio_background
-keep class com.ryanheise.just_audio.** { *; }
-keep class com.ryanheise.just_audio_background.** { *; }

# Keep AudioService components (Activities, Services, Receivers)
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.audioservice.AudioServiceActivity { *; }
-keep class com.ryanheise.audioservice.AudioServiceFragmentActivity { *; }
-keep class com.ryanheise.audioservice.AudioService { *; }
-keep class com.ryanheise.audioservice.MediaButtonReceiver { *; }

# Keep AndroidX Media and MediaSession classes
-keep class androidx.media.** { *; }
-keep class android.support.v4.media.** { *; }
-keep class androidx.media.app.** { *; }
-keep class androidx.media.session.** { *; }

# Keep MainActivity
-keep class com.rvbhati.player.** { *; }

# Keep ExoPlayer / Media3 used by just_audio
-keep class com.google.android.exoplayer2.** { *; }
-keep class androidx.media3.** { *; }

# Don't warn on missing optional libraries
-dontwarn com.ryanheise.audioservice.**
-dontwarn com.google.android.exoplayer2.**
