import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Paytm exact color swatch ──────────────────────────────────────────────
  static const Color swatch50       = Color(0xFFFFF3E0);
  static const Color primary        = Color(0xFFFF6600);
  static const Color primaryDark    = Color(0xFFCC4400);
  static const Color primaryLight   = Color(0xFFFF8533);
  static const Color secondary      = Color(0xFF00BAF2);
  static const Color secondaryDark  = Color(0xFF0099CC);
  static const Color success        = Color(0xFF00D474);
  static const Color successDark    = Color(0xFF00A85A);
  static const Color error          = Color(0xFFFF3B30);
  static const Color errorDark      = Color(0xFFCC2E25);

  // ── Legacy aliases (existing screens reference these) ─────────────────────
  static const Color primaryBlue    = Color(0xFF0066CC);
  static const Color accentOrange   = primary;
  static const Color darkOrange     = primaryDark;
  static const Color successGreen   = success;
  static const Color errorRed       = error;

  // ── Neutrals ──────────────────────────────────────────────────────────────
  static const Color background     = Color(0xFFF5F6FA);
  static const Color cardWhite      = Color(0xFFFFFFFF);
  static const Color textDark       = Color(0xFF1A1A2E);
  static const Color textGrey       = Color(0xFF6B7280);
  static const Color divider        = Color(0xFFE5E7EB);
  static const Color shimmer        = Color(0xFFEEEEEE);

  // ── Gradients ─────────────────────────────────────────────────────────────
  static const LinearGradient paytmGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient paytmHeaderGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF0066CC), Color(0xFF004A99)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient successGradient = LinearGradient(
    colors: [success, successDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [secondary, secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Material swatch ───────────────────────────────────────────────────────
  static const MaterialColor paytmSwatch = MaterialColor(0xFFFF6600, {
    50:  Color(0xFFFFF3E0),
    100: Color(0xFFFFE0B2),
    200: Color(0xFFFFCC80),
    300: Color(0xFFFFB74D),
    400: Color(0xFFFFA726),
    500: Color(0xFFFF6600),
    600: Color(0xFFF57C00),
    700: Color(0xFFE65100),
    800: Color(0xFFCC4400),
    900: Color(0xFF9E2A00),
  });

  // ── ThemeData ─────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primarySwatch: paytmSwatch,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: Colors.white,
        primaryContainer: swatch50,
        onPrimaryContainer: primaryDark,
        secondary: secondary,
        onSecondary: Colors.white,
        secondaryContainer: Color(0xFFE0F7FF),
        onSecondaryContainer: secondaryDark,
        error: error,
        onError: Colors.white,
        errorContainer: Color(0xFFFFEDEC),
        onErrorContainer: errorDark,
        surface: cardWhite,
        onSurface: textDark,
        surfaceContainerHighest: Color(0xFFF0F0F0),
        onSurfaceVariant: textGrey,
        outline: divider,
        outlineVariant: Color(0xFFEEEEEE),
        shadow: Colors.black,
        scrim: Colors.black,
        inverseSurface: textDark,
        onInverseSurface: cardWhite,
        inversePrimary: primaryLight,
      ),
      scaffoldBackgroundColor: background,
      textTheme: GoogleFonts.robotoTextTheme().copyWith(
        displayLarge: GoogleFonts.roboto(
            fontSize: 32, fontWeight: FontWeight.w800, color: textDark),
        displayMedium: GoogleFonts.roboto(
            fontSize: 28, fontWeight: FontWeight.w700, color: textDark),
        headlineLarge: GoogleFonts.roboto(
            fontSize: 24, fontWeight: FontWeight.w700, color: textDark),
        headlineMedium: GoogleFonts.roboto(
            fontSize: 22, fontWeight: FontWeight.w700, color: textDark),
        headlineSmall: GoogleFonts.roboto(
            fontSize: 20, fontWeight: FontWeight.w600, color: textDark),
        titleLarge: GoogleFonts.roboto(
            fontSize: 18, fontWeight: FontWeight.w600, color: textDark),
        titleMedium: GoogleFonts.roboto(
            fontSize: 16, fontWeight: FontWeight.w500, color: textDark),
        titleSmall: GoogleFonts.roboto(
            fontSize: 14, fontWeight: FontWeight.w500, color: textDark),
        bodyLarge: GoogleFonts.roboto(
            fontSize: 15, fontWeight: FontWeight.w400, color: textDark),
        bodyMedium: GoogleFonts.roboto(
            fontSize: 13, fontWeight: FontWeight.w400, color: textGrey),
        bodySmall: GoogleFonts.roboto(
            fontSize: 12, fontWeight: FontWeight.w400, color: textGrey),
        labelLarge: GoogleFonts.roboto(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: textDark),
        labelMedium: GoogleFonts.roboto(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.4,
            color: textGrey),
        labelSmall: GoogleFonts.roboto(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.5,
            color: textGrey),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        shadowColor: Colors.black26,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white, size: 22),
        actionsIconTheme: const IconThemeData(color: Colors.white, size: 22),
        titleTextStyle: GoogleFonts.roboto(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),
      cardTheme: CardTheme(
        elevation: 12,
        shadowColor: Colors.black.withOpacity(0.07),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: cardWhite,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 6,
          shadowColor: primary.withOpacity(0.40),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(double.infinity, 54),
          textStyle: GoogleFonts.roboto(
              fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          minimumSize: const Size(double.infinity, 54),
          textStyle: GoogleFonts.roboto(
              fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.4),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.roboto(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        hintStyle: GoogleFonts.roboto(color: textGrey, fontSize: 14),
        labelStyle: GoogleFonts.roboto(color: textGrey, fontSize: 14),
        floatingLabelStyle: GoogleFonts.roboto(color: primary, fontSize: 13),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: swatch50,
        disabledColor: Colors.grey.shade100,
        side: const BorderSide(color: divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        labelStyle:
            GoogleFonts.roboto(fontSize: 13, fontWeight: FontWeight.w500),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shadowColor: Colors.black12,
        elevation: 8,
        indicatorColor: primary.withOpacity(0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return GoogleFonts.roboto(
            fontSize: 11,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            color: selected ? primary : textGrey,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? primary : textGrey,
            size: 22,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: textDark,
        contentTextStyle:
            GoogleFonts.roboto(color: Colors.white, fontSize: 13),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: Colors.white,
        elevation: 24,
        shadowColor: Colors.black26,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titleTextStyle: GoogleFonts.roboto(
            fontSize: 18, fontWeight: FontWeight.w700, color: textDark),
        contentTextStyle:
            GoogleFonts.roboto(fontSize: 14, color: textGrey),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        elevation: 16,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        surfaceTintColor: Colors.white,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: swatch50,
        circularTrackColor: swatch50,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected) ? primary : Colors.white),
        trackColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? primary.withOpacity(0.4)
                : Colors.grey.shade300),
      ),
    );
  }
}

// ── PaytmAppBar ───────────────────────────────────────────────────────────────
class PaytmAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final bool showBack;
  final Widget? bottom;
  final double bottomHeight;
  final VoidCallback? onBack;

  const PaytmAppBar({
    super.key,
    required this.title,
    this.actions,
    this.showBack = true,
    this.bottom,
    this.bottomHeight = 0,
    this.onBack,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + bottomHeight);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.paytmHeaderGradient,
        boxShadow: [
          BoxShadow(
            color: Color(0x33FF6600),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: showBack
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Colors.white, size: 20),
                onPressed: onBack ?? () => Navigator.maybePop(context),
                splashRadius: 22,
              )
            : null,
        automaticallyImplyLeading: showBack,
        title: Text(
          title,
          style: GoogleFonts.roboto(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
        actions: actions,
        bottom: bottom != null
            ? PreferredSize(
                preferredSize: Size.fromHeight(bottomHeight),
                child: bottom!,
              )
            : null,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
    );
  }
}

// ── PaytmButton ───────────────────────────────────────────────────────────────
class PaytmButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final Gradient? gradient;
  final double height;

  const PaytmButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.gradient,
    this.height = 54,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null && !isLoading;
    return SizedBox(
      width: double.infinity,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: disabled ? null : (gradient ?? AppTheme.paytmGradient),
          color: disabled ? AppTheme.divider : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.38),
                    blurRadius: 14,
                    offset: const Offset(0, 5),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: (isLoading || disabled) ? null : onPressed,
            borderRadius: BorderRadius.circular(14),
            splashColor: Colors.white24,
            highlightColor: Colors.white10,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: 20),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          label,
                          style: GoogleFonts.roboto(
                            color: disabled ? AppTheme.textGrey : Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── PaytmGreenButton ──────────────────────────────────────────────────────────
class PaytmGreenButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  const PaytmGreenButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PaytmButton(
      label: label,
      onPressed: onPressed,
      isLoading: isLoading,
      icon: icon,
      gradient: AppTheme.successGradient,
    );
  }
}

// ── PaytmCard ─────────────────────────────────────────────────────────────────
class PaytmCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double elevation;
  final double borderRadius;
  final Color? color;
  final VoidCallback? onTap;

  const PaytmCard({
    super.key,
    required this.child,
    this.padding,
    this.elevation = 12,
    this.borderRadius = 20,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: elevation,
      shadowColor: Colors.black.withOpacity(0.07),
      borderRadius: BorderRadius.circular(borderRadius),
      color: color ?? Colors.white,
      surfaceTintColor: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        splashColor: AppTheme.primary.withOpacity(0.05),
        highlightColor: AppTheme.primary.withOpacity(0.03),
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}

// ── PaytmAmountChip ───────────────────────────────────────────────────────────
class PaytmAmountChip extends StatelessWidget {
  final double amount;
  final bool isSelected;
  final VoidCallback onTap;

  const PaytmAmountChip({
    super.key,
    required this.amount,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          gradient: isSelected ? AppTheme.paytmGradient : null,
          color: isSelected ? null : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.transparent : AppTheme.divider,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withOpacity(0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Text(
          '₹${amount.toStringAsFixed(0)}',
          style: GoogleFonts.roboto(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppTheme.textDark,
          ),
        ),
      ),
    );
  }
}

// ── PaytmStatusBadge ──────────────────────────────────────────────────────────
enum PaytmBadgeVariant { success, pending, failed }

class PaytmStatusBadge extends StatelessWidget {
  final String label;
  final PaytmBadgeVariant variant;

  const PaytmStatusBadge({
    super.key,
    required this.label,
    required this.variant,
  });

  factory PaytmStatusBadge.fromStatus(String status) {
    final v = status.toUpperCase();
    final variant = v == 'SUCCESS'
        ? PaytmBadgeVariant.success
        : v == 'FAILED' || v == 'ERROR'
            ? PaytmBadgeVariant.failed
            : PaytmBadgeVariant.pending;
    return PaytmStatusBadge(label: status, variant: variant);
  }

  Color get _color => switch (variant) {
        PaytmBadgeVariant.success => AppTheme.success,
        PaytmBadgeVariant.failed  => AppTheme.error,
        PaytmBadgeVariant.pending => AppTheme.textGrey,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: _color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label.toUpperCase(),
            style: GoogleFonts.roboto(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _color,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

// ── StatusBadge (legacy alias — keeps existing screens compiling) ─────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final bool isSuccess;

  const StatusBadge({super.key, required this.label, required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    return PaytmStatusBadge(
      label: label,
      variant: isSuccess ? PaytmBadgeVariant.success : PaytmBadgeVariant.failed,
    );
  }
}
