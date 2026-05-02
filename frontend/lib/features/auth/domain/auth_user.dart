class AuthCompany {
  AuthCompany({required this.id, required this.name, this.logoUrl});

  final int id;
  final String name;
  final String? logoUrl;

  factory AuthCompany.fromJson(Map<String, dynamic> j) =>
      AuthCompany(id: j['id'] as int, name: j['name'] as String, logoUrl: j['logoUrl'] as String?);
}

class AuthBranch {
  AuthBranch({required this.id, required this.name});
  final int id;
  final String name;

  factory AuthBranch.fromJson(Map<String, dynamic> j) =>
      AuthBranch(id: j['id'] as int, name: j['name'] as String);
}

class AuthUser {
  AuthUser({
    required this.id,
    required this.username,
    required this.email,
    required this.fullName,
    required this.isSuperAdmin,
    this.avatarUrl,
    this.company,
    this.branch,
    this.totpEnabled = false,
    this.totpEnabledAt,
  });

  final int id;
  final String username;
  final String email;
  final String fullName;
  final bool isSuperAdmin;
  final String? avatarUrl;
  final AuthCompany? company;
  final AuthBranch? branch;
  // Phase 4.16 follow-up — 2FA state surfaced from /auth/me.
  final bool totpEnabled;
  final DateTime? totpEnabledAt;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as int,
        username: j['username'] as String,
        email: j['email'] as String,
        fullName: j['fullName'] as String,
        isSuperAdmin: (j['isSuperAdmin'] as bool?) ?? false,
        avatarUrl: j['avatarUrl'] as String?,
        company: j['company'] is Map<String, dynamic>
            ? AuthCompany.fromJson(j['company'] as Map<String, dynamic>)
            : null,
        branch: j['branch'] is Map<String, dynamic>
            ? AuthBranch.fromJson(j['branch'] as Map<String, dynamic>)
            : null,
        totpEnabled: j['totpEnabled'] == true,
        totpEnabledAt: j['totpEnabledAt'] is String
            ? DateTime.tryParse(j['totpEnabledAt'] as String)
            : null,
      );
}
