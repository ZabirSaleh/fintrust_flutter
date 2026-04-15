class UserModel {
  final int? id;
  final String email;
  final String fullName;
  final String password;
  final String createdAt;

  const UserModel({
    this.id,
    required this.email,
    required this.fullName,
    required this.password,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'email': email,
        'full_name': fullName,
        'password': password,
        'created_at': createdAt,
      };

  factory UserModel.fromMap(Map<String, dynamic> map) => UserModel(
        id: map['id'] as int?,
        email: map['email'] as String,
        fullName: map['full_name'] as String,
        password: map['password'] as String,
        createdAt: map['created_at'] as String,
      );
}
