// example/SDK_UpdateKeyPageThreshold.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:accumulate_api/accumulate_api.dart';
import 'package:convert/convert.dart' as conv;

/// ========================= USER CONFIG (EDIT) =========================
/// TODO: switch to mainnet if desired:
const String endpoint = "https://mainnet.accumulatenetwork.io/v2";


/// TODO: set the key page you want to update (the page whose threshold you’re changing)
const String keyPageUrl = "acc://tessst0001.acme/book/1";

/// TODO: set your private key for the signer that’s authorized on [keyPageUrl].
/// Accepts HEX (with/without 0x) or base64; 32/64/96 bytes supported.
/// const String privateKeyMaterial = "enter keys";
const String privateKeyMaterial = "4a868f6ef8d4ad5a1fa00b906d845e611b1ec48475c2a4f2f0e3d5871eb7e551";

/// Desired threshold
const int newThreshold = 2;
/// Optional memo
const String memo = "Set threshold to 2";

/// =====================================================================

Future<void> main(List<String> args) async {
  final client = ACMEClient(endpoint);
  print("Endpoint: $endpoint");
  print("Target key page: $keyPageUrl");
  print("Setting threshold => $newThreshold");

  try {
    final signer = _buildSignerFromKeyMaterial(privateKeyMaterial);

    // Build operation: SetThreshold
    final op = KeyOperation()
      ..type = KeyPageOperationType.SetThreshold
      ..threshold = newThreshold;

    final params = UpdateKeyPageParam()
      ..operations = [op]
      ..memo = memo;

    final txid = await _updateKeyPageWithRetry(client, keyPageUrl, signer, params);
    print("SUCCESS. Submitted updateKeyPage. txid=$txid");
  } catch (e, st) {
    print("FAILED: $e");
    print(st);
  }
}

/// --- Helpers ------------------------------------------------------------

/// Prefer HEX; fallback to base64 if not hex.
/// Supports 32 (seed), 64 (expanded priv||pub), or 96 (seed||expanded) bytes.
Uint8List _decodeHexPreferBase64Fallback(String s) {
  final cleaned = s
      .trim()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceFirst(RegExp(r'^0x', caseSensitive: false), '');

  final isHex = RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleaned);
  if (isHex) {
    if (cleaned.length.isOdd) {
      throw ArgumentError("Hex length must be even.");
    }
    return Uint8List.fromList(conv.hex.decode(cleaned));
  }
  try {
    return Uint8List.fromList(base64.decode(cleaned));
  } catch (_) {
    throw ArgumentError("Key is neither valid hex nor base64.");
  }
}

Ed25519KeypairSigner _buildSignerFromKeyMaterial(String keyMaterial) {
  final raw = _decodeHexPreferBase64Fallback(keyMaterial);
  final len = raw.length;

  if (len == 32) {
    final kp = Ed25519Keypair.fromSeed(raw);
    return Ed25519KeypairSigner(kp);
  } else if (len == 64) {
    return Ed25519KeypairSigner.fromKeyRaw(raw);
  } else if (len == 96) {
    final last64 = Uint8List.sublistView(raw, 32, 96);
    return Ed25519KeypairSigner.fromKeyRaw(last64);
  }

  throw ArgumentError(
    "Unexpected private key length: $len bytes. "
    "Expected 32 (seed), 64 (expanded), or 96 (seed||expanded).",
  );
}

Future<int> _fetchKeyPageVersion(ACMEClient client, String keyPageUrl) async {
  final resp = await client.queryUrl(AccURL(keyPageUrl));
  final v = resp['result']?['data']?['version'];
  if (v is int) return v;
  throw StateError("Could not resolve key page version for $keyPageUrl");
}

bool _isBadSignerVersion(Map<String, dynamic> res) {
  try {
    final code = res["result"]?["code"];
    final msg  = res["result"]?["message"]?.toString() ?? "";
    if (code == 1 && msg.contains("badSignerVersion")) return true;

    final list = res["result"]?["result"];
    if (list is List) {
      for (final item in list) {
        final codeStr = item["code"]?.toString() ?? "";
        if (codeStr == "badSignerVersion") return true;
      }
    }
  } catch (_) {}
  return false;
}

/// Submit updateKeyPage with pre-fetch of version and a single retry if needed.
Future<String?> _updateKeyPageWithRetry(
  ACMEClient client,
  String keyPageUrl,
  Ed25519KeypairSigner signer,
  UpdateKeyPageParam params,
) async {
  // 1) Pre-fetch version
  int version = 1;
  try {
    version = await _fetchKeyPageVersion(client, keyPageUrl);
  } catch (e) {
    print("WARN: version fetch failed, defaulting to 1: $e");
  }
  var txSigner = TxSigner(keyPageUrl, signer, version);

  // 2) First attempt
  print("Submitting updateKeyPage (v$version)...");
  var response = await client.updateKeyPage(AccURL.toAccURL(keyPageUrl), params, txSigner);

  // 3) One retry on badSignerVersion
  if (_isBadSignerVersion(response)) {
    print("badSignerVersion detected; re-querying page version and retrying once...");
    final v2 = await _fetchKeyPageVersion(client, keyPageUrl);
    txSigner = TxSigner.withNewVersion(txSigner, v2);
    response = await client.updateKeyPage(AccURL.toAccURL(keyPageUrl), params, txSigner);
  }

  if (response.containsKey('error')) {
    throw StateError("Error updating key page: ${response['error']}");
  }

  final txid = response['result']?['txid']?.toString();
  return txid;
}