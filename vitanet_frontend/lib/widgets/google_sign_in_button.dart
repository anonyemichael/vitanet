import 'package:flutter/material.dart';

class GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool loading;

  const GoogleSignInButton({
    super.key,
    required this.onPressed,
    this.loading = false,
  });


  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);


    return SizedBox(
      width: double.infinity,
      height: 54,

      child: OutlinedButton(

        onPressed:
            loading ? null : onPressed,


        style:
            OutlinedButton.styleFrom(

          backgroundColor:
              theme.colorScheme.surface,


          side: BorderSide(
            color:
                theme.dividerColor,
          ),


          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),

        ),


        child: loading

            ? SizedBox(
                height: 22,
                width: 22,

                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,

                  color:
                      theme.colorScheme.primary,
                ),
              )


            : Row(
                mainAxisAlignment:
                    MainAxisAlignment.center,

                children: [

                  const _GoogleIcon(),


                  const SizedBox(width: 12),


                  Text(
                    "Continue with Google",

                    style:
                        theme.textTheme.labelLarge,
                  ),

                ],
              ),
      ),
    );
  }
}



class _GoogleIcon extends StatelessWidget {

  const _GoogleIcon();


  @override
  Widget build(BuildContext context) {

    return Container(

      width: 24,
      height: 24,


      alignment:
          Alignment.center,


      child:
          const Text(

        "G",

        style: TextStyle(

          fontSize: 20,

          fontWeight:
              FontWeight.w700,

          color:
              Color(0xFF4285F4),

        ),
      ),
    );
  }
}