// Copyright 2023 the Dart project authors. All rights reserved.
// Use of this source code is governed by a BSD-style license
// that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

void main(List<String> args) {
  final argParser = ArgParser()
    ..addFlag('verify',
        negatable: false, help: 'Verify the generated samples files.')
    ..addFlag('help',
        abbr: 'h', negatable: false, help: 'Display this help output.');

  final argResults = argParser.parse(args);

  if (argResults['help'] as bool) {
    print(argParser.usage);
    exit(0);
  }

  final samples = Samples();
  samples.parse();
  if (argResults['verify'] as bool) {
    samples.verifyGeneration();
  } else {
    samples.generate();
  }
}

const Set<String> categories = {
  'Dart',
  'Flutter',
};

class Samples {
  late final List<Sample> samples;

  void parse() {
    // read the samples
    var json =
        jsonDecode(File(p.join('lib', 'samples.json')).readAsStringSync());

    // do basic validation
    samples = (json as List).map((j) => Sample.fromJson(j)).toList();

    var hadFailure = false;
    void fail(String message) {
      stderr.writeln(message);
      hadFailure = true;
    }

    for (var sample in samples) {
      print(sample);

      if (sample.id.contains(' ')) {
        fail('Illegal chars in sample ID.');
      }

      if (!File(sample.path).existsSync()) {
        fail('File ${sample.path} not found.');
      }

      if (!categories.contains(sample.category)) {
        fail('Unknown category: ${sample.category}');
      }

      if (samples.where((s) => s.id == sample.id).length > 1) {
        fail('Duplicate sample id: ${sample.id}');
      }
    }

    if (hadFailure) {
      exit(1);
    }
  }

  void generate() {
    var readme = File('README.md');
    readme.writeAsStringSync(_generateReadmeContent());

    // print generation message
    print('');
    print('Wrote ${readme.path}');
  }

  void verifyGeneration() {
    print('');

    print('Verifying sample file generation...');

    var readme = File('README.md');
    if (readme.readAsStringSync() != _generateReadmeContent()) {
      stderr.writeln('Generated sample files not up-to-date.');
      stderr.writeln('Re-generate by running:');
      stderr.writeln('');
      stderr.writeln('  dart tool/samples.dart');
      stderr.writeln('');
      exit(1);
    }

    // print success message
    print('Generated files up-to-date');
  }

  String _generateReadmeContent() {
    const marker = '<!-- samples -->';

    var contents = File('README.md').readAsStringSync();
    var table = _generateTable();

    return contents.substring(0, contents.indexOf(marker) + marker.length + 1) +
        table +
        contents.substring(contents.lastIndexOf(marker));
  }

  String _generateTable() {
    return '''
| Category | Name | ID | Source |
| --- | --- | --- | --- |
${samples.map((s) => s.toTableRow()).join('\n')}
''';
  }
}

class Sample {
  final String category;
  final String name;
  final String id;
  final String path;

  Sample({
    required this.category,
    required this.name,
    required this.id,
    required this.path,
  });

  factory Sample.fromJson(Map json) {
    return Sample(
      category: json['category'],
      name: json['name'],
      id: (json['id'] as String?) ?? _idFromName(json['name']),
      path: json['path'],
    );
  }

  String toTableRow() => '| $category | $name | `$id` | [$path]($path) |';

  @override
  String toString() => '[$category] $name ($id)';

  static String _idFromName(String name) =>
      name.trim().toLowerCase().replaceAll(' ', '-');
}
