// C:\Accumulate_Stuff\accumulate-dart-client\example\SDK_Usage_Examples\SDK_Examples_file_5_Query_Tx_Signatures_Memo_Data.dart

import 'dart:convert';
import 'dart:typed_data';
import 'package:accumulate_api/accumulate_api.dart';
import 'package:convert/convert.dart' as conv;

// Your generated/handwritten model
import 'package:accumulate_api/src/model/query_transaction_response_model.dart' as qtrm;

/// Mainnet JSON-RPC endpoint
const String endPoint = "https://mainnet.accumulatenetwork.io/v2";
final ACMEClient client = ACMEClient(endPoint);

/// Put a txid or a tx URL here, or pass as first CLI arg.
const String TX_REF = "acc://0bdb08d8991b1f427f80bba17155b4f9717f8d3ae8f310546682996f7e4aa8c5@0test1test01.acme/tokens";

Future<void> main(List<String> args) async {
  final ref = (args.isNotEmpty ? args.first : TX_REF).trim();
  if (ref.isEmpty || ref.startsWith("<PASTE_")) {
    print("Usage: dart SDK_Examples_file_5_Query_Tx_Signatures_Memo_Data.dart <txid|txUrl>");
    return;
  }

  print("RPC: $endPoint");
  print("Query: $ref");

  try {
    Map<String, dynamic> resp;
    if (ref.startsWith("acc://")) {
      resp = await client.queryTxByUrl(ref);
    } else {
      resp = await client.queryTx(ref);
    }

    try {
      await _printViaModel(resp);
    } catch (e) {
      print("Model parse failed ($e), falling back to raw JSON reader...");
      await _printViaRaw(resp);
    }
  } catch (e) {
    print("Query error: $e");
  }
}

/// ---------- MODEL PATH (preferred) ----------

Future<void> _printViaModel(Map<String, dynamic> resp) async {
  final parsed = qtrm.QueryTransactionResponseModel.fromJson(resp);
  final result = parsed.result;
  if (result == null) {
    print("No result found.");
    print(resp);
    return;
  }

  print("------------------------------------------------------------");
  print("Type: ${result.type}");
  print("Origin: ${result.origin}");
  print("Sponsor: ${result.sponsor}");
  print("TxID: ${result.txid}");
  print("Txn Hash: ${result.transactionHash}");

  // Header memo & metadata (model)
  final hdr = result.transaction?.header;
  print("Header Memo: ${hdr?.memo ?? "<none>"}");

  final metaStr = hdr?.metadata; // base64 or hex string if present
  if (metaStr != null && metaStr.isNotEmpty) {
    final info = _decodeDataString(metaStr);
    print("Header Metadata: ${info.summary}");
    if (info.utf8Preview != null) {
      print('Header Metadata UTF-8 Preview: "${info.utf8Preview}"');
    }
  } else {
    print("Header Metadata: <none>");
  }
  print("------------------------------------------------------------");

  if (result.signatures != null && result.signatures!.isNotEmpty) {
    print("Signatures (top-level): ${result.signatures!.length}");
    for (var i = 0; i < result.signatures!.length; i++) {
      final sig = result.signatures![i];
      _printSigModel(sig, prefix: "  [$i] ");
    }
  } else {
    print("No top-level signatures found.");
  }

  if (result.signatureBooks != null && result.signatureBooks!.isNotEmpty) {
    print("------------------------------------------------------------");
    print("SignatureBooks: ${result.signatureBooks!.length}");
    for (var b = 0; b < result.signatureBooks!.length; b++) {
      final book = result.signatureBooks![b];
      final pages = book.pages ?? const [];
      print(" Book[$b] Authority: ${book.authority} (pages: ${pages.length})");

      for (var p = 0; p < pages.length; p++) {
        final page = pages[p];
        final entries = page.signatures ?? const [];
        print("   Page[$p] Signer: ${page.signer?.url}  (sigs: ${entries.length})");

        for (var s = 0; s < entries.length; s++) {
          final sig = entries[s];
          _printSigModel(sig, prefix: "     [$s] ");
        }
      }
    }
  }

  print("------------------------------------------------------------");
  print("Done.");
}

void _printSigModel(qtrm.Signature sig, {String prefix = ""}) {
  final typ = sig.type ?? "";
  final signer = sig.signer ?? "";
  final sv = sig.signerVersion?.toString() ?? "?";
  final ts = sig.timestamp?.toString() ?? "?";
  final pk = _short(sig.publicKey, 16);
  final sigShort = _short(sig.signature, 16);

  print("${prefix}Type: $typ");
  print("${prefix}Signer: $signer (v$sv)");
  print("${prefix}Timestamp: $ts");
  print("${prefix}PublicKey: $pk");
  print("${prefix}Signature: $sigShort");

  // Signature-level memo/data (will only show if the signature included them)
  print("${prefix}Memo: ${sig.memo ?? "<none>"}");

  if (sig.data != null && sig.data!.isNotEmpty) {
    final info = _decodeDataString(sig.data!);
    print("${prefix}Data: ${info.summary}");
    if (info.utf8Preview != null) {
      print('${prefix}Data UTF-8 Preview: "${info.utf8Preview}"');
    }
  } else {
    print("${prefix}Data: <none>");
  }

  if (sig.transactionHash != null) {
    print("${prefix}TransactionHash (on sig): ${sig.transactionHash}");
  }
  print("${prefix}--------------------------------");
}

/// ---------- RAW PATH (fallback if model fails) ----------

Future<void> _printViaRaw(Map<String, dynamic> resp) async {
  final r = resp["result"] as Map<String, dynamic>?;

  if (r == null) {
    print("No result field in response.");
    print(resp);
    return;
  }

  print("------------------------------------------------------------");
  print("Type: ${r["type"]}");
  print("Origin: ${r["origin"]}");
  print("Sponsor: ${r["sponsor"]}");
  print("TxID: ${r["txid"]}");
  print("Txn Hash: ${r["transactionHash"]}");

  // Header memo & metadata (raw JSON)
  final headerMemo = (r["transaction"]?["header"]?["memo"]);
  print("Header Memo: ${headerMemo ?? "<none>"}");

  final headerMeta = (r["transaction"]?["header"]?["metadata"]);
  if (headerMeta is String && headerMeta.isNotEmpty) {
    final info = _decodeDataString(headerMeta);
    print("Header Metadata: ${info.summary}");
    if (info.utf8Preview != null) {
      print('Header Metadata UTF-8 Preview: "${info.utf8Preview}"');
    }
  } else {
    print("Header Metadata: <none>");
  }
  print("------------------------------------------------------------");

  final sigs = (r["signatures"] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  if (sigs.isNotEmpty) {
    print("Signatures (top-level): ${sigs.length}");
    for (var i = 0; i < sigs.length; i++) {
      _printSigRaw(sigs[i], prefix: "  [$i] ");
    }
  } else {
    print("No top-level signatures found.");
  }

  final books = (r["signatureBooks"] as List?)?.cast<Map<String, dynamic>>() ?? const [];
  if (books.isNotEmpty) {
    print("------------------------------------------------------------");
    print("SignatureBooks: ${books.length}");
    for (var b = 0; b < books.length; b++) {
      final book = books[b];
      final pages = (book["pages"] as List?)?.cast<Map<String, dynamic>>() ?? const [];
      print(" Book[$b] Authority: ${book["authority"]} (pages: ${pages.length})");

      for (var p = 0; p < pages.length; p++) {
        final page = pages[p];
        final signer = (page["signer"] as Map<String, dynamic>?)?["url"];
        final entries = (page["signatures"] as List?)?.cast<Map<String, dynamic>>() ?? const [];
        print("   Page[$p] Signer: $signer (sigs: ${entries.length})");
        for (var s = 0; s < entries.length; s++) {
          _printSigRaw(entries[s], prefix: "     [$s] ");
        }
      }
    }
  }

  print("------------------------------------------------------------");
  print("Done.");
}

void _printSigRaw(Map<String, dynamic> sig, {String prefix = ""}) {
  final typ = (sig["type"] ?? "").toString();
  final signer = (sig["signer"] ?? "").toString();
  final sv = sig["signerVersion"]?.toString() ?? "?";
  final ts = sig["timestamp"]?.toString() ?? "?";
  final pk = _short(sig["publicKey"]?.toString(), 16);
  final sigShort = _short(sig["signature"]?.toString(), 16);

  print("${prefix}Type: $typ");
  print("${prefix}Signer: $signer (v$sv)");
  print("${prefix}Timestamp: $ts");
  print("${prefix}PublicKey: $pk");
  print("${prefix}Signature: $sigShort");

  // Signature-level memo/data (if present)
  print("${prefix}Memo: ${sig["memo"] ?? "<none>"}");

  final dataStr = sig["data"]?.toString();
  if (dataStr != null && dataStr.isNotEmpty) {
    final info = _decodeDataString(dataStr);
    print("${prefix}Data: ${info.summary}");
    if (info.utf8Preview != null) {
      print('${prefix}Data UTF-8 Preview: "${info.utf8Preview}"');
    }
  } else {
    print("${prefix}Data: <none>");
  }

  final th = sig["transactionHash"];
  if (th != null) {
    print("${prefix}TransactionHash (on sig): $th");
  }
  print("${prefix}--------------------------------");
}

/// ---------- utils ----------

_DecodeInfo _decodeDataString(String s) {
  final cleaned = s
      .trim()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceFirst(RegExp(r'^0x', caseSensitive: false), '');

  Uint8List? bytes;

  // Try base64 first
  try {
    bytes = Uint8List.fromList(base64.decode(cleaned));
  } catch (_) {
    // Try hex
    try {
      if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(cleaned) && cleaned.length % 2 == 0) {
        bytes = Uint8List.fromList(conv.hex.decode(cleaned));
      }
    } catch (_) {}
  }

  if (bytes == null) {
    return _DecodeInfo(
      summary: "<raw string, undecodable as base64/hex> len=${s.length}",
      utf8Preview: null,
    );
  }

  final hexPreview = conv.hex.encode(bytes.length > 32 ? bytes.sublist(0, 32) : bytes);
  String? asUtf8;
  try {
    asUtf8 = utf8.decode(bytes);
  } catch (_) {
    asUtf8 = null;
  }

  return _DecodeInfo(
    summary: "bytes=${bytes.length}, hexPreview=${_short(hexPreview, 64)}",
    utf8Preview: asUtf8,
  );
}

class _DecodeInfo {
  final String summary;
  final String? utf8Preview;
  _DecodeInfo({required this.summary, this.utf8Preview});
}

String _short(String? s, int keep) {
  if (s == null) return "<null>";
  if (s.length <= keep) return s;
  return s.substring(0, keep) + "...";
}
