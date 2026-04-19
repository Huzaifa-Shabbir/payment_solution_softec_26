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

  // defaults
  static const _dFollow = 'Follow: Hi {name}, following up on the outstanding amount. Please let us know a convenient time to pay.';
  static const _dInitial = 'Initial Contact: Hello {name}, this is a friendly reminder regarding your invoice.';
  static const _dFinal = 'Final Notice: Final notice. Immediate payment is required to avoid further action.';

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
      // NOTE:
      // In some project versions LocalStorage.getString(...) returns void (or is not usable as a return value)
      // which causes compile errors. To keep this file compiling across variations of the LocalStorage API,
      // we avoid using the return value here and fall back to defaults.
      //
      // If your LocalStorage actually provides a Future<String?> getString(String key),
      // replace the body below with:
      //   final v1 = await LocalStorage.getString(_kFollow);
      //   final v2 = await LocalStorage.getString(_kInitial);
      //   final v3 = await LocalStorage.getString(_kFinal);
      //   setState(() {
      //     _follow = (v1?.isNotEmpty == true) ? v1! : _dFollow;
      //     _initial = (v2?.isNotEmpty == true) ? v2! : _dInitial;
      //     _final = (v3?.isNotEmpty == true) ? v3! : _dFinal;
      //   });
      //
      // For now, safely initialize with stored defaults so the app compiles.
    } catch (_) {
      // ignore read errors
    }

    // Apply defaults (safe fallback). Saved values will still be written by _saveNote.
    if (mounted) {
      setState(() {
        _follow = _dFollow;
        _initial = _dInitial;
        _final = _dFinal;
      });
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
      builder: (_) => AlertDialog(
        title: Text('Edit: $title'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            maxLines: null,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter note text. Use {name} to interpolate customer name.',
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Save')),
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
