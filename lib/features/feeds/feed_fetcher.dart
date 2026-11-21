import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// A download that failed, with a sentence for the user.
class FeedFetchError implements Exception {
  final String message;
  const FeedFetchError(this.message);

  @override
  String toString() => message;
}

/// Downloads a calendar feed straight from its server (the FH timetable,
/// Moodle), the same way DeskPlan does (main/calendar/FeedFetcher.js). These
/// are public servers with real certificates, checked normally: this is not
/// the pinned connection to the PC, and it works on mobile data too.
abstract class FeedFetcher {
  Future<String> fetchText(String url);

  /// webcal:// becomes https://; only https is accepted, so a Moodle token
  /// is never sent in the clear. Throws [FeedFetchError].
  static String normalizeUrl(String input) {
    final text = input.trim().replaceFirst(
      RegExp(r'^webcals?://', caseSensitive: false),
      'https://',
    );
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FeedFetchError('That is not a web address.');
    }
    if (uri.scheme.toLowerCase() != 'https') {
      throw const FeedFetchError('Use an https:// or webcal:// address.');
    }
    return uri
        .replace(scheme: 'https', host: uri.host.toLowerCase())
        .toString();
  }
}

class HttpFeedFetcher implements FeedFetcher {
  static const maxBytes = 2 * 1024 * 1024;
  static const timeout = Duration(seconds: 20);

  @override
  Future<String> fetchText(String input) async {
    final url = Uri.parse(FeedFetcher.normalizeUrl(input));
    final client = HttpClient()..connectionTimeout = timeout;
    try {
      final request = await client.getUrl(url).timeout(timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'text/calendar, */*');
      final response = await request.close().timeout(timeout);
      final status = response.statusCode;
      if (status == 401 || status == 403) {
        throw const FeedFetchError(
          'The server refused this address. The link may have expired: copy a new one.',
        );
      }
      if (status < 200 || status >= 300) {
        throw FeedFetchError(
          'The calendar server answered with error $status.',
        );
      }
      if (response.contentLength > maxBytes) {
        throw const FeedFetchError('This is too large to be a calendar.');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(timeout)) {
        bytes.addAll(chunk);
        if (bytes.length > maxBytes) {
          throw const FeedFetchError('This is too large to be a calendar.');
        }
      }
      return utf8.decode(bytes, allowMalformed: true);
    } on FeedFetchError {
      rethrow;
    } on TimeoutException {
      throw const FeedFetchError('The calendar server did not answer in time.');
    } on Object catch (e) {
      throw FeedFetchError('Could not reach the calendar server ($e).');
    } finally {
      client.close(force: true);
    }
  }
}
