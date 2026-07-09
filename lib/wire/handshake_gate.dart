import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../kind/gate_verdict.dart';
import '../setup/app_mask.dart';
import 'mask_store.dart';
import 'masked_agent.dart';

// ---------------------------------------------------------------
// HandshakeGate — posts the portal body, reads the verdict
// ---------------------------------------------------------------
// Sends the merged attribution body to the portal endpoint. On an
// allowed reply the link + ttl are cached so returning launches can
// fall back to the cached URL if the network later fails. A missing
// endpoint or any error yields a failure verdict, which routes the
// user to the native carnival game.
// ---------------------------------------------------------------

class HandshakeGate {
  HandshakeGate(this._store);

  final MaskStore _store;

  Future<GateVerdict> knock(Map<String, dynamic> body) async {
    final String endpoint = AppMask.portalGate;
    if (endpoint.isEmpty) {
      return GateVerdict.failure('no-endpoint');
    }

    try {
      final dynamic response = await maskedAgent
          .post(
            Uri.parse(endpoint),
            headers: <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint(
            '[HandshakeGate] response ${response.statusCode}: ${response.body}');
      }

      if (response.statusCode != 200) {
        return GateVerdict.failure('http-${response.statusCode}');
      }

      final Map<String, dynamic> map =
          jsonDecode(response.body) as Map<String, dynamic>;
      final GateVerdict verdict = GateVerdict.parse(map);

      if (verdict.granted && verdict.hasLink) {
        await _store.writeCachedLink(verdict.link!);
        if (verdict.freshUntil != null) {
          await _store.writeLinkTtl(verdict.freshUntil!);
        }
      }
      return verdict;
    } catch (e) {
      return GateVerdict.failure(e.toString());
    }
  }

  Future<String?> cachedLink() => _store.readCachedLink();
}
