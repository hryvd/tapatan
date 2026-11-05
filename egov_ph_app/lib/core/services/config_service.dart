import 'package:shared_preferences/shared_preferences.dart';

class ConfigService {
  static const String _keySsoBaseUrl = 'cfg_sso_base_url';
  static const String _keySsoPartnerCode = 'cfg_sso_partner_code';
  static const String _keySsoPartnerSecret = 'cfg_sso_partner_secret';

  static const String _keyVerifyBaseUrl = 'cfg_verify_base_url';
  static const String _keyVerifyClientId = 'cfg_verify_client_id';
  static const String _keyVerifyClientSecret = 'cfg_verify_client_secret';

  static const String _keyAiBaseUrl = 'cfg_ai_base_url';
  static const String _keyAiAccessCode = 'cfg_ai_access_code';

  static const String _keyLivenessBaseUrl = 'cfg_liveness_base_url';
  static const String _keyLivenessApiKey = 'cfg_liveness_api_key';

  static const String _keyChainRpcUrl = 'cfg_chain_rpc_url';

  static late SharedPreferences _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // Getters with default values
  static String get ssoBaseUrl => _prefs.getString(_keySsoBaseUrl) ?? 'https://stg-superapp-sso.oueg.info';
  static String get ssoPartnerCode => _prefs.getString(_keySsoPartnerCode) ?? 'HACKATHON_SSO';
  static String get ssoPartnerSecret => _prefs.getString(_keySsoPartnerSecret) ?? '0d77fba530ee49f5b00e36fe947bd384';

  static String get verifyBaseUrl => _prefs.getString(_keyVerifyBaseUrl) ?? 'https://verify.e.gov.ph';
  static String get verifyClientId => _prefs.getString(_keyVerifyClientId) ?? 'a24bef86-8826-48f7-aac5-978ca5805c29';
  static String get verifyClientSecret => _prefs.getString(_keyVerifyClientSecret) ?? '1EQT3mEC8GqEYCcUufaylPewnWi052VcJdnAOmIPHFy5zbUv0JcqVEwf7DSeb1OB';
  static String get verifyPubKey => 'eyJpdiI6InAzOGc3d1BZcVVZck1IY3plS0xscVE9PSIsInZhbHVlIjoiSlRESmdFYkZ4ZnV3M1ZkUjFiTHpDUT09IiwibWFjIjoiZTEzZjI5ZGRkZTVhNWNkNGU3ZmQ0NDY4MTAyZDY2Yjc1NjJiYmMxNTMwN2E2NzVlZmM5ZjhjZmEyZWM1ZmMwMCIsInRhZyI6IiJ9';

  static String get aiBaseUrl => _prefs.getString(_keyAiBaseUrl) ?? 'https://ai.e.gov.ph';
  static String get aiAccessCode => _prefs.getString(_keyAiAccessCode) ?? 'f2c81ce889a5850fd59487ce988ec1324183682c62d300bdbd33d5064862942b';

  static String get livenessBaseUrl => _prefs.getString(_keyLivenessBaseUrl) ?? 'https://hackathon-face-liveness.e.gov.ph';
  static String get livenessApiKey => _prefs.getString(_keyLivenessApiKey) ?? '9e31b23d-eeb4-ae08-ff13-cdf8380e5307';

  static String get eMessageToken => '40419e47290ae8488a0a796b7c4c66aa';
  static String get eGovPayApiKey => 'test_bcc2092263e426957841fb633d09ec8b38b865929f2d3cb75d71f18469862885';
  static String get eReportToken => 'ce8691fdca4e8365f2c9ec6279e3558c7e9b6387b0c5e986147e436aebeb4705';
  static String get compassApiKey => 'dbm_live_571ba033e980281325557042746ca1c82fca5de2350e6c6c';

  static String get chainRpcUrl => _prefs.getString(_keyChainRpcUrl) ?? 'https://hackathon-blockchain.e.gov.ph';

  // Setters
  static Future<void> setSsoConfig(String url, String code, String secret) async {
    await _prefs.setString(_keySsoBaseUrl, url);
    await _prefs.setString(_keySsoPartnerCode, code);
    await _prefs.setString(_keySsoPartnerSecret, secret);
  }

  static Future<void> setVerifyConfig(String url, String clientId, String secret) async {
    await _prefs.setString(_keyVerifyBaseUrl, url);
    await _prefs.setString(_keyVerifyClientId, clientId);
    await _prefs.setString(_keyVerifyClientSecret, secret);
  }

  static Future<void> setAiConfig(String url, String accessCode) async {
    await _prefs.setString(_keyAiBaseUrl, url);
    await _prefs.setString(_keyAiAccessCode, accessCode);
  }

  static Future<void> setLivenessConfig(String url, String apiKey) async {
    await _prefs.setString(_keyLivenessBaseUrl, url);
    await _prefs.setString(_keyLivenessApiKey, apiKey);
  }

  static Future<void> setChainRpcUrl(String url) async {
    await _prefs.setString(_keyChainRpcUrl, url);
  }
}
