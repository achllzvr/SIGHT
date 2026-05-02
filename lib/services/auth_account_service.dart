import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'connectivity_service.dart';

import 'api_client_service.dart';
import 'api_config_service.dart';

class GuardianAccount {
  final String email;
  final String passwordHash;
  final DateTime createdAt;
  final bool isEmailVerified;

  const GuardianAccount({
    required this.email,
    required this.passwordHash,
    required this.createdAt,
    required this.isEmailVerified,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'passwordHash': passwordHash,
    'createdAt': createdAt.toIso8601String(),
    'isEmailVerified': isEmailVerified,
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
    required this.loginCode,
    required this.displayName,
    required this.passwordHash,
    required this.guardianEmail,
    required this.childId,
    required this.createdAt,
    this.birthdate,
  });

  Map<String, dynamic> toJson() => {
    'loginCode': loginCode,
    'displayName': displayName,
    'passwordHash': passwordHash,
    'guardianEmail': guardianEmail,
    'childId': childId,
    'createdAt': createdAt.toIso8601String(),
    'birthdate': birthdate?.toIso8601String(),
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
  // ignore: unused_field
  final Random _random = Random();

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
    required String password
  }) async {
    if (!await ConnectivityService.instance.isOnline()) {
      return const AccountActionResult(success: false, message: 'Internet connection required to create a Parent account.');
    }
    
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) return const AccountActionResult(success: false, message: 'Enter a valid email.');
    if (password.length < 6) return const AccountActionResult(success: false, message: 'Password must be at least 6 characters.');
    
    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.registerGuardianEndpoint);
      final response = await ApiClientService.instance.post(
        uri,
        jsonBody: {
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'email': normalizedEmail,
          'password': password, 
        }
      );

      if (!response.isSuccess) {
        return AccountActionResult(success: false, message: 'Server error: ${response.rawBody}');
      }

      // Cache locally
      final accounts = await _loadGuardianAccounts();
      accounts.add(GuardianAccount(email: normalizedEmail, passwordHash: _hashPassword(password), createdAt: DateTime.now(), isEmailVerified: false));
      await _saveGuardianAccounts(accounts);
      
      return const AccountActionResult(success: true, message: 'Guardian account created successfully.');
    } catch (e) {
      return AccountActionResult(success: false, message: 'Network error: $e');
    }
  }

  Future<bool> authenticateGuardian({required String email, required String password}) async {
    final normalizedEmail = email.trim().toLowerCase();
    
    // STRICT ONLINE CHECK
    if (!await ConnectivityService.instance.isOnline()) {
      throw Exception('Internet connection is required to login as a Guardian.');
    }

    final uri = ApiConfigService.buildUri('/api/shared/login');
    final response = await ApiClientService.instance.post(uri, jsonBody: {
      'email': normalizedEmail,
      'password': password
    });
    
    if (response.isSuccess) {
      return true;
    }
    
    return false; // Server rejected credentials
  }

  // --- CHILD ACCOUNT CREATION (ONLINE ONLY) ---
  Future<ChildAccountCreationResult> createChildAccount({
    required String guardianEmail, 
    required String firstName, 
    required String lastName, 
    required String password,
  }) async {
    if (!await ConnectivityService.instance.isOnline()) {
      return const ChildAccountCreationResult(success: false, message: 'Internet connection required to create a Child account.');
    }
    
    final normalizedGuardianEmail = guardianEmail.trim().toLowerCase();
    if (normalizedGuardianEmail.isEmpty) return const ChildAccountCreationResult(success: false, message: 'Guardian session invalid.');
    if (firstName.trim().isEmpty) return const ChildAccountCreationResult(success: false, message: 'First name required.');
    if (password.length < 4) return const ChildAccountCreationResult(success: false, message: 'Password must be at least 4 characters.');

    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.registerChildEndpoint);
      final response = await ApiClientService.instance.post(
        uri,
        jsonBody: {
          'guardian_email': normalizedGuardianEmail,
          'first_name': firstName.trim(),
          'last_name': lastName.trim(),
          'password': password,
        }
      );

      if (!response.isSuccess) {
        return ChildAccountCreationResult(success: false, message: 'Server error: ${response.rawBody}');
      }

      // STRICT SERVER RELIANCE: Extract the REAL ID and Code generated by Laravel
      final responseData = response.data['data'] ?? {};
      final childData = responseData['child'] ?? {};
      
      final int? serverChildId = childData['child_id'] ?? responseData['child_id'];
      final String serverCode = (childData['login_code'] ?? responseData['login_code'])?.toString() ?? '';

      if (serverChildId == null || serverCode.isEmpty) {
        return const ChildAccountCreationResult(success: false, message: 'Invalid response from server.');
      }

      final String displayName = '${firstName.trim()} ${lastName.trim()}'.trim();

      // Mirror the exact server state to local cache
      final account = ChildAccount(
        loginCode: serverCode, 
        displayName: displayName, 
        passwordHash: _hashPassword(password),
        guardianEmail: normalizedGuardianEmail, 
        childId: serverChildId, 
        createdAt: DateTime.now(),
      );
      
      final accounts = await _loadChildAccounts();
      accounts.add(account);
      await _saveChildAccounts(accounts);
      
      return ChildAccountCreationResult(success: true, message: 'Child account created.', account: account);
    } catch (e) {
      return ChildAccountCreationResult(success: false, message: 'Network error: $e');
    }
  }

  Future<List<ChildAccount>> listChildrenForGuardian(String guardianEmail) async {
    final normalizedEmail = guardianEmail.trim().toLowerCase();
    final uri = ApiConfigService.buildUri('/api/mobile/guardian/children', queryParameters: {'email': normalizedEmail});
    final response = await ApiClientService.instance.get(uri);
    
    // --> NEW: Expose the actual Laravel error to the SnackBar!
    if (!response.isSuccess) {
      throw Exception('Server Error ${response.statusCode}: ${response.rawBody}');
    }
    
    if (response.data != null && response.data['data'] != null) {
      final List<dynamic> serverChildren = response.data['data'];
      
      final List<ChildAccount> liveAccounts = serverChildren.map((c) {
        return ChildAccount(
          loginCode: c['login_code']?.toString() ?? '',
          displayName: '${c['first_name']} ${c['last_name']}'.trim(),
          passwordHash: c['password_hash'] ?? '', 
          guardianEmail: normalizedEmail,
          childId: c['child_id'],
          createdAt: DateTime.now(),
        );
      }).toList();
      
      var localAccounts = await _loadChildAccounts();
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

  // --- EMAIL VERIFICATION (ONLINE ONLY) ---
  // TODO: API METHOD FOR VERIFY EMAIL
  Future<AccountActionResult> verifyEmail(String email) async {
    if (!await ConnectivityService.instance.isOnline()) {
      return const AccountActionResult(success: false, message: 'Internet required for Email Verification.');
    }

    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.verifyEmailEndpoint);
      final response = await ApiClientService.instance.post(
        uri,
        jsonBody: {'email': email.trim().toLowerCase()}
      );

      if (!response.isSuccess) {
        return const AccountActionResult(success: false, message: 'Failed to send verification email.');
      }

      // Update local cache
      final accounts = await _loadGuardianAccounts();
      final index = accounts.indexWhere((a) => a.email == email.trim().toLowerCase());
      if (index != -1) {
        final old = accounts[index];
        accounts[index] = GuardianAccount(email: old.email, passwordHash: old.passwordHash, createdAt: old.createdAt, isEmailVerified: true);
        await _saveGuardianAccounts(accounts);
      }
      return const AccountActionResult(success: true, message: 'Verification email sent! Check your inbox.');
    } catch (e) {
      return AccountActionResult(success: false, message: 'Network error: $e');
    }
  }

  // --- RESET PARENT PASSWORD (ONLINE ONLY) ---
  // TODO: API METHOD FOR RESETTING PARENT PASSWORD
  Future<AccountActionResult> resetParentPassword(String email, String currentPassword, String newPassword) async {
    if (!await ConnectivityService.instance.isOnline()) {
      return const AccountActionResult(success: false, message: 'Internet connection required to reset password.');
    }

    final isValid = await authenticateGuardian(email: email, password: currentPassword);
    if (!isValid) return const AccountActionResult(success: false, message: 'Current password is incorrect.');
    
    try {
      final uri = ApiConfigService.buildUri(ApiConfigService.resetPasswordEndpoint);
      final response = await ApiClientService.instance.post(
        uri,
        jsonBody: {
          'email': email.trim().toLowerCase(),
          'current_password': currentPassword,
          'new_password': newPassword
        }
      );

      if (!response.isSuccess) {
        return AccountActionResult(success: false, message: 'Server error: ${response.rawBody}');
      }

      // Update local cache
      final accounts = await _loadGuardianAccounts();
      final index = accounts.indexWhere((a) => a.email == email.trim().toLowerCase());
      if (index != -1) {
        final old = accounts[index];
        accounts[index] = GuardianAccount(email: old.email, passwordHash: _hashPassword(newPassword), createdAt: old.createdAt, isEmailVerified: old.isEmailVerified);
        await _saveGuardianAccounts(accounts);
      }
      return const AccountActionResult(success: true, message: 'Parent password updated successfully.');
    } catch (e) {
      return AccountActionResult(success: false, message: 'Network error: $e');
    }
  }

  // --- CHILD LOGIN (TRIES ONLINE FIRST, FALLS BACK TO OFFLINE CACHE) ---
  Future<ChildAccount?> authenticateChild({required String loginCode, required String password}) async {
    final normalizedCode = loginCode.trim().toUpperCase();
    final hash = _hashPassword(password);
    final accounts = await _loadChildAccounts();

    // 1. Try API if online
    if (await ConnectivityService.instance.isOnline()) {
      try {
        final uri = ApiConfigService.buildUri(ApiConfigService.loginChildEndpoint);
        final response = await ApiClientService.instance.post(
          uri,
          jsonBody: {
            'login_code': normalizedCode,
            'password': password
          }
        );

        if (response.isSuccess) {
           // Extract the nested data object
           final serverData = response.data['data'] ?? {};

           // Success from API. If it's not in our local cache, add it so they can login offline later.
           bool existsLocally = accounts.any((a) => a.loginCode == normalizedCode);
           if (!existsLocally) {
              final newAccount = ChildAccount(
                loginCode: normalizedCode, 
                displayName: serverData['display_name'] ?? 'Child', 
                passwordHash: hash,
                guardianEmail: serverData['guardian_email'] ?? '', 
                childId: serverData['child_id'],
                createdAt: DateTime.now(),
              );
              accounts.add(newAccount);
              await _saveChildAccounts(accounts);
              return newAccount;
           }
        }
      } catch (e) {
        // API failed (timeout/500). Fall through to offline cache check.
      }
    }
    
    // 2. Fallback to Local Cache (Offline Login)
    try {
      return accounts.firstWhere((a) => a.loginCode == normalizedCode && a.passwordHash == hash);
    } catch (_) {
      return null; 
    }
  }
}