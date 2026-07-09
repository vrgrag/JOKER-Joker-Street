/// Parsed response from the portal (config) endpoint.
///
/// The backend contract is `{ ok, url, expires, message }`; fields
/// are renamed on the client side but the wire keys are mapped
/// verbatim so the backend contract stays intact.
class GateVerdict {
  const GateVerdict({
    required this.granted,
    this.link,
    this.notice,
    this.freshUntil,
  });

  /// Backend `ok` — true means show the WebView with [link].
  final bool granted;

  /// Backend `url` — the content URL to display.
  final String? link;

  /// Backend `message` — diagnostic note (e.g. "organic").
  final String? notice;

  /// Backend `expires` — unix seconds after which [link] should be
  /// refreshed.
  final int? freshUntil;

  factory GateVerdict.parse(Map<String, dynamic> map) {
    return GateVerdict(
      granted: map['ok'] as bool? ?? false,
      link: map['url'] as String?,
      notice: map['message'] as String?,
      freshUntil: map['expires'] as int?,
    );
  }

  factory GateVerdict.failure(String notice) =>
      GateVerdict(granted: false, notice: notice);

  bool get hasLink => link != null && link!.isNotEmpty;
}
