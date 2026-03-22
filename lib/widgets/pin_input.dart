import 'package:flutter/material.dart';

class PinInput extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const PinInput({
    super.key,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 4,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        hintText: hint,
        counterText: '',
      ),
    );
  }
}
