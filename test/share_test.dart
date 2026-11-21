import 'dart:io';

import 'package:deskplan_companion/features/connection/pc_info.dart';
import 'package:deskplan_companion/features/share_intake/android_share_intake.dart';
import 'package:deskplan_companion/features/share_intake/share_entry.dart';
import 'package:deskplan_companion/features/share_intake/shared_item.dart';
import 'package:deskplan_companion/features/share_intake/url_shortcut.dart';
import 'package:flutter_test/flutter_test.dart';

const _pc = PcInfo(
  name: 'PC',
  version: '',
  destinations: [],
  allowedExtensions: {'pdf', 'png', 'url'},
);

void main() {
  group('UrlShortcut', () {
    test('finds the link in browser share text', () {
      final url = UrlShortcut.extractWebUrl(
        'Intro to design https://example.com/page?a=1&b=2',
      );
      expect(url.toString(), 'https://example.com/page?a=1&b=2');
    });

    test('drops punctuation stuck to the end', () {
      expect(
        UrlShortcut.extractWebUrl('see http://example.com/x.').toString(),
        'http://example.com/x',
      );
    });

    test('plain text and other schemes are not links', () {
      expect(UrlShortcut.extractWebUrl('just some words'), isNull);
      expect(UrlShortcut.extractWebUrl('file:///etc/passwd'), isNull);
      expect(UrlShortcut.extractWebUrl('javascript:alert(1)'), isNull);
    });

    test('writes the Internet Shortcut format with CRLF', () {
      expect(
        UrlShortcut.content(Uri.parse('https://example.com/')),
        '[InternetShortcut]\r\nURL=https://example.com/\r\n',
      );
    });

    test('names the file after the title, or the site', () {
      final url = Uri.parse('https://www.example.com/a');
      expect(
        UrlShortcut.fileName(url, title: 'Week 1: "Intro" / notes'),
        'Week 1 Intro notes.url',
      );
      expect(UrlShortcut.fileName(url), 'example.com.url');
    });
  });

  group('ShareEntry', () {
    test('a web link becomes a .url file that the PC accepts', () async {
      final entry = await ShareEntry.from(
        const SharedText(
          text: 'Cool page https://example.com/x',
          subject: 'Cool page',
        ),
      );
      expect(entry.name, 'Cool page.url');
      expect(entry.linkContent, contains('URL=https://example.com/x'));
      expect(entry.problem(_pc), isNull);
    });

    test('text that is not a link is refused', () async {
      final entry = await ShareEntry.from(const SharedText(text: 'hello'));
      expect(entry.problem(_pc), contains('documents, images and links'));
    });

    test('files are judged by the name, which the user can edit', () async {
      final file = File('${Directory.systemTemp.path}/deskplan_share_test');
      await file.writeAsString('x');
      addTearDown(file.delete);

      final entry = await ShareEntry.from(
        SharedFile(path: file.path, name: 'setup.exe'),
      );
      expect(entry.problem(_pc), ShareEntry.unsupportedMessage);

      entry.name = 'notes.PDF';
      expect(entry.problem(_pc), isNull);

      entry.name = '  ';
      expect(entry.problem(_pc), 'Enter a name');
    });

    test('the ending is locked: only the name before it changes', () async {
      final file = File('${Directory.systemTemp.path}/deskplan_share_test3');
      await file.writeAsString('x');
      addTearDown(file.delete);
      final entry = await ShareEntry.from(
        SharedFile(path: file.path, name: 'Chapter 4.final.pdf'),
      );
      expect(entry.extension, '.pdf');
      expect(entry.baseName, 'Chapter 4.final');

      entry.rename('Week 1 notes');
      expect(entry.name, 'Week 1 notes.pdf');

      entry.rename(''); // cleared: the ending must not turn into the name
      expect(entry.name, '.pdf');
      expect(entry.extension, '.pdf');
      expect(entry.problem(_pc), 'Enter a name');
    });

    test('names with no real ending have none to lock', () {
      expect(ShareEntry.extensionOf('README'), '');
      expect(ShareEntry.extensionOf('.hidden'), '');
      expect(ShareEntry.extensionOf('trailing.'), '');
      expect(ShareEntry.extensionOf('a.b.PNG'), '.PNG');
    });

    test('with no remembered PC info the PC decides', () async {
      final file = File('${Directory.systemTemp.path}/deskplan_share_test2');
      await file.writeAsString('x');
      addTearDown(file.delete);
      final entry = await ShareEntry.from(
        SharedFile(path: file.path, name: 'setup.exe'),
      );
      expect(entry.problem(null), isNull);
    });
  });

  group('AndroidShareIntake.parse', () {
    test('reads files and text, skips anything unreadable', () {
      final items = AndroidShareIntake.parse([
        {'type': 'file', 'path': '/cache/a', 'name': 'a.pdf'},
        {'type': 'text', 'text': 'https://x.com', 'subject': 'X'},
        {'type': 'file', 'path': 1},
        {'type': 'weird'},
        'junk',
      ]);
      expect(items, hasLength(2));
      expect((items[0] as SharedFile).name, 'a.pdf');
      expect((items[1] as SharedText).subject, 'X');
    });

    test('nothing shared gives an empty list', () {
      expect(AndroidShareIntake.parse(null), isEmpty);
      expect(AndroidShareIntake.parse('x'), isEmpty);
    });
  });
}
