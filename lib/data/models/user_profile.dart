class EmergencyContact {
  final String name;
  final String phone;
  final String? email;
  final String relation;

  const EmergencyContact({
    required this.name,
    required this.phone,
    this.email,
    required this.relation,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'relation': relation,
      };

  factory EmergencyContact.fromMap(Map<String, dynamic> map) => EmergencyContact(
        name: map['name'] as String,
        phone: map['phone'] as String,
        email: map['email'] as String?,
        relation: map['relation'] as String,
      );
}

/// User health profile stored locally for better triage context.
class UserProfile {
  final String name;
  final int? age;
  final String? sex;
  final List<String> preExistingConditions;
  final List<String> allergies;
  final String role;
  
  // New comprehensive medical fields
  final String? bloodType;
  final String? bio;
  final String? phone;
  final String? dob;
  final double? height;
  final double? weight;
  final List<String> medications;
  final List<String> familyMedicalHistory;
  
  // Image
  final String? profileImagePath;
  
  // Lifestyle
  final bool smoking;
  final bool alcohol;
  final String? exerciseFrequency;

  // Emergency Contacts
  final List<EmergencyContact> emergencyContacts;
  
  // Location
  final double? latitude;
  final double? longitude;

  const UserProfile({
    required this.name,
    this.age,
    this.sex,
    this.preExistingConditions = const [],
    this.allergies = const [],
    this.role = 'user',
    this.bloodType,
    this.bio,
    this.phone,
    this.dob,
    this.height,
    this.weight,
    this.medications = const [],
    this.familyMedicalHistory = const [],
    this.smoking = false,
    this.alcohol = false,
    this.exerciseFrequency,
    this.emergencyContacts = const [],
    this.latitude,
    this.longitude,
    this.profileImagePath,
  });

  UserProfile copyWith({
    String? name,
    int? age,
    String? sex,
    List<String>? preExistingConditions,
    List<String>? allergies,
    String? role,
    String? bloodType,
    String? bio,
    String? phone,
    String? dob,
    double? height,
    double? weight,
    List<String>? medications,
    List<String>? familyMedicalHistory,
    bool? smoking,
    bool? alcohol,
    String? exerciseFrequency,
    List<EmergencyContact>? emergencyContacts,
    double? latitude,
    double? longitude,
    String? profileImagePath,
  }) =>
      UserProfile(
        name: name ?? this.name,
        age: age ?? this.age,
        sex: sex ?? this.sex,
        preExistingConditions: preExistingConditions ?? this.preExistingConditions,
        allergies: allergies ?? this.allergies,
        role: role ?? this.role,
        bloodType: bloodType ?? this.bloodType,
        bio: bio ?? this.bio,
        phone: phone ?? this.phone,
        dob: dob ?? this.dob,
        height: height ?? this.height,
        weight: weight ?? this.weight,
        medications: medications ?? this.medications,
        familyMedicalHistory: familyMedicalHistory ?? this.familyMedicalHistory,
        smoking: smoking ?? this.smoking,
        alcohol: alcohol ?? this.alcohol,
        exerciseFrequency: exerciseFrequency ?? this.exerciseFrequency,
        emergencyContacts: emergencyContacts ?? this.emergencyContacts,
        latitude: latitude ?? this.latitude,
        longitude: longitude ?? this.longitude,
        profileImagePath: profileImagePath ?? this.profileImagePath,
      );

  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'sex': sex,
        'preExistingConditions': preExistingConditions,
        'allergies': allergies,
        'role': role,
        'bloodType': bloodType,
        'bio': bio,
        'phone': phone,
        'dob': dob,
        'height': height,
        'weight': weight,
        'medications': medications,
        'familyMedicalHistory': familyMedicalHistory,
        'smoking': smoking,
        'alcohol': alcohol,
        'exerciseFrequency': exerciseFrequency,
        'emergencyContacts': emergencyContacts.map((e) => e.toMap()).toList(),
        'latitude': latitude,
        'longitude': longitude,
        'profileImagePath': profileImagePath,
      };

  factory UserProfile.fromMap(Map<String, dynamic> map) => UserProfile(
        name: map['name'] as String,
        age: map['age'] as int?,
        sex: map['sex'] as String?,
        preExistingConditions: List<String>.from(map['preExistingConditions'] as List? ?? []),
        allergies: List<String>.from(map['allergies'] as List? ?? []),
        role: map['role'] as String? ?? 'user',
        bloodType: map['bloodType'] as String?,
        bio: map['bio'] as String?,
        phone: map['phone'] as String?,
        dob: map['dob'] as String?,
        height: (map['height'] as num?)?.toDouble(),
        weight: (map['weight'] as num?)?.toDouble(),
        medications: List<String>.from(map['medications'] as List? ?? []),
        familyMedicalHistory: List<String>.from(map['familyMedicalHistory'] as List? ?? []),
        smoking: map['smoking'] as bool? ?? false,
        alcohol: map['alcohol'] as bool? ?? false,
        exerciseFrequency: map['exerciseFrequency'] as String?,
        emergencyContacts: (map['emergencyContacts'] as List?)
                ?.map((e) => EmergencyContact.fromMap(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
        latitude: map['latitude'] as double?,
        longitude: map['longitude'] as double?,
        profileImagePath: map['profileImagePath'] as String?,
      );
}
