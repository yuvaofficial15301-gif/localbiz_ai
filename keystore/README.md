# Release signing key

`localbiz-release.jks` signs every APK build so that **new versions install over
the old one and keep your shop data**. (A different key each build would force
you to uninstall first, which deletes all data.)

* This key is for sideloading on your own phone, not for Play Store publishing.
* Keep your GitHub repository **private**: the passwords are in `key.properties`.
* Never delete or regenerate this file once you have installed an APK.
* To use your own key instead, replace the .jks and key.properties (same alias/passwords).
