import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../theme.dart';
import '../widgets.dart';
import 'security_page.dart';

class IntruderPage extends StatelessWidget {
  const IntruderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.I,
      builder: (context, _) {
        final list = AppState.I.intruders;
        return SubPage(
          title: 'Events',
          trailing: list.isEmpty
              ? null
              : CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text('Clear', style: TextStyle(color: C.red, fontSize: 16)),
                  onPressed: () async {
                    if (!await confirm(
                      context,
                      'Delete all',
                      'All events and photos will be deleted.',
                      ok: 'Delete',
                      destructive: true,
                    )) {
                      return;
                    }
                    await Store.deleteIntruders(list.map((e) => e.id));
                    await AppState.I.loadIntruders();
                  },
                ),
          children: [
            if (list.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 80),
                child: Center(child: Text('No events', style: T.sub)),
              )
            else
              Section(children: [for (final e in list) IntruderTile(event: e)]),
          ],
        );
      },
    );
  }
}

class IntruderDetailPage extends StatelessWidget {
  const IntruderDetailPage({super.key, required this.event});
  final IntruderEvent event;

  @override
  Widget build(BuildContext context) {
    final e = event;
    final photos = e.photos.where((p) => File(p).existsSync()).toList();
    return SubPage(
      title: e.appName,
      children: [
        if (photos.isEmpty)
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Text('No photo taken (camera busy or no permission).', style: T.sub),
          )
        else
          for (final p in photos)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GestureDetector(
                onTap: () => Navigator.of(context, rootNavigator: true).push(
                  PageRouteBuilder(
                    opaque: false,
                    transitionDuration: const Duration(milliseconds: 180),
                    pageBuilder: (_, _, _) => _PhotoViewer(path: p),
                    transitionsBuilder: (_, a, _, c) => FadeTransition(opacity: a, child: c),
                  ),
                ),
                child: Hero(
                  tag: p,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 3 / 4,
                      child: Image.file(File(p), fit: BoxFit.cover, cacheWidth: 900),
                    ),
                  ),
                ),
              ),
            ),
        Section(
          children: [
            Tile(title: 'Time', value: fmtTime(e.time)),
            Tile(title: 'Reason', value: e.reason == 'duress' ? 'Decoy code' : 'Wrong code'),
            if (e.reason != 'duress') Tile(title: 'Attempts', value: '${e.attempts}'),
          ],
        ),
        Section(
          children: [
            Tile(
              title: 'Delete',
              titleColor: C.red,
              onTap: () async {
                await Store.deleteIntruders([e.id]);
                await AppState.I.loadIntruders();
                if (context.mounted) Navigator.pop(context);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _PhotoViewer extends StatelessWidget {
  const _PhotoViewer({required this.path});
  final String path;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => Navigator.pop(context),
    child: ColoredBox(
      color: Colors.black,
      child: Center(
        child: Hero(
          tag: path,
          child: InteractiveViewer(maxScale: 5, child: Image.file(File(path))),
        ),
      ),
    ),
  );
}
