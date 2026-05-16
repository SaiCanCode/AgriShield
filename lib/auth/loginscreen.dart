import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/routes.dart';
import 'login_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    ref.listen<LoginState>(loginControllerProvider, (previous, next) {
      if (next.user != null && previous?.user == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context).pushReplacementNamed(Routes.dashboard);
        });
      }
    });

    final state = ref.watch(loginControllerProvider);
    final controller = ref.read(loginControllerProvider.notifier);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [ AgriColors.backgroundDark, AgriColors.backgroundSurface, colorScheme.primary.withValues(alpha: 0.28), ],
          ), ),

        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Card(
                  elevation: theme.cardTheme.elevation ?? 0,
                  shadowColor: theme.shadowColor,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withValues(
                                alpha: 0.14,
                              ),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Icon(
                              Icons.phone_iphone_rounded,
                              size: 36,
                              color: AgriColors.primary,
                            ),),
                          const SizedBox(height: 20),
                          Text(
                            'Sign in with your phone number',
                            textAlign: TextAlign.center,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Agrishield will send a one-time code to verify your account.',
                            textAlign: TextAlign.center,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurface.withValues(
                                alpha: 0.75,
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            enabled: !state.isLoading,
                            decoration: InputDecoration(
                              labelText: 'Phone number',
                              hintText: '+2349974321',
                              prefixIcon: const Icon(Icons.call_outlined),
                            ),
                            onChanged: controller.updatePhoneNumber,
                            validator: (value) {
                              final phone = (value ?? '').trim();
                              if (phone.isEmpty) {
                                return 'Enter your phone number';
                              }
                              if (!phone.startsWith('+') || phone.length < 10) {
                                return 'Use country code, e.g. +2349951234567';
                              }
                              return null;
                            },),

                          if (state.isCodeSent) ...[
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _codeController,
                              keyboardType: TextInputType.number,
                              enabled: !state.isLoading,
                              decoration: InputDecoration(
                                labelText: 'Verification code',
                                hintText: 'Enter the 6-digit code',
                                prefixIcon: const Icon(Icons.verified_outlined),
                              ),
                              onChanged: controller.updateSmsCode,
                              validator: (value) {
                                final code = (value ?? '').trim();
                                if (!state.isCodeSent) return null;
                                if (code.length < 4) {
                                  return 'Enter the verification code';
                                }
                                return null;
                              },
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (state.errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: colorScheme.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: colorScheme.errorContainer,
                                ),
                              ),
                              child: Text(
                                state.errorMessage!,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colorScheme.error,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: state.isLoading
                                  ? null
                                  : () async {
                                      FocusScope.of(context).unfocus();

                                      if (!_formKey.currentState!.validate()) {
                                        return;
                                      }

                                      if (!state.isCodeSent) {
                                        await controller.sendOtp();
                                      } else {
                                        await controller.verifyOtp();
                                      }
                                    },
                              child: state.isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.black,
                                            ),
                                      ),
                                    )
                                  : Text(
                                      state.isCodeSent
                                          ? 'Verify code'
                                          : 'Send code',
                                      style: textTheme.labelLarge,
                                    ),
                            ),
                          ),
                          if (state.isCodeSent) ...[
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: state.isLoading
                                  ? null
                                  : () async {
                                      await controller.sendOtp();
                                    },
                              child: const Text('Resend code'),
                            ),
                          ], ],
                      ),),),
                ),),),
          ),),),
    );
  }
}
