import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class GuardianAccount {
  final String email;
  final String passwordHash;
  final DateTime createdAt;

  const GuardianAccount({
    required this.email,
    required this.passwordHash,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'passwordHash': passwordHash,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory GuardianAccount.fromJson(Map<String, dynamic> json) {
    return GuardianAccount(
      email: (json['email'] as String? ?? '').toLowerCase(),
      passwordHash: json['passwordHash'] as String? ?? '',
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class ChildAccount {
  final String loginCode;
  final String displayName;
  final String passwordHash;
  final String guardianEmail;
  final int? childId;
  final DateTime createdAt;

  const ChildAccount({
    required this.loginCode,
    required this.displayName,
    required this.passwordHash,
    required this.guardianEmail,
    required this.childId,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'loginCode': loginCode,
      'displayName': displayName,
      'passwordHash': passwordHash,
      'guardianEmail': guardianEmail,
      'childId': childId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ChildAccount.fromJson(Map<String, dynamic> json) {
    return ChildAccount(
      loginCode: (json['loginCode'] as String? ?? '').toUpperCase(),
      displayName: json['displayName'] as String? ?? 'Child',
      passwordHash: json['passwordHash'] as String? ?? '',
      guardianEmail: (json['guardianEmail'] as String? ?? '').toLowerCase(),
      childId: (json['childId'] as num?)?.toInt(),
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

class AccountActionResult {
  final bool success;
  final String message;

  const AccountActionResult({required this.success, required this.message});
}

class ChildAccountCreationResult extends AccountActionResult {
  final ChildAccount? account;

  const ChildAccountCreationResult({
    required bool success,
    required String message,
    this.account,
  }) : super(success: success, message: message);
}

class AuthAccountService {
  AuthAccountService._private();

  static final AuthAccountService instance = AuthAccountService._private();

  static const _guardianAccountsKey = 'guardian_accounts_v1';
  static const _childAccountsKey = 'child_accounts_v1';

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Random _random = Random();

  String _hashPassword(String value) {
    return sha256.convert(utf8.encode(value)).toString();
  }

  Future<List<GuardianAccount>> _loadGuardianAccounts() async {
    final raw = await _storage.read(key: _guardianAccountsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final list = (jsonDecode(raw) as List)
        .whereType<Map<String, dynamic>>()
        .map(GuardianAccount.fromJson)
        .toList(growable: true);
    return list;
  }

  Future<void> _saveGuardianAccounts(List<GuardianAccount> accounts) async {
    await _storage.write(
      key: _guardianAccountsKey,
      value: jsonEncode(accounts.map((e) => e.toJson()).toList()),
    );
  }

  Future<List<ChildAccount>> _loadChildAccounts() async {
    final raw = await _storage.read(key: _childAccountsKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }

    final list = (jsonDecode(raw) as List)
        .whereType<Map<String, dynamic>>()
        .map(ChildAccount.fromJson)
        .toList(growable: true);
    return list;
  }

  Future<void> _saveChildAccounts(List<ChildAccount> accounts) async {
    await _storage.write(
      key: _childAccountsKey,
      value: jsonEncode(accounts.map((e) => e.toJson()).toList()),
    );
  }

  Future<AccountActionResult> registerGuardian({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    if (normalizedEmail.isEmpty || !normalizedEmail.contains('@')) {
      return const AccountActionResult(success: false, message: 'Enter a valid guardian email.');
    }

    if (password.length < 6) {
      return const AccountActionResult(success: false, message: 'Password must be at least 6 characters.');
    }

    final accounts = await _loadGuardianAccounts();
    final exists = accounts.any((account) => account.email == normalizedEmail);
    if (exists) {
      return const AccountActionResult(success: false, message: 'Guardian account already exists.');
    }

    accounts.add(
      GuardianAccount(
        email: normalizedEmail,
        passwordHash: _hashPassword(password),
        createdAt: DateTime.now(),
      ),
    );
    await _saveGuardianAccounts(accounts);

    return const AccountActionResult(success: true, message: 'Guardian account created.');
  }

  Future<bool> authenticateGuardian({
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    final accounts = await _loadGuardianAccounts();
    final hash = _hashPassword(password);

    return accounts.any((account) => account.email == normalizedEmail && account.passwordHash == hash);
  }

  Future<ChildAccountCreationResult> createChildAccount({
    required String guardianEmail,
    required String displayName,
    required String password,
    int? childId,
  }) async {
    final normalizedGuardianEmail = guardianEmail.trim().toLowerCase();
    if (normalizedGuardianEmail.isEmpty) {
      return const ChildAccountCreationResult(success: false, message: 'Guardian session is invalid.');
    }

    if (displayName.trim().isEmpty) {
      return const ChildAccountCreationResult(success: false, message: 'Child display name is required.');
    }

    if (password.length < 4) {
      return const ChildAccountCreationResult(success: false, message: 'Child password must be at least 4 characters.');
    }

    final accounts = await _loadChildAccounts();
    String code;
    do {
      code = (_random.nextInt(900000) + 100000).toString();
    } while (accounts.any((account) => account.loginCode == code));

    final account = ChildAccount(
      loginCode: code,
      displayName: displayName.trim(),
      passwordHash: _hashPassword(password),
      guardianEmail: normalizedGuardianEmail,
      childId: childId,
      createdAt: DateTime.now(),
    );

    accounts.add(account);
    await _saveChildAccounts(accounts);

    return ChildAccountCreationResult(
      success: true,
      message: 'Child account created.',
      account: account,
    );
  }

  Future<ChildAccount?> authenticateChild({
    required String loginCode,
    required String password,
  }) async {
    final normalizedCode = loginCode.trim().toUpperCase();
    final hash = _hashPassword(password);
    final accounts = await _loadChildAccounts();

    try {
      return accounts.firstWhere((account) => account.loginCode == normalizedCode && account.passwordHash == hash);
    } catch (_) {
      return null;
    }
  }

  Future<List<ChildAccount>> listChildrenForGuardian(String guardianEmail) async {
    final normalized = guardianEmail.trim().toLowerCase();
    final accounts = await _loadChildAccounts();
    return accounts
        .where((account) => account.guardianEmail == normalized)
        .toList(growable: false)
      ..sort((a, b) => a.displayName.compareTo(b.displayName));
  }
}