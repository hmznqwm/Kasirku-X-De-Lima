import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_provider.dart';
import '../services/event_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/responsive.dart';
import '../widgets/common.dart';
import '../widgets/sales_chart.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _api = ApiService.instance;
  Future<DashboardSummary>? _future;
  
  late EventProvider _ev;
  int _localProdukVersion = 0;
  int _localTransaksiVersion = 0;

  @override
  void initState() {
    super.initState();
    _ev = context.read<EventProvider>();
    _localProdukVersion = _ev.produkVersion;
    _localTransaksiVersion = _ev.transaksiVersion;
    _ev.addListener(_onEvent);
    _load();
  }

  @override
  void dispose() {
    _ev.removeListener(_onEvent);
    super.dispose();
  }

  void _onEvent() {
    if (_localProdukVersion != _ev.produkVersion || 
        _localTransaksiVersion != _ev.transaksiVersion) {
      _localProdukVersion = _ev.produkVersion;
      _localTransaksiVersion = _ev.transaksiVersion;
      if (mounted) _load();
    }
  }

  void _load() {
    setState(() {
      _future = _api
          .call('dashboard.summary')
          .then((d) => DashboardSummary.fromJson(Map<String, dynamic>.from(d)))
          .catchError((e) => throw _friendlyError(e));
    });
  }

  /// Ubah error teknis (exception, timeout, dsb) jadi pesan yang gampang
  /// dimengerti pengguna, bukan sekadar melempar stack trace mentah.
  Object _friendlyError(Object e) {
    if (e is ApiException) return e;
    final msg = e.toString();
    if (msg.contains('DatabaseException') ||
        msg.contains('SqfliteFfiException')) {
      return ApiException(
          'Gagal membaca data lokal. Coba tutup dan buka ulang aplikasi.');
    }
    return ApiException('Terjadi kesalahan tak terduga saat memuat dashboard.');
  }

  Future<void> _loadAsync() async {
    _load();
    // Tunggu future selesai supaya RefreshIndicator tahu kapan berhenti berputar.
    try {
      await _future;
    } catch (_) {
      // Error sudah ditangani & ditampilkan lewat FutureBuilder di bawah.
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().me;
    final padding = Responsive.pagePadding(context);

    return Scaffold(
      appBar: AppBar(

        title: const Text('Dashboard'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadAsync,
        child: FutureBuilder<DashboardSummary>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const LoadingView();
            }
            if (snap.hasError) {
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: ErrorView(
                  message: friendlyErrorMessage(snap.error!),
                  onRetry: _load,
                ),
              );
            }
            final data = snap.data!;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ResponsiveCenter(
                maxWidth: Responsive.maxContentWidth(context),
                child: Padding(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Halo, ${me?.name ?? ''}',
                        style: TextStyle(
                          fontSize: Responsive.fontSize(context, base: 18),
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF0F172A),
                          letterSpacing: -0.3,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Ringkasan performa toko Anda',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: Responsive.fontSize(context, base: 13),
                        ),
                      ),
                      SizedBox(height: Responsive.isMobile(context) ? 14 : 18),
                      // ── Kotak Ringkasan KPI (Responsif: 1 Kolom di HP, 2-3 di Tablet, 5 di Desktop) ──
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = constraints.maxWidth;
                          final List<Widget> kpiCards = [
                            _buildKpiCard(
                              title: 'Transaksi Hari Ini',
                              value: rupiah(data.transHariIni),
                              badgeText: _calcGrowthBadge(data.transHariIni, data.transKemarin),
                              icon: Icons.trending_up,
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
                              title: 'Profit Hari Ini',
                              value: rupiah(data.profitHariIni),
                              badgeText: data.transHariIni > 0
                                  ? '+${(data.profitHariIni / data.transHariIni * 100).toStringAsFixed(1)}%'
                                  : '+0.0%',
                              icon: Icons.monetization_on_outlined,
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
                              title: 'Total Transaksi',
                              value: rupiah(data.totalTrans),
                              badgeText: 'Akumulasi',
                              icon: Icons.receipt_long_rounded,
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
                              title: 'Total Profit',
                              value: rupiah(data.totalProfit),
                              badgeText: 'Total Laba',
                              icon: Icons.account_balance_wallet_outlined,
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
                              title: 'Produk Aktif',
                              value: '${data.totalProdukAktif} Produk',
                              badgeText: 'Tersedia',
                              icon: Icons.inventory_2_outlined,
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
                            // Layout Vertikal untuk Layar Sempit / HP Android
                            return Column(
                              children: [
                                for (int i = 0; i < kpiCards.length; i++) ...[
                                  kpiCards[i],
                                  if (i < kpiCards.length - 1) const SizedBox(height: 8),
                                ],
                              ],
                            );
                          }

                          // Layout Grid untuk Tablet & Desktop
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
                      const SizedBox(height: 16),
                      // Grafik Penjualan
                      const SalesChartCard(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  String _calcGrowthBadge(double today, double yesterday) {
    if (yesterday > 0) {
      final growth = ((today - yesterday) / yesterday) * 100;
      final sign = growth >= 0 ? '+' : '';
      return '$sign${growth.toStringAsFixed(1)}%';
    } else if (today > 0) {
      return '+100%';
    }
    return '+0.0%';
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
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
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
}
