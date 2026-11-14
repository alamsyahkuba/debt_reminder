import 'dart:io';

/// Release bump modes accepted by the GitHub release workflow.
enum BumpType {
  auto,
  patch,
  minor,
  major,
  buildOnly,
  initial;

  static BumpType parse(String value) {
    return switch (value.trim()) {
      'auto' => BumpType.auto,
      'patch' => BumpType.patch,
      'minor' => BumpType.minor,
      'major' => BumpType.major,
      'build-only' => BumpType.buildOnly,
      'initial' => BumpType.initial,
      _ => throw ReleaseException(
        'Bump "$value" tidak valid. Gunakan auto, patch, minor, major, '
        'build-only, atau initial.',
      ),
    };
  }

  String get cliName {
    return switch (this) {
      BumpType.buildOnly => 'build-only',
      _ => name,
    };
  }
}

final class ReleaseVersion {
  const ReleaseVersion({
    required this.major,
    required this.minor,
    required this.patch,
    required this.build,
  });

  final int major;
  final int minor;
  final int patch;
  final int build;

  String get name => '$major.$minor.$patch';
  String get full => '$name+$build';

  factory ReleaseVersion.parse(String value) {
    final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)\+(\d+)$').firstMatch(value);
    if (match == null) {
      throw ReleaseException(
        'Versi "$value" tidak valid. Gunakan format MAJOR.MINOR.PATCH+BUILD.',
      );
    }

    return ReleaseVersion(
      major: int.parse(match.group(1)!),
      minor: int.parse(match.group(2)!),
      patch: int.parse(match.group(3)!),
      build: int.parse(match.group(4)!),
    );
  }

  ReleaseVersion bumped(BumpType type) {
    return switch (type) {
      BumpType.patch => ReleaseVersion(
        major: major,
        minor: minor,
        patch: patch + 1,
        build: build + 1,
      ),
      BumpType.minor => ReleaseVersion(
        major: major,
        minor: minor + 1,
        patch: 0,
        build: build + 1,
      ),
      BumpType.major => ReleaseVersion(
        major: major + 1,
        minor: 0,
        patch: 0,
        build: build + 1,
      ),
      BumpType.buildOnly => ReleaseVersion(
        major: major,
        minor: minor,
        patch: patch,
        build: build + 1,
      ),
      BumpType.initial => this,
      BumpType.auto => throw ReleaseException(
        'Bump auto harus di-resolve sebelum menaikkan versi.',
      ),
    };
  }
}

final class ReleaseDecision {
  const ReleaseDecision({
    required this.previous,
    required this.next,
    required this.resolvedBump,
    required this.tag,
    required this.previousTag,
  });

  final ReleaseVersion previous;
  final ReleaseVersion next;
  final BumpType resolvedBump;
  final String tag;
  final String? previousTag;
}

final class ReleaseException implements Exception {
  const ReleaseException(this.message);

  final String message;

  @override
  String toString() => message;
}

ReleaseDecision decideRelease({
  required ReleaseVersion current,
  required BumpType requested,
  required String? previousTag,
  required Iterable<String> commits,
  required Set<String> existingTags,
}) {
  if (requested == BumpType.initial) {
    if (previousTag != null) {
      throw const ReleaseException(
        'Mode initial hanya boleh dipakai sebelum tag rilis pertama.',
      );
    }
    if (existingTags.isNotEmpty) {
      throw ReleaseException(
        'Mode initial ditolak karena sudah ada tag rilis: '
        '${existingTags.join(', ')}.',
      );
    }

    return ReleaseDecision(
      previous: current,
      next: current,
      resolvedBump: BumpType.initial,
      tag: 'v${current.name}',
      previousTag: null,
    );
  }

  if (previousTag == null) {
    throw ReleaseException(
      'Belum ada tag rilis. Gunakan --bump=initial untuk rilis pertama.',
    );
  }

  final parsedPreviousTag = _parseReleaseTag(previousTag);
  if (parsedPreviousTag != current.name) {
    throw ReleaseException(
      'Versi pubspec ${current.name} tidak sama dengan tag terakhir '
      '$previousTag. Perbaiki versi sebelum release.',
    );
  }

  final resolvedBump = requested == BumpType.auto
      ? resolveAutoBump(commits)
      : requested;
  final next = current.bumped(resolvedBump);
  final tag = 'v${next.name}';

  if (resolvedBump != BumpType.buildOnly && existingTags.contains(tag)) {
    throw ReleaseException(
      'Tag $tag sudah ada. Naikkan version name atau gunakan mode lain.',
    );
  }

  return ReleaseDecision(
    previous: current,
    next: next,
    resolvedBump: resolvedBump,
    tag: resolvedBump == BumpType.buildOnly ? '' : tag,
    previousTag: previousTag,
  );
}

BumpType resolveAutoBump(Iterable<String> commits) {
  var sawCommit = false;
  var sawFeature = false;
  var sawBreaking = false;

  for (final raw in commits) {
    final message = raw.trim();
    if (message.isEmpty) {
      continue;
    }

    final firstLine = message.split(RegExp(r'\r?\n')).first.trim();
    if (firstLine.startsWith('chore(release):')) {
      continue;
    }

    sawCommit = true;

    if (message.contains('BREAKING CHANGE:') ||
        RegExp(r'^[a-zA-Z0-9_-]+(\([^)]+\))?!:').hasMatch(firstLine)) {
      sawBreaking = true;
    } else if (RegExp(r'^feat(\([^)]+\))?:').hasMatch(firstLine)) {
      sawFeature = true;
    }
  }

  if (!sawCommit) {
    throw const ReleaseException(
      'Tidak ada commit baru yang dapat dirilis sejak tag terakhir.',
    );
  }
  if (sawBreaking) {
    return BumpType.major;
  }
  if (sawFeature) {
    return BumpType.minor;
  }
  return BumpType.patch;
}

String? readPubspecVersion(File file) {
  final source = file.readAsStringSync();
  final match = RegExp(
    r'^version:\s*([^\r\n]+)\s*$',
    multiLine: true,
  ).firstMatch(source);
  return match?.group(1)?.trim();
}

void writePubspecVersion(File file, ReleaseVersion version) {
  final source = file.readAsStringSync();
  final pattern = RegExp(r'^version:\s*[^\r\n]+', multiLine: true);
  if (!pattern.hasMatch(source)) {
    throw const ReleaseException(
      'Baris version tidak ditemukan di pubspec.yaml.',
    );
  }

  final updated = source.replaceFirst(pattern, 'version: ${version.full}');
  file.writeAsStringSync(updated);
}

void main(List<String> arguments) {
  try {
    final options = _Options.parse(arguments);
    final pubspec = File('pubspec.yaml');
    final rawVersion = readPubspecVersion(pubspec);
    if (rawVersion == null) {
      throw const ReleaseException(
        'Baris version tidak ditemukan di pubspec.yaml.',
      );
    }

    final current = ReleaseVersion.parse(rawVersion);
    final existingTags = _readTags();
    final previousTag = _latestReleaseTag(existingTags);
    final commits = _readCommits(previousTag);
    final decision = decideRelease(
      current: current,
      requested: options.bump,
      previousTag: previousTag,
      commits: commits,
      existingTags: existingTags,
    );

    if (options.apply) {
      writePubspecVersion(pubspec, decision.next);
    }

    final output = _buildOutput(decision);
    stdout.write(output);

    final githubOutput = options.githubOutput;
    if (githubOutput != null && githubOutput.isNotEmpty) {
      File(githubOutput)
          .writeAsStringSync(output, mode: FileMode.append, flush: true);
    }
  } on ReleaseException catch (error) {
    stderr.writeln('Release dibatalkan: ${error.message}');
    exitCode = 1;
  } on ProcessException catch (error) {
    stderr.writeln('Release dibatalkan: ${error.message}');
    exitCode = 1;
  }
}

final class _Options {
  const _Options({required this.bump, required this.apply, this.githubOutput});

  final BumpType bump;
  final bool apply;
  final String? githubOutput;

  factory _Options.parse(List<String> arguments) {
    var bump = BumpType.auto;
    var apply = false;
    String? githubOutput;

    for (final argument in arguments) {
      if (argument == '--apply') {
        apply = true;
      } else if (argument.startsWith('--bump=')) {
        bump = BumpType.parse(argument.substring('--bump='.length));
      } else if (argument.startsWith('--github-output=')) {
        githubOutput = argument.substring('--github-output='.length);
      } else if (argument == '--help' || argument == '-h') {
        stdout.writeln(
          'Usage: dart run tool/release/next_version.dart '
          '--bump=auto|patch|minor|major|build-only|initial '
          '[--apply] [--github-output=path]',
        );
        exit(0);
      } else {
        throw ReleaseException('Argumen tidak dikenal: $argument');
      }
    }

    return _Options(bump: bump, apply: apply, githubOutput: githubOutput);
  }
}

String _buildOutput(ReleaseDecision decision) {
  final previousTag = decision.previousTag ?? '';
  return '${<String>['previous_version=${decision.previous.full}', 'version=${decision.next.full}', 'version_name=${decision.next.name}', 'build_number=${decision.next.build}', 'bump=${decision.resolvedBump.cliName}', 'previous_tag=$previousTag', 'tag=${decision.tag}'].join('\n')}\n';
}

Set<String> _readTags() {
  final result = Process.runSync('git', <String>['tag', '--list', 'v*']);
  if (result.exitCode != 0) {
    throw ReleaseException(
      'Tidak dapat membaca Git tags: ${result.stderr.toString().trim()}',
    );
  }

  return result.stdout
      .toString()
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toSet();
}

String? _latestReleaseTag(Set<String> tags) {
  if (tags.isEmpty) {
    return null;
  }

  final result = Process.runSync('git', <String>[
    'describe',
    '--tags',
    '--abbrev=0',
    '--match',
    'v[0-9]*',
  ]);
  if (result.exitCode != 0) {
    throw ReleaseException(
      'Tidak dapat menentukan tag terakhir: '
      '${result.stderr.toString().trim()}',
    );
  }

  final tag = result.stdout.toString().trim();
  return tag.isEmpty ? null : tag;
}

List<String> _readCommits(String? previousTag) {
  final arguments = <String>['log', '--format=%B%x1e'];
  if (previousTag != null) {
    arguments.add('$previousTag..HEAD');
  }

  final result = Process.runSync('git', arguments);
  if (result.exitCode != 0) {
    throw ReleaseException(
      'Tidak dapat membaca commit: ${result.stderr.toString().trim()}',
    );
  }

  return result.stdout
      .toString()
      .split('\x1e')
      .map((message) => message.trim())
      .where((message) => message.isNotEmpty)
      .toList(growable: false);
}

String _parseReleaseTag(String tag) {
  final match = RegExp(r'^v(\d+\.\d+\.\d+)$').firstMatch(tag);
  if (match == null) {
    throw ReleaseException('Tag "$tag" bukan tag rilis SemVer yang valid.');
  }
  return match.group(1)!;
}
