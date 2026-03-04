import 'package:cloud_firestore/cloud_firestore.dart';
import 'backend_type.dart';

class UserModel {
  final String id;
  final String name;
  final String username;
  final String email;
  final String? phone;
  final BackendType backendType;

  UserModel({
    required this.id,
    required this.name,
    required this.username,
    required this.email,
    this.phone,
    this.backendType = BackendType.firebase,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'username': username,
      'email': email,
      'phone': phone,
      'backendType': backendType.storageValue,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      username: map['username'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      backendType: backendTypeFromStorage(map['backendType'] as String?),
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel.fromMap(data, doc.id);
  }
}
