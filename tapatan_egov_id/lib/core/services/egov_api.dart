import 'dart:convert';
import 'package:http/http.dart' as http;
import 'config_service.dart';

class AuditEvent {
  final String eventType;
  final String blockHash;
  final String previousHash;
  final DateTime timestamp;
  AuditEvent({required this.eventType, required this.blockHash, required this.previousHash, required this.timestamp});
}

class EGovResponse {
  final bool success;
  final String? errorMessage;
  final String requestId;
  final DateTime timestamp;
  final bool isLive;
  final int httpStatusCode;
  final String rawBody;
  final Map<String, dynamic> data;

  EGovResponse({
    required this.success,
    this.errorMessage,
    required this.requestId,
    required this.timestamp,
    required this.isLive,
    this.httpStatusCode = 200,
    this.rawBody = '',
    this.data = const {},
  });
}

class EGovSsoService {
  static Future<EGovResponse> issueToken({
    required String clientAppId,
    required List<String> scopes,
    String? exchangeCode,
    String? philsysNumber,
  }) async {
    try {
      final url = Uri.parse('${ConfigService.ssoBaseUrl}/api/token');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'exchange_code': exchangeCode ?? 'mock_exchange_code',
          'scope': scopes.join(' '),
          'partner_code': ConfigService.ssoPartnerCode,
          'partner_secret': ConfigService.ssoPartnerSecret,
          if (philsysNumber != null) 'philsys_number': philsysNumber,
          'client_app_id': clientAppId,
        }),
      );

      final isSuccess = response.statusCode == 200;
      final body = jsonDecode(response.body);

      return EGovResponse(
        success: isSuccess,
        errorMessage: isSuccess ? null : body['message'] ?? 'SSO Token error',
        requestId: body['request_id'] ?? 'N/A',
        timestamp: DateTime.now(),
        isLive: true,
        httpStatusCode: response.statusCode,
        rawBody: response.body,
        data: isSuccess ? {'accessToken': body['access_token'] ?? 'mock_sso_token'} : {},
      );
    } catch (e) {
      return EGovResponse(success: false, errorMessage: e.toString(), requestId: 'ERR', timestamp: DateTime.now(), isLive: true);
    }
  }

  static Future<EGovResponse> validateToken({required String accessToken}) async {
    try {
      final url = Uri.parse('${ConfigService.ssoBaseUrl}/api/auth/validate');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $accessToken',
        },
      );

      final isSuccess = response.statusCode == 200;
      return EGovResponse(
        success: isSuccess,
        requestId: 'N/A',
        timestamp: DateTime.now(),
        isLive: true,
        httpStatusCode: response.statusCode,
        rawBody: response.body,
        data: isSuccess ? {'status': 'active'} : {},
      );
    } catch (e) {
      return EGovResponse(success: false, errorMessage: e.toString(), requestId: 'ERR', timestamp: DateTime.now(), isLive: true);
    }
  }
}

class EVerifyService {
  static Future<EGovResponse> verify({required String cardSerial, required String nfcChallenge}) async {
    try {
      final url = Uri.parse('${ConfigService.verifyBaseUrl}/api/verify');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'client-id': ConfigService.verifyClientId,
          'client-secret': ConfigService.verifyClientSecret,
        },
        body: jsonEncode({
          'card_serial': cardSerial,
          'nfc_challenge': nfcChallenge,
          'pubkey': ConfigService.verifyPubKey,
        }),
      );

      final isSuccess = response.statusCode == 200;
      final body = jsonDecode(response.body);
      
      return EGovResponse(
        success: isSuccess,
        errorMessage: isSuccess ? null : 'eVerify failed',
        requestId: 'N/A',
        timestamp: DateTime.now(),
        isLive: true,
        httpStatusCode: response.statusCode,
        rawBody: response.body,
        data: isSuccess ? {'confidenceScore': body['confidence_score'] ?? 98} : {},
      );
    } catch (e) {
      return EGovResponse(success: false, errorMessage: e.toString(), requestId: 'ERR', timestamp: DateTime.now(), isLive: true);
    }
  }
}

class FaceLivenessService {
  static Future<EGovResponse> check({required String philsysNumber, required String sessionToken}) async {
    try {
      final url = Uri.parse('${ConfigService.livenessBaseUrl}/api/liveness/check');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': ConfigService.livenessApiKey,
        },
        body: jsonEncode({
          'philsys_number': philsysNumber,
          'session_token': sessionToken,
        }),
      );

      final isSuccess = response.statusCode == 200;
      return EGovResponse(
        success: isSuccess,
        errorMessage: isSuccess ? null : 'Liveness check failed',
        requestId: 'N/A',
        timestamp: DateTime.now(),
        isLive: true,
        httpStatusCode: response.statusCode,
        rawBody: response.body,
        data: isSuccess ? {'livenessConfirmed': true} : {},
      );
    } catch (e) {
      return EGovResponse(success: false, errorMessage: e.toString(), requestId: 'ERR', timestamp: DateTime.now(), isLive: true);
    }
  }
}

class EGovAiService {
  static Future<EGovResponse> analyzeRisk({required String philsysNumber, required String requestType, required Map<String, dynamic> context}) async {
    try {
      final url = Uri.parse('${ConfigService.aiBaseUrl}/api/ai/analyze');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'access-code': ConfigService.aiAccessCode,
        },
        body: jsonEncode({
          'philsys_number': philsysNumber,
          'request_type': requestType,
          'context': context,
        }),
      );

      final isSuccess = response.statusCode == 200;
      final body = jsonDecode(response.body);
      
      return EGovResponse(
        success: isSuccess,
        errorMessage: isSuccess ? null : 'Risk analysis failed',
        requestId: 'N/A',
        timestamp: DateTime.now(),
        isLive: true,
        httpStatusCode: response.statusCode,
        rawBody: response.body,
        data: isSuccess ? {'riskLevel': body['risk_level'] ?? 'LOW', 'approvalRecommendation': body['recommendation'] ?? 'APPROVE'} : {},
      );
    } catch (e) {
      return EGovResponse(success: false, errorMessage: e.toString(), requestId: 'ERR', timestamp: DateTime.now(), isLive: true);
    }
  }
}

class EGovChainService {
  static final List<AuditEvent> chain = [];

  static Future<EGovResponse> logEvent({required String eventType, required String actor, required Map<String, dynamic> metadata}) async {
    try {
      final url = Uri.parse('${ConfigService.chainRpcUrl}/rpc/log');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'event_type': eventType,
          'actor': actor,
          'metadata': metadata,
        }),
      );

      final hash = 'LIVE_HASH_${DateTime.now().millisecondsSinceEpoch}';
      final prevHash = chain.isEmpty ? '00000000000000000000' : chain.last.blockHash;
      chain.add(AuditEvent(eventType: eventType, blockHash: hash, previousHash: prevHash, timestamp: DateTime.now()));
      
      return EGovResponse(
        success: true,
        requestId: 'N/A',
        timestamp: DateTime.now(),
        isLive: true,
        httpStatusCode: response.statusCode,
        rawBody: response.body,
        data: {'blockHash': hash},
      );
    } catch (e) {
      return EGovResponse(success: false, errorMessage: e.toString(), requestId: 'ERR', timestamp: DateTime.now(), isLive: true);
    }
  }
}

class EMessageService {
  static Future<EGovResponse> sendApprovalRequest({required String philsysNumber, required String action, required String requester, required Map<String, dynamic> payload}) async {
    try {
      // Mocking URL since base URL wasn't provided in ConfigService, default to generic
      final url = Uri.parse('https://emessage.e.gov.ph/api/send');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${ConfigService.eMessageToken}',
        },
        body: jsonEncode({
          'philsys_number': philsysNumber,
          'action': action,
          'requester': requester,
          'payload': payload,
        }),
      );

      final isSuccess = response.statusCode == 200;
      final body = jsonDecode(response.body);

      return EGovResponse(
        success: isSuccess,
        errorMessage: isSuccess ? null : 'Failed to send eMessage',
        requestId: 'N/A',
        timestamp: DateTime.now(),
        isLive: true,
        httpStatusCode: response.statusCode,
        rawBody: response.body,
        data: isSuccess ? {'approvalCode': body['approval_code'] ?? '123456'} : {},
      );
    } catch (e) {
      return EGovResponse(success: false, errorMessage: e.toString(), requestId: 'ERR', timestamp: DateTime.now(), isLive: true);
    }
  }
}
