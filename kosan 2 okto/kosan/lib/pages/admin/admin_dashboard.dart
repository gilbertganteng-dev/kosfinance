// ============================================================
// ADMIN DASHBOARD
// Urutan: Notifikasi -> Ringkasan Keuangan -> Grafik -> Pengeluaran per Kategori -> Transaksi Terbaru
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../pages.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  @override
  void initState() {
    super.initState();
    // Dengarkan perubahan data agar dashboard selalu terbaru
    appDataRevision.addListener(_refreshFromSharedData);
  }

  void _refreshFromSharedData() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_refreshFromSharedData); // wajib dilepas agar tidak bocor memori
    super.dispose();
  }

  // Ringkasan keuangan bulan ini
  double get totalIncome => transactions
      .where((item) => item.type == 'Pemasukan' && transactionInMonth(item, today))
      .fold(0.0, (sum, item) => sum + item.amount);

  double get totalExpense => transactions
      .where((item) => item.type == 'Pengeluaran' && transactionInMonth(item, today))
      .fold(0.0, (sum, item) => sum + item.amount);

  double get balance => totalIncome - totalExpense; // saldo = pemasukan - pengeluaran

  int get unpaidIuran => iuranList.where((i) => i.status == stBelum).length;

  int get waitingIuran => iuranList.where((i) => i.status == stProses).length;
  int get unreadNotificationCount => adminNotifications.where((n) => !n.isRead).length;

  // Ikon notifikasi sesuai jenisnya
  IconData _notificationIcon(String type) {
    switch (type) {
      case 'payment': return Icons.payments_outlined;
      case 'booking': return Icons.meeting_room_outlined;
      case 'complaint': return Icons.build_outlined;
      default: return Icons.person_add_alt_outlined;
    }
  }

  // Ketuk notifikasi -> tandai dibaca lalu buka halaman terkait
  Future<void> _openNotification(AdminNotificationData notification) async {
    setState(() => notification.isRead = true);
    Widget page;
    switch (notification.type) {
      case 'payment':
        page = const IuranPage();
        break;
      case 'booking':
        page = const AdminRoomPage();
        break;
      case 'account':
        page = const RegisteredUsersPage();
        break;
      case 'complaint':
        page = const ComplaintsPage(isAdmin: true);
        break;
      default:
        page = const IuranPage();
    }
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) setState(() {});
  }

  // Kartu notifikasi aktivitas (5 terbaru)
  Widget _notificationsSection() {
    final latest = adminNotifications.take(5).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.notifications_active_outlined, color: primaryGreen),
              const SizedBox(width: 8),
              const Expanded(child: Text('Notifikasi Aktivitas', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              // Lencana merah jumlah notifikasi belum dibaca
              if (unreadNotificationCount > 0)
                CircleAvatar(radius: 13, backgroundColor: Colors.red, child: Text('$unreadNotificationCount', style: const TextStyle(color: Colors.white, fontSize: 12))),
            ]),
            const SizedBox(height: 8),
            if (latest.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Belum ada aktivitas baru dari penghuni atau calon penghuni.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...latest.map((notification) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: notification.isRead ? Colors.grey.shade100 : lightGreen,
                  child: Icon(_notificationIcon(notification.type), color: notification.isRead ? Colors.grey : primaryGreen),
                ),
                title: Text(notification.title, style: TextStyle(fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold)),
                subtitle: Text('${notification.message}\n${formatDateTime(notification.createdAt)}'),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _openNotification(notification),
              )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    expireBookingReservations(notify: false);
    // Nilai terbesar dipakai sebagai skala panjang bar grafik
    final maxAmount = totalIncome > totalExpense ? totalIncome : totalExpense;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Admin', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      drawer: const AdminDrawer(), // menu samping
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}), // tarik ke bawah untuk menyegarkan
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // 1. Notifikasi
            _notificationsSection(),
            const SizedBox(height: 14),
            // 2. Ringkasan keuangan
            const Text('Ringkasan Keuangan', style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text('Pantau kondisi keuangan kos bulan ini.', style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(title: 'Pemasukan', value: formatRupiah(totalIncome), icon: Icons.trending_up, color: Colors.green),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(title: 'Pengeluaran', value: formatRupiah(totalExpense), icon: Icons.trending_down, color: Colors.red),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(title: 'Saldo', value: formatRupiah(balance), icon: Icons.account_balance_wallet, color: Colors.blue),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(title: 'Belum Dibayar', value: '$unpaidIuran', icon: Icons.notifications_none, color: Colors.orange),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: SummaryCard(title: 'Perlu Konfirmasi', value: '$waitingIuran', icon: Icons.hourglass_top, color: Colors.indigo),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SummaryCard(title: 'Kamar Kosong', value: '${vacantCount()}', icon: Icons.meeting_room_outlined, color: Colors.teal),
                ),
              ],
            ),
            const SizedBox(height: 22),
            // 3. Grafik batang pemasukan vs pengeluaran
            SectionTitle(
              title: 'Grafik Keuangan',
              actionText: 'Lihat',
              onAction: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ReportPage()),
              ),
            ),
            const SizedBox(height: 10),
            FinancialBar(title: 'Pemasukan', amount: totalIncome, maxAmount: maxAmount, color: Colors.green),
            FinancialBar(title: 'Pengeluaran', amount: totalExpense, maxAmount: maxAmount, color: Colors.red),
            const SizedBox(height: 10),
            // 4. Pengeluaran bulan ini dirinci per kategori (listrik, wifi, penjaga, dst.)
            ExpenseBreakdownCard(month: today),
            const SizedBox(height: 10),
            // 5. Transaksi terbaru (3 teratas)
            const SectionTitle(title: 'Transaksi Terbaru'),
            const SizedBox(height: 8),
            ...(List<TransactionData>.from(transactions)..sort((a, b) => b.id.compareTo(a.id))).take(3).map((t) => TransactionCard(transaction: t)),
          ],
        ),
      ),
    );
  }
}
