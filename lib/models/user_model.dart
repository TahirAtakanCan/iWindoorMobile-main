class UserModel {
  final int id;
  final String fullName;
  final String email;
  final String role;

  UserModel({
    required this.id, 
    required this.fullName, 
    required this.email, 
    required this.role
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? 0, // ID null gelirse 0 yap
      fullName: json['fullName'] ?? "İsimsiz Kullanıcı", // İsim null ise varsayılan yazı
      email: json['email'] ?? "", // Email null ise boş bırak
      role: json['role'] ?? "EMPLOYEE", // Rol null ise EMPLOYEE varsay
    );
  }
}