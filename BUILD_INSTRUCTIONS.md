# Build instructions

## Option A: GitHub Actions (no Flutter needed on your computer)
1. Create a **private** repository on github.com (private matters: the signing key is in the repo).
2. Upload the whole project folder contents (the unzipped `localbiz_ai`), including the hidden
   `.github` folder, to the `main` branch.
   * Web upload: "Add file" → "Upload files"; drag the folder contents. Check that
     `.github/workflows/build-apk.yml` appears in the repo.
   * Or with git: `git init && git add -A && git commit -m "LocalBiz AI 0.1.0" && git branch -M main && git remote add origin <url> && git push -u origin main`
   * If the hidden `.github` folder did not upload (some browsers skip dot-folders): in the repo click
     **Add file → Create new file**, type the name `.github/workflows/build-apk.yml`, paste the contents of
     `WORKFLOW_COPY_build-apk.yml`, and commit.
3. Open the repo → **Actions** tab → "Build Android APK". It starts automatically on push
   (or press **Run workflow**). Takes about 10 to 20 minutes the first time.
4. When it is green, open the run:
   * **Artifacts → LocalBizAI-apk** (zip containing `LocalBizAI-release.apk`), or
   * repo → **Releases** → latest "LocalBiz AI build N" → download `LocalBizAI-release.apk`
     (easiest: open the repo in your phone browser, log in, download directly).
5. If it is red: open the run, download the **build-logs** artifact (or expand the failing step)
   and send me the error text. I will fix the same project and give you a new zip.

The workflow also runs `flutter analyze` and `flutter test` and uploads their logs; those two
steps never block the APK build, so you can see problems without losing the build.

## Option B: on a PC with Flutter 3.24.5 and Android SDK
```
cd localbiz_ai
flutter create --platforms=android --org com.localbiz --project-name localbiz_ai _scaffold
cp -r _scaffold/android ./android && rm -rf _scaffold
python3 tool/patch_android.py
flutter pub get
flutter analyze
flutter test        # needs libsqlite3 available (Linux: apt install libsqlite3-dev)
flutter build apk --release
```
Output: `build/app/outputs/flutter-apk/app-release.apk`.

## Install on your phone
1. Copy/download `LocalBizAI-release.apk` to the phone.
2. Open it. If Android asks, allow "Install unknown apps" for the app you used (Chrome / Files).
3. Open **LocalBiz AI** and complete the shop setup. Choose a PIN you will remember.
4. For offline speech: Android Settings → Google → Voice / Speech → Offline speech recognition,
   download Tamil / Hindi / etc. Text typing always works.
Optional with a USB cable: `adb install -r LocalBizAI-release.apk`.

## Updating later
New versions are signed with the same key (`keystore/`), so installing over the old app keeps
your data (database migrations are in `lib/core/database/app_database.dart`).
Never uninstall before updating, and make a backup first (Settings → Backup & restore).
