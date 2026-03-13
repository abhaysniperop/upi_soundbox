import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/api_service.dart';
import '../services/api_config.dart';
import '../theme/app_theme.dart';

enum _SplashState { animating, checking, online, offline, retrying }

class SplashScreen extends StatefulWidget {
  final Widget child;
  const SplashScreen({super.key, required this.child});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  _SplashState _state = _SplashState.animating;
  PingResult? _pingResult;
  int _retryCount = 0;
  final _pingService = PingService();

  // ── Logo entrance: 0 → 600ms ──────────────────────────────────────────────
  late AnimationController _logoCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoY;

  // ── Wordmark slide-in: 400 → 1000ms ──────────────────────────────────────
  late AnimationController _wordCtrl;
  late Animation<double> _wordOpacity;
  late Animation<double> _wordX;

  // ── Tagline fade: 800 → 1400ms ────────────────────────────────────────────
  late AnimationController _tagCtrl;
  late Animation<double> _tagOpacity;

  // ── Ring pulse (infinite while animating) ─────────────────────────────────
  late AnimationController _ringCtrl;
  late Animation<double> _ringScale;
  late Animation<double> _ringOpacity;

  // ── Shimmer sweep on logo icon ────────────────────────────────────────────
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerX;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _runSequence();
  }

  void _initAnimations() {
    _logoCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _logoScale = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.4)));
    _logoY = Tween<double>(begin: 40.0, end: 0.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.easeOutCubic));

    _wordCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _wordOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _wordCtrl, curve: Curves.easeOut));
    _wordX = Tween<double>(begin: 24.0, end: 0.0).animate(
        CurvedAnimation(parent: _wordCtrl, curve: Curves.easeOutCubic));

    _tagCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _tagOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _tagCtrl, curve: Curves.easeIn));

    _ringCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat();
    _ringScale = Tween<double>(begin: 0.75, end: 1.6).animate(
        CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOut));
    _ringOpacity = Tween<double>(begin: 0.45, end: 0.0).animate(
        CurvedAnimation(parent: _ringCtrl, curve: Curves.easeIn));

    _shimmerCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: false);
    _shimmerX = Tween<double>(begin: -1.5, end: 2.5).animate(
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));
  }

  Future<void> _runSequence() async {
    // Logo entrance
    await Future.delayed(const Duration(milliseconds: 150));
    _logoCtrl.forward();

    // Wordmark
    await Future.delayed(const Duration(milliseconds: 400));
    _wordCtrl.forward();

    // Tagline
    await Future.delayed(const Duration(milliseconds: 400));
    _tagCtrl.forward();

    // Wait until 3 seconds total have passed then check server
    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) {
      setState(() => _state = _SplashState.checking);
      _ringCtrl.stop();
      _shimmerCtrl.stop();
      _checkServer();
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _wordCtrl.dispose();
    _tagCtrl.dispose();
    _ringCtrl.dispose();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkServer() async {
    setState(() => _state = _SplashState.checking);
    final result = await _pingService.call();
    if (!mounted) return;
    setState(() {
      _pingResult = result;
      _state = result.isOnline ? _SplashState.online : _SplashState.offline;
    });
    if (result.isOnline) {
      await Future.delayed(const Duration(milliseconds: 700));
      if (mounted) _navigateToApp();
    }
  }

  Future<void> _retry() async {
    setState(() {
      _retryCount++;
      _state = _SplashState.retrying;
    });
    await Future.delayed(const Duration(milliseconds: 350));
    await _checkServer();
  }

  void _navigateToApp() {
    Navigator.of(context).pushReplacement(PageRouteBuilder(
      pageBuilder: (_, animation, __) => widget.child,
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
      transitionDuration: const Duration(milliseconds: 400),
    ));
  }

  void _skipOffline() => _navigateToApp();

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.paytmHeaderGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              children: [
                const Spacer(flex: 2),
                _buildLogoSection(),
                const SizedBox(height: 56),
                _buildStatusSection(),
                const Spacer(flex: 3),
                _buildFooter(),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoSection() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoCtrl, _wordCtrl, _tagCtrl]),
      builder: (_, __) {
        return Column(
          children: [
            // Ring pulse behind icon
            Stack(
              alignment: Alignment.center,
              children: [
                if (_state == _SplashState.animating)
                  AnimatedBuilder(
                    animation: _ringCtrl,
                    builder: (_, __) => Opacity(
                      opacity: _ringOpacity.value,
                      child: Transform.scale(
                        scale: _ringScale.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.6),
                                width: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                // Icon with shimmer
                Opacity(
                  opacity: _logoOpacity.value,
                  child: Transform.translate(
                    offset: Offset(0, _logoY.value),
                    child: Transform.scale(
                      scale: _logoScale.value,
                      child: _buildIconBox(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            // Wordmark
            Opacity(
              opacity: _wordOpacity.value,
              child: Transform.translate(
                offset: Offset(_wordX.value, 0),
                child: Text(
                  'UPI Soundbox',
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Tagline
            Opacity(
              opacity: _tagOpacity.value,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 22,
                    height: 1.5,
                    color: Colors.white.withOpacity(0.4),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'PAYMENT INJECTOR',
                    style: GoogleFonts.roboto(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 3.0,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 22,
                    height: 1.5,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildIconBox() {
    return AnimatedBuilder(
      animation: _shimmerCtrl,
      builder: (_, child) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              child!,
              if (_state == _SplashState.animating)
                Positioned.fill(
                  child: _ShimmerOverlay(progress: _shimmerX.value),
                ),
            ],
          ),
        );
      },
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
              color: Colors.white.withOpacity(0.35), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Icon(
          Icons.account_balance_wallet_rounded,
          color: Colors.white,
          size: 50,
        ),
      ),
    );
  }

  Widget _buildStatusSection() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      child: switch (_state) {
        _SplashState.animating                              => const SizedBox.shrink(key: ValueKey('anim')),
        _SplashState.checking || _SplashState.retrying     => _buildChecking(),
        _SplashState.online                                => _buildOnline(),
        _SplashState.offline                               => _buildOffline(),
      },
    );
  }

  Widget _buildChecking() {
    return Column(
      key: const ValueKey('checking'),
      children: [
        const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
        ),
        const SizedBox(height: 14),
        Text(
          _state == _SplashState.retrying
              ? 'Retrying... (attempt $_retryCount)'
              : 'Connecting to server...',
          style: GoogleFonts.roboto(
              color: Colors.white.withOpacity(0.85), fontSize: 14),
        ),
        const SizedBox(height: 5),
        Text(
          _shortenUrl(kApiBase),
          style: GoogleFonts.robotoMono(
              color: Colors.white.withOpacity(0.5), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildOnline() {
    return Column(
      key: const ValueKey('online'),
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: AppTheme.success.withOpacity(0.18),
            shape: BoxShape.circle,
            border: Border.all(
                color: AppTheme.success.withOpacity(0.5), width: 1.5),
          ),
          child: const Icon(Icons.check_circle_rounded,
              color: AppTheme.success, size: 27),
        ),
        const SizedBox(height: 13),
        Text(
          'Server online',
          style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
        if (_pingResult != null) ...[
          const SizedBox(height: 8),
          _buildPingStats(),
        ],
      ],
    );
  }

  Widget _buildOffline() {
    return Column(
      key: const ValueKey('offline'),
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
            border:
                Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          ),
          child: Icon(Icons.cloud_off_rounded,
              color: Colors.white.withOpacity(0.8), size: 25),
        ),
        const SizedBox(height: 13),
        Text(
          'Server unreachable',
          style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          'Check API URL in api_config.dart',
          style: GoogleFonts.roboto(
              color: Colors.white.withOpacity(0.6), fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionButton(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onTap: _retry,
                primary: true),
            const SizedBox(width: 10),
            _ActionButton(
                label: 'Continue offline',
                icon: Icons.arrow_forward_rounded,
                onTap: _skipOffline,
                primary: false),
          ],
        ),
      ],
    );
  }

  Widget _buildPingStats() {
    final r = _pingResult!;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _StatChip(
          label: '${r.latencyMs}ms',
          icon: Icons.speed_rounded,
          color: r.latencyMs < 300
              ? AppTheme.success
              : r.latencyMs < 800
                  ? Colors.amber
                  : AppTheme.error,
        ),
        if (r.uptime != null) ...[
          const SizedBox(width: 8),
          _StatChip(
            label: _formatUptime(r.uptime!),
            icon: Icons.timer_outlined,
            color: Colors.white,
          ),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Text(
      'v1.0.0  •  Paytm Style',
      style: GoogleFonts.roboto(
          color: Colors.white.withOpacity(0.38),
          fontSize: 11,
          letterSpacing: 0.5),
    );
  }

  String _shortenUrl(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return url;
    }
  }

  String _formatUptime(double seconds) {
    if (seconds < 60) return '${seconds.toInt()}s up';
    if (seconds < 3600) return '${(seconds / 60).toInt()}m up';
    return '${(seconds / 3600).toStringAsFixed(1)}h up';
  }
}

// ── Shimmer overlay painted diagonally across the icon ───────────────────────
class _ShimmerOverlay extends StatelessWidget {
  final double progress;
  const _ShimmerOverlay({required this.progress});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ShimmerPainter(progress: progress));
  }
}

class _ShimmerPainter extends CustomPainter {
  final double progress;
  const _ShimmerPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final x = progress * size.width;
    final paint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.white.withOpacity(0.0),
          Colors.white.withOpacity(0.28),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
        transform: GradientRotation(pi / 5),
      ).createShader(Rect.fromLTWH(x - 40, 0, 80, size.height));
    canvas.drawRect(Rect.fromLTWH(x - 40, 0, 80, size.height), paint);
  }

  @override
  bool shouldRepaint(_ShimmerPainter old) => old.progress != progress;
}

// ── Shared sub-widgets ────────────────────────────────────────────────────────
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.primary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
        decoration: BoxDecoration(
          color: primary ? Colors.white : Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(11),
          border: primary
              ? null
              : Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 16,
                color: primary ? AppTheme.primary : Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: primary ? AppTheme.primary : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;

  const _StatChip(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.roboto(
                  fontSize: 12, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}
