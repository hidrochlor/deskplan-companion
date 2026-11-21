import 'dart:convert';

import '../connection/client_reply.dart';
import '../connection/deskplan_client.dart';
import 'feed_fetcher.dart';
import 'feed_mappers.dart';
import 'feed_service.dart';
import 'phone_feed.dart';

/// What one exchange with DeskPlan did.
class FeedSyncOutcome {
  final NoReply? blocked;
  final String? failure;

  const FeedSyncOutcome({this.blocked, this.failure});
}

/// Keeps the phone's feed list and course choices the same as DeskPlan's
/// (protocol.md section 5, `/v1/feed-settings`). Changes made here are sent
/// (PUT); DeskPlan keeps the newer of each and answers the whole list, which
/// the phone then takes as it is. Without changes it only asks (GET).
class FeedSettingsSync {
  final DeskPlanClient _client;
  final FeedService _feeds;

  FeedSettingsSync(this._client, this._feeds);

  Future<FeedSyncOutcome> run() async {
    final store = _feeds.store;
    final all = await store.all();
    final dirtyFeeds = all.where((f) => f.dirty).toList();
    final dirtyChoices = (await store.choices()).where((c) => c.dirty).toList();
    final ClientReply reply;
    if (dirtyFeeds.isEmpty && dirtyChoices.isEmpty) {
      reply = await _client.send('GET', ['v1', 'feed-settings']);
    } else {
      reply = await _client.send(
        'PUT',
        ['v1', 'feed-settings'],
        jsonBody: {
          'feeds': [
            for (final f in dirtyFeeds)
              {
                'id': f.id,
                'url': f.removed ? null : await store.urls.read(f.id),
                'name': f.name,
                'removed': f.removed,
                'updatedAt': f.updatedAt.toIso8601String(),
              },
          ],
          'courses': [for (final c in dirtyChoices) c.toWire()],
        },
      );
    }
    if (reply is NoReply) return FeedSyncOutcome(blocked: reply);
    final Reply(:status, :body) = reply as Reply;
    final blocked = NoReply.fromStatus(status, DeskPlanClient.errorCode(body));
    if (blocked != null) return FeedSyncOutcome(blocked: blocked);
    if (status != 200) {
      return FeedSyncOutcome(
        failure: 'DeskPlan did not take the calendar list ($status)',
      );
    }
    try {
      await _take(jsonDecode(body));
    } on FormatException catch (e) {
      return FeedSyncOutcome(
        failure:
            'DeskPlan sent a calendar list the phone cannot read (${e.message})',
      );
    }
    return const FeedSyncOutcome();
  }

  /// DeskPlan's list replaces the phone's. A feed added on both under
  /// different ids takes DeskPlan's id; a feed DeskPlan does not list is
  /// gone. New or changed addresses are downloaded.
  Future<void> _take(Object? json) async {
    if (json is! Map || json['feeds'] is! List || json['courses'] is! List) {
      throw const FormatException('not a calendar list');
    }
    final store = _feeds.store;
    final local = {for (final f in await store.all()) f.id: f};
    final localUrls = <String, String>{};
    for (final id in local.keys) {
      final url = await store.urls.read(id);
      if (url != null) localUrls[id] = url;
    }
    final keep = <String>{};
    final download = <String>[];
    for (final raw in json['feeds'] as List) {
      if (raw is! Map || raw['id'] is! String || raw['removed'] is! bool) {
        throw const FormatException('a feed is not one');
      }
      final id = raw['id'] as String;
      final updatedAt = DateTime.tryParse('${raw['updatedAt']}');
      if (updatedAt == null) throw const FormatException('a feed has no time');
      if (raw['removed'] == true) continue; // dropped below
      final url = raw['url'];
      if (url is! String) throw const FormatException('a feed has no address');
      final String normal;
      try {
        normal = FeedFetcher.normalizeUrl(url);
      } on FeedFetchError catch (e) {
        throw FormatException(e.message);
      }
      keep.add(id);
      // The same address under the phone's own id: DeskPlan's id wins.
      for (final MapEntry(key: otherId, value: otherUrl) in localUrls.entries) {
        if (otherId != id && otherUrl == normal) {
          await _feeds.calendar.removeFeed(otherId);
          await store.forget(otherId);
        }
      }
      final mine = local[id];
      final name = raw['name'] is String ? raw['name'] as String : '';
      await store.urls.write(id, normal);
      await store.save(
        (mine ??
                PhoneFeed(
                  id: id,
                  name: name,
                  kind: FeedKind.fromWire(raw['kind']),
                  host: Uri.parse(normal).host,
                  updatedAt: updatedAt,
                ))
            .copyWith(
              name: name.isEmpty ? null : name,
              host: Uri.parse(normal).host,
              updatedAt: updatedAt,
              removed: false,
              dirty: false,
            ),
      );
      if (mine == null || mine.removed || localUrls[id] != normal) {
        download.add(id);
      }
    }
    for (final id in local.keys) {
      if (keep.contains(id)) continue;
      await _feeds.calendar.removeFeed(id);
      await store.forget(id);
    }

    final choices = <CourseChoice>[];
    for (final raw in json['courses'] as List) {
      if (raw is! Map ||
          raw['feedId'] is! String ||
          raw['key'] is! String ||
          raw['hidden'] is! bool) {
        throw const FormatException('a course choice is not one');
      }
      final at = DateTime.tryParse('${raw['updatedAt']}');
      if (at == null) throw const FormatException('a course has no time');
      choices.add(
        CourseChoice(
          feedId: raw['feedId'] as String,
          key: raw['key'] as String,
          hidden: raw['hidden'] as bool,
          updatedAt: at,
        ),
      );
    }
    await _feeds.replaceChoices(choices);
    for (final id in download) {
      await _feeds.refresh(id);
    }
  }
}
