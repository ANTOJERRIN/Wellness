class HealthProfileModel {
  final String medicalHistory;
  final String lifestyle;
  final String symptoms;
  final String allergies;
  final String medications;

  HealthProfileModel({
    required this.medicalHistory,
    required this.lifestyle,
    required this.symptoms,
    required this.allergies,
    required this.medications,
  });

  factory HealthProfileModel.fromJson(Map<String, dynamic> json) {
    return HealthProfileModel(
      medicalHistory: json['medicalHistory'] as String? ?? '',
      lifestyle: json['lifestyle'] as String? ?? '',
      symptoms: json['symptoms'] as String? ?? '',
      allergies: json['allergies'] as String? ?? '',
      medications: json['medications'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'medicalHistory': medicalHistory,
      'lifestyle': lifestyle,
      'symptoms': symptoms,
      'allergies': allergies,
      'medications': medications,
    };
  }
}

class UserProfileModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final HealthProfileModel healthProfile;

  UserProfileModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.healthProfile,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      role: json['role'] as String? ?? '',
      healthProfile: HealthProfileModel.fromJson(
        json['healthProfile'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'role': role,
      'healthProfile': healthProfile.toJson(),
    };
  }
}
