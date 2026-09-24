import 'package:flutter/material.dart';

const authTeal = Color(0xFF087F83);
const authInk = Color(0xFF17383D);

/// Shared, scrollable authentication layout for phones, tablets and desktops.
class AuthLayout extends StatelessWidget {
  const AuthLayout({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: ColorScheme.fromSeed(seedColor: authTeal),
        textTheme: theme.textTheme.apply(
          bodyColor: authInk,
          displayColor: authInk,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF7FAFA),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          prefixIconColor: authTeal,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD9E5E5)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: authTeal, width: 2),
          ),
          errorMaxLines: 3,
        ),
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF0F6F5),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 900;
              return SingleChildScrollView(
                padding: EdgeInsets.all(wide ? 40 : 20),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: (constraints.maxHeight - (wide ? 80 : 40)).clamp(
                      0,
                      double.infinity,
                    ),
                  ),
                  child: Center(
                    child: Container(
                      constraints: BoxConstraints(maxWidth: wide ? 1080 : 520),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x0D17383D),
                            blurRadius: 40,
                            offset: Offset(0, 16),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: wide
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Expanded(child: _WelcomePanel()),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(40),
                                    child: child,
                                  ),
                                ),
                              ],
                            )
                          : Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  const _Brand(),
                                  const SizedBox(height: 32),
                                  child,
                                ],
                              ),
                            ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({this.inverse = false});
  final bool inverse;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: inverse ? Colors.white24 : const Color(0xFFE4F3F0),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.local_hospital_rounded,
          color: inverse ? Colors.white : authTeal,
          size: 26,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Text(
          'Clinic Solution',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: inverse ? Colors.white : authInk,
          ),
        ),
      ),
    ],
  );
}

class _WelcomePanel extends StatelessWidget {
  const _WelcomePanel();

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 700),
    padding: const EdgeInsets.all(40),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF075D64), Color(0xFF109A95)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Brand(inverse: true),
        const SizedBox(height: 64),
        const Text(
          'Better care.\nSimpler days.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'A little less admin.\nMore time for the people who matter.',
          style: TextStyle(color: Color(0xFFD2EFEB), fontSize: 17, height: 1.6),
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withAlpha(22),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),
          child: const Column(
            children: [
              _Feature(
                Icons.calendar_month_outlined,
                'Appointments, made simple',
                'Plan visits and keep your day organised.',
              ),
              SizedBox(height: 24),
              _Feature(
                Icons.favorite_border_rounded,
                'People at the centre',
                'Connect patients with their clinic.',
              ),
              SizedBox(height: 24),
              _Feature(
                Icons.apartment_rounded,
                'Your practice, connected',
                'One place to start your clinic day.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Feature extends StatelessWidget {
  const _Feature(this.icon, this.title, this.description);
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, color: const Color(0xFFBCEDE0), size: 24),
      const SizedBox(width: 14),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              description,
              style: const TextStyle(
                color: Color(0xFFD2EFEB),
                height: 1.5,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class AuthTextField extends StatefulWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText = '',
    this.prefixIcon,
    this.validator,
    this.keyboardType = TextInputType.text,
    this.isPassword = false,
  });
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData? prefixIcon;
  final String? Function(String?)? validator;
  final TextInputType keyboardType;
  final bool isPassword;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _visible = false;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    keyboardType: widget.keyboardType,
    validator: widget.validator,
    obscureText: widget.isPassword && !_visible,
    autocorrect:
        !widget.isPassword && widget.keyboardType != TextInputType.emailAddress,
    enableSuggestions: !widget.isPassword,
    style: const TextStyle(fontSize: 16, color: authInk),
    decoration: InputDecoration(
      labelText: widget.labelText,
      hintText: widget.hintText.isEmpty ? null : widget.hintText,
      prefixIcon: widget.prefixIcon == null ? null : Icon(widget.prefixIcon),
      suffixIcon: widget.isPassword
          ? IconButton(
              tooltip: _visible ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => _visible = !_visible),
              icon: Icon(
                _visible
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
              ),
            )
          : null,
    ),
  );
}

class AuthButton extends StatelessWidget {
  const AuthButton({super.key, required this.text, required this.onPressed});
  final String text;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: authTeal,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: onPressed,
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
  );
}
