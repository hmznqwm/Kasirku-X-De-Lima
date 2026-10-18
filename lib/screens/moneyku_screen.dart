import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../utils/responsive.dart';

class MoneyKuScreen extends StatefulWidget {
  const MoneyKuScreen({super.key});

  @override
  State<MoneyKuScreen> createState() => _MoneyKuScreenState();
}

class _MoneyKuScreenState extends State<MoneyKuScreen> {
  final _api = ApiService.instance;
  bool _loading = true;
  DateTimeRange? _dateRange;

  double _cash = 0;
  double _qris = 0;
  double _kredit = 0;
  double _transfer = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final p = <String, dynamic>{};
      if (_dateRange != null) {
        p['tglMulai'] = _dateRange!.start.toIso8601String().split('T').first;
        p['tglSelesai'] = _dateRange!.end.toIso8601String().split('T').first;
      }

      final data = await _api.call('moneyku.summary', p);
      _cash = (data['cash'] as num?)?.toDouble() ?? 0;
      _qris = (data['qris'] as num?)?.toDouble() ?? 0;
      _kredit = (data['kredit'] as num?)?.toDouble() ?? 0;
      _transfer = (data['transfer'] as num?)?.toDouble() ?? 0;
    } catch (e) {
      if (mounted) showToast(context, e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final res = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: now,
      initialDateRange: _dateRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );
    if (res != null) {
      setState(() => _dateRange = res);
      _load();
    }
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String badgeText,
    required IconData icon,
    required List<Color> gradientColors,
    required Color titleColor,
    required Color valueColor,
    required Color badgeBgColor,
    required Color badgeTextColor,
    required Color iconColor,
    List<BoxShadow>? shadows,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: shadows ??
            [
              BoxShadow(
                color: const Color(0xFF1D4ED8).withValues(alpha: 0.22),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 18.5,
                fontWeight: FontWeight.w700,
                color: valueColor,
                letterSpacing: -0.3,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeTextColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              Icon(icon, color: iconColor, size: 19),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('MoneyKu'),
      ),
      backgroundColor: AppColors.bg,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: padding,
                children: [
                  // ── Header + filter ──
                  const Text(
                    'Ringkasan Pemasukan',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Nominal uang masuk dari transaksi kasir (tidak termasuk belanja/pengeluaran)',
                    style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),

                  // ── Date filter row ──
                  InkWell(
                    onTap: _pickDate,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Periode Pemasukan',
                                  style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _dateRange == null
                                      ? 'Semua Waktu'
                                      : '${tanggalBulan(_dateRange!.start.toIso8601String())} – ${tanggalBulan(_dateRange!.end.toIso8601String())}',
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.text),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (_dateRange != null)
                            GestureDetector(
                              onTap: () {
                                setState(() => _dateRange = null);
                                _load();
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  color: Colors.red.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(Icons.close, color: Colors.red.shade700, size: 16),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Kotak Ringkasan KPI (Responsif: 1 Kolom di HP, 2-3 di Tablet, 5 di Desktop) ──
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final List<Widget> kpiCards = [
                        _buildKpiCard(
                          title: 'Pembayaran Tunai (Cash)',
                          value: rupiah(_cash),
                          badgeText: 'Tunai',
                          icon: Icons.payments_outlined,
                          gradientColors: const [Color(0xFF059669), Color(0xFF047857)],
                          titleColor: Colors.white.withValues(alpha: 0.9),
                          valueColor: Colors.white,
                          badgeBgColor: const Color(0xFFDCFCE7),
                          badgeTextColor: const Color(0xFF15803D),
                          iconColor: Colors.white,
                          shadows: [
                            BoxShadow(
                              color: const Color(0xFF047857).withValues(alpha: 0.22),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        _buildKpiCard(
                          title: 'Pembayaran QRIS',
                          value: rupiah(_qris),
                          badgeText: 'Digital / QRIS',
                          icon: Icons.qr_code_2_rounded,
                          gradientColors: const [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                          titleColor: Colors.white.withValues(alpha: 0.9),
                          valueColor: Colors.white,
                          badgeBgColor: const Color(0xFFDBEAFE),
                          badgeTextColor: const Color(0xFF1E40AF),
                          iconColor: Colors.white,
                          shadows: [
                            BoxShadow(
                              color: const Color(0xFF1D4ED8).withValues(alpha: 0.22),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        _buildKpiCard(
                          title: 'Pembayaran Kredit / Tempo',
                          value: rupiah(_kredit),
                          badgeText: 'Kredit',
                          icon: Icons.credit_card_outlined,
                          gradientColors: const [Color(0xFF0284C7), Color(0xFF0369A1)],
                          titleColor: Colors.white.withValues(alpha: 0.9),
                          valueColor: Colors.white,
                          badgeBgColor: const Color(0xFFE0F2FE),
                          badgeTextColor: const Color(0xFF0369A1),
                          iconColor: Colors.white,
                          shadows: [
                            BoxShadow(
                              color: const Color(0xFF0369A1).withValues(alpha: 0.22),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        _buildKpiCard(
                          title: 'Pembayaran Transfer Bank',
                          value: rupiah(_transfer),
                          badgeText: 'Transfer',
                          icon: Icons.account_balance_outlined,
                          gradientColors: const [Color(0xFF0D9488), Color(0xFF0F766E)],
                          titleColor: Colors.white.withValues(alpha: 0.9),
                          valueColor: Colors.white,
                          badgeBgColor: const Color(0xFFCCFBF1),
                          badgeTextColor: const Color(0xFF115E59),
                          iconColor: Colors.white,
                          shadows: [
                            BoxShadow(
                              color: const Color(0xFF0F766E).withValues(alpha: 0.22),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        _buildKpiCard(
                          title: 'Total Pemasukan',
                          value: rupiah(_cash + _qris + _kredit + _transfer),
                          badgeText: 'Total Saldo',
                          icon: Icons.account_balance_wallet_outlined,
                          gradientColors: const [Color(0xFFF59E0B), Color(0xFFD97706)],
                          titleColor: Colors.white.withValues(alpha: 0.92),
                          valueColor: Colors.white,
                          badgeBgColor: const Color(0xFFFEF9C3),
                          badgeTextColor: const Color(0xFF92400E),
                          iconColor: Colors.white,
                          shadows: [
                            BoxShadow(
                              color: const Color(0xFFD97706).withValues(alpha: 0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                      ];

                      if (width < 600) {
                        return Column(
                          children: [
                            for (int i = 0; i < kpiCards.length; i++) ...[
                              kpiCards[i],
                              if (i < kpiCards.length - 1) const SizedBox(height: 8),
                            ],
                          ],
                        );
                      }

                      int columns = 2;
                      if (width >= 1150) {
                        columns = 5;
                      } else if (width >= 800) {
                        columns = 3;
                      }

                      const double spacing = 12.0;
                      final double itemWidth = (width - (spacing * (columns - 1))) / columns;

                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: kpiCards.map((card) {
                          return SizedBox(
                            width: itemWidth,
                            child: card,
                          );
                        }).toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
