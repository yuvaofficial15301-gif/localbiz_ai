import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/l10n/languages.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/widgets.dart';
import '../billing/receipt_screen.dart';

void openAssistant(BuildContext context, {bool autoListen = false}) {
  Navigator.of(context).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => AssistantScreen(autoListen: autoListen),
  ));
}

class AssistantScreen extends ConsumerStatefulWidget {
  final bool autoListen;
  const AssistantScreen({super.key, this.autoListen = false});
  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  String _voiceNote = '';

  @override
  void initState() {
    super.initState();
    if (widget.autoListen) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _toggleMic());
    }
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    ref.read(svcProvider).voice.cancelListening();
    super.dispose();
  }

  void _scrollDown() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      }
    });
  }

  /// Starts recognition only because the user tapped the mic.
  Future<void> _toggleMic() async {
    final ctl = ref.read(assistantProvider.notifier);
    final svc = ref.read(svcProvider);
    if (ref.read(assistantProvider).listening) {
      await svc.voice.stopListening();
      ctl.setListening(false);
      return;
    }
    await svc.voice.stopSpeaking();
    final lang = Languages.byCode(ref.read(langProvider));
    final offlineOnly = await svc.settings.getBool('voice_offline_only', def: true);
    final ok = await svc.voice.init();
    if (!ok) {
      setState(() => _voiceNote =
          'Speech recognition is not available on this phone. Please type your command.');
      return;
    }
    final locale = await svc.voice.resolveLocale(lang.speechLocale);
    if (locale == null) {
      setState(() => _voiceNote =
          '${lang.name} speech is not installed on this phone. Install the offline language pack in Android settings, or type your command.');
      return;
    }
    svc.voice.onError = (e) {
      if (!mounted) return;
      ctl.setListening(false);
      setState(() => _voiceNote = offlineOnly
          ? 'Could not listen offline ($e). Install the offline ${lang.name} speech pack, or type your command.'
          : 'Speech error: $e. Please try again or type.');
    };
    svc.voice.onStatus = (s) {
      if (!mounted) return;
      if (s == 'done' || s == 'notListening') ctl.setListening(false);
    };
    setState(() => _voiceNote = '');
    ctl.setListening(true);
    final started = await svc.voice.listen(
      localeId: locale,
      onDeviceOnly: offlineOnly,
      onResult: (text, isFinal) {
        if (!mounted) return;
        ctl.setPartial(text);
        if (isFinal) {
          ctl.setListening(false);
          if (text.trim().isNotEmpty) ctl.submit(text);
        }
      },
    );
    if (!started) {
      ctl.setListening(false);
      setState(() => _voiceNote = 'Could not start listening. Please type your command.');
    }
  }

  Future<void> _confirm() async {
    final ctl = ref.read(assistantProvider.notifier);
    await ctl.confirm();
    await _maybePin();
  }

  Future<void> _maybePin() async {
    final st = ref.read(assistantProvider);
    if (st.needsPin && mounted) {
      final pin = await askPin(context, title: 'Owner PIN');
      final ctl = ref.read(assistantProvider.notifier);
      if (pin == null) {
        ctl.cancel();
      } else {
        await ctl.confirm(pin: pin);
        await _maybePin();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(assistantProvider);
    ref.listen(assistantProvider.select((s) => s.messages.length), (_, __) => _scrollDown());
    final lang = ref.watch(langProvider);
    final hint = tr(ref, 'type_hint');
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        title: Text(tr(ref, 'talk_title'), style: const TextStyle(fontSize: 18)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(Languages.byCode(lang).native,
                  style: const TextStyle(color: AppColors.muted)),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: st.messages.isEmpty
                ? const EmptyState(
                    'Try: "Rice price enna?", "Arisi 5 kilo add pannu",\n"Sugar stock evlo?", "Today sales?",\n"Bill complete pannu"',
                    icon: Icons.record_voice_over)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.all(12),
                    itemCount: st.messages.length,
                    itemBuilder: (c, i) {
                      final m = st.messages[i];
                      return Align(
                        alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(14),
                          constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.82),
                          decoration: BoxDecoration(
                            color: m.fromUser ? AppColors.secondary : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 3)],
                          ),
                          child: Text(m.text, style: const TextStyle(fontSize: 18)),
                        ),
                      );
                    },
                  ),
          ),
          if (st.listening || st.busy || st.partial.isNotEmpty || _voiceNote.isNotEmpty)
            Container(
              width: double.infinity,
              color: const Color(0xFFE8F5E9),
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (st.listening)
                    Row(children: [
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text(tr(ref, 'listening'), style: const TextStyle(fontSize: 17)),
                    ]),
                  if (st.busy && !st.listening)
                    Row(children: [
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Text(tr(ref, 'processing'), style: const TextStyle(fontSize: 17)),
                    ]),
                  if (st.partial.isNotEmpty)
                    Text('“${st.partial}”',
                        style: const TextStyle(fontSize: 18, fontStyle: FontStyle.italic)),
                  if (_voiceNote.isNotEmpty)
                    Text(_voiceNote, style: const TextStyle(color: AppColors.error, fontSize: 15)),
                ],
              ),
            ),
          if (st.pending != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Row(
                children: [
                  Expanded(
                    child: BigButton(tr(ref, 'cancel'),
                        icon: Icons.close, outlined: true, onPressed: st.busy ? null : () => ref.read(assistantProvider.notifier).cancel()),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BigButton(tr(ref, 'confirm'),
                        icon: Icons.check, onPressed: st.busy ? null : _confirm),
                  ),
                ],
              ),
            ),
          if (st.lastBillId != null)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: BigButton('Open receipt',
                  icon: Icons.receipt_long,
                  outlined: true,
                  onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ReceiptScreen(billId: st.lastBillId!)))),
            ),
          Container(
            color: Colors.white,
            padding: EdgeInsets.fromLTRB(
                12, 10, 12, 10 + MediaQuery.of(context).viewInsets.bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _text,
                    textInputAction: TextInputAction.send,
                    decoration: InputDecoration(hintText: hint),
                    style: const TextStyle(fontSize: 18),
                    onSubmitted: (v) {
                      ref.read(assistantProvider.notifier).submit(v);
                      _text.clear();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  onPressed: () {
                    ref.read(assistantProvider.notifier).submit(_text.text);
                    _text.clear();
                  },
                  icon: const Icon(Icons.send),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 64,
                  height: 64,
                  child: FloatingActionButton(
                    heroTag: 'mic_in_assistant',
                    backgroundColor: st.listening ? AppColors.error : AppColors.primary,
                    foregroundColor: Colors.white,
                    onPressed: _toggleMic,
                    child: Icon(st.listening ? Icons.stop : Icons.mic, size: 32),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
