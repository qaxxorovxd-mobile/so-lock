import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/native.dart';
import '../lock/gate.dart';
import '../theme.dart';
import '../widgets.dart';

const _dayNames = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

String _hm(int m) => '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

class SmartPage extends StatelessWidget {
  const SmartPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final s = AppState.I;
        final sm = s.config.smart;
        return LargeTitlePage(
          title: 'Smart Lock',
          slivers: [
            SliverList(
              delegate: SliverChildListDelegate([
                const Padding(
                  padding: EdgeInsets.fromLTRB(32, 0, 32, 20),
                  child: Text('Automatically control when and where apps get locked.', style: T.sub),
                ),
                // ---- schedule ----
                Section(
                  header: 'Schedule',
                  footer: sm.scheduleOn
                      ? 'Apps are locked only between ${_hm(sm.start)} and ${_hm(sm.end)}.'
                      : 'When on, apps are locked only during this window.',
                  children: [
                    SwitchTile(
                      leading: const Glyph(CupertinoIcons.clock_fill, C.indigo),
                      title: 'Use schedule',
                      value: sm.scheduleOn,
                      onChanged: (v) => s.update((c) => c.smart.scheduleOn = v),
                    ),
                    if (sm.scheduleOn) ...[
                      Tile(
                        title: 'Starts',
                        value: _hm(sm.start),
                        onTap: () => _pickTime(context, sm.start, (m) => s.update((c) => c.smart.start = m)),
                      ),
                      Tile(
                        title: 'Ends',
                        value: _hm(sm.end),
                        onTap: () => _pickTime(context, sm.end, (m) => s.update((c) => c.smart.end = m)),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 8,
                          alignment: WrapAlignment.spaceBetween,
                          children: [
                            for (var d = 1; d <= 7; d++)
                              _DayChip(
                                label: _dayNames[d - 1],
                                on: sm.days.contains(d),
                                onTap: () => s.update((c) {
                                  if (!c.smart.days.remove(d)) c.smart.days.add(d);
                                }),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                // ---- wifi ----
                Section(
                  header: 'Trusted Wi‑Fi',
                  footer: 'Apps stay unlocked while connected to these networks. Reading the network name requires location permission.',
                  children: [
                    SwitchTile(
                      leading: const Glyph(CupertinoIcons.wifi, C.blue),
                      title: 'Trusted networks',
                      value: sm.wifiOn,
                      onChanged: (v) => s.update((c) => c.smart.wifiOn = v),
                    ),
                    if (sm.wifiOn) ...[
                      for (final ssid in sm.ssids)
                        Tile(
                          title: ssid,
                          leading: const SizedBox(
                            width: 30,
                            child: Icon(CupertinoIcons.wifi, color: C.text2, size: 20),
                          ),
                          trailing: _RemoveButton(onTap: () => s.update((c) => c.smart.ssids.remove(ssid))),
                        ),
                      Tile(
                        title: 'Add current network',
                        titleColor: C.blue,
                        leading: const SizedBox(
                          width: 30,
                          child: Icon(CupertinoIcons.add_circled_solid, color: C.blue, size: 22),
                        ),
                        onTap: () => _addWifi(context),
                      ),
                    ],
                  ],
                ),
                // ---- places ----
                Section(
                  header: 'Trusted places',
                  footer: 'Apps stay unlocked at home or other trusted places. Grant “Allow all the time” location access for this to work in the background.',
                  children: [
                    SwitchTile(
                      leading: const Glyph(CupertinoIcons.location_fill, C.green),
                      title: 'Trusted places',
                      value: sm.placesOn,
                      onChanged: (v) => s.update((c) => c.smart.placesOn = v),
                    ),
                    if (sm.placesOn) ...[
                      for (final p in sm.places)
                        Tile(
                          title: p.name,
                          subtitle: '${p.radius.round()} m radius',
                          leading: const SizedBox(
                            width: 30,
                            child: Icon(CupertinoIcons.house_fill, color: C.text2, size: 20),
                          ),
                          trailing: _RemoveButton(onTap: () => s.update((c) => c.smart.places.remove(p))),
                        ),
                      Tile(
                        title: 'Add current location',
                        titleColor: C.blue,
                        leading: const SizedBox(
                          width: 30,
                          child: Icon(CupertinoIcons.add_circled_solid, color: C.blue, size: 22),
                        ),
                        onTap: () => _addPlace(context),
                      ),
                      Tile(
                        title: 'Background location access',
                        chevron: true,
                        onTap: () async {
                          LockGate.suppress();
                          if (!await Native.requestPermission('backgroundLocation')) {
                            LockGate.suppress();
                            await Native.openAppSettings();
                          }
                        },
                      ),
                    ],
                  ],
                ),
                // ---- relock ----
                Section(
                  header: 'Re-lock',
                  footer: 'When an unlocked app locks again. Short hops to another screen and back — like a gallery’s private-album password, share sheets or pickers — never re-lock the app; going to the home screen does.',
                  children: [
                    _RadioTile(
                      title: 'When I leave the app',
                      on: s.config.relock == 'exit',
                      onTap: () => s.update((c) => c.relock = 'exit'),
                    ),
                    _RadioTile(
                      title: 'When screen turns off',
                      on: s.config.relock == 'screen',
                      onTap: () => s.update((c) => c.relock = 'screen'),
                    ),
                    _RadioTile(
                      title: 'After a delay',
                      on: s.config.relock == 'timeout',
                      onTap: () => s.update((c) => c.relock = 'timeout'),
                    ),
                    if (s.config.relock == 'timeout')
                      Tile(
                        title: 'Delay',
                        trailing: _Stepper(
                          value: s.config.relockMinutes,
                          min: 1,
                          max: 30,
                          suffix: ' min',
                          onChanged: (v) => s.update((c) => c.relockMinutes = v),
                        ),
                      ),
                  ],
                ),
              ]),
            ),
          ],
        );
      },
    );
  }

  Future<void> _pickTime(BuildContext context, int initial, ValueChanged<int> onDone) async {
    var value = initial;
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (c) => Container(
        height: 300,
        decoration: const BoxDecoration(
          color: C.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: CupertinoButton(
                onPressed: () => Navigator.pop(c),
                child: const Text(
                  'Done',
                  style: TextStyle(color: C.blue, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Expanded(
              child: CupertinoTheme(
                data: const CupertinoThemeData(brightness: Brightness.light),
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: DateTime(2000, 1, 1, initial ~/ 60, initial % 60),
                  onDateTimeChanged: (d) => value = d.hour * 60 + d.minute,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    onDone(value);
  }

  Future<void> _addWifi(BuildContext context) async {
    LockGate.suppress();
    if (!await Native.requestPermission('location')) {
      if (context.mounted) toast(context, 'Location permission required');
      return;
    }
    final ssid = await Native.currentWifi();
    if (!context.mounted) return;
    if (ssid == null) {
      toast(context, 'Not connected to Wi‑Fi');
      return;
    }
    final s = AppState.I;
    if (s.config.smart.ssids.contains(ssid)) {
      toast(context, '“$ssid” is already added');
      return;
    }
    s.update((c) => c.smart.ssids.add(ssid));
    toast(context, '“$ssid” added');
  }

  Future<void> _addPlace(BuildContext context) async {
    LockGate.suppress();
    if (!await Native.requestPermission('location')) {
      if (context.mounted) toast(context, 'Location permission required');
      return;
    }
    final loc = await Native.currentLocation();
    if (!context.mounted) return;
    if (loc == null) {
      toast(context, 'Location unavailable. Make sure GPS is on');
      return;
    }
    final name = TextEditingController(text: 'Home');
    var radius = 150.0;
    final ok = await showCupertinoDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => CupertinoAlertDialog(
          title: const Text('Trusted place'),
          content: Column(
            children: [
              const SizedBox(height: 12),
              CupertinoTextField(controller: name, placeholder: 'Name', autofocus: true),
              const SizedBox(height: 14),
              Text('Radius: ${radius.round()} m'),
              Material(
                color: Colors.transparent,
                child: Slider(
                  value: radius,
                  min: 50,
                  max: 1000,
                  divisions: 19,
                  onChanged: (v) => set(() => radius = v),
                ),
              ),
            ],
          ),
          actions: [
            CupertinoDialogAction(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    AppState.I.update(
      (c) => c.smart.places.add(
        TrustedPlace(
          name: name.text.trim().isEmpty ? 'Place' : name.text.trim(),
          lat: (loc['lat'] as num).toDouble(),
          lng: (loc['lng'] as num).toDouble(),
          radius: radius,
        ),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      width: 38,
      height: 38,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, color: on ? C.silver : C.card2),
      child: Text(
        label,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: on ? Colors.white : C.text2),
      ),
    ),
  );
}

class _RemoveButton extends StatelessWidget {
  const _RemoveButton({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: const Padding(
      padding: EdgeInsets.all(4),
      child: Icon(CupertinoIcons.minus_circle_fill, color: C.red, size: 22),
    ),
  );
}

class _RadioTile extends StatelessWidget {
  const _RadioTile({required this.title, required this.on, required this.onTap});
  final String title;
  final bool on;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Tile(title: title, onTap: onTap, trailing: Check(on));
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix = '',
  });
  final int value, min, max;
  final String suffix;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    Widget btn(IconData i, bool enabled, VoidCallback f) => GestureDetector(
      onTap: enabled ? f : null,
      child: Container(
        width: 36,
        height: 30,
        alignment: Alignment.center,
        child: Icon(i, size: 18, color: enabled ? C.text : C.text3),
      ),
    );
    return Container(
      decoration: BoxDecoration(color: C.card2, borderRadius: BorderRadius.circular(9)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          btn(CupertinoIcons.minus, value > min, () => onChanged(value - 1)),
          SizedBox(
            width: 56,
            child: Text('$value$suffix', textAlign: TextAlign.center, style: T.body.copyWith(fontSize: 15)),
          ),
          btn(CupertinoIcons.plus, value < max, () => onChanged(value + 1)),
        ],
      ),
    );
  }
}

class StepperControl extends _Stepper {
  const StepperControl({
    required super.value,
    required super.min,
    required super.max,
    required super.onChanged,
    super.suffix,
  });
}
