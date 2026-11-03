import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class BigButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool outlined;
  final Color? color;
  const BigButton(this.label,
      {super.key, this.icon, this.onPressed, this.outlined = false, this.color});

  @override
  Widget build(BuildContext context) {
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[Icon(icon, size: 24), const SizedBox(width: 10)],
        Flexible(child: Text(label, textAlign: TextAlign.center)),
      ],
    );
    if (outlined) {
      return OutlinedButton(onPressed: onPressed, child: child);
    }
    return ElevatedButton(
      onPressed: onPressed,
      style: color == null ? null : ElevatedButton.styleFrom(backgroundColor: color),
      child: child,
    );
  }
}

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? color;
  const StatCard(this.label, this.value, this.icon, {super.key, this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color ?? AppColors.primary, size: 28),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            Text(label,
                style: const TextStyle(color: AppColors.muted, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  const SectionTitle(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );
}

class EmptyState extends StatelessWidget {
  final String text;
  final IconData icon;
  const EmptyState(this.text, {super.key, this.icon = Icons.inbox_outlined});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 56, color: AppColors.secondary),
              const SizedBox(height: 12),
              Text(text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 17, color: AppColors.muted)),
            ],
          ),
        ),
      );
}

class ErrorState extends StatelessWidget {
  final Object error;
  const ErrorState(this.error, {super.key});
  @override
  Widget build(BuildContext context) => EmptyState('$error', icon: Icons.error_outline);
}

void toast(BuildContext context, String msg, {bool error = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 16)),
      backgroundColor: error ? AppColors.error : AppColors.primary,
      behavior: SnackBarBehavior.floating,
    ));
}

Future<bool> askConfirm(BuildContext context, String title, String body,
    {String ok = 'Confirm', String cancel = 'Cancel', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(body, style: const TextStyle(fontSize: 16)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(cancel)),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(ok, style: TextStyle(color: danger ? AppColors.error : AppColors.primary)),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Asks for a PIN (step-up authentication). Returns null if cancelled.
Future<String?> askPin(BuildContext context, {String title = 'Enter PIN'}) async {
  final ctl = TextEditingController();
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctl,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 6,
        decoration: const InputDecoration(labelText: 'PIN'),
        style: const TextStyle(fontSize: 22, letterSpacing: 6),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('OK')),
      ],
    ),
  );
  return (r == null || r.isEmpty) ? null : r;
}

Future<String?> askText(BuildContext context, String title,
    {String label = '', bool obscure = false, String initial = ''}) async {
  final ctl = TextEditingController(text: initial);
  final r = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: ctl,
        autofocus: true,
        obscureText: obscure,
        decoration: InputDecoration(labelText: label),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(c, ctl.text), child: const Text('OK')),
      ],
    ),
  );
  return (r == null || r.isEmpty) ? null : r;
}

String shortDate(String iso) {
  if (iso.length >= 16) return '${iso.substring(8, 10)}/${iso.substring(5, 7)}/${iso.substring(0, 4)} ${iso.substring(11, 16)}';
  return iso;
}

String dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Simple bar chart without external dependencies.
class BarChart extends StatelessWidget {
  final List<String> labels;
  final List<int> values;
  final String Function(int) fmt;
  const BarChart(
      {super.key, required this.labels, required this.values, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 1 : values.reduce((a, b) => a > b ? a : b);
    return SizedBox(
      height: 190,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < values.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FittedBox(
                        child: Text(values[i] == 0 ? '' : fmt(values[i]),
                            style: const TextStyle(fontSize: 11))),
                    const SizedBox(height: 2),
                    Container(
                      height: maxV == 0 ? 2 : 120.0 * values[i] / maxV + 2,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(labels[i], style: const TextStyle(fontSize: 12)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
