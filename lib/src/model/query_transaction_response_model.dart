// lib/src/model/query_transaction_response_model.dart
import 'dart:convert';

QueryTransactionResponseModel queryTransactionResponseModelFromJson(String str) =>
    QueryTransactionResponseModel.fromJson(json.decode(str));

String queryTransactionResponseModelToJson(QueryTransactionResponseModel data) =>
    json.encode(data.toJson());

class QueryTransactionResponseModel {
  String? jsonrpc;
  QueryTransactionResponseModelResult? result;
  int? id;

  QueryTransactionResponseModel({this.jsonrpc, this.result, this.id});

  factory QueryTransactionResponseModel.fromJson(Map<String, dynamic> json) =>
      QueryTransactionResponseModel(
        jsonrpc: json["jsonrpc"],
        result: json["result"] == null
            ? null
            : QueryTransactionResponseModelResult.fromJson(json["result"]),
        id: json["id"],
      );

  Map<String, dynamic> toJson() => {
        "jsonrpc": jsonrpc,
        "result": result?.toJson(),
        "id": id,
      };
}

class QueryTransactionResponseModelResult {
  String? type;
  Data? data;
  String? origin;
  String? sponsor;
  String? transactionHash;
  String? txid;
  Transaction? transaction;
  List<Signature>? signatures;
  Status? status;
  List<String>? syntheticTxids;
  List<SignatureBook>? signatureBooks;

  QueryTransactionResponseModelResult({
    this.type,
    this.data,
    this.origin,
    this.sponsor,
    this.transactionHash,
    this.txid,
    this.transaction,
    this.signatures,
    this.status,
    this.syntheticTxids,
    this.signatureBooks,
  });

  factory QueryTransactionResponseModelResult.fromJson(Map<String, dynamic> json) =>
      QueryTransactionResponseModelResult(
        type: json["type"],
        data: json["data"] == null ? null : Data.fromJson(json["data"]),
        origin: json["origin"],
        sponsor: json["sponsor"],
        transactionHash: json["transactionHash"],
        txid: json["txid"],
        transaction: json["transaction"] == null
            ? null
            : Transaction.fromJson(json["transaction"]),
        signatures: (json["signatures"] as List?)
                ?.map((x) => Signature.fromJson(x))
                .toList() ??
            [],
        status: json["status"] == null ? null : Status.fromJson(json["status"]),
        syntheticTxids:
            (json["syntheticTxids"] as List?)?.map((x) => x.toString()).toList() ?? [],
        signatureBooks: (json["signatureBooks"] as List?)
                ?.map((x) => SignatureBook.fromJson(x))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        "type": type,
        "data": data?.toJson(),
        "origin": origin,
        "sponsor": sponsor,
        "transactionHash": transactionHash,
        "txid": txid,
        "transaction": transaction?.toJson(),
        "signatures": signatures?.map((x) => x.toJson()).toList(),
        "status": status?.toJson(),
        "syntheticTxids": syntheticTxids,
        "signatureBooks": signatureBooks?.map((x) => x.toJson()).toList(),
      };
}

class Data {
  String? type;
  String? url;

  Data({this.type, this.url});

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        type: json["type"],
        url: json["url"],
      );

  Map<String, dynamic> toJson() => {
        "type": type,
        "url": url,
      };
}

class SignatureBook {
  String? authority;
  List<Page>? pages;

  SignatureBook({this.authority, this.pages});

  factory SignatureBook.fromJson(Map<String, dynamic> json) => SignatureBook(
        authority: json["authority"],
        pages: (json["pages"] as List?)
                ?.map((x) => Page.fromJson(x))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        "authority": authority,
        "pages": pages?.map((x) => x.toJson()).toList(),
      };
}

class Page {
  Data? signer;
  List<Signature>? signatures;

  Page({this.signer, this.signatures});

  factory Page.fromJson(Map<String, dynamic> json) => Page(
        signer: json["signer"] == null ? null : Data.fromJson(json["signer"]),
        signatures: (json["signatures"] as List?)
                ?.map((x) => Signature.fromJson(x))
                .toList() ??
            [],
      );

  Map<String, dynamic> toJson() => {
        "signer": signer?.toJson(),
        "signatures": signatures?.map((x) => x.toJson()).toList(),
      };
}

class Signature {
  String? type;
  String? publicKey;
  String? signature;
  String? signer;
  int? signerVersion;
  double? timestamp;        // Kept as double to match your current prints
  String? transactionHash;

  // ✅ Signature-level optional fields
  String? memo;             // UTF-8 text (if present in RPC JSON)
  String? data;             // Encoded bytes (base64/hex as string in RPC JSON)

  Signature({
    this.type,
    this.publicKey,
    this.signature,
    this.signer,
    this.signerVersion,
    this.timestamp,
    this.transactionHash,
    this.memo,
    this.data,
  });

  factory Signature.fromJson(Map<String, dynamic> json) => Signature(
        type: json["type"],
        publicKey: json["publicKey"],
        signature: json["signature"],
        signer: json["signer"],
        signerVersion: (json["signerVersion"] as num?)?.toInt(),
        timestamp: (json["timestamp"] as num?)?.toDouble(),
        transactionHash: json["transactionHash"],
        memo: json["memo"],
        data: json["data"],
      );

  Map<String, dynamic> toJson() => {
        "type": type,
        "publicKey": publicKey,
        "signature": signature,
        "signer": signer,
        "signerVersion": signerVersion,
        "timestamp": timestamp,
        "transactionHash": transactionHash,
        "memo": memo,
        "data": data,
      };
}

class Status {
  bool? delivered;
  bool? failed;
  StatusResult? result;
  String? initiator;
  List<Signer>? signers;

  Status({this.delivered, this.failed, this.result, this.initiator, this.signers});

  factory Status.fromJson(Map<String, dynamic> json) => Status(
        delivered: json["delivered"],
        failed: json["failed"],
        result: json["result"] == null ? null : StatusResult.fromJson(json["result"]),
        initiator: json["initiator"],
        signers:
            (json["signers"] as List?)?.map((x) => Signer.fromJson(x)).toList() ?? [],
      );

  Map<String, dynamic> toJson() => {
        "delivered": delivered,
        "failed": failed,
        "result": result?.toJson(),
        "initiator": initiator,
        "signers": signers?.map((x) => x.toJson()).toList(),
      };
}

class StatusResult {
  String? type;

  StatusResult({this.type});

  factory StatusResult.fromJson(Map<String, dynamic> json) => StatusResult(
        type: json["type"],
      );

  Map<String, dynamic> toJson() => {
        "type": type,
      };
}

class Signer {
  String? type;
  String? url;
  double? lastUsedOn;   // preserved type to avoid downstream changes
  double? nonce;

  Signer({this.type, this.url, this.lastUsedOn, this.nonce});

  factory Signer.fromJson(Map<String, dynamic> json) => Signer(
        type: json["type"],
        url: json["url"],
        lastUsedOn: (json["lastUsedOn"] as num?)?.toDouble(),
        nonce: (json["nonce"] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        "type": type,
        "url": url,
        "lastUsedOn": lastUsedOn,
        "nonce": nonce,
      };
}

class Transaction {
  Header? header;
  Data? body;

  Transaction({this.header, this.body});

  factory Transaction.fromJson(Map<String, dynamic> json) => Transaction(
        header: json["header"] == null ? null : Header.fromJson(json["header"]),
        body: json["body"] == null ? null : Data.fromJson(json["body"]),
      );

  Map<String, dynamic> toJson() => {
        "header": header?.toJson(),
        "body": body?.toJson(),
      };
}

/// ✅ Transaction header with memo + optional metadata
class Header {
  String? principal;
  String? origin;
  String? initiator;
  String? memo;       // TX-level memo (string)
  String? metadata;   // Optional binary as base64/hex string in RPC JSON

  Header({
    this.principal,
    this.origin,
    this.initiator,
    this.memo,
    this.metadata,
  });

  factory Header.fromJson(Map<String, dynamic> json) => Header(
        principal: json["principal"],
        origin: json["origin"],
        initiator: json["initiator"],
        memo: json["memo"],
        metadata: json["metadata"],
      );

  Map<String, dynamic> toJson() => {
        "principal": principal,
        "origin": origin,
        "initiator": initiator,
        if (memo != null) "memo": memo,
        if (metadata != null) "metadata": metadata,
      };
}
