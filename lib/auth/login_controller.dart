import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'auth_service.dart';
import 'login_model.dart';

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final loginControllerProvider =
    StateNotifierProvider<LoginController, LoginState>((ref) {
      return LoginController(ref.read(authServiceProvider));
    });

class LoginState {
  final LoginModel form;
  final bool isLoading;
  final bool isCodeSent;
  final String? verificationId;
  final String? errorMessage;
  final User? user;

  const LoginState({
    required this.form,
    this.isLoading = false,
    this.isCodeSent = false,
    this.verificationId,
    this.errorMessage,
    this.user,
  });

  LoginState copyWith({
    LoginModel? form,
    bool? isLoading,
    bool? isCodeSent,
    String? verificationId,
    String? errorMessage,
    bool clearErrorMessage = false,
    User? user,
    bool clearUser = false,
  }) {
    return LoginState(
      form: form ?? this.form,
      isLoading: isLoading ?? this.isLoading,
      isCodeSent: isCodeSent ?? this.isCodeSent,
      verificationId: verificationId ?? this.verificationId,
      errorMessage: clearErrorMessage ? null : errorMessage ?? this.errorMessage,
      user: clearUser ? null : user ?? this.user,
    );
  }

  factory LoginState.initial() => LoginState(form: LoginModel());
}

class LoginController extends StateNotifier<LoginState> {
  LoginController(this._authService) : super(LoginState.initial());

  final AuthService _authService;

  void updatePhoneNumber(String value) {
    state = state.copyWith(
      form: LoginModel(
        phoneNumber: value,
        verificationId: state.verificationId,
        smsCode: state.form.smsCode,
      ),
      clearErrorMessage: true,
    );
  }

  void updateSmsCode(String value) {
    state = state.copyWith(
      form: LoginModel(
        phoneNumber: state.form.phoneNumber,
        verificationId: state.verificationId,
        smsCode: value,
      ),
      clearErrorMessage: true,
    );
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }

  Future<bool> sendOtp() async {
    if (!state.form.validatePhone()) {
      state = state.copyWith(
        errorMessage:
            'Enter a valid phone number in international format, e.g. +15551234567.',
      );
      return false;
    }

    state = state.copyWith(
      isLoading: true,
      clearErrorMessage: true,
      isCodeSent: false,
    );

    try {
      await _authService.verifyPhoneNumber(
        phoneNumber: state.form.phoneNumber.trim(),
        verificationCompleted: (credential) async {
          final result = await _authService.signInWithCredential(credential);
          state = state.copyWith(
            isLoading: false,
            isCodeSent: true,
            user: result.user,
            clearErrorMessage: true,
          );
        },
        verificationFailed: (exception) {
          state = state.copyWith(
            isLoading: false,
            errorMessage: _mapFirebaseAuthException(exception),
          );
        },
        codeSent: (verificationId, resendToken) {
          state = state.copyWith(
            isLoading: false,
            isCodeSent: true,
            verificationId: verificationId,
            form: LoginModel(
              phoneNumber: state.form.phoneNumber,
              verificationId: verificationId,
              smsCode: state.form.smsCode,
            ),
            clearErrorMessage: true,
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          state = state.copyWith(
            verificationId: verificationId,
            isLoading: false,
          );
        },
      );
      return true;
    } on FirebaseAuthException catch (exception) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapFirebaseAuthException(exception),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'AgriShield failed to send the OTP. Please try again.',
      );
      return false;
    }
  }

  Future<bool> verifyOtp() async {
    if (state.verificationId == null || state.verificationId!.isEmpty) {
      state = state.copyWith(errorMessage: 'Request an OTP first.');
      return false;
    }

    if (!state.form.validateSmsCode()) {
      state = state.copyWith(
        errorMessage: 'Enter the verification code sent to your phone.',
      );
      return false;
    }

    state = state.copyWith(isLoading: true, clearErrorMessage: true);

    try {
      final result = await _authService.signInWithSmsCode(
        verificationId: state.verificationId!,
        smsCode: state.form.smsCode.trim(),
      );
      state = state.copyWith(
        isLoading: false,
        user: result.user,
        clearErrorMessage: true,
      );

      return true;
    } on FirebaseAuthException catch (exception) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: _mapFirebaseAuthException(exception),
      );
      return false;
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'AgriShield failed to verify the code. Please try again.',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _authService.signOut();
    state = LoginState.initial();
  }

  String _mapFirebaseAuthException(FirebaseAuthException exception) {
    switch (exception.code) {
      case 'invalid-phone-number':
        return 'The phone number format is invalid.';
      case 'captcha-check-failed':
        return 'Verification failed. Please try again.';
      case 'invalid-verification-code':
        return 'The verification code is invalid.';
      case 'session-expired':
        return 'The verification code has expired. Request a new one.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return exception.message ?? 'Authentication failed. Please try again.';
    }
  }
}
