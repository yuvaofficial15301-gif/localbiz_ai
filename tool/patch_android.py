#!/usr/bin/env python3
"""Adapts the freshly generated Flutter Android scaffold for LocalBiz AI.

Run from the project root AFTER `flutter create` produced ./android :
  - manifest: permissions (no INTERNET on purpose), app label, no auto-backup
  - MainActivity: FlutterFragmentActivity (needed by local_auth / biometrics)
  - Gradle: minSdk 24, core-library desugaring (notifications), stable release signing
Fails loudly if an expected pattern is missing, so problems are visible in CI.
"""
import glob
import pathlib
import re
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ANDROID = ROOT / "android"
MARK = "LOCALBIZ_PATCHED"


def fail(msg):
    print("PATCH ERROR: " + msg)
    sys.exit(1)


def sub_once(pattern, repl, text, what, flags=0):
    new, n = re.subn(pattern, repl, text, count=1, flags=flags)
    if n != 1:
        fail("could not patch: " + what)
    return new


# ----------------------------------------------------------------- gradle
gradle = ANDROID / "app" / "build.gradle"
if not gradle.exists():
    if (ANDROID / "app" / "build.gradle.kts").exists():
        fail("Kotlin-DSL gradle files found; this script supports the Groovy template "
             "(Flutter 3.24.x). Pin flutter-version in the workflow to 3.24.5.")
    fail("android/app/build.gradle not found (did flutter create run?)")

g = gradle.read_text()
if MARK not in g:
    # minSdk
    g, n = re.subn(r"minSdk(?:Version)?\s*=?\s*flutter\.minSdkVersion", "minSdk = 24", g)
    if n < 1:
        fail("minSdk line not found")
    # desugaring flag
    g = sub_once(r"(compileOptions\s*\{)",
                 r"\1\n        coreLibraryDesugaringEnabled true", g, "compileOptions")
    # key.properties loader before android {
    loader = (
        "def keystoreProperties = new Properties()\n"
        "def keystorePropertiesFile = rootProject.file('key.properties')\n"
        "if (keystorePropertiesFile.exists()) {\n"
        "    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))\n"
        "}\n\n"
    )
    g = sub_once(r"(\n)(android\s*\{)", r"\1" + loader.replace("\\", "\\\\") + r"\2", g, "android block")
    # signing config + release uses it
    signing = (
        "    signingConfigs {\n"
        "        release {\n"
        "            keyAlias keystoreProperties['keyAlias']\n"
        "            keyPassword keystoreProperties['keyPassword']\n"
        "            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null\n"
        "            storePassword keystoreProperties['storePassword']\n"
        "        }\n"
        "    }\n\n"
    )
    g = sub_once(r"(\n)(\s*)(buildTypes\s*\{)", r"\1" + signing.replace("\\", "\\\\") + r"\2\3", g, "buildTypes")
    g, n = re.subn(r"signingConfig\s*=?\s*signingConfigs\.debug", "signingConfig = signingConfigs.release", g)
    if n < 1:
        fail("release signingConfig line not found")
    g += (
        "\n// " + MARK + "\n"
        "dependencies {\n"
        "    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.0.4'\n"
        "}\n"
    )
    gradle.write_text(g)
    print("patched app/build.gradle")
else:
    print("app/build.gradle already patched")

# key.properties for signing (stable key => updates keep user data)
shutil.copyfile(ROOT / "keystore" / "key.properties", ANDROID / "key.properties")

# ----------------------------------------------------------------- manifest
manifest = ANDROID / "app" / "src" / "main" / "AndroidManifest.xml"
m = manifest.read_text()
if "RECORD_AUDIO" not in m:
    perms = (
        '    <uses-permission android:name="android.permission.RECORD_AUDIO"/>\n'
        '    <uses-permission android:name="android.permission.USE_BIOMETRIC"/>\n'
        '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>\n'
        '    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>\n'
    )
    m = sub_once(r"(<manifest[^>]*>\s*\n)", r"\1" + perms, m, "manifest root")
    intents = (
        '        <intent><action android:name="android.speech.RecognitionService"/></intent>\n'
        '        <intent><action android:name="android.intent.action.TTS_SERVICE"/></intent>\n'
    )
    if "<queries>" in m:
        m = m.replace("<queries>", "<queries>\n" + intents, 1)
    else:
        m = m.replace("</manifest>", "    <queries>\n" + intents + "    </queries>\n</manifest>", 1)
    m = re.sub(r'android:label="[^"]*"', 'android:label="LocalBiz AI"', m, count=1)
    if "android:allowBackup" not in m:
        m = sub_once(r"(<application)", r'\1\n        android:allowBackup="false"', m, "application tag")
    manifest.write_text(m)
    print("patched AndroidManifest.xml")
else:
    print("AndroidManifest.xml already patched")

# ----------------------------------------------------------------- MainActivity
acts = glob.glob(str(ANDROID / "app" / "src" / "main" / "**" / "MainActivity.*"), recursive=True)
if not acts:
    fail("MainActivity not found")
act = pathlib.Path(acts[0])
text = act.read_text()
pkg = re.search(r"^package\s+([\w.]+)", text, re.M)
if not pkg:
    fail("package line not found in MainActivity")
kt = act.with_suffix(".kt")
kt.write_text(
    "package %s\n\n"
    "import io.flutter.embedding.android.FlutterFragmentActivity\n\n"
    "class MainActivity : FlutterFragmentActivity()\n" % pkg.group(1)
)
if act != kt:
    act.unlink()
print("MainActivity -> FlutterFragmentActivity")
print("Android patch complete.")
