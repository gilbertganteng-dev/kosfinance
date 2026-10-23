// ============================================================
// CUSTOMER DASHBOARD (penghuni)
// Dibuat sederhana. Urutan: Notifikasi -> Pengingat (hanya jika ada tagihan)
// -> Pengumuman -> Kamar Saya -> Tagihan Saya -> Lapor Kerusakan
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../pages.dart';

class CustomerDashboard extends StatefulWidget {
  final UserAccount user; // penghuni yang sedang login

  const CustomerDashboard({super.key, required this.user});

  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  @override
  void initState() {
    super.initState();
    appDataRevision.addListener(_refresh); // refresh otomatis saat data berubah
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    appDataRevision.removeListener(_refresh);
    super.dispose();
  }

  // Buka halaman lain lalu segarkan dashboard saat kembali
  void go(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page)).then((_) => setState(() {}));
  }

  // ---------- 1. NOTIFIKASI (paling atas, seperti admin) ----------
  Widget _notificationsSection(List<ResidentNotificationData> all) {
    final latest = all.take(3).toList(); // cukup 3 terbaru supaya tidak ramai
    final unread = all.where((n) => !n.isRead).length;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.notifications_active_outlined, color: primaryGreen),
              const SizedBox(width: 8),
              const Expanded(child: Text('Notifikasi', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              if (unread > 0)
                CircleAvatar(
                  radius: 13,
                  backgroundColor: Colors.red,
                  child: Text('$unread', style: const TextStyle(color: Colors.white, fontSize: 12)),
                ),
            ]),
            const SizedBox(height: 8),
            if (latest.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Belum ada notifikasi baru.', style: TextStyle(color: Colors.grey)),
              )
            else
              ...latest.map((n) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: n.isRead ? Colors.grey.shade100 : lightGreen,
                      child: Icon(Icons.notifications_none, color: n.isRead ? Colors.grey : primaryGreen),
                    ),
                    title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                    subtitle: Text('${n.message}\n${formatDateTime(n.createdAt)}'),
                    isThreeLine: true,
                    onTap: () => setState(() => n.isRead = true), // ketuk = tandai dibaca
                  )),
            if (unread > 0)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => setState(() {
                    for (final n in all) {
                      n.isRead = true;
                    }
                  }),
                  child: const Text('Tandai semua dibaca'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- 2. PENGINGAT JATUH TEMPO (oranye, hanya tampil jika ada tagihan) ----------
  Widget _reminderSection(List<IuranData> pending) {
    return Card(
      color: Colors.orange.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.orange.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              Icon(Icons.alarm, color: Colors.orange),
              SizedBox(width: 8),
              Text('Pengingat Jatuh Tempo', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ]),
            const SizedBox(height: 8),
            ...pending.map((i) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(
                    i.status == stProses ? Icons.hourglass_top : Icons.warning_amber_rounded,
                    color: i.status == stProses ? Colors.blue : Colors.orange,
                  ),
                  title: Text('${i.iuranType} • ${formatRupiah(i.amount)}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(dueLabel(i)),
                )),
          ],
        ),
      ),
    );
  }

  // ---------- 3. PENGUMUMAN & PERATURAN (biru) ----------
  Widget _announcementSection() {
    final latest = announcements.take(2).toList();
    return Card(
      color: Colors.blue.shade50,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.blue.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.campaign_outlined, color: Colors.blue),
              const SizedBox(width: 8),
              const Expanded(child: Text('Pengumuman & Peraturan', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))),
              TextButton(
                onPressed: () => go(const AnnouncementsPage()),
                child: const Text('Semua'),
              ),
            ]),
            if (latest.isEmpty)
              const Text('Belum ada pengumuman.', style: TextStyle(color: Colors.grey))
            else
              // ExpansionTile: judul bisa diketuk untuk membuka isi pengumuman
              ...latest.map((a) => ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    shape: const Border(),
                    collapsedShape: const Border(),
                    title: Text(a.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(formatDate(a.createdAt), style: const TextStyle(fontSize: 12)),
                    childrenPadding: const EdgeInsets.only(bottom: 10),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(a.body)],
                  )),
          ],
        ),
      ),
    );
  }

  // ---------- 4. KAMAR SAYA (hanya INFO kamar & masa sewa, tanpa pembayaran) ----------
  Widget _roomSection(UserAccount user, Room? room) {
    // Belum punya kamar -> ajak cek kamar & harga
    if (room == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Belum memiliki kamar', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              const Text('Lihat tipe, harga, diskon, dan kamar yang masih kosong, lalu booking.', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => go(RoomListPage(user: user)),
                  icon: const Icon(Icons.search),
                  label: const Text('Cek Kamar & Harga'),
                  style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final type = roomTypes[room.typeIndex];
    final isActive = room.status == 'Terisi';
    final days = room.daysLeft;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Kamar ${room.number}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(type.name, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
                Pill(
                  text: isActive ? 'Aktif' : 'Belum Aktif',
                  color: isActive ? Colors.green : Colors.orange,
                ),
              ],
            ),
            const Divider(height: 24),
            if (isActive) ...[
              InfoRow(
                label: 'Masa sewa tersisa',
                value: days == null ? '-' : (days < 0 ? 'Sudah berakhir' : '$days hari'),
              ),
              if (room.checkIn != null) InfoRow(label: 'Check-in', value: formatDate(room.checkIn!)),
              if (room.checkOut != null) InfoRow(label: 'Check-out', value: formatDate(room.checkOut!)),
            ] else ...[
              if (room.checkIn != null) InfoRow(label: 'Rencana masuk', value: formatDate(room.checkIn!)),
              const SizedBox(height: 6),
              const Text(
                'Kamar baru aktif setelah pembayaran booking lunas 100% dikonfirmasi pemilik kos. Bayar lewat bagian Tagihan di bawah.',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------- 5. TAGIHAN SAYA (pembayaran) ----------
  Widget _billSection(IuranData? active) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: active == null
            ? const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green, size: 28),
                  SizedBox(width: 12),
                  Expanded(child: Text('Belum ada tagihan.', style: TextStyle(color: Colors.grey))),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(formatRupiah(active.amount), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                      StatusChip(status: active.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${active.iuranType} • jatuh tempo ${active.dueDate}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 12),
                  // Tampilkan alasan jika pembayaran sebelumnya ditolak admin
                  if (active.status == stBelum && active.rejectNote != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text('Pembayaran sebelumnya ditolak: ${active.rejectNote}', style: const TextStyle(color: Colors.red)),
                    ),
                  // Tombol/keterangan berbeda sesuai status pembayaran
                  if (active.status == stBelum)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => go(PaymentPage(iuran: active)),
                        icon: const Icon(Icons.payment),
                        label: const Text('Bayar Sekarang (Lunas)'),
                        style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
                      ),
                    )
                  else if (active.status == stProses)
                    const Row(children: [
                      Icon(Icons.hourglass_top, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('Pembayaran sedang diperiksa pemilik kos.', style: TextStyle(color: Colors.blue))),
                    ])
                  else
                    const Row(children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 20),
                      SizedBox(width: 8),
                      Expanded(child: Text('Sudah lunas. Terima kasih!', style: TextStyle(color: Colors.green))),
                    ]),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => go(MyIuranPage(user: widget.user)),
                      child: const Text('Semua tagihan & riwayat'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // Tombol akses cepat (kartu kecil)
  Widget _quickAction(IconData icon, String title, VoidCallback onTap) {
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: lightGreen, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: primaryGreen),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Bersihkan booking yang lewat 24 jam dan belum dibayar (tanpa notify agar aman di build).
    expireBookingReservations(notify: false);

    final user = widget.user;
    final myIurans = iuranFor(user); // semua tagihan milik penghuni ini
    final pending = myIurans.where((i) => i.status != stLunas).toList(); // yang belum lunas
    // Tagihan yang ditampilkan: yang belum lunas dulu, kalau tidak ada tampilkan yang terakhir
    final IuranData? active = pending.isNotEmpty ? pending.first : (myIurans.isNotEmpty ? myIurans.last : null);

    final room = roomOf(user);
    final isActive = room?.status == 'Terisi';
    final notes = notificationsFor(user);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard Penghuni', style: TextStyle(fontWeight: FontWeight.bold))),
      drawer: CustomerDrawer(user: user),
      body: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Kartu sapaan
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(20)),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 26,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 30, color: primaryGreen),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Selamat datang,', style: TextStyle(color: Colors.white70)),
                        Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                        Text(
                          room == null
                              ? 'Belum memiliki kamar'
                              : isActive
                                  ? 'Kamar ${room.number}'
                                  : 'Kamar ${room.number} • menunggu pembayaran',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _notificationsSection(notes),
            // Kartu pengingat hanya muncul jika ada tagihan yang belum lunas
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 4),
              _reminderSection(pending),
            ],
            const SizedBox(height: 4),
            _announcementSection(),
            const SizedBox(height: 14),
            const Text('Kamar Saya', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _roomSection(user, room),
            const SizedBox(height: 14),
            const Text('Tagihan Saya', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _billSection(active),
            // Tombol lapor kerusakan hanya untuk penghuni yang kamarnya sudah aktif
            if (isActive) ...[
              const SizedBox(height: 14),
              _quickAction(Icons.build_outlined, 'Lapor Kerusakan', () => go(ComplaintsPage(user: user))),
            ],
          ],
        ),
      ),
    );
  }
}
