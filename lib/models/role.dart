enum UserRole {
  candidat,
  etudiant,
  admin,
}

extension UserRoleExtension on UserRole {
  String get string {
    switch (this) {
      case UserRole.candidat:
        return 'candidat';
      case UserRole.etudiant:
        return 'etudiant';
      case UserRole.admin:
        return 'admin';
    }
  }

  static UserRole fromString(String value) {
    switch (value) {
      case 'candidat':
        return UserRole.candidat;
      case 'etudiant':
        return UserRole.etudiant;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.candidat;
    }
  }
}