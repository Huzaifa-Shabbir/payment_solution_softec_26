import 'package:flutter/material.dart';
import '../../services/local_storage.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // keys used for persistence
  static const _kFollow = 'note_follow';
  static const _kInitial = 'note_initial';
  static const _kFinal = 'note_final';

  // defaults (match the templates used in AccountFollowUp screen)
  static const _dInitial = '''Hi {name},

I’m reaching out regarding the outstanding balance of {amount} for {client}. Please let us know if there are any issues preventing payment or if you’d like to discuss a payment plan.

Best regards,''';
  static const _dFollow = '''Hi {name},

Just a friendly reminder that the payment of {amount} for {client} is still outstanding. We’d appreciate your prompt attention to this matter.

Thank you,''';
  static const _dFinal = '''Hi {name},

This is a final notice regarding the outstanding balance of {amount} for {client}. The invoice is now overdue. Please contact us immediately to resolve this.

Regards,''';

  String _follow = _dFollow;
  String _initial = _dInitial;
  String _final = _dFinal;

  @override
  void initState() {
    super.initState();
    _loadNotes();
  }

  Future<void> _maybeAwait(dynamic v) async {
    if (v is Future) return await v;
    return v;
  }

  Future<void> _loadNotes() async {
    try {
      // LocalStorage/getString is synchronous in this project wrapper and returns String?
      final v1 = getString(_kFollow);
      final v2 = getString(_kInitial);
      final v3 = getString(_kFinal);

      if (mounted) {
        setState(() {
          _follow = (v1?.isNotEmpty == true) ? v1! : _dFollow;
          _initial = (v2?.isNotEmpty == true) ? v2! : _dInitial;
          _final = (v3?.isNotEmpty == true) ? v3! : _dFinal;
        });
      }
    } catch (_) {
      // ignore read errors, keep defaults
      if (mounted) {
        setState(() {
          _follow = _dFollow;
          _initial = _dInitial;
          _final = _dFinal;
        });
      }
    }
  }

  Future<void> _saveNote(String key, String value) async {
    try {
      var res = LocalStorage.setString(key, value);
      await _maybeAwait(res);
    } catch (_) {
      // ignore persistence errors for now
    }
  }

  Future<void> _editNote(BuildContext ctx, String title, String key, String current, void Function(String) onSaved) async {
    final controller = TextEditingController(text: current);
    final res = await showDialog<bool>(
      context: ctx,
      // use the dialog builder context so Navigator.pop targets the dialog only
      builder: (dialogCtx) => AlertDialog(
        title: Text('Edit: $title'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: null,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter note text. Use {name}, {client}, {amount}, {overdue} placeholders as needed.',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogCtx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(dialogCtx).pop(true), child: const Text('Save')),
        ],
      ),
    );

    if (res == true) {
      final text = controller.text.trim();
      onSaved(text);
      await _saveNote(key, text);
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Saved')));
    }
  }

  Widget _noteTile(String title, String subtitle, String key, String current, void Function(String) onSaved) {
    final display = current.isEmpty ? '(empty)' : (current.length > 120 ? current.substring(0, 120) + '…' : current);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text(display),
        trailing: const Icon(Icons.edit),
        onTap: () => _editNote(context, title, key, current, onSaved),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text('Message templates (tap to edit). Use {name} placeholder to insert creditor name.', style: TextStyle(color: Colors.grey)),
          ),
          const SizedBox(height: 8),
          _noteTile('Follow', _follow, _kFollow, _follow, (v) => setState(() => _follow = v)),
          _noteTile('Initial Contact', _initial, _kInitial, _initial, (v) => setState(() => _initial = v)),
          _noteTile('Final Notice', _final, _kFinal, _final, (v) => setState(() => _final = v)),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}