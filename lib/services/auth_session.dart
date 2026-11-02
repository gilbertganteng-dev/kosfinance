import '../models/models.dart';
import 'api_service.dart';

/// Holds the authenticated account for the current application session.
class AuthSession {
  AuthSession._();

  static UserAccount? currentUser;

  static UserAccount userFromJson(Map<String, dynamic> json) => UserAccount(
        id: _intOrNull(json['id']),
        username: (json['username'] ?? '').toString(),
        password: '',
        name: (json['name'] ?? '').toString(),
        phone: (json['phone'] ?? '').toString(),
        email: (json['email'] ?? '').toString(),
        role: _roleLabel((json['role'] ?? 'resident').toString()),
      );

  static String _roleLabel(String role) => role.toLowerCase() == 'admin' ? 'Admin' : 'Penghuni';

  static int? _intOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }

  static Future<void> saveSession(Map<String, dynamic> payload) async {
    final token = payload['token']?.toString();
    final user = payload['user'];
    if (token == null || token.isEmpty || user is! Map) {
      throw const ApiException('Respons autentikasi tidak memuat token atau profil pengguna.');
    }
    await ApiService.setToken(token);
    currentUser = userFromJson(Map<String, dynamic>.from(user));
  }

  static Future<bool> restore() async {
    final token = await ApiService.getToken();
    if (token == null || token.isEmpty) return false;

    try {
      final response = await ApiService.get('auth/me');
      final user = response['data'];
      if (user is! Map) throw const ApiException('Respons profil pengguna tidak valid.');
      currentUser = userFromJson(Map<String, dynamic>.from(user));
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await signOutLocal();
        return false;
      }
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      await ApiService.post('auth/logout', const <String, dynamic>{});
    } on ApiException {
      // Local credentials are removed even if the server is currently offline.
    }
    await signOutLocal();
  }

  static Future<void> signOutLocal() async {
    currentUser = null;
    await ApiService.clearToken();
  }
}
