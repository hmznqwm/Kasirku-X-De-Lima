import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class SalesChartCard extends StatefulWidget {
  const SalesChartCard({super.key});

  @override
  State<SalesChartCard> createState() => _SalesChartCardState();
}

class _SalesChartCardState extends State<SalesChartCard> {
  final _api = ApiService.instance;

  String _period = '7_hari'; // 'hari' | '7_hari' | '30_hari' | 'kustom'
  DateTimeRange? _customRange;

  Future<Map<String, dynamic>>? _future;

  // Harmonious modern color palette for Donut Chart
  static const List<Color> _donutColors = [
    Color(0xFF2563EB), // Royal Blue
    Color(0xFF1E1B4B), // Dark Indigo
    Color(0xFF06B6D4), // Cyan / Teal
    Color(0xFF60A5FA), // Light Sky Blue
    Color(0xFF8B5CF6), // Purple
    Color(0xFFF59E0B), // Amber
    Color(0xFF10B981), // Emerald
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final payload = <String, dynamic>{'period': _period};
    if (_period == 'kustom' && _customRange != null) {
      payload['start_date'] = _customRange!.start.toIso8601String().substring(0, 10);
      payload['end_date'] = _customRange!.end.toIso8601String().substring(0, 10);
    }

    setState(() {
      _future = _api.call('dashboard.analytics', payload).then((res) => Map<String, dynamic>.from(res as Map));
    });
  }

  Future<void> _selectCustomRange() async {
    final now = DateTime.now();
    DateTime start = _customRange?.start ?? now.subtract(const Duration(days: 6));
    DateTime end = _customRange?.end ?? now;

    final result = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CustomDateFilterSheet(
        initialStart: start,
        initialEnd: end,
      ),
    );

    if (result != null) {
      setState(() {
        _customRange = result;
        _period = 'kustom';
      });
      _load();
    }
  }

  String _formatShortCurrency(double value, {bool withRp = true}) {
    final prefix = withRp ? 'Rp ' : '';
    if (value >= 1000000000000) {
      final v = value / 1000000000000;
      return '$prefix${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}T';
    } else if (value >= 1000000000) {
      final v = value / 1000000000;
      return '$prefix${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}M';
    } else if (value >= 1000000) {
      final v = value / 1000000;
      return '$prefix${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}jt';
    } else if (value >= 1000) {
      final v = value / 1000;
      return '$prefix${v % 1 == 0 ? v.toInt() : v.toStringAsFixed(1)}rb';
    }
    return '$prefix${value.toInt()}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Segmented Filter Pills ──────────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border.withValues(alpha: 0.6)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildFilterPill('hari', 'Hari Ini'),
              _buildFilterPill('7_hari', '7 Hari'),
              _buildFilterPill('30_hari', '30 Hari'),
              _buildFilterPill('kustom', 'Kustom', isCustom: true),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Future Builder for Charts Data ─────────────────────────────────
        FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 240,
                child: Center(child: CircularProgressIndicator()),
              );
            }

            final data = snap.data ?? {};
            final trendLabels = List<String>.from(data['trendLabels'] ?? []);
            final trendData = (data['trendData'] as List? ?? []).map((e) => (e as num).toDouble()).toList();
            final trendProfitData = (data['trendProfitData'] as List? ?? []).map((e) => (e as num).toDouble()).toList();
            final trendFullDates = List<String>.from(data['trendFullDates'] ?? []);
            final topCategories = (data['topCategories'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
            final topProducts = (data['topProducts'] as List? ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
            final totalOmset = (data['totalOmset'] as num? ?? 0).toDouble();

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 2. Tren Penjualan (Line Chart Card) ────────────────────
                    _buildSalesTrendCard(trendLabels, trendData, trendProfitData, trendFullDates),
                    const SizedBox(height: 16),

                    if (isWide) ...[
                      // Desktop: Tampil Bersisian (2 Kolom)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTopCategoriesCard(topCategories, totalOmset),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildTopProductsCard(topProducts),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Mobile / Android: Tumpuk Vertikal
                      // ── 3. Kategori Terlaris (Donut Chart Card) ────────────────
                      _buildTopCategoriesCard(topCategories, totalOmset),
                      const SizedBox(height: 16),

                      // ── 4. Top 5 Produk Paling Laris (Horizontal Bar Card) ──────
                      _buildTopProductsCard(topProducts),
                    ],
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilterPill(String key, String label, {bool isCustom = false}) {
    final isSelected = _period == key;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (isCustom) {
            _selectCustomRange();
          } else {
            if (_period != key) {
              setState(() => _period = key);
              _load();
            }
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.muted,
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Card 1: Tren Penjualan & Profit (Rp)
  // ──────────────────────────────────────────────────────────────────────────
  // ──────────────────────────────────────────────────────────────────────────
  // Card 1: Tren Penjualan & Profit (Rp)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildSalesTrendCard(
    List<String> labels,
    List<double> values,
    List<double> profitValues,
    List<String> fullDates,
  ) {
    double maxY = values.isNotEmpty ? values.reduce(max) : 0;
    double maxProfitY = profitValues.isNotEmpty ? profitValues.reduce(max) : 0;
    double highestY = max(maxY, maxProfitY);
    if (highestY <= 0) highestY = 100000;
    // Add 35% headroom so tooltips at peaks are never clipped
    highestY = highestY * 1.35;

    final spots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    final profitSpots = <FlSpot>[];
    for (int i = 0; i < profitValues.length; i++) {
      profitSpots.add(FlSpot(i.toDouble(), profitValues[i]));
    }

    final hasData = values.any((v) => v > 0) || profitValues.any((v) => v > 0);
    final isDense = labels.length > 8;

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tren Penjualan (Rp)',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                  color: AppColors.text,
                  letterSpacing: -0.3,
                ),
              ),
              Row(
                children: [
                  _buildLegendDot(const Color(0xFF2563EB), 'Omset'),
                  const SizedBox(width: 10),
                  _buildLegendDot(const Color(0xFF10B981), 'Profit'),
                ],
              ),
            ],
          ),
          if (isDense) ...[
            const SizedBox(height: 6),
            const Row(
              children: [
                Icon(Icons.swipe_outlined, size: 14, color: AppColors.muted),
                SizedBox(width: 5),
                Text(
                  'Geser horizontal / cubit (zoom) untuk melihat detail harian',
                  style: TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: !hasData
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.show_chart, size: 40, color: AppColors.muted.withValues(alpha: 0.5)),
                        const SizedBox(height: 8),
                        const Text(
                          'Belum ada transaksi di periode ini',
                          style: TextStyle(color: AppColors.muted, fontSize: 12.5),
                        ),
                      ],
                    ),
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      Widget buildLineChart(bool showLeftTitles, double width) {
                        return SizedBox(
                          width: width,
                          height: 220,
                          child: LineChart(
                          LineChartData(
                            clipData: const FlClipData.none(),
                            minX: 0,
                            maxX: spots.isNotEmpty ? (spots.length - 1).toDouble() : 1,
                            minY: 0,
                            maxY: highestY,
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: false,
                              horizontalInterval: highestY / 3,
                              getDrawingHorizontalLine: (value) => FlLine(
                                color: AppColors.border.withValues(alpha: 0.4),
                                strokeWidth: 1,
                              ),
                            ),
                            titlesData: FlTitlesData(
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              leftTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: showLeftTitles,
                                  reservedSize: 44,
                                  interval: highestY / 3,
                                  getTitlesWidget: (value, meta) {
                                    if (value == 0) {
                                      return const Text('Rp 0', style: TextStyle(fontSize: 10, color: AppColors.muted));
                                    }
                                    return Text(
                                      _formatShortCurrency(value),
                                      style: const TextStyle(fontSize: 10, color: AppColors.muted),
                                    );
                                  },
                                ),
                              ),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  reservedSize: 30,
                                  interval: 1,
                                  getTitlesWidget: (value, meta) {
                                    final idx = value.toInt();
                                    if (idx >= 0 && idx < labels.length) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          labels[idx],
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.muted,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      );
                                    }
                                    return const SizedBox.shrink();
                                  },
                                ),
                              ),
                            ),
                            borderData: FlBorderData(show: false),
                            lineTouchData: LineTouchData(
                              handleBuiltInTouches: true,
                              touchTooltipData: LineTouchTooltipData(
                                getTooltipColor: (_) => const Color(0xFF0F172A),
                                tooltipRoundedRadius: 10,
                                tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                tooltipMargin: 10,
                                fitInsideHorizontally: true,
                                fitInsideVertically: true,
                                maxContentWidth: 240,
                                getTooltipItems: (touchedSpots) {
                                  if (touchedSpots.isEmpty) return [];
                                  final firstSpot = touchedSpots.first;
                                  final idx = firstSpot.spotIndex;
                                  final dateText = (idx >= 0 && idx < fullDates.length) ? fullDates[idx] : '';
                                  final omsetVal = (idx >= 0 && idx < values.length) ? values[idx] : 0.0;
                                  final profitVal = (idx >= 0 && idx < profitValues.length) ? profitValues[idx] : 0.0;

                                  return touchedSpots.map((spot) {
                                    if (spot.barIndex == 0) {
                                      return LineTooltipItem(
                                        '$dateText\n',
                                        const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                                        children: [
                                          TextSpan(
                                            text: 'Omset:  ${rupiah(omsetVal)}\n',
                                            style: const TextStyle(color: Color(0xFF60A5FA), fontSize: 12.5, fontWeight: FontWeight.w700),
                                          ),
                                          TextSpan(
                                            text: 'Profit: ${rupiah(profitVal)}',
                                            style: const TextStyle(color: Color(0xFF34D399), fontSize: 12.5, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      );
                                    }
                                    return null;
                                  }).toList();
                                },
                              ),
                            ),
                            lineBarsData: [
                              // Line 1: Omset (Blue)
                              LineChartBarData(
                                spots: spots,
                                isCurved: true,
                                curveSmoothness: 0.35,
                                preventCurveOverShooting: true,
                                barWidth: 3.2,
                                isStrokeCapRound: true,
                                color: const Color(0xFF2563EB),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFF2563EB).withValues(alpha: 0.3),
                                      const Color(0xFF2563EB).withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                    radius: 3.5,
                                    color: const Color(0xFF2563EB),
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  ),
                                ),
                              ),
                              // Line 2: Profit (Green)
                              LineChartBarData(
                                spots: profitSpots,
                                isCurved: true,
                                curveSmoothness: 0.35,
                                preventCurveOverShooting: true,
                                barWidth: 3.0,
                                isStrokeCapRound: true,
                                color: const Color(0xFF10B981),
                                belowBarData: BarAreaData(
                                  show: true,
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      const Color(0xFF10B981).withValues(alpha: 0.25),
                                      const Color(0xFF10B981).withValues(alpha: 0.0),
                                    ],
                                  ),
                                ),
                                dotData: FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                                    radius: 3.5,
                                    color: const Color(0xFF10B981),
                                    strokeWidth: 2,
                                    strokeColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                      if (!isDense) {
                        return buildLineChart(true, constraints.maxWidth);
                      }

                      // For 30 days / dense periods: Fixed Y Axis on Left + Scrollable/Zoomable Chart
                      final dynamicWidth = max(constraints.maxWidth - 44, labels.length * 54.0);

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Fixed Y Axis Column
                          SizedBox(
                            width: 44,
                            height: 190,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(_formatShortCurrency(highestY), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                                Text(_formatShortCurrency(highestY * 2 / 3), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                                Text(_formatShortCurrency(highestY / 3), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                                const Text('Rp 0', style: TextStyle(fontSize: 10, color: AppColors.muted)),
                              ],
                            ),
                          ),
                          // Scrollable & Zoomable Chart
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              child: InteractiveViewer(
                                minScale: 1.0,
                                maxScale: 3.0,
                                panEnabled: false,
                                scaleEnabled: true,
                                child: buildLineChart(false, dynamicWidth),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Card 2: Kategori Terlaris (Donut Chart Card)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTopCategoriesCard(List<Map<String, dynamic>> categories, double totalOmset) {
    final hasData = categories.isNotEmpty && totalOmset > 0;

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Kategori Terlaris',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
              color: AppColors.text,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          if (!hasData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada data kategori di periode ini',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            )
          else
            Row(
              children: [
                // ── Left: Legend & Percentages ──
                Expanded(
                  flex: 6,
                  child: Column(
                    children: List.generate(categories.length > 5 ? 5 : categories.length, (idx) {
                      final cat = categories[idx];
                      final color = _donutColors[idx % _donutColors.length];
                      final name = cat['kategori']?.toString() ?? '-';
                      final pct = (cat['percentage'] as num? ?? 0).toDouble();

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 5.5),
                        child: Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                name,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              '${pct.toStringAsFixed(0)}%',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: AppColors.text,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(width: 12),

                // ── Right: Donut Chart ──
                Expanded(
                  flex: 5,
                  child: SizedBox(
                    height: 140,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        PieChart(
                          PieChartData(
                            sectionsSpace: 2.5,
                            centerSpaceRadius: 38,
                            startDegreeOffset: -90,
                            sections: List.generate(categories.length > 5 ? 5 : categories.length, (idx) {
                              final cat = categories[idx];
                              final color = _donutColors[idx % _donutColors.length];
                              final pct = (cat['percentage'] as num? ?? 0).toDouble();
                              return PieChartSectionData(
                                color: color,
                                value: pct,
                                showTitle: false,
                                radius: 18,
                              );
                            }),
                          ),
                        ),
                        SizedBox(
                          width: 72,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  _formatShortCurrency(totalOmset),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: AppColors.text,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Total Omset',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    color: AppColors.muted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Card 3: Top 5 Produk Paling Laris (Horizontal Bar Chart Card)
  // ──────────────────────────────────────────────────────────────────────────
  Widget _buildTopProductsCard(List<Map<String, dynamic>> products) {
    final maxQty = products.isNotEmpty
        ? products.map((p) => (p['qty'] as num? ?? 0).toDouble()).reduce(max)
        : 1.0;

    return SectionCard(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Top 5 Produk Paling Laris',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15.5,
              color: AppColors.text,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 16),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'Belum ada produk terjual di periode ini',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              ),
            )
          else
            Column(
              children: List.generate(products.length, (idx) {
                final p = products[idx];
                final name = p['nama']?.toString() ?? '-';
                final qty = (p['qty'] as num? ?? 0).toInt();
                final ratio = maxQty > 0 ? (qty / maxQty).clamp(0.05, 1.0) : 0.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6.5),
                  child: Row(
                    children: [
                      // Product Name
                      SizedBox(
                        width: 120,
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.text,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Horizontal Bar
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final barWidth = constraints.maxWidth * ratio;
                            return Stack(
                              children: [
                                Container(
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: AppColors.border.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                                Container(
                                  height: 14,
                                  width: barWidth,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF3B82F6),
                                        Color(0xFF06B6D4),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Qty Count
                      SizedBox(
                        width: 38,
                        child: Text(
                          '$qty',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                          textAlign: TextAlign.end,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Compact & Simple Custom Date Picker Bottom Sheet
// ────────────────────────────────────────────────────────────────────────────

class _CustomDateFilterSheet extends StatefulWidget {
  final DateTime initialStart;
  final DateTime initialEnd;

  const _CustomDateFilterSheet({
    required this.initialStart,
    required this.initialEnd,
  });

  @override
  State<_CustomDateFilterSheet> createState() => _CustomDateFilterSheetState();
}

class _CustomDateFilterSheetState extends State<_CustomDateFilterSheet> {
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStart;
    _endDate = widget.initialEnd;
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? _startDate : _endDate,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: AppColors.text,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_startDate.isAfter(_endDate)) {
            _endDate = _startDate;
          }
        } else {
          _endDate = picked;
          if (_endDate.isBefore(_startDate)) {
            _startDate = _endDate;
          }
        }
      });
    }
  }

  void _applyPreset(int daysAgo) {
    final now = DateTime.now();
    setState(() {
      _startDate = now.subtract(Duration(days: daysAgo));
      _endDate = now;
    });
  }

  void _applyMonthPreset(bool thisMonth) {
    final now = DateTime.now();
    if (thisMonth) {
      setState(() {
        _startDate = DateTime(now.year, now.month, 1);
        _endDate = now;
      });
    } else {
      final prevMonthLastDay = DateTime(now.year, now.month, 0);
      setState(() {
        _startDate = DateTime(prevMonthLastDay.year, prevMonthLastDay.month, 1);
        _endDate = prevMonthLastDay;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pilih Rentang Tanggal',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.text,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Atur periode tanggal untuk grafik',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AppColors.muted, size: 22),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Date Pickers Row
            Row(
              children: [
                Expanded(
                  child: _buildDateBox(
                    label: 'Dari Tanggal',
                    date: _startDate,
                    onTap: () => _pickDate(isStart: true),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward_rounded, color: AppColors.muted, size: 18),
                ),
                Expanded(
                  child: _buildDateBox(
                    label: 'Sampai Tanggal',
                    date: _endDate,
                    onTap: () => _pickDate(isStart: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Quick Preset Chips
            const Text(
              'Pilihan Cepat',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildPresetChip('7 Hari Lalu', () => _applyPreset(6)),
                _buildPresetChip('14 Hari Lalu', () => _applyPreset(13)),
                _buildPresetChip('Bulan Ini', () => _applyMonthPreset(true)),
                _buildPresetChip('Bulan Lalu', () => _applyMonthPreset(false)),
              ],
            ),
            const SizedBox(height: 22),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: () {
                  Navigator.pop(
                    context,
                    DateTimeRange(start: _startDate, end: _endDate),
                  );
                },
                child: const Text(
                  'Terapkan Filter',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBox({
    required String label,
    required DateTime date,
    required VoidCallback onTap,
  }) {
    final str = tanggalPendek(date.toIso8601String().substring(0, 10));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined, size: 15, color: AppColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    str,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPresetChip(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bg,
          border: Border.all(color: AppColors.border.withValues(alpha: 0.8)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
        ),
      ),
    );
  }
}
