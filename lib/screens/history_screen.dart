import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../models/attack_model.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<AttackModel> _attacks = [];
  List<AttackModel> _filtered = [];
  bool _isLoading = true;
  String _filter = 'all';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final attacks = await DatabaseService.instance.getHistory();
    setState(() {
      _attacks = attacks;
      _applyFilter(_filter);
      _isLoading = false;
    });
  }

  void _applyFilter(String filter) {
    setState(() {
      _filter = filter;
      switch (filter) {
        case 'success':
          _filtered = _attacks.where((a) => a.isSuccess).toList();
          break;
        case 'failed':
          _filtered = _attacks.where((a) => !a.isSuccess).toList();
          break;
        default:
          _filtered = List.from(_attacks);
      }
    });
  }

  Future<void> _deleteAttack(String id) async {
    await DatabaseService.instance.deleteAttack(id);
    _load();
  }

  Future<void> _clearAll() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Clear History',
            style: GoogleFonts.roboto(fontWeight: FontWeight.w700)),
        content: const Text('Are you sure? This will delete all attack history.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.instance.clearHistory();
      _load();
    }
  }

  void _showDetail(AttackModel attack) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Attack Detail',
                    style: GoogleFonts.roboto(
                        fontSize: 17, fontWeight: FontWeight.w700)),
                const Spacer(),
                StatusBadge(
                  label: attack.status,
                  isSuccess: attack.isSuccess,
                ),
              ],
            ),
            const SizedBox(height: 20),
            _detailRow('ID', attack.id),
            _detailRow('Timestamp',
                DateFormat('dd MMM yyyy, hh:mm:ss a').format(attack.timestamp)),
            _detailRow('Target IP', attack.targetIP),
            _detailRow('Amount', '₹${attack.amount.toStringAsFixed(2)}'),
            _detailRow('Vendor', attack.vendor.toUpperCase()),
            _detailRow('Status', attack.status),
            if (attack.response != null && attack.response!.isNotEmpty)
              _detailRow('Response', attack.response!),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: GoogleFonts.roboto(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.textGrey)),
          ),
          Expanded(
            child: Text(value,
                style: GoogleFonts.robotoMono(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textDark)),
          ),
        ],
      ),
    );
  }

  double get _totalSuccess =>
      _attacks.where((a) => a.isSuccess).fold(0.0, (sum, a) => sum + a.amount);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppTheme.primaryBlue,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              backgroundColor: AppTheme.primaryBlue,
              expandedHeight: 180,
              actions: [
                if (_attacks.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined,
                        color: Colors.white),
                    onPressed: _clearAll,
                    tooltip: 'Clear all',
                  ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(gradient: AppTheme.blueGradient),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Attack History',
                              style: GoogleFonts.roboto(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                              )),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildHeaderStat('${_attacks.length}', 'Total'),
                              const SizedBox(width: 20),
                              _buildHeaderStat(
                                  '${_attacks.where((a) => a.isSuccess).length}',
                                  'Success'),
                              const SizedBox(width: 20),
                              _buildHeaderStat(
                                  '₹${_totalSuccess.toStringAsFixed(0)}',
                                  'Injected'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: _buildFilterChips(),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                  child:
                      CircularProgressIndicator(color: AppTheme.primaryBlue),
                ),
              )
            else if (_filtered.isEmpty)
              SliverFillRemaining(child: _buildEmptyState())
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                sliver: SliverToBoxAdapter(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _filtered.length,
                    itemBuilder: (context, index) {
                      final attack = _filtered[index];
                      final showHeader = index == 0 ||
                          !_isSameDay(attack.timestamp,
                              _filtered[index - 1].timestamp);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeader) ...[
                            if (index != 0) const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                _formatDateHeader(attack.timestamp),
                                style: GoogleFonts.roboto(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textGrey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                          _buildAttackCard(attack),
                        ],
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String value, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(value,
            style: GoogleFonts.roboto(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            )),
        Text(label,
            style: GoogleFonts.roboto(
                color: Colors.white.withOpacity(0.75), fontSize: 12)),
      ],
    );
  }

  Widget _buildFilterChips() {
    final filters = [
      {'key': 'all', 'label': 'All'},
      {'key': 'success', 'label': 'Success'},
      {'key': 'failed', 'label': 'Failed'},
    ];
    return Row(
      children: filters.map((f) {
        final isSelected = _filter == f['key'];
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => _applyFilter(f['key']!),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primaryBlue : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.divider,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        )
                      ]
                    : null,
              ),
              child: Text(
                f['label']!,
                style: GoogleFonts.roboto(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textGrey,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildAttackCard(AttackModel attack) {
    final vendorColors = {
      'paytm': const Color(0xFF0066CC),
      'phonepe': const Color(0xFF5F259F),
      'gpay': const Color(0xFF4285F4),
      'bharatpe': const Color(0xFF00C853),
      'generic': const Color(0xFF607D8B),
    };
    final vendorIcons = {
      'paytm': '₹',
      'phonepe': 'P',
      'gpay': 'G',
      'bharatpe': 'B',
      'generic': 'U',
    };
    final color = vendorColors[attack.vendor] ?? AppTheme.primaryBlue;
    final icon = vendorIcons[attack.vendor] ?? '?';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: Key(attack.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: AppTheme.errorRed,
            borderRadius: BorderRadius.circular(16),
          ),
          child:
              const Icon(Icons.delete_outline, color: Colors.white, size: 24),
        ),
        confirmDismiss: (_) async {
          return await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              title: Text('Delete',
                  style: GoogleFonts.roboto(fontWeight: FontWeight.w700)),
              content: const Text('Delete this attack record?'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorRed),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
        },
        onDismissed: (_) => _deleteAttack(attack.id),
        child: GestureDetector(
          onTap: () => _showDetail(attack),
          child: PaytmCard(
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Center(
                    child: Text(icon,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            attack.vendor.toUpperCase(),
                            style: GoogleFonts.roboto(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(
                            label: attack.status,
                            isSuccess: attack.isSuccess,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        attack.targetIP,
                        style: GoogleFonts.robotoMono(
                            fontSize: 12, color: AppTheme.textGrey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('hh:mm a').format(attack.timestamp),
                        style: GoogleFonts.roboto(
                            fontSize: 11,
                            color: AppTheme.textGrey.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${attack.amount.toStringAsFixed(2)}',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: attack.isSuccess
                            ? AppTheme.successGreen
                            : AppTheme.errorRed,
                      ),
                    ),
                    if (attack.response != null && attack.response!.isNotEmpty)
                      const Icon(Icons.chevron_right,
                          size: 16, color: AppTheme.textGrey),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_outlined,
              size: 72, color: AppTheme.textGrey.withOpacity(0.35)),
          const SizedBox(height: 16),
          Text('No attacks yet',
              style: GoogleFonts.roboto(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.textGrey,
              )),
          const SizedBox(height: 8),
          Text(
            'Injected payments will appear here',
            style: GoogleFonts.roboto(
                fontSize: 13, color: AppTheme.textGrey.withOpacity(0.7)),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime dt) {
    final now = DateTime.now();
    if (_isSameDay(dt, now)) return 'TODAY';
    if (_isSameDay(dt, now.subtract(const Duration(days: 1)))) return 'YESTERDAY';
    return DateFormat('dd MMM yyyy').format(dt).toUpperCase();
  }
}
