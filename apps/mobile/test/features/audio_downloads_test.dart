import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:louanges_a_dieu/core/catalog/published_hymn.dart';
import 'package:louanges_a_dieu/features/audio/audio_downloads.dart';

AudioTrack track(String key) => AudioTrack(
  id: '00000000-0000-4000-8000-0000000a0001',
  mediaType: MediaType.melody,
  storageKey: key,
  duration: null,
  segments: const [],
);

void main() {
  late Directory dir;
  final url = Uri.parse('https://media.test/lad/cantiques/0002/melodie.mp3');
  final bytes = List<int>.generate(50000, (i) => i % 251);

  setUp(() => dir = Directory.systemTemp.createTempSync('lad-audio-'));
  tearDown(() => dir.deleteSync(recursive: true));

  AudioDownloads downloads(http.Client client) => AudioDownloads(
    root: () async => Directory('${dir.path}/audio'),
    client: client,
  );

  test(
    'télécharge, signale l’avancement, puis le fichier est disponible',
    () async {
      final service = downloads(
        MockClient.streaming((request, _) async {
          expect(request.url, url);
          return http.StreamedResponse(
            Stream.fromIterable([
              bytes.sublist(0, 20000),
              bytes.sublist(20000),
            ]),
            200,
            contentLength: bytes.length,
          );
        }),
      );
      final t = track('cantiques/0002/melodie.mp3');
      final progress = <double?>[];
      final state = service.watch(t);
      state.addListener(() => progress.add(state.value.progress));

      await service.download(t, url);

      expect(state.value.status, DownloadStatus.ready);
      expect(progress, containsAllInOrder([0.0, 0.4, 1.0]));
      final file = await service.file(t);
      expect(file!.readAsBytesSync(), bytes);
      expect(await service.usage(), (count: 1, bytes: bytes.length));
    },
  );

  test('échec (404 ou fichier incomplet) : rien sur l’appareil', () async {
    final missing = downloads(
      MockClient((_) async => http.Response('introuvable', 404)),
    );
    final t = track('cantiques/0002/melodie.mp3');
    await missing.download(t, url);
    expect(missing.watch(t).value.status, DownloadStatus.failed);
    expect(await missing.file(t), isNull);

    final truncated = downloads(
      MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          Stream.value(bytes.sublist(0, 100)),
          200,
          contentLength: bytes.length,
        ),
      ),
    );
    await truncated.download(t, url);
    expect(truncated.watch(t).value.status, DownloadStatus.failed);
    expect(await truncated.file(t), isNull);
    expect(await truncated.usage(), (count: 0, bytes: 0));
  });

  test('fichier remplacé (clé changée) : l’ancien disparaît', () async {
    final service = downloads(
      MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    await service.download(track('cantiques/0002/melodie.mp3'), url);
    final updated = track('cantiques/0002/melodie-v2.mp3');
    expect(await service.file(updated), isNull);
    await service.download(updated, url);
    expect(await service.file(updated), isNotNull);
    expect((await service.usage()).count, 1);
  });

  test('suppression d’un enregistrement, puis de tous', () async {
    final service = downloads(
      MockClient((_) async => http.Response.bytes(bytes, 200)),
    );
    final t = track('cantiques/0002/melodie.mp3');
    await service.download(t, url);
    await service.delete(t);
    expect(await service.file(t), isNull);
    expect(service.watch(t).value.status, DownloadStatus.absent);

    await service.download(t, url);
    await service.deleteAll();
    expect(await service.usage(), (count: 0, bytes: 0));
    expect(service.watch(t).value.status, DownloadStatus.absent);
  });
}
