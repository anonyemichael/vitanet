import 'package:flutter/material.dart';

class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  final String? Function(String?)? validator;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.suffixIcon,
    this.validator,
  });


  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);


    return TextFormField(
      controller: controller,

      obscureText: obscureText,

      keyboardType: keyboardType,

      validator: validator,


      style: theme.textTheme.bodyLarge,


      decoration: InputDecoration(

        labelText: label,

        hintText: hint,


        suffixIcon: suffixIcon,


        filled: true,

        fillColor:
            theme.colorScheme.surface,


        contentPadding:
            const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),


        border:
            OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),

              borderSide:
                  BorderSide(
                    color:
                        theme.dividerColor,
                  ),
            ),


        enabledBorder:
            OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),

              borderSide:
                  BorderSide(
                    color:
                        theme.dividerColor,
                  ),
            ),


        focusedBorder:
            OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),

              borderSide:
                  BorderSide(
                    color:
                        theme.colorScheme.primary,

                    width: 1.5,
                  ),
            ),


        errorBorder:
            OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(16),

              borderSide:
                  BorderSide(
                    color:
                        theme.colorScheme.error,
                  ),
            ),
      ),
    );
  }
}