import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:school_attendance/core/auth/auth_notifier.dart';
import 'package:school_attendance/features/auth/repository/auth_repository.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({
    super.key,
    required this.reqId,
    required this.mobile,
    required this.isRegistration,
    this.name,
    this.schoolName,
    this.password,
  });

  final String reqId;
  final String mobile;
  final bool isRegistration;
  final String? name;
  final String? schoolName;
  final String? password;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  String? _error;
  int _resendCooldown = 60;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _otpCtrl.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendCooldown = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendCooldown <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendCooldown = 0);
      } else {
        if (mounted) setState(() => _resendCooldown--);
      }
    });
  }

  Future<void> _verify() async {
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'Enter a 6-digit OTP');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final tokens = await ref.read(authRepositoryProvider).verifyRegistrationOtp(
            reqId: widget.reqId,
            otp: otp,
            name: widget.name ?? '',
            mobile: widget.mobile,
            schoolName: widget.schoolName ?? '',
            password: widget.password ?? '',
          );
      await ref.read(authNotifierProvider.notifier).login(
            accessToken: tokens['access_token']!,
            refreshToken: tokens['refresh_token']!,
            teacherID: tokens['teacher_id']!,
          );
    } on AuthException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Something went wrong. Try again.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _resend() async {
    if (_resendCooldown > 0) return;
    setState(() => _error = null);
    try {
      await ref.read(authRepositoryProvider).retryOtp(reqId: widget.reqId);
      _startResendTimer();
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify OTP'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/register'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Enter the 6-digit OTP sent to +91 ${widget.mobile}',
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextFormField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 6,
                style: const TextStyle(fontSize: 24, letterSpacing: 8),
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  hintText: '------',
                  border: OutlineInputBorder(),
                  counterText: '',
                ),
                onChanged: (v) {
                  if (v.length == 6) _verify();
                },
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _loading ? null : _verify,
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Verify OTP'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _resendCooldown > 0 ? null : _resend,
                child: Text(
                  _resendCooldown > 0
                      ? 'Resend OTP in ${_resendCooldown}s'
                      : 'Resend OTP',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
