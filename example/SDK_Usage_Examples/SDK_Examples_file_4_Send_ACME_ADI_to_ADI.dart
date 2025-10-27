// C:\Accumulate_Stuff\accumulate-dart-client\example\SDK_Usage_Examples\SDK_Examples_file_4_Send_ACME_ADI_to_ADI.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:convert/convert.dart' as conv;
import 'package:accumulate_api/accumulate_api.dart';

/// Mainnet JSON-RPC endpoint
const String endPoint = "https://mainnet.accumulatenetwork.io/v2";
final ACMEClient client = ACMEClient(endPoint);

/// Your ADI token accounts
const String fromAccount = "acc://0test1test01.acme/tokens";
const String toAccount   = "acc://0test1test01.acme/staking";

/// Key page with send authority over `fromAccount`
/// If your book is actually "booke", change to ".../booke/1"
const String keyPageUrl  = "acc://0test1test01.acme/book/1";

/// Paste your Ed25519 secret key here:
/// - HEX 128 chars = 64 bytes (priv32||pub32)  -> uses fromKeyRaw
/// - HEX 64  chars = 32 bytes (seed)           -> uses fromSeed
/// - BASE64 variants supported too
//const String PRIVATE_KEY_MATERIAL = "<PASTE_HEX_OR_BASE64_SECRET>";

const String PRIVATE_KEY_MATERIAL = "e81b0bb64ab68b5af018eef638661f50afc72dc16816f859c095c2c8a0b58c7b";

/// --- New: test signature metadata to attach ---
const String TEST_SIG_MEMO = "Test Signature Memo";
final Uint8List TEST_SIG_DATA = Uint8List.fromList(utf8.encode("Example binary payload"));

/// Wrapper that attaches memo/data to the produced Signature.
/// NOTE: This sets fields *after* calling the base sign(). If your SDK’s signing
/// hash needs to include memo/data (Go behavior), update TxSigner/signing hash
/// implementation accordingly so these fields are included in the preimage.
class TxSignerWithMeta extends TxSigner {
  final String? memo;
  final Uint8List? data;

  TxSignerWithMeta(
    dynamic url,
    Signer signer,
    int version, {
    this.memo,
    this.data,
  }) : super(url, signer, version);

  static TxSignerWithMeta withNewVersion(TxSignerWithMeta s, int version) {
    return TxSignerWithMeta(
      s.info.url.toString(),
      s.signer,
      version,
      memo: s.memo,
      data: s.data,
    );
  }

  @override
  Signature sign(Transaction tx) {
    final sig = super.sign(tx);
    // These require your Signature class to have these fields:
    //   String? memo;
    //   Uint8List? data;
    sig.memo = memo;
    sig.data = data;
    return sig;
  }
}

Future<void> main() async {
  print("RPC: $endPoint");
  print("From: $fromAccount");
  print("To  : $toAccount");

  if (PRIVATE_KEY_MATERIAL.startsWith("<PASTE_") || PRIVATE_KEY_MATERIAL.isEmpty) {
    throw ArgumentError("Set PRIVATE_KEY_MATERIAL to your signer’s secret key (hex/base64).");
  }

  try {
    // 1) Build signer
    final signer = _buildSignerFromKeyMaterial(PRIVATE_KEY_MATERIAL);

    // 2) Resolve current key page version
    final initVersion = await _fetchKeyPageVersion(keyPageUrl);

    // 3) Build TxSigner with memo/data attachment
    var txSigner = TxSignerWithMeta(
      keyPageUrl,
      signer,
      initVersion,
      memo: TEST_SIG_MEMO,
      data: TEST_SIG_DATA,
    );

    // 1 ACME = 300,000,000 sub-units (8 decimals)
    const int amountSubUnits = 100000000;

    final params = SendTokensParam()
      ..to = [
        TokenRecipientParam()
          ..url = toAccount
          ..amount = amountSubUnits
      ]
      ..memo = "Move 3 ACME from tokens -> staking";

    // 4) Submit (with one-time auto-retry if version raced)
    var res = await client.sendTokens(fromAccount, params, txSigner);
    if (_isBadSignerVersion(res)) {
      // Re-fetch version and retry once
      final v2 = await _fetchKeyPageVersion(keyPageUrl);
      txSigner = TxSignerWithMeta.withNewVersion(txSigner, v2);
      res = await client.sendTokens(fromAccount, params, txSigner);
    }

    print("sendTokens submitted: $res");

    // Optional: query the tx after a short delay (only if accepted)
    final txId = res["result"]?["txid"];
    if (txId is String && txId.isNotEmpty && !_isBadSignerVersion(res)) {
      await Future.delayed(const Duration(seconds: 5));
      final q = await client.queryTx(txId);
      print("queryTx: $q");

      // If your query models added `memo` and `data` to Signature, you’ll see them in q["result"]["signatures"][...]
    }
  } catch (e) {
    print("Error during transfer: $e");
  }
}

/// --- Helpers ---

/// Detect a badSignerVersion response (supports both error formats)
bool _isBadSignerVersion(Map<String, dynamic> res) {
  try {
    final code = res["result"]?["code"];
    final msg  = res["result"]?["message"]?.toString() ?? "";
    if (code == 1 && msg.contains("badSignerVersion")) return true;

    final resultList = res["result"]?["result"];
    if (resultList is List) {
      for (final item in resultList) {
        final codeStr = item["code"]?.toString() ?? "";
        if (codeStr == "badSignerVersion") return true;
      }
    }
  } catch (_) {}
  return false;
}

/// Query the key page and return its current version.
Future<int> _fetchKeyPageVersion(String kpUrl) async {
  final resp = await client.queryUrl(AccURL(kpUrl));
  final v = resp["result"]?["data"]?["version"];
  if (v is int) return v;
  throw StateError("Could not resolve key page version for $kpUrl");
}

/// Build signer from hex/base64 key material.
///
/// Length handling:
/// - 32 bytes -> SEED (Ed25519Keypair.fromSeed)
/// - 64 bytes -> expanded private (priv||pub) -> fromKeyRaw(64B)
/// - 96 bytes -> (seed||expanded) -> take LAST 64 and fromKeyRaw
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
    "Expected 32 (seed), 64 (expanded), or 96 (seed||expanded)."
  );
}

/// Prefer HEX if the string matches pure hex; otherwise try base64.
/// This avoids mis-decoding 128-hex as base64 (which yields 96 bytes).
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

  // Not hex -> try base64
  try {
    return Uint8List.fromList(base64.decode(cleaned));
  } catch (_) {
    throw ArgumentError("Key is neither valid hex nor base64.");
  }
}
