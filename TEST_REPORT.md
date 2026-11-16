# Test report

**Executed: NO.** The author's environment had no Flutter/Dart SDK and no network, so none of the
tests below have been run, and `flutter analyze` has not been run. Do not read this file as a
pass report. The GitHub Actions workflow runs both and uploads `analyze.log` / `test.log`.

## What was verified without Flutter
* Bracket balance and import-path resolution for all 52 Dart files (script check).
* The Android patch script was exercised against a mock of the Flutter 3.24 Groovy template.
* The GitHub workflow YAML parses.
* Test expectations were traced by hand against the code.

## Automated tests written (81 cases, `flutter test`)
| Area | File | Covers |
|---|---|---|
| Money, quantity, units, bill math, PBKDF2 vectors, PIN hashing, CSV | core_test.dart | exact arithmetic, discount/tax allocation |
| Shop registration, products CRUD, search/filter/sort, CSV import/export | services_test.dart | |
| Retail/wholesale pricing, increase/decrease, price history append-only | services_test.dart | |
| Wholesale authorisation at the service layer (employee/manager denied) | services_test.dart | |
| Billing: snapshot, old bills unchanged after price change, new bill uses latest price, stock deduction, rollback, idempotency, negative stock | services_test.dart | |
| Stock movements, purchases (cost independent of prices) | services_test.dart | |
| Reports, authentication, role permissions, migrations, foreign keys | services_test.dart | |
| Intent extraction in 7 languages, invalid commands, LLM intent validation | assistant_test.dart | |
| Assistant end-to-end on a real (in-memory) database: voice billing script, price update with confirmation, wholesale PIN, clarification flow, profile answers | assistant_test.dart | |
| Offline architecture (no network packages / HTTP clients) | assistant_test.dart | |
| Backup encrypt/decrypt, wrong passphrase, tamper detection, restore | backup_test.dart | |

Tests use `sqflite_common_ffi` (plain SQLite in memory). SQLCipher itself, Keystore, biometrics,
speech and notifications are device features and are NOT covered by unit tests.

## Not tested at all (needs a phone)
First-run UI flow, lock screen, biometric prompt, microphone/speech in each language,
text-to-speech, PDF receipt rendering and sharing, printing, notifications, backup share sheet,
file pickers, performance, app restart persistence on a device.
