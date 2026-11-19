import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/security.dart';
import '../code_entry.dart';
import '../theme.dart';
import '../widgets.dart';

class DuressEditPage extends StatefulWidget {
  const DuressEditPage({super.key, this.code});
  final DuressCode? code;
  @override
  State<DuressEditPage> createState() => _DuressEditPageState();
}

class _DuressEditPageState extends State<DuressEditPage> {
  late String? _hash = widget.code?.hash;
  late DuressAction _action = widget.code?.action ?? DuressAction.lockScreen;
  late bool _photo = widget.code?.photo ?? true;
  late final _label = TextEditingController(text: widget.code?.label ?? '');

  AppConfig get cfg => AppState.I.config;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  Future<void> _setCode() async {
    final r = await CodeEntryPage.open(
      context,
      type: cfg.type,
      title: 'Decoy code',
      subtitle: 'Must differ from your main code. Same length, so nobody can tell them apart.',
      validate: (c) {
        if (Security.isMain(cfg, c)) return 'This is your main code';
        final h = Security.hash(c, cfg.salt);
        if (cfg.duress.any((d) => d.hash == h && d.id != widget.code?.id)) return 'This code is already in use';
        return null;
      },
    );
    if (r == null) return;
    setState(() => _hash = Security.hash(r.code, cfg.salt));
  }

  void _save() {
    final h = _hash;
    if (h == null) return;
    AppState.I.update((c) {
      final existing = widget.code;
      if (existing != null) {
        existing
          ..hash = h
          ..action = _action
          ..photo = _photo
          ..label = _label.text.trim();
      } else {
        c.duress.add(
          DuressCode(
            id: DateTime.now().microsecondsSinceEpoch.toString(),
            hash: h,
            action: _action,
            photo: _photo,
            label: _label.text.trim(),
          ),
        );
      }
    });
    Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (!await confirm(context, 'Delete code', 'This decoy code will be deleted.', ok: 'Delete', destructive: true)) return;
    AppState.I.update((c) => c.duress.removeWhere((d) => d.id == widget.code!.id));
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SubPage(
      title: widget.code == null ? 'New code' : 'Decoy code',
      trailing: CupertinoButton(
        padding: EdgeInsets.zero,
        onPressed: _hash == null ? null : _save,
        child: Text(
          'Save',
          style: TextStyle(color: _hash == null ? C.text3 : C.blue, fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),
      children: [
        Section(
          footer: 'To an observer, this code looks like it was accepted.',
          children: [
            Tile(
              leading: const Glyph(CupertinoIcons.number, C.pink),
              title: 'Code',
              value: _hash == null ? 'Not set' : '•' * cfg.type.length.clamp(4, 6),
              chevron: true,
              onTap: _setCode,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(58, 4, 14, 4),
              child: CupertinoTextField.borderless(
                controller: _label,
                placeholder: 'Name (optional), e.g. “Forced”',
                placeholderStyle: T.body.copyWith(color: C.text3),
                style: T.body,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ),
        Section(
          header: 'When entered',
          children: [
            for (final a in DuressAction.values)
              Tile(title: a.title, subtitle: a.subtitle, trailing: Check(_action == a), onTap: () => setState(() => _action = a)),
          ],
        ),
        Section(
          footer: 'Whoever enters this code is silently photographed with the front camera. Photos appear under Security.',
          children: [
            SwitchTile(
              leading: const Glyph(CupertinoIcons.camera_fill, C.orange),
              title: 'Silent photo',
              value: _photo,
              onChanged: (v) => setState(() => _photo = v),
            ),
          ],
        ),
        if (widget.code != null)
          Section(
            children: [Tile(title: 'Delete code', titleColor: C.red, onTap: _delete)],
          ),
      ],
    );
  }
}
