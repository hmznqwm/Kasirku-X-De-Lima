import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_update_service.dart';
import '../services/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'dashboard_screen.dart';
import 'pos_screen.dart';
import 'produk_screen.dart';
import 'riwayat_screen.dart';
import 'lainnya_screen.dart';
import 'profil_screen.dart';
import 'pengeluaran_screen.dart';
import 'inventaris_screen.dart';
import 'moneyku_screen.dart';
import 'supplier_screen.dart';
import 'monitoring_screen.dart';
import 'users_screen.dart';

final GlobalKey<ScaffoldState> homeShellKey = GlobalKey<ScaffoldState>();

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _mobileIndex = 0;
  int _desktopIndex = 0;
  bool _isSidebarCollapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpdate());
  }

  Future<void> _checkUpdate() async {
    final updateInfo = await AppUpdateService.instance.checkUpdate();
    if (!mounted || updateInfo == null) return;
    final currentVer = await AppUpdateService.instance.getCurrentVersion();
    if (!mounted) return;
    AppUpdateService.instance.showUpdateDialog(context, updateInfo, currentVer);
  }

  @override
  Widget build(BuildContext context) {
    final bool isWindows = !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);
    final bool isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final bool isWide = MediaQuery.of(context).size.width >= 700;

    if (isWindows || isLandscape || isWide) {
      return _buildDesktopLayout(context);
    }
    return _buildMobileLayout(context);
  }

  // ==========================================
  // MOBILE LAYOUT (ANDROID / IOS) - UNCHANGED
  // ==========================================
  Widget _buildMobileLayout(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isAdmin = auth.me?.isAdmin ?? false;

    final pages = isAdmin
        ? const [
            DashboardScreen(),
            PosScreen(),
            ProdukScreen(),
            RiwayatScreen(),
            ProfilScreen(),
          ]
        : const [
            PosScreen(),
            ProdukScreen(),
            RiwayatScreen(),
            LainnyaScreen(),
          ];

    final maxIdx = pages.length - 1;
    final currentIndex = _mobileIndex > maxIdx ? 0 : _mobileIndex;

    return Scaffold(
      key: homeShellKey,
      body: pages[currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          border: Border(
            top: BorderSide(color: AppColors.border.withValues(alpha: 0.7), width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            height: 66,
            backgroundColor: Colors.transparent,
            indicatorColor: AppColors.primary.withValues(alpha: 0.12),
            indicatorShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return TextStyle(
                fontSize: 11.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppColors.primary : AppColors.muted,
                letterSpacing: 0.1,
              );
            }),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              final selected = states.contains(WidgetState.selected);
              return IconThemeData(
                color: selected ? AppColors.primary : AppColors.muted,
                size: 23,
              );
            }),
          ),
          child: NavigationBar(
            selectedIndex: currentIndex,
            onDestinationSelected: (i) => setState(() => _mobileIndex = i),
            elevation: 0,
            destinations: isAdmin
                ? const [
                    NavigationDestination(
                      icon: Icon(Icons.space_dashboard_outlined),
                      selectedIcon: Icon(Icons.space_dashboard_rounded),
                      label: 'Dashboard',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.storefront_outlined),
                      selectedIcon: Icon(Icons.storefront_rounded),
                      label: 'Kasir',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2_rounded),
                      label: 'Produk',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history_rounded),
                      label: 'Riwayat',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.account_circle_outlined),
                      selectedIcon: Icon(Icons.account_circle_rounded),
                      label: 'Profil',
                    ),
                  ]
                : const [
                    NavigationDestination(
                      icon: Icon(Icons.storefront_outlined),
                      selectedIcon: Icon(Icons.storefront_rounded),
                      label: 'Kasir',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.inventory_2_outlined),
                      selectedIcon: Icon(Icons.inventory_2_rounded),
                      label: 'Produk',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.history_outlined),
                      selectedIcon: Icon(Icons.history_rounded),
                      label: 'Riwayat',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.grid_view_outlined),
                      selectedIcon: Icon(Icons.grid_view_rounded),
                      label: 'Lainnya',
                    ),
                  ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // DESKTOP LAYOUT (WINDOWS) - FULL SIDEBAR
  // ==========================================
  Widget _buildDesktopLayout(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final me = auth.me;
    final isAdmin = me?.isAdmin ?? false;

    // List menu dan halaman di desktop
    final List<_DesktopMenuItem> menuItems = [
      if (isAdmin)
        const _DesktopMenuItem(
          section: 'UTAMA',
          title: 'Dashboard',
          icon: Icons.space_dashboard_outlined,
          selectedIcon: Icons.space_dashboard_rounded,
          page: DashboardScreen(),
        ),
      const _DesktopMenuItem(
        section: 'UTAMA',
        title: 'Kasir / POS',
        icon: Icons.storefront_outlined,
        selectedIcon: Icons.storefront_rounded,
        page: PosScreen(),
      ),
      const _DesktopMenuItem(
        section: 'UTAMA',
        title: 'Data Produk',
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2_rounded,
        page: ProdukScreen(),
      ),
      const _DesktopMenuItem(
        section: 'UTAMA',
        title: 'Riwayat Transaksi',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long_rounded,
        page: RiwayatScreen(),
      ),
      const _DesktopMenuItem(
        section: 'OPERASIONAL',
        title: 'Pengeluaran Toko',
        icon: Icons.account_balance_wallet_outlined,
        selectedIcon: Icons.account_balance_wallet_rounded,
        page: PengeluaranScreen(),
      ),
      const _DesktopMenuItem(
        section: 'OPERASIONAL',
        title: 'Inventaris & Aset',
        icon: Icons.inventory_outlined,
        selectedIcon: Icons.inventory_rounded,
        page: InventarisScreen(),
      ),
      if (isAdmin) ...[
        const _DesktopMenuItem(
          section: 'ADMINISTRASI',
          title: 'MoneyKu (Kas)',
          icon: Icons.savings_outlined,
          selectedIcon: Icons.savings_rounded,
          page: MoneyKuScreen(),
        ),
        const _DesktopMenuItem(
          section: 'ADMINISTRASI',
          title: 'Data Supplier',
          icon: Icons.business_outlined,
          selectedIcon: Icons.business_rounded,
          page: SupplierScreen(),
        ),
        const _DesktopMenuItem(
          section: 'ADMINISTRASI',
          title: 'Monitoring Log',
          icon: Icons.monitor_heart_outlined,
          selectedIcon: Icons.monitor_heart_rounded,
          page: MonitoringScreen(),
        ),
        const _DesktopMenuItem(
          section: 'ADMINISTRASI',
          title: 'Manajemen User',
          icon: Icons.people_alt_outlined,
          selectedIcon: Icons.people_alt_rounded,
          page: UsersScreen(),
        ),
      ],
    ];

    final maxDesktopIdx = menuItems.length - 1;
    final activeIndex = _desktopIndex > maxDesktopIdx ? 0 : _desktopIndex;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          // SIDEBAR (RESPONSIVE COLLAPSIBLE)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
            width: _isSidebarCollapsed ? 74 : 270,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                right: BorderSide(color: AppColors.border.withValues(alpha: 0.8), width: 1),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 16,
                  offset: const Offset(4, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // 1. Sidebar Header (Brand & Logo + Toggle Collapse Button)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isSidebarCollapsed ? 12 : 16,
                    vertical: 16,
                  ),
                  decoration: const BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFF1F5F9)),
                    ),
                  ),
                  child: _isSidebarCollapsed
                      ? Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 34,
                                height: 34,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 34,
                                  height: 34,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            IconButton(
                              icon: const Icon(Icons.menu_rounded, size: 21, color: Color(0xFF64748B)),
                              tooltip: 'Tampilkan Sidebar',
                              onPressed: () => setState(() => _isSidebarCollapsed = false),
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(9),
                              child: Image.asset(
                                'assets/images/logo.png',
                                width: 36,
                                height: 36,
                                fit: BoxFit.contain,
                                errorBuilder: (_, __, ___) => Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(9),
                                  ),
                                  child: const Icon(Icons.point_of_sale_rounded, color: AppColors.primary, size: 20),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'KasirKu',
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF0F172A),
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  SizedBox(height: 1.5),
                                  Text(
                                    'Sistem Kasir & Toko',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF64748B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.menu_open_rounded, size: 21, color: Color(0xFF64748B)),
                              tooltip: 'Sembunyikan Sidebar',
                              onPressed: () => setState(() => _isSidebarCollapsed = true),
                            ),
                          ],
                        ),
                ),

                // 2. Scrollable Sidebar Navigation Items
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: _isSidebarCollapsed ? 8 : 10,
                    ),
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      final isSelected = index == activeIndex;
                      final showSectionHeader = !_isSidebarCollapsed &&
                          (index == 0 || menuItems[index - 1].section != item.section);

                      if (_isSidebarCollapsed) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Tooltip(
                            message: item.title,
                            waitDuration: const Duration(milliseconds: 150),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(10),
                              onTap: () => setState(() => _desktopIndex = index),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: isSelected ? const Color(0xFFEFF6FF) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: isSelected
                                      ? Border.all(color: const Color(0xFFBFDBFE), width: 1)
                                      : Border.all(color: Colors.transparent, width: 1),
                                ),
                                child: Center(
                                  child: Icon(
                                    isSelected ? item.selectedIcon : item.icon,
                                    size: 21,
                                    color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showSectionHeader) ...[
                            Padding(
                              padding: EdgeInsets.only(
                                left: 10,
                                right: 10,
                                top: index == 0 ? 4 : 14,
                                bottom: 6,
                              ),
                              child: Text(
                                item.section,
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                          InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _desktopIndex = index),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9.5),
                              margin: const EdgeInsets.symmetric(vertical: 1.5),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFEFF6FF)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isSelected
                                    ? Border.all(color: const Color(0xFFBFDBFE), width: 1)
                                    : Border.all(color: Colors.transparent, width: 1),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected ? item.selectedIcon : item.icon,
                                    size: 19.5,
                                    color: isSelected ? AppColors.primary : const Color(0xFF64748B),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                        color: isSelected ? AppColors.primary : const Color(0xFF334155),
                                        letterSpacing: -0.1,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(
                                      Icons.chevron_right_rounded,
                                      size: 16,
                                      color: AppColors.primary,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // 3. Sidebar Footer (User Profile & Logout)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: _isSidebarCollapsed ? 8 : 14,
                    vertical: 12,
                  ),
                  decoration: const BoxDecoration(
                    color: Color(0xFFF8FAFC),
                    border: Border(
                      top: BorderSide(color: Color(0xFFF1F5F9)),
                    ),
                  ),
                  child: _isSidebarCollapsed
                      ? Column(
                          children: [
                            Tooltip(
                              message: '${me?.name ?? 'Kasir'} (${me?.role ?? 'KASIR'})',
                              child: CircleAvatar(
                                radius: 16,
                                backgroundColor: const Color(0xFFEFF6FF),
                                child: Text(
                                  me != null && me.name.isNotEmpty ? me.name[0].toUpperCase() : '?',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            IconButton(
                              icon: const Icon(Icons.logout_rounded, size: 18, color: Color(0xFF94A3B8)),
                              tooltip: 'Keluar',
                              hoverColor: const Color(0xFFFEE2E2),
                              style: IconButton.styleFrom(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: () async {
                                final ok = await confirmDialog(
                                  context,
                                  title: 'Keluar',
                                  message: 'Yakin ingin logout dari aplikasi KasirKu?',
                                );
                                if (ok) await auth.logout();
                              },
                            ),
                          ],
                        )
                      : Row(
                          children: [
                            CircleAvatar(
                              radius: 17,
                              backgroundColor: const Color(0xFFEFF6FF),
                              child: Text(
                                me != null && me.name.isNotEmpty ? me.name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    me?.name ?? 'Kasir',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isAdmin ? const Color(0xFFDCFCE7) : const Color(0xFFFEF3C7),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      me?.role ?? 'KASIR',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: isAdmin ? const Color(0xFF16A34A) : const Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.logout_rounded, size: 19, color: Color(0xFF94A3B8)),
                              tooltip: 'Logout',
                              hoverColor: const Color(0xFFFEE2E2),
                              onPressed: () async {
                                final ok = await confirmDialog(
                                  context,
                                  title: 'Keluar',
                                  message: 'Yakin ingin logout dari aplikasi KasirKu?',
                                );
                                if (ok) await auth.logout();
                              },
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),

          // MAIN CONTENT VIEW
          Expanded(
            child: menuItems[activeIndex].page,
          ),
        ],
      ),
    );
  }
}

class _DesktopMenuItem {
  final String section;
  final String title;
  final IconData icon;
  final IconData selectedIcon;
  final Widget page;

  const _DesktopMenuItem({
    required this.section,
    required this.title,
    required this.icon,
    required this.selectedIcon,
    required this.page,
  });
}

class UserBadge extends StatelessWidget {
  const UserBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthProvider>().me;
    if (me == null) return const SizedBox.shrink();
    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
          child: Text(
            me.name.isNotEmpty ? me.name[0].toUpperCase() : '?',
            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
