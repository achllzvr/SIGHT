import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lumi/services/auth_session_service.dart';
import 'connectivity_service.dart';
import 'api_client_service.dart';
import 'api_config_service.dart';

class GuardianAccount {
  final String email;
  final String passwordHash;
  final DateTime createdAt;
  final bool isEmailVerified;

  const GuardianAccount({
    required this.email, required this.passwordHash,
    required this.createdAt, required this.isEmailVerified,
  });

  Map<String, dynamic> toJson() => {
    'email': email, 'passwordHash': passwordHash,
    'createdAt': createdAt.toIso8601String(), 'isEmailVerified': isEmailVerified,
  };

  factory GuardianAccount.fromJson(Map<String, dynamic> json) => GuardianAccount(
    email: (json['email'] as String? ?? '').toLowerCase(),
    passwordHash: json['passwordHash'] as String? ?? '',
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    isEmailVerified: json['isEmailVerified'] as bool? ?? false,
  );
}

class ChildAccount {
  final String loginCode;
  final String displayName;
  final String passwordHash;
  final String guardianEmail;
  final int? childId;
  final DateTime createdAt;
  final DateTime? birthdate;

  const ChildAccount({
    required this.loginCode, required this.displayName, required this.passwordHash,
    required this.guardianEmail, required this.childId, required this.createdAt, this.birthdate,
  });

  Map<String, dynamic> toJson() => {
    'loginCode': loginCode, 'displayName': displayName, 'passwordHash': passwordHash,
    'guardianEmail': guardianEmail, 'childId': childId,
    'createdAt': createdAt.toIso8601String(), 'birthdate': birthdate?.toIso8601String(),
  };

  factory ChildAccount.fromJson(Map<String, dynamic> json) => ChildAccount(
    loginCode: (json['loginCode'] as String? ?? '').toUpperCase(),
    displayName: json['displayName'] as String? ?? 'Child',
    passwordHash: json['passwordHash'] as String? ?? '',
    guardianEmail: (json['guardianEmail'] as String? ?? '').toLowerCase(),
    childId: (json['childId'] as num?)?.toInt(),
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    birthdate: json['birthdate'] != null ? DateTime.tryParse(json['birthdate'] as String) : null,
  );
}

class AccountActionResult {
  final bool success;
  final String message;
  const AccountActionResult({required this.success, required this.message});
}

class ChildAccountCreationResult extends AccountActionResult {
  final ChildAccount? account;
  const ChildAccountCreationResult({required super.success, required super.message, this.account});
}

class AuthAccountService {
  AuthAccountService._private();
  static final AuthAccountService instance = AuthAccountService._private();

  static const _guardianAccountsKey = 'guardian_accounts_v1';
  static const _childAccountsKey = 'child_accounts_v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  String _hashPassword(String value) => sha256.convert(utf8.encode(value)).toString();

  Future<List<GuardianAccount>> _loadGuardianAccounts() async {
    final raw = await _storage.read(key: _guardianAccountsKey);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List).whereType<Map<String, dynamic>>().map(GuardianAccount.fromJson).toList();
  }

  Future<void> _saveGuardianAccounts(List<GuardianAccount> accounts) async {
    await _storage.write(key: _guardianAccountsKey, value: jsonEncode(accounts.map((e) => e.toJson()).toList()));
  }

  Future<List<ChildAccount>> _loadChildAccounts() async {
    final raw = await _storage.read(key: _childAccountsKey);
    if (raw == null || raw.isEmpty) return [];
    return (jsonDecode(raw) as List).whereType<Map<String, dynamic>>().map(ChildAccount.fromJson).toList();
  }

  Future<void> _saveChildAccounts(List<ChildAccount> accounts) async {
    await _storage.write(key: _childAccountsKey, value: jsonEncode(accounts.map((e) => e.toJson()).toList()));
  }

  // --- PARENT ACCOUNT CREATION (ONLINE ONLY) ---
  Future<AccountActionResult> registerGuardian({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    List<int> documentIds = const [],
  }) async {
    if (!await ConnectivityService.instance.isOnline()) {
      return const AccountActionResult(success: false, message: 'Internet connection required to create a Parent account.');
    }
    if (documentIds.isEmpty) {
      return const AccountActionResult(success: false, message: 'You must accept the Terms & Privacy Policy first.');
    }
    
    final normalizedEmail = email.trim().toLowerCase();
    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.registerGuardianEndpoint);
      final response = await ApiClientService.instance.post(uri, jsonBody: {
          'first_name': firstName.trim(), 'last_name': lastName.trim(),
          'email': normalizedEmail, 'password': password,
          // Only forward cloud document IDs; bundled fallbacks use negative IDs.
          'document_ids': documentIds.where((id) => id > 0).toList(),
      });

      if (!response.isSuccess) {
        debugPrint('registerGuardian failed (${response.statusCode}): ${response.rawBody}');
        return AccountActionResult(
          success: false,
          message: _friendlyErrorMessage(
            response,
            fallback: 'Could not create account. Please try again.',
          ),
        );
      }

      final accounts = await _loadGuardianAccounts();
      accounts.add(GuardianAccount(email: normalizedEmail, passwordHash: _hashPassword(password), createdAt: DateTime.now(), isEmailVerified: false));
      await _saveGuardianAccounts(accounts);
      
      return const AccountActionResult(success: true, message: 'Guardian account created successfully.');
    } catch (e) {
      return AccountActionResult(success: false, message: _friendlyException(e));
    }
  }

  // STRICT ONLINE AUTHENTICATION
  Future<bool> authenticateGuardian({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    
    if (!await ConnectivityService.instance.isOnline()) {
      throw Exception('Internet connection is required to login as a Guardian.');
    }

    final uri = ApiConfigService.buildUri('/api/shared/login');
    final response = await ApiClientService.instance.post(uri, jsonBody: {'email': normalizedEmail, 'password': password});
    
    if (response.isSuccess) {
      final token = response.data['token'];
      if (token != null && token.isNotEmpty) {
        await AuthSessionService.instance.saveAccessToken(token);
      }

      final accounts = await _loadGuardianAccounts();
      if (!accounts.any((a) => a.email == normalizedEmail)) {
        accounts.add(GuardianAccount(email: normalizedEmail, passwordHash: _hashPassword(password), createdAt: DateTime.now(), isEmailVerified: true));
        await _saveGuardianAccounts(accounts);
      }
      return true;
    }
    return false;
  }

  // --- STRICT ONLINE CHILD CREATION (requires Sanctum token) ---
  Future<ChildAccountCreationResult> createChildAccount({
    required String guardianEmail,
    required String firstName,
    required String lastName,
    required String password,
    required DateTime birthdate,
  }) async {
    if (!await ConnectivityService.instance.isOnline()) {
      return const ChildAccountCreationResult(
        success: false,
        message: 'Internet connection required to create a child account.',
      );
    }

    final normalizedGuardianEmail = guardianEmail.trim().toLowerCase();
    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.registerChildEndpoint);
      final birthStr =
          '${birthdate.year.toString().padLeft(4, '0')}-'
          '${birthdate.month.toString().padLeft(2, '0')}-'
          '${birthdate.day.toString().padLeft(2, '0')}';
      final response = await ApiClientService.instance.post(uri, jsonBody: {
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'password': password,
        'birthdate': birthStr,
      });

      if (!response.isSuccess) {
        return ChildAccountCreationResult(
          success: false,
          message: _friendlyErrorMessage(
            response,
            fallback: 'Could not create child account. Please try again.',
          ),
        );
      }

      final responseData = response.data['data'] ?? {};
      final childData = responseData['child'] ?? {};

      final int? serverChildId = childData['child_id'] ?? responseData['child_id'];
      final String serverCode = (childData['login_code'] ?? responseData['login_code'])?.toString() ?? '';

      if (serverChildId == null || serverCode.isEmpty) {
        return const ChildAccountCreationResult(success: false, message: 'Invalid response from server.');
      }

      final account = ChildAccount(
        loginCode: serverCode,
        displayName: '${firstName.trim()} ${lastName.trim()}'.trim(),
        passwordHash: _hashPassword(password),
        guardianEmail: normalizedGuardianEmail,
        childId: serverChildId,
        createdAt: DateTime.now(),
        birthdate: birthdate,
      );

      final accounts = await _loadChildAccounts();
      accounts.add(account);
      await _saveChildAccounts(accounts);

      return ChildAccountCreationResult(
        success: true,
        message: 'Child account created. Login code: $serverCode',
        account: account,
      );
    } catch (e) {
      return ChildAccountCreationResult(success: false, message: _friendlyException(e));
    }
  }

  // --- STRICT ONLINE LIST FETCHING (auth user only — no email query) ---
  Future<List<ChildAccount>> listChildrenForGuardian(String guardianEmail) async {
    final normalizedEmail = guardianEmail.trim().toLowerCase();

    if (!await ConnectivityService.instance.isOnline()) {
      throw Exception('Internet connection is required to view the Parent Dashboard.');
    }

    final uri = ApiConfigService.buildUri(ApiConfigService.guardianChildrenEndpoint);
    final response = await ApiClientService.instance.get(uri);
    
    if (!response.isSuccess) {
      throw Exception(
        _friendlyErrorMessage(
          response,
          fallback: 'Could not load children. Please try again.',
        ),
      );
    }
    
    if (response.data != null && response.data['data'] != null) {
      final List<dynamic> serverChildren = response.data['data'];
      var localAccounts = await _loadChildAccounts();
      
      final List<ChildAccount> liveAccounts = serverChildren.map((c) {
        final serverCode = c['login_code']?.toString() ?? '';
        
        // Preserve local SHA256 only — never cache server bcrypt into passwordHash
        // (offline login compares SHA256 of the typed password).
        String preservedHash = '';
        try {
          preservedHash = localAccounts.firstWhere((a) => a.loginCode == serverCode).passwordHash;
          // Reject leaked bcrypt hashes from older app versions
          if (preservedHash.startsWith(r'$2y$') || preservedHash.startsWith(r'$2a$') || preservedHash.startsWith(r'$2b$')) {
            preservedHash = '';
          }
        } catch (_) {}

        return ChildAccount(
          loginCode: serverCode,
          displayName: '${c['first_name']} ${c['last_name']}'.trim(),
          passwordHash: preservedHash,
          guardianEmail: normalizedEmail, childId: c['child_id'], createdAt: DateTime.now(),
        );
      }).toList();
      
      localAccounts.removeWhere((a) => a.guardianEmail == normalizedEmail); 
      localAccounts.addAll(liveAccounts); 
      await _saveChildAccounts(localAccounts);
      
      return liveAccounts..sort((a, b) => a.displayName.compareTo(b.displayName));
    }
    throw Exception('Invalid data format received from server.');
  }

  Future<GuardianAccount?> getGuardianAccount(String email) async {
    final accounts = await _loadGuardianAccounts();
    try {
      return accounts.firstWhere((a) => a.email == email.trim().toLowerCase());
    } catch (_) { return null; }
  }

  /// Submit Gmail SMTP OTP to verify guardian email.
  Future<AccountActionResult> verifyEmailOtp({required String email, required String otp}) async {
    if (!await ConnectivityService.instance.isOnline()) {
      return const AccountActionResult(success: false, message: 'Internet required to verify email.');
    }
    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.verifyEmailEndpoint);
      final response = await ApiClientService.instance.post(uri, jsonBody: {
        'email': email.trim().toLowerCase(),
        'otp': otp.trim(),
      });
      if (!response.isSuccess) {
        return AccountActionResult(
          success: false,
          message: _friendlyErrorMessage(response, fallback: 'Invalid or expired code.'),
        );
      }

      final accounts = await _loadGuardianAccounts();
      final index = accounts.indexWhere((a) => a.email == email.trim().toLowerCase());
      if (index != -1) {
        final old = accounts[index];
        accounts[index] = GuardianAccount(
          email: old.email,
          passwordHash: old.passwordHash,
          createdAt: old.createdAt,
          isEmailVerified: true,
        );
        await _saveGuardianAccounts(accounts);
      }
      return const AccountActionResult(success: true, message: 'Email verified successfully.');
    } catch (e) {
      return AccountActionResult(success: false, message: _friendlyException(e));
    }
  }

  Future<AccountActionResult> resendVerificationOtp(String email) async {
    if (!await ConnectivityService.instance.isOnline()) {
      return const AccountActionResult(success: false, message: 'Internet required.');
    }
    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.resendVerificationEndpoint);
      final response = await ApiClientService.instance.post(uri, jsonBody: {
        'email': email.trim().toLowerCase(),
      });
      if (!response.isSuccess) {
        return AccountActionResult(
          success: false,
          message: _friendlyErrorMessage(response, fallback: 'Could not resend code.'),
        );
      }
      return const AccountActionResult(success: true, message: 'A new code was sent to your email.');
    } catch (e) {
      return AccountActionResult(success: false, message: _friendlyException(e));
    }
  }

  @Deprecated('Use verifyEmailOtp')
  Future<AccountActionResult> verifyEmail(String email) async {
    return resendVerificationOtp(email);
  }

  Future<AccountActionResult> resetParentPassword(String email, String currentPassword, String newPassword) async {
    if (!await ConnectivityService.instance.isOnline()) return const AccountActionResult(success: false, message: 'Internet connection required.');

    final isValid = await authenticateGuardian(email: email, password: currentPassword);
    if (!isValid) return const AccountActionResult(success: false, message: 'Current password is incorrect.');
    
    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.resetPasswordEndpoint);
      final response = await ApiClientService.instance.post(uri, jsonBody: {'email': email.trim().toLowerCase(), 'current_password': currentPassword, 'new_password': newPassword});
      if (!response.isSuccess) {
        return AccountActionResult(
          success: false,
          message: _friendlyErrorMessage(response, fallback: 'Could not update password.'),
        );
      }

      final accounts = await _loadGuardianAccounts();
      final index = accounts.indexWhere((a) => a.email == email.trim().toLowerCase());
      if (index != -1) {
        final old = accounts[index];
        accounts[index] = GuardianAccount(email: old.email, passwordHash: _hashPassword(newPassword), createdAt: old.createdAt, isEmailVerified: old.isEmailVerified);
        await _saveGuardianAccounts(accounts);
      }
      return const AccountActionResult(success: true, message: 'Parent password updated successfully.');
    } catch (e) {
      return AccountActionResult(success: false, message: _friendlyException(e));
    }
  }

  /// Guardian-authenticated update of a child's login password (server + local cache).
  Future<AccountActionResult> updateChildPassword({
    required String guardianEmail,
    required String guardianPassword,
    required int childId,
    required String loginCode,
    required String newPassword,
  }) async {
    if (!await ConnectivityService.instance.isOnline()) {
      return const AccountActionResult(success: false, message: 'Internet connection required.');
    }
    if (newPassword.trim().length < 4) {
      return const AccountActionResult(success: false, message: 'Child password must be 4+ characters.');
    }

    try {
      final endpoint = ApiConfigService.updateChildPasswordEndpoint.replaceFirst(
        '{child_id}',
        childId.toString(),
      );
      final uri = ApiConfigService.buildUri(endpoint);
      final response = await ApiClientService.instance.put(
        uri,
        jsonBody: {
          'new_password': newPassword,
          'guardian_email': guardianEmail.trim().toLowerCase(),
          'guardian_password': guardianPassword,
        },
      );
      if (!response.isSuccess) {
        return AccountActionResult(
          success: false,
          message: _friendlyErrorMessage(response, fallback: 'Could not update child password.'),
        );
      }

      final accounts = await _loadChildAccounts();
      final normalizedCode = loginCode.trim().toUpperCase();
      final index = accounts.indexWhere(
        (a) => a.childId == childId || a.loginCode == normalizedCode,
      );
      if (index != -1) {
        final old = accounts[index];
        accounts[index] = ChildAccount(
          loginCode: old.loginCode,
          displayName: old.displayName,
          passwordHash: _hashPassword(newPassword),
          guardianEmail: old.guardianEmail,
          childId: old.childId,
          createdAt: old.createdAt,
        );
        await _saveChildAccounts(accounts);
      }

      return const AccountActionResult(success: true, message: 'Child password updated successfully.');
    } catch (e) {
      return AccountActionResult(success: false, message: _friendlyException(e));
    }
  }

  /// Prefer short, user-safe copy — never dump Laravel stack traces / SQL into the UI.
  String _friendlyErrorMessage(
    ApiClientResponse response, {
    required String fallback,
  }) {
    final extracted = _extractApiMessage(response);
    if (extracted != null && !_looksLikeInternalError(extracted)) {
      return extracted;
    }

    final status = response.statusCode;
    if (status == 401 || status == 403) {
      return 'Wrong email or password.';
    }
    if (status == 409) {
      return 'An account with this email already exists.';
    }
    if (status == 422) {
      return extracted != null && !_looksLikeInternalError(extracted)
          ? extracted
          : 'Please check your details and try again.';
    }
    if (status == 429) {
      return 'Too many attempts. Please wait a moment and try again.';
    }
    if (status >= 500 || status == 0) {
      return 'Our servers are temporarily unavailable. Please try again in a few minutes.';
    }
    return fallback;
  }

  String _friendlyException(Object e) {
    final text = e.toString().replaceAll('Exception: ', '');
    if (_looksLikeInternalError(text) || text.length > 160) {
      return 'Could not reach the server. Check your connection and try again.';
    }
    return text;
  }

  bool _looksLikeInternalError(String message) {
    final lower = message.toLowerCase();
    return lower.contains('sqlstate') ||
        lower.contains('connection refused') ||
        lower.contains('queryexception') ||
        lower.contains('illuminate\\') ||
        lower.contains('stack trace') ||
        lower.contains('"exception"') ||
        lower.contains('"file":') ||
        lower.contains('/vendor/') ||
        message.trimLeft().startsWith('{') ||
        message.length > 180;
  }

  String? _extractApiMessage(ApiClientResponse response) {
    final data = response.data;
    if (data is Map) {
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) return message.trim();
      final errors = data['errors'];
      if (errors is Map && errors.isNotEmpty) {
        final first = errors.values.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
        if (first is String) return first;
      }
    }
    return null;
  }

  // --- CHILD LOGIN (ONLINE FIRST, OFFLINE FALLBACK ONLY ON NETWORK FAILURE) ---
  Future<ChildAccount?> authenticateChild({required String loginCode, required String password}) async {
    final normalizedCode = loginCode.trim().toUpperCase();
    final hash = _hashPassword(password);
    final accounts = await _loadChildAccounts();

    if (await ConnectivityService.instance.isOnline()) {
      ApiClientResponse? response;
      try {
        final uri = ApiConfigService.buildUri(ApiConfigService.loginChildEndpoint);
        response = await ApiClientService.instance.post(
          uri,
          jsonBody: {'login_code': normalizedCode, 'password': password},
        );
      } catch (e) {
        debugPrint('Child online login network failure, falling back to cache: $e');
        response = null;
      }

      if (response != null) {
        if (response.isSuccess) {
          final serverData = response.data['data'] ?? {};

          final token = serverData['access_token'];
          if (token != null && token.isNotEmpty) {
            await AuthSessionService.instance.saveAccessToken(token);
          }

          ChildAccount matchedAccount;
          final index = accounts.indexWhere((a) => a.loginCode == normalizedCode);

          if (index != -1) {
            matchedAccount = ChildAccount(
              loginCode: normalizedCode,
              displayName: serverData['display_name'] ?? accounts[index].displayName,
              passwordHash: hash,
              guardianEmail: serverData['guardian_email'] ?? accounts[index].guardianEmail,
              childId: serverData['child_id'] ?? accounts[index].childId,
              createdAt: accounts[index].createdAt,
            );
            accounts[index] = matchedAccount;
          } else {
            matchedAccount = ChildAccount(
              loginCode: normalizedCode,
              displayName: serverData['display_name'] ?? 'Child',
              passwordHash: hash,
              guardianEmail: serverData['guardian_email'] ?? '',
              childId: serverData['child_id'],
              createdAt: DateTime.now(),
            );
            accounts.add(matchedAccount);
          }

          await _saveChildAccounts(accounts);
          return matchedAccount;
        }

        // Real HTTP error from server — surface to UI, do not use offline cache.
        throw Exception(
          _friendlyErrorMessage(response, fallback: 'Wrong child code or password.'),
        );
      }
    }

    // Offline, or online request never completed (network error).
    try {
      final local = accounts.firstWhere(
        (a) => a.loginCode == normalizedCode && a.passwordHash.isNotEmpty && a.passwordHash == hash,
      );
      // Drop any prior guardian/API token so it cannot ride along with offline child auth.
      await AuthSessionService.instance.clearAccessToken();
      return local;
    } catch (_) {
      return null;
    }
  }
}