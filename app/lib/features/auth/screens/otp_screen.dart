import 'package:flutter/material.dart';

class OtpScreen extends StatelessWidget {
  const OtpScreen({
    super.key,
    required this.reqId,
    required this.mobile,
    required this.isRegistration,
  });

  final String reqId;
  final String mobile;
  final bool isRegistration;

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('OTP — implemented in plan 04-03')),
    );
  }
}
