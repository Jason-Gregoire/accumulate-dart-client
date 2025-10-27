// Setup DID Infrastructure using Dart Client
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:hex/hex.dart';

// Import the accumulate API
import 'package:accumulate_api/accumulate_api.dart';

// Point to our local devnet
final endPoint = "http://localhost:26660/v2";
ACMEClient client = ACMEClient(endPoint);
int delayBeforePrintSeconds = 30; // Give devnet time to process/settle

Future<void> main() async {
  print("=== Setting up DID Infrastructure on Local Devnet ===");
  print("Endpoint: $endPoint");
  await setupCompleteInfrastructure();
}

Future<void> delayBeforePrint() async {
  await Future.delayed(Duration(seconds: delayBeforePrintSeconds));
}

Future<void> setupCompleteInfrastructure() async {
  print("\n--- Step 1: Generate Keypairs ---");

  // Generate consistent keypair for testing
  Ed25519KeypairSigner liteSigner = Ed25519KeypairSigner.generate();
  LiteIdentity lid = LiteIdentity(liteSigner);
  print("Lite Identity URL: ${lid.url}");
  print("Lite Token Account: ${lid.acmeTokenAccount}");
  printKeypairDetails(liteSigner);

  Ed25519KeypairSigner adiSigner = Ed25519KeypairSigner.generate();
  print("\nADI Signer:");
  printKeypairDetails(adiSigner);

  print("\n--- Step 2: Fund Lite Account ---");
  await addFundsToAccount(lid.acmeTokenAccount, times: 5);

  print("\n--- Step 3: Get Oracle Value ---");
  final oracle = await client.valueFromOracle();
  print("Oracle value: $oracle");

  print("\n--- Step 4: Add Credits to Lite Identity ---");
  await addCredits(lid, 2000000, oracle); // 2M credits

  print("\n--- Step 5: Create ADI ---");
  String adiName = "did-test-adi-${DateTime.now().millisecondsSinceEpoch}";
  await createAdi(lid, adiSigner, adiName);

  print("\n--- Step 6: Add Credits to ADI Key Page ---");
  String keyPageUrl = "acc://$adiName.acme/book/1";
  print("Key Page URL: $keyPageUrl");
  await addCreditsToAdiKeyPage(lid, keyPageUrl, 1000000, oracle); // 1M credits

  await delayBeforePrint(); // Let credits settle

  print("\n--- Step 7: Create Data Account ---");
  String identityUrl = "acc://$adiName.acme";
  String dataAccountUrl = "$identityUrl/did-storage";
  await createAdiDataAccount(adiSigner, identityUrl, keyPageUrl, dataAccountUrl);

  await delayBeforePrint(); // Let data account creation settle

  print("\n--- Step 8: Write Sample DID Document ---");
  await writeDidDocument(adiSigner, keyPageUrl, dataAccountUrl);

  print("\n=== Infrastructure Setup Complete! ===");
  print("ADI Name: $adiName");
  print("ADI URL: $identityUrl");
  print("Data Account: $dataAccountUrl");
  print("Key Page: $keyPageUrl");
  print("\nYou can now test DID creation with the registrar!");
}

Future<void> addFundsToAccount(AccURL accountUrl, {int times = 5}) async {
  print("Adding funds to: $accountUrl");
  for (int i = 0; i < times; i++) {
    await client.faucet(accountUrl);
    await Future.delayed(Duration(seconds: 2));
    print("Faucet call ${i + 1}/$times completed");
  }
}

Future<void> addCredits(LiteIdentity lid, int creditAmount, int oracle) async {
  AddCreditsParam addCreditsParam = AddCreditsParam();
  addCreditsParam.recipient = lid.url;
  addCreditsParam.amount = (creditAmount * pow(10, 8).toInt()) ~/ oracle;
  addCreditsParam.oracle = oracle;
  addCreditsParam.memo = "Credits for DID infrastructure";

  print("Adding $creditAmount credits to ${lid.url}");
  print("ACME amount: ${addCreditsParam.amount}");

  var res = await client.addCredits(lid.acmeTokenAccount, addCreditsParam, lid);
  print("addCredits response: $res");

  if (res["result"] != null && res["result"]["txid"] != null) {
    String txId = res["result"]["txid"];
    print("Transaction ID: $txId");
    await delayBeforePrint();

    res = await client.queryTx(txId);
    print("Transaction confirmed: ${res["result"]?["status"]}");
  }
}

Future<void> createAdi(LiteIdentity lid, Ed25519KeypairSigner adiSigner, String adiName) async {
  final String identityUrl = "acc://$adiName.acme";
  final String bookUrl = "$identityUrl/book";

  CreateIdentityParam createIdentityParam = CreateIdentityParam();
  createIdentityParam.url = identityUrl;
  createIdentityParam.keyBookUrl = bookUrl;
  createIdentityParam.keyHash = adiSigner.publicKeyHash();

  print("Creating ADI: $identityUrl");
  print("Key Book: $bookUrl");

  try {
    var response = await client.createIdentity(lid.url, createIdentityParam, lid);
    var txId = response["result"]["txid"];
    print("Create ADI response: $response");
    print("Transaction ID: $txId");

    await delayBeforePrint();
    var txStatus = await client.queryTx(txId);
    print("ADI creation confirmed: ${txStatus["result"]?["status"]}");
  } catch (e) {
    print("Error creating ADI: $e");
  }
}

Future<void> addCreditsToAdiKeyPage(LiteIdentity lid, String keyPageUrl, int creditAmount, int oracle) async {
  AddCreditsParam addCreditsParam = AddCreditsParam();
  addCreditsParam.recipient = keyPageUrl;
  addCreditsParam.amount = (creditAmount * pow(10, 8).toInt()) ~/ oracle;
  addCreditsParam.oracle = oracle;

  print("Adding $creditAmount credits to ADI key page: $keyPageUrl");
  print("ACME amount: ${addCreditsParam.amount}");

  var res = await client.addCredits(lid.acmeTokenAccount, addCreditsParam, lid);
  print("addCredits to key page response: $res");

  if (res["result"] != null && res["result"]["txid"] != null) {
    String txId = res["result"]["txid"];
    await delayBeforePrint();
    var txStatus = await client.queryTx(txId);
    print("Key page credits confirmed: ${txStatus["result"]?["status"]}");
  }
}

Future<void> createAdiDataAccount(Ed25519KeypairSigner adiSigner, String identityUrl, String keyPageUrl, String dataAccountUrl) async {
  CreateDataAccountParam dataAccountParams = CreateDataAccountParam();
  dataAccountParams.url = dataAccountUrl;
  TxSigner txSigner = TxSigner(keyPageUrl, adiSigner);

  print("Creating data account: $dataAccountUrl");

  var res = await client.createDataAccount(identityUrl, dataAccountParams, txSigner);
  print("Create data account response: $res");
}

Future<void> writeDidDocument(Ed25519KeypairSigner adiSigner, String keyPageUrl, String dataAccountUrl) async {
  // Extract ADI name from data account URL for proper DID formation
  String adiName = dataAccountUrl.split('/')[2]; // Extract from acc://adi-name.acme/did-storage

  // Create Lattica DID with multiple format examples
  String latticaDID = "did:lattica:$adiName";
  String accAliasDID = "did:acc:$adiName";  // Accumulate alias
  String ethAliasDID = "did:eth:test-sample-did";  // Ethereum alias example
  String btcAliasDID = "did:btc:test-sample-did";  // Bitcoin alias example

  // Create comprehensive DID document with Universal Lattica format
  Map<String, dynamic> didDocument = {
    "@context": [
      "https://www.w3.org/ns/did/v1",
      "https://w3id.org/security/suites/ed25519-2020/v1"
    ],
    "id": latticaDID,
    "alsoKnownAs": [
      accAliasDID,    // Accumulate ecosystem alias
      ethAliasDID,    // Ethereum ecosystem alias
      btcAliasDID,    // Bitcoin ecosystem alias
    ],
    "verificationMethod": [
      // Universal Accumulate verification methods (always present)
      {
        "id": "$latticaDID#keybook",
        "type": "AccumulateKeyBook2024",
        "controller": latticaDID,
        "accumulateKeyBookUrl": "acc://$adiName/book"
      },
      {
        "id": "$latticaDID#keypage-1",
        "type": "AccumulateKeyPage2024",
        "controller": latticaDID,
        "accumulateKeyPageUrl": "$keyPageUrl"
      },
      // Static key for backward compatibility and external chain integration
      {
        "id": "$latticaDID#ed25519-key",
        "type": "Ed25519VerificationKey2020",
        "controller": latticaDID,
        "publicKeyHex": HEX.encode(adiSigner.publicKey())
      }
    ],
    "authentication": [
      "$latticaDID#keybook",
      "$latticaDID#keypage-1"
    ],
    "assertionMethod": [
      "$latticaDID#keypage-1",
      "$latticaDID#ed25519-key"
    ],
    "capabilityDelegation": ["$latticaDID#keybook"],
    "capabilityInvocation": [
      "$latticaDID#keybook",
      "$latticaDID#keypage-1"
    ],
    "service": [
      {
        "id": "$latticaDID#accumulate-data",
        "type": "AccumulateDataService",
        "serviceEndpoint": dataAccountUrl
      },
      {
        "id": "$latticaDID#messaging",
        "type": "MessagingService",
        "serviceEndpoint": {
          "uri": "https://messaging.example.com",
          "accept": ["didcomm/v2", "didcomm/v1"],
          "routingKeys": []
        }
      }
    ]
  };

  String didDocumentJson = json.encode(didDocument);
  List<Uint8List> dataEntries = [
    utf8.encode("DID Document").asUint8List(),
    utf8.encode(didDocumentJson).asUint8List(),
  ];

  WriteDataParam writeDataParam = WriteDataParam()
    ..data = dataEntries
    ..scratch = false
    ..writeToState = true;

  TxSigner txSigner = TxSigner(keyPageUrl, adiSigner);

  // Check key page version
  var r = await client.queryUrl(txSigner.url);
  txSigner = TxSigner.withNewVersion(txSigner, r["result"]["data"]["version"]);

  print("Writing DID document to: $dataAccountUrl");
  print("Primary DID: $latticaDID");
  print("Accumulate Alias: $accAliasDID");
  print("External Chain Aliases: $ethAliasDID, $btcAliasDID");
  print("DID Document: $didDocumentJson");

  try {
    var res = await client.writeData(dataAccountUrl, writeDataParam, txSigner);
    print("Write DID document response: $res");
  } catch (error) {
    print("Error writing DID document: $error");
  }
}

void printKeypairDetails(Ed25519KeypairSigner signer) {
  String publicKeyHex = HEX.encode(signer.publicKey());
  String privateKeyHex = HEX.encode(signer.secretKey());
  String mnemonic = signer.mnemonic();

  print("Public Key: $publicKeyHex");
  print("Private Key: $privateKeyHex");
  print("Mnemonic: $mnemonic");
}