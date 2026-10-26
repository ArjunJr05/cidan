import '../constants/app_strings.dart';

class Validators {
  Validators._();

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.emptyEmailError;
    }
    final email = value.trim();
    // Regular expression for email validation
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(email)) {
      return AppStrings.invalidEmailError;
    }
    return null;
  }

  static String? validateEmailOrPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return AppStrings.emptyEmailError;
    }
    final input = value.trim();
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    final phoneRegex = RegExp(r'^(\+?[0-9]{1,4}[\-\s]?)?[0-9]{7,15}$');
    if (!emailRegex.hasMatch(input) && !phoneRegex.hasMatch(input)) {
      return 'Please enter a valid bank email or mobile number';
    }
    return null;
  }

  static String? validateOtp(String? value) {
    if (value == null || value.trim().length < 6) {
      return AppStrings.incompleteOtpError;
    }
    if (!RegExp(r'^[0-9]{6}$').hasMatch(value.trim())) {
      return AppStrings.invalidOtpError;
    }
    return null;
  }
}
