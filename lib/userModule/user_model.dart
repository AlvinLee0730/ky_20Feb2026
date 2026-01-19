class AppUser {
  final String userID;
  final String userName;
  final String? email;
  final String? phoneNumber;
  final String? userPhoto;
  final String accountStatus;
  final String role;

  AppUser({
    required this.userID,
    required this.userName,
    this.email,
    this.phoneNumber,
    this.userPhoto,
    this.accountStatus = 'Active',
    this.role = 'User',
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      userID: json['userID'],
      userName: json['userName'],
      email: json['userEmail'],
      phoneNumber: json['phoneNumber'],
      userPhoto: json['userPhoto'],
      accountStatus: json['accountStatus'] ?? 'Active',
      role: json['role'] ?? 'User',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'userID': userID,
      'userName': userName,
      'userEmail': email,
      'phoneNumber': phoneNumber,
      'userPhoto': userPhoto,
      'accountStatus': accountStatus,
      'role': role,
    };
  }
}
