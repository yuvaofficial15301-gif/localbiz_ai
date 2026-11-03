import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../ai/conversation/assistant_engine.dart';
import '../core/l10n/languages.dart';
import '../core/l10n/strings.dart';
import '../core/utils/money.dart';
import '../shared/models/models.dart';
import 'services/app_services.dart';

final servicesProvider = FutureProvider<AppServices>((ref) => AppServices.create());

final svcProvider = Provider<AppServices>(
    (ref) => ref.watch(servicesProvider).requireValue);

/// Bumped after any data change so list screens reload.
final refreshProvider = StateProvider<int>((ref) => 0);
final tabProvider = StateProvider<int>((ref) => 0);
final historyTabProvider = StateProvider<int>((ref) => 0);
final langProvider = StateProvider<String>((ref) => 'en');

String tr(WidgetRef ref, String key, [Map<String, String>? p]) =>
    S.t(ref.watch(langProvider), key, p);

final profileProvider = FutureProvider.autoDispose<ShopProfile?>((ref) async {
  ref.watch(refreshProvider);
  final p = await ref.watch(svcProvider).shop.profile();
  if (p != null) Money.symbol = p.currency;
  return p;
});

// ---------------------------------------------------------------- auth

class AuthState {
  final bool ready;
  final bool locked;
  final Session? session;
  final String? error;
  final DateTime? lockedUntil;
  const AuthState({
    this.ready = false,
    this.locked = true,
    this.session,
    this.error,
    this.lockedUntil,
  });
  AuthState copyWith({
    bool? ready,
    bool? locked,
    Session? session,
    String? error,
    DateTime? lockedUntil,
    bool clearError = false,
    bool clearLockout = false,
  }) =>
      AuthState(
        ready: ready ?? this.ready,
        locked: locked ?? this.locked,
        session: session ?? this.session,
        error: clearError ? null : (error ?? this.error),
        lockedUntil: clearLockout ? null : (lockedUntil ?? this.lockedUntil),
      );
}

class AuthController extends StateNotifier<AuthState> {
  final AppServices svc;
  final Ref ref;
  DateTime lastActivity = DateTime.now();
  static const maxAttempts = 5;

  AuthController(this.svc, this.ref) : super(const AuthState()) {
    _init();
  }

  Future<void> _init() async {
    final n = await svc.users.count();
    if (n == 0) {
      state = const AuthState(ready: true, locked: false);
    } else {
      final until = await svc.settings.get('lock_until');
      state = AuthState(
          ready: true,
          locked: true,
          lockedUntil: until == null ? null : DateTime.tryParse(until));
    }
  }

  void touch() => lastActivity = DateTime.now();

  Future<void> _afterLogin(Session s) async {
    lastActivity = DateTime.now();
    final p = await svc.shop.profile();
    if (p != null) {
      Money.symbol = p.currency;
      ref.read(langProvider.notifier).state = p.language;
    }
    state = AuthState(ready: true, locked: false, session: s);
    ref.read(refreshProvider.notifier).state++;
    // optional local alerts (low stock, expiry, backup reminder)
    svc.alerts.check(s);
  }

  Future<List<UserRec>> loginChoices() => svc.users.listActive();

  /// Returns null on success, otherwise an error code.
  Future<String?> loginPin(int userId, String pin) async {
    final until = state.lockedUntil;
    if (until != null && until.isAfter(DateTime.now())) return 'locked';
    final ok = await svc.users.verifyPin(userId, pin);
    if (!ok) {
      final fails = await svc.settings.getInt('fail_count') + 1;
      await svc.settings.setInt('fail_count', fails);
      await svc.audit.db.insert('audit_logs', {
        'at': nowIso(), 'user_name': 'user#$userId', 'action': 'login_failed', 'detail': '',
      });
      if (fails >= maxAttempts) {
        final secs = 30 * (1 << ((fails - maxAttempts).clamp(0, 6).toInt()));
        final t = DateTime.now().add(Duration(seconds: secs));
        await svc.settings.set('lock_until', t.toIso8601String());
        state = state.copyWith(lockedUntil: t);
      }
      return 'wrong';
    }
    await svc.settings.setInt('fail_count', 0);
    await svc.settings.set('lock_until', '');
    final s = await svc.users.sessionFor(userId);
    if (s == null) return 'wrong';
    await svc.audit.db.insert('audit_logs', {
      'at': nowIso(), 'user_name': s.name, 'action': 'login', 'detail': '',
    });
    await _afterLogin(s);
    state = state.copyWith(clearLockout: true);
    return null;
  }

  /// Biometric unlock signs in as the owner (the only user who can enable it).
  Future<bool> loginOwnerBiometric() async {
    final s = await svc.users.ownerSession();
    if (s == null) return false;
    await _afterLogin(s);
    return true;
  }

  /// Used right after first-time registration.
  Future<void> loginAfterRegister() async {
    final s = await svc.users.ownerSession();
    if (s != null) await _afterLogin(s);
  }

  void lock() {
    if (state.session == null && state.ready) return;
    state = state.copyWith(locked: true);
    ref.read(assistantProvider.notifier).engine.reset();
  }
}

final authProvider = StateNotifierProvider<AuthController, AuthState>(
    (ref) => AuthController(ref.watch(svcProvider), ref));

Session sess(WidgetRef ref) => ref.read(authProvider).session!;

// ---------------------------------------------------------------- bill draft

class BillDraftNotifier extends StateNotifier<BillDraft> {
  BillDraftNotifier() : super(BillDraft.empty());
  void set(BillDraft d) => state = d;
  void clear() => state = BillDraft.empty();
}

final billDraftProvider =
    StateNotifierProvider<BillDraftNotifier, BillDraft>((ref) => BillDraftNotifier());

// ---------------------------------------------------------------- assistant

class ChatMessage {
  final bool fromUser;
  final String text;
  const ChatMessage(this.fromUser, this.text);
}

class AssistantState {
  final List<ChatMessage> messages;
  final bool listening;
  final bool busy;
  final String partial;
  final Pending? pending;
  final bool needsPin;
  final int? lastBillId;
  const AssistantState({
    this.messages = const [],
    this.listening = false,
    this.busy = false,
    this.partial = '',
    this.pending,
    this.needsPin = false,
    this.lastBillId,
  });
  AssistantState copyWith({
    List<ChatMessage>? messages,
    bool? listening,
    bool? busy,
    String? partial,
    Pending? pending,
    bool clearPending = false,
    bool? needsPin,
    int? lastBillId,
  }) =>
      AssistantState(
        messages: messages ?? this.messages,
        listening: listening ?? this.listening,
        busy: busy ?? this.busy,
        partial: partial ?? this.partial,
        pending: clearPending ? null : (pending ?? this.pending),
        needsPin: needsPin ?? this.needsPin,
        lastBillId: lastBillId ?? this.lastBillId,
      );
}

class AssistantController extends StateNotifier<AssistantState> {
  final Ref ref;
  late final AssistantEngine engine;

  AssistantController(this.ref) : super(const AssistantState()) {
    final svc = ref.read(svcProvider);
    engine = AssistantEngine(
      products: svc.products,
      pricing: svc.pricing,
      inventory: svc.inventory,
      billing: svc.billing,
      reports: svc.reports,
      shop: svc.shop,
      users: svc.users,
      getSession: () => ref.read(authProvider).session,
      getLang: () => ref.read(langProvider),
      getDraft: () => ref.read(billDraftProvider),
      setDraft: (d) => ref.read(billDraftProvider.notifier).set(d),
    );
  }

  String get _lang => ref.read(langProvider);

  void _add(bool user, String text) {
    state = state.copyWith(messages: [...state.messages, ChatMessage(user, text)]);
  }

  Future<void> submit(String text) async {
    final t = text.trim();
    if (t.isEmpty || state.busy) return;
    _add(true, t);
    state = state.copyWith(busy: true, partial: '');
    final r = await engine.handle(t);
    _apply(r);
  }

  Future<void> confirm({String? pin}) async {
    state = state.copyWith(busy: true);
    final r = await engine.confirm(pin: pin);
    _apply(r);
  }

  void cancel() {
    final r = engine.cancel();
    _apply(r);
  }

  void _apply(AssistantReply r) {
    _add(false, r.text);
    state = state.copyWith(
      busy: false,
      pending: r.pending,
      clearPending: r.pending == null,
      needsPin: r.needsPin,
      lastBillId: r.savedBillId,
    );
    if (r.dataChanged) ref.read(refreshProvider.notifier).state++;
    if (r.nav == 'history_bills') {
      ref.read(historyTabProvider.notifier).state = 0;
      ref.read(tabProvider.notifier).state = 3;
    }
    _speak(r.text);
  }

  Future<void> _speak(String text) async {
    final svc = ref.read(svcProvider);
    if (!await svc.settings.getBool('tts_enabled', def: true)) return;
    final lang = Languages.byCode(_lang);
    await svc.voice.speak(text, lang.ttsLocale);
  }

  void setPartial(String t) => state = state.copyWith(partial: t);
  void setListening(bool v) => state = state.copyWith(listening: v);
  void clearNeedsPin() => state = state.copyWith(needsPin: false);
}

final assistantProvider =
    StateNotifierProvider<AssistantController, AssistantState>(
        (ref) => AssistantController(ref));

// ---------------------------------------------------------------- connectivity

final onlineProvider = StreamProvider<bool>((ref) async* {
  final c = Connectivity();
  bool isOn(List<ConnectivityResult> r) =>
      r.any((e) => e != ConnectivityResult.none);
  try {
    yield isOn(await c.checkConnectivity());
    await for (final r in c.onConnectivityChanged) {
      yield isOn(r);
    }
  } catch (_) {
    yield false;
  }
});
