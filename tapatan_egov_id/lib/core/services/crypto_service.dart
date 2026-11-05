import 'dart:convert';
import 'dart:async';

class CryptoService {
  Future<String> signDocument(String documentHash) async {
    // Simulate PKCS#1/#7 hash signing delay
    await Future.delayed(const Duration(milliseconds: 1500));
    
    // Create a mock signature using base64 encoding of the hash + mock key
    final mockSignatureData = 'signed_with_egov_private_key_$documentHash';
    return base64Encode(utf8.encode(mockSignatureData));
  }

  Future<bool> verifySignature(String documentHash, String signature) async {
    // Simulate verification delay
    await Future.delayed(const Duration(milliseconds: 800));
    
    try {
      final decoded = utf8.decode(base64Decode(signature));
      return decoded == 'signed_with_egov_private_key_$documentHash';
    } catch (e) {
      return false;
    }
  }
}
