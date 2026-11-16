# Development status: LocalBiz AI 0.1.0

**Honest summary:** all source code, tests, docs and the CI build pipeline are written.
**The project has never been compiled or run.** The authoring environment had no Flutter/Dart,
no Android SDK and no network, so there is **no APK yet**. The APK is produced by the GitHub
Actions workflow in `.github/workflows/build-apk.yml`. Expect a few compile errors on the first
run; send me the log and I will fix them (same project, new zip).

## Implemented in source (not yet compiled)
| Area | State |
|---|---|
| Onboarding (name, shop, category, phone, address, language, currency, opening date, owner PIN) | written |
| PIN auth (PBKDF2-SHA256, lockout after 5 tries), biometric unlock (owner), auto-lock, lock overlay | written |
| Encrypted DB (SQLCipher, key in Android Keystore storage), migrations, append-only price history | written |
| Roles: owner / manager / employee, delegable permissions, owner-only wholesale and security | written |
| Products: add/edit/soft-delete/search/filter/sort/detail/CSV import+export, units incl. custom | written |
| Retail + wholesale in ONE table; retail-only normal queries; wholesale gated in service layer; PIN step-up for wholesale changes | written |
| Price set / increase / decrease / history (UI + voice) | written |
| Billing: manual + voice, multi-item, unit conversion, discount (amount/%), tax, payment methods, price snapshot, transactional save, idempotency | written |
| Receipts: drawn with Flutter text engine (Indic scripts, ₹) → PNG → PDF; share; print dialog | written |
| Inventory: stock in/out/adjust, movements, low stock, expiry date, no negative stock unless enabled | written |
| Purchases: supplier, items, pending/paid, own unit cost; no profit calculation (by design) | written |
| Reports: today/week/month, last-7-days chart, best sellers, bill search by number/date/product/payment | written |
| Assistant: deterministic multilingual parser, clarification questions, confirmations, TTS replies, text fallback | written |
| Local LLM: model import/validation/removal, RAM check, validated structured-intent contract | written (inference runtime NOT included) |
| Backup: AES-256-GCM encrypted export, verification, restore with safety copy, share to any location | written |
| Notifications: low stock, expiry, backup reminder (checked on unlock, once per day) | written |
| Settings: profile, language, voice, AI model, billing/tax, security, staff/permissions, backup, notifications, export, audit log, about | written |
| Offline: no INTERNET permission is added; offline indicator on Home | written |

## Known blockers and limitations (be aware)
1. **No APK has been built.** Nothing here has been compiled, analysed or executed.
2. **On-device LLM inference is not implemented.** Embedding llama.cpp needs a native build
   (NDK/CMake or a third-party FFI plugin) that I could not choose or verify offline. The model
   screen manages the GGUF file honestly and reports "runtime missing". The deterministic engine
   covers every listed command without it. Suggested models: Qwen2.5-1.5B-Instruct Q4_K_M
   (~1.1 GB file, ~2 GB RAM) or Llama-3.2-1B-Instruct Q4_K_M (~0.8 GB, ~1.5 GB RAM). Not installed.
3. **Offline speech per language is UNTESTED.** It depends on Android's recogniser and the language
   packs installed on your phone. "Offline only" mode requests on-device recognition and tells you
   if it is unavailable; typing always works. Settings → Voice → "Check support" lists what the
   phone reports (not accuracy).
4. Tamil/Malayalam/Kannada/Telugu/Hindi translations were written without a native review;
   please report wrong wording. Deep form labels outside navigation/home/assistant are English.
5. Tanglish understanding is keyword/rule based; unusual spellings may need alternative names on
   the product ("Other names" field).
6. Notifications are checked when the app is unlocked, not by a background scheduler.
7. Biometric unlock signs in as the owner only.
8. Unit tests use plain SQLite (sqflite_common_ffi); a type mismatch with sqflite_sqlcipher's
   `Database` class would show as a test compile error (the app itself is unaffected).
9. The default Flutter launcher icon is used.
10. The signing key is in the repo for convenience: keep the repo private.

## Version history
* 0.1.0: first complete source drop (uncompiled).
