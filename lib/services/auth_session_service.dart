import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum AppUserRole { guardian, child }

extension AppUserRoleX on AppUserRole {
  String get key => name;

  static AppUserRole? fromKey(String? value) {
    switch (value) {
      case 'guardian':
        return AppUserRole.guardian;
      case 'child':
        return AppUserRole.child;
      default:
        return null;
    }
  }
}

class UserSession {
  final AppUserRole role;
  final String? guardianEmail;
  final String? childLoginCode;
  final int? childId;

  const UserSession({
    required this.role,
    this.guardianEmail,
    this.childLoginCode,
    this.childId,
  });
}

class AuthSessionService {
  AuthSessionService._private();

  static final AuthSessionService instance = AuthSessionService._private();

  static const _accessTokenKey = 'auth_access_token';
  static const _userRoleKey = 'session_user_role';
  static const _guardianEmailKey = 'session_guardian_email';
  static const _childLoginCodeKey = 'session_child_login_code';
  static const _childIdKey = 'session_child_id';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveAccessToken(String token) async {
    await _storage.write(key: _accessTokenKey, value: token);
  }

  Future<String?> loadAccessToken() async {
    return _storage.read(key: _accessTokenKey);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _accessTokenKey);
  }

  Future<void> saveGuardianSession({required String guardianEmail}) async {
    await _storage.write(key: _userRoleKey, value: AppUserRole.guardian.key);
    await _storage.write(key: _guardianEmailKey, value: guardianEmail.trim().toLowerCase());
    await _storage.delete(key: _childLoginCodeKey);
    await _storage.delete(key: _childIdKey);
  }

  Future<void> saveChildSession({
    required String childLoginCode,
    int? childId,
  }) async {
    await _storage.write(key: _userRoleKey, value: AppUserRole.child.key);
    await _storage.write(key: _childLoginCodeKey, value: childLoginCode.trim().toUpperCase());
    if (childId == null) {
      await _storage.delete(key: _childIdKey);
    } else {
      await _storage.write(key: _childIdKey, value: childId.toString());
    }
    await _storage.delete(key: _guardianEmailKey);
  }

  Future<UserSession?> loadUserSession() async {
    final role = AppUserRoleX.fromKey(await _storage.read(key: _userRoleKey));
    if (role == null) {
      return null;
    }

    if (role == AppUserRole.guardian) {
      final email = await _storage.read(key: _guardianEmailKey);
      if (email == null || email.isEmpty) {
        return null;
      }

      return UserSession(role: role, guardianEmail: email);
    }

    final code = await _storage.read(key: _childLoginCodeKey);
    if (code == null || code.isEmpty) {
      return null;
    }

    final childIdRaw = await _storage.read(key: _childIdKey);
    return UserSession(
      role: role,
      childLoginCode: code,
      childId: int.tryParse(childIdRaw ?? ''),
    );
  }

  Future<void> clearUserSession() async {
    await _storage.delete(key: _userRoleKey);
    await _storage.delete(key: _guardianEmailKey);
    await _storage.delete(key: _childLoginCodeKey);
    await _storage.delete(key: _childIdKey);
  }
}