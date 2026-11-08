import os

kts_path = "android/app/build.gradle.kts"
if os.path.exists(kts_path):
    with open(kts_path) as f:
        c = f.read()
    signing_code = """
    signingConfigs {
        create("release") {
            storeFile = file("release.jks")
            storePassword = "rvbhati123"
            keyAlias = "rvbhati"
            keyPassword = "rvbhati123"
        }
    }
"""
    if 'create("release")' not in c:
        c = c.replace("buildTypes {", signing_code + "\n    buildTypes {")
        c = c.replace('signingConfigs.getByName("debug")', 'signingConfigs.getByName("release")')
        with open(kts_path, "w") as f:
            f.write(c)
        print("Patched android/app/build.gradle.kts with release signingConfig")

gradle_path = "android/app/build.gradle"
if os.path.exists(gradle_path):
    with open(gradle_path) as f:
        c = f.read()
    signing_code = """
    signingConfigs {
        release {
            storeFile file("release.jks")
            storePassword "rvbhati123"
            keyAlias "rvbhati"
            keyPassword "rvbhati123"
        }
    }
"""
    if "release {" not in c:
        c = c.replace("buildTypes {", signing_code + "\n    buildTypes {")
        c = c.replace("signingConfigs.debug", "signingConfigs.release")
        with open(gradle_path, "w") as f:
            f.write(c)
        print("Patched android/app/build.gradle with release signingConfig")
