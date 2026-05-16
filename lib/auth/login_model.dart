class LoginModel {
  String phoneNumber;
  String? verificationId;
  String smsCode;

  LoginModel({this.phoneNumber = '', this.verificationId, this.smsCode = ''});

  bool validatePhone() {
    final phone = phoneNumber.trim();
    return phone.isNotEmpty && phone.startsWith('+') && phone.length >= 10;
  }

  bool validateSmsCode() {
    final sms = smsCode.trim();
    return sms.length >= 4;
  }

  Map<String, String> toMap() => {
    'phoneNumber': phoneNumber,
    'verificationId': verificationId ?? '',
    'smsCode': smsCode,
  };
}
