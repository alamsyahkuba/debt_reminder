import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/release/next_version.dart';

void main() {
  group('ReleaseVersion', () {
    test('parse dan format versi', () {
      final version = ReleaseVersion.parse('1.2.3+7');
      expect(version.major, 1);
      expect(version.minor, 2);
      expect(version.patch, 3);
      expect(version.build, 7);
      expect(version.name, '1.2.3');
      expect(version.full, '1.2.3+7');
    });

    test('patch menaikkan patch dan build', () {
      final next = ReleaseVersion.parse('1.2.3+7').bumped(BumpType.patch);
      expect(next.full, '1.2.4+8');
    });

    test('minor mereset patch dan menaikkan build', () {
      final next = ReleaseVersion.parse('1.2.3+7').bumped(BumpType.minor);
      expect(next.full, '1.3.0+8');
    });

    test('major mereset minor/patch dan menaikkan build', () {
      final next = ReleaseVersion.parse('1.2.3+7').bumped(BumpType.major);
      expect(next.full, '2.0.0+8');
    });

    test('build-only hanya menaikkan build', () {
      final next = ReleaseVersion.parse('1.2.3+7').bumped(BumpType.buildOnly);
      expect(next.full, '1.2.3+8');
    });

    test('format tidak valid ditolak', () {
      expect(
        () => ReleaseVersion.parse('1.2.3'),
        throwsA(isA<ReleaseException>()),
      );
      expect(
        () => ReleaseVersion.parse('v1.2.3+4'),
        throwsA(isA<ReleaseException>()),
      );
    });
  });

  group('resolveAutoBump', () {
    test('feat menghasilkan minor', () {
      expect(resolveAutoBump(['feat: tambah filter']), BumpType.minor);
    });

    test('fix/perf menghasilkan patch', () {
      expect(resolveAutoBump(['fix: perbaiki sync']), BumpType.patch);
      expect(resolveAutoBump(['perf: percepat pull']), BumpType.patch);
    });

    test('breaking change menghasilkan major', () {
      expect(resolveAutoBump(['feat!: ubah format data']), BumpType.major);
      expect(
        resolveAutoBump(['fix: ubah perilaku\n\nBREAKING CHANGE: format baru']),
        BumpType.major,
      );
    });

    test('commit release diabaikan', () {
      expect(
        resolveAutoBump(['chore(release): v1.0.0+1', 'fix: perbaiki bug']),
        BumpType.patch,
      );
    });

    test('commit non-conventional memakai fallback patch', () {
      expect(resolveAutoBump(['perbaikan kecil']), BumpType.patch);
    });

    test('tidak ada commit yang dapat dirilis ditolak', () {
      expect(
        () => resolveAutoBump(['chore(release): v1.0.0+1']),
        throwsA(isA<ReleaseException>()),
      );
      expect(() => resolveAutoBump([]), throwsA(isA<ReleaseException>()));
    });
  });

  group('decideRelease', () {
    const current = ReleaseVersion(major: 1, minor: 0, patch: 0, build: 1);

    test('initial memakai versi saat ini dan tag v1.0.0', () {
      final decision = decideRelease(
        current: current,
        requested: BumpType.initial,
        previousTag: null,
        commits: const <String>['feat: initial release'],
        existingTags: const <String>{},
      );

      expect(decision.next.full, '1.0.0+1');
      expect(decision.tag, 'v1.0.0');
      expect(decision.resolvedBump, BumpType.initial);
    });

    test('initial ditolak jika sudah ada tag', () {
      expect(
        () => decideRelease(
          current: current,
          requested: BumpType.initial,
          previousTag: null,
          commits: const <String>['feat: initial release'],
          existingTags: const <String>{'v1.0.0'},
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('initial ditolak jika sudah ada previous tag', () {
      expect(
        () => decideRelease(
          current: current,
          requested: BumpType.initial,
          previousTag: 'v1.0.0',
          commits: const <String>['feat: initial release'],
          existingTags: const <String>{'v1.0.0'},
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('auto menghasilkan patch setelah v1.0.0', () {
      final decision = decideRelease(
        current: current,
        requested: BumpType.auto,
        previousTag: 'v1.0.0',
        commits: const <String>['fix: perbaiki sync'],
        existingTags: const <String>{'v1.0.0'},
      );

      expect(decision.resolvedBump, BumpType.patch);
      expect(decision.next.full, '1.0.1+2');
      expect(decision.tag, 'v1.0.1');
    });

    test('auto tanpa tag harus memakai initial', () {
      expect(
        () => decideRelease(
          current: current,
          requested: BumpType.auto,
          previousTag: null,
          commits: const <String>['fix: perbaiki sync'],
          existingTags: const <String>{},
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('versi pubspec harus sama dengan tag terakhir', () {
      expect(
        () => decideRelease(
          current: current,
          requested: BumpType.patch,
          previousTag: 'v1.0.1',
          commits: const <String>['fix: perbaiki sync'],
          existingTags: const <String>{'v1.0.1'},
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('tag yang sudah ada ditolak', () {
      expect(
        () => decideRelease(
          current: current,
          requested: BumpType.patch,
          previousTag: 'v1.0.0',
          commits: const <String>['fix: perbaiki sync'],
          existingTags: const <String>{'v1.0.0', 'v1.0.1'},
        ),
        throwsA(isA<ReleaseException>()),
      );
    });

    test('build-only tidak membuat tag rilis', () {
      final decision = decideRelease(
        current: current,
        requested: BumpType.buildOnly,
        previousTag: 'v1.0.0',
        commits: const <String>[],
        existingTags: const <String>{'v1.0.0'},
      );

      expect(decision.next.full, '1.0.0+2');
      expect(decision.tag, isEmpty);
    });
  });

  group('pubspec', () {
    test('membaca dan menulis versi tanpa mengubah baris lain', () {
      final directory = Directory.systemTemp.createTempSync('release-version');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/pubspec.yaml');
      file.writeAsStringSync(
        'name: demo\nversion: 1.2.3+4\nenvironment:\n  sdk: ^3.0.0\n',
      );

      expect(readPubspecVersion(file), '1.2.3+4');
      writePubspecVersion(file, ReleaseVersion.parse('1.3.0+5'));

      expect(file.readAsStringSync(), contains('version: 1.3.0+5'));
      expect(file.readAsStringSync(), contains('name: demo'));
    });

    test('baris version yang hilang ditolak', () {
      final directory = Directory.systemTemp.createTempSync('release-version');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/pubspec.yaml');
      file.writeAsStringSync('name: demo\n');

      expect(
        () => writePubspecVersion(file, ReleaseVersion.parse('1.0.0+1')),
        throwsA(isA<ReleaseException>()),
      );
    });
  });
}
