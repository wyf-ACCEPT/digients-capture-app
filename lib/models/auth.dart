enum AuthIdentifierType { phone, email }

class Profile {
  final String uid;
  final String displayName;
  final String? phone;
  final String? email;
  final String locale;

  const Profile({
    required this.uid,
    required this.displayName,
    this.phone,
    this.email,
    this.locale = 'en',
  });

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        uid: j['uid'] as String,
        displayName: j['displayName'] as String,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
        locale: (j['locale'] as String?) ?? 'en',
      );

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        'locale': locale,
      };
}

class AuthVerifyResponse {
  final String accessToken;
  final String refreshToken;
  final Profile profile;

  const AuthVerifyResponse({
    required this.accessToken,
    required this.refreshToken,
    required this.profile,
  });

  factory AuthVerifyResponse.fromJson(Map<String, dynamic> j) =>
      AuthVerifyResponse(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        profile: Profile.fromJson(j['profile'] as Map<String, dynamic>),
      );
}

class AuthSession {
  final String accessToken;
  final Profile profile;

  const AuthSession({required this.accessToken, required this.profile});
}
