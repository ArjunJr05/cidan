class AppStrings {
  AppStrings._();

  static const String appName = 'CIDAN';
  static const String appTagline = 'Regulatory Compliance AI';
  static const String help = 'Help';

  // Login
  static const String bankUser = 'Bank User';
  static const String adminStaff = 'Admin/Staff';
  static const String loginTitle = 'Login with your bank email';
  static const String loginSubtitle = 'Enter your official bank email to receive a secure OTP code';
  static const String emailPlaceholder = 'ravi.sharma@abcbank.com';
  static const String sendOtpCode = 'Send OTP Code';
  static const String encryptionNote = 'Your information is encrypted and securely protected.';

  // OTP
  static const String verifyEmailSubtitle = "We've sent a 6-digit code to";
  static const String resendOtpIn = 'Resend OTP in';
  static const String resendOtpNow = 'Resend OTP';
  static const String verifyOtp = 'Verify OTP';
  static const String expiryTitle = 'This code will expire in 5 minutes.';
  static const String expirySubtitle = 'For security, please do not share it with anyone.';

  // Validation
  static const String emptyEmailError = 'Please enter your bank email address';
  static const String invalidEmailError = 'Please enter a valid official bank email';
  static const String incompleteOtpError = 'Please enter all 6 digits of the OTP';
  static const String invalidOtpError = 'Invalid OTP code. Please enter the valid 6-digit code.';
}
