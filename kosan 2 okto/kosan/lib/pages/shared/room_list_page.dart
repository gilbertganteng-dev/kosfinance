// ============================================================
// KAMAR & HARGA
// - user != null  -> calon penghuni / penghuni (boleh booking)
// - isAdmin true  -> admin (boleh EDIT tipe, harga, diskon, tarif listrik & air)
// - keduanya kosong -> pengunjung (hanya melihat)
// ============================================================

import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../data/data.dart';
import '../../models/models.dart';
import '../../widgets/widgets.dart';
import '../pages.dart';

class RoomListPage extends StatefulWidget {
  final UserAccount? user;
  final bool isAdmin;

  const RoomListPage({super.key, this.user, this.isAdmin = false});

  @override
  State<RoomListPage> createState() => _RoomListPageState();
}

class _RoomListPageState extends State<RoomListPage> {
  // Foto contoh tiap tipe kamar (diambil dari internet)
  static const photos = [
    'https://images.unsplash.com/photo-1616486338812-3dadae4b4ace?w=1000',
    'https://images.unsplash.com/photo-1618221195710-dd6b41faaea6?w=1000',
    'https://images.unsplash.com/photo-1598928506311-c55ded91a20c?w=1000',
    'https://images.unsplash.com/photo-1616486029423-aaa4789e8c9a?w=1000',
  ];

  // Membuka halaman booking untuk kamar yang dipilih
  void bookRoom(Room room) {
    final user = widget.user;
    if (user == null) {
      showMessage(context, 'Login atau daftar akun penghuni dulu untuk booking.');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingPage(room: room, user: user)),
    ).then((_) => setState(() {})); // segarkan daftar kamar setelah booking
  }

  // ---------- ADMIN: edit tipe kamar (nama, fasilitas, harga, diskon) ----------
  Future<void> editType(int index) async {
    final t = roomTypes[index];
    final nameC = TextEditingController(text: t.name);
    final priceC = TextEditingController(text: t.price.toStringAsFixed(0));
    final discC = TextEditingController(text: '${t.discount}');
    bool ac = t.ac;
    bool wc = t.wcDalam;

    final ok = await showDialog<bool>(
      context: context,
      // StatefulBuilder: supaya switch di dalam dialog bisa berubah tampilannya
      builder: (context) => StatefulBuilder(
        builder: (context, setDialog) => AlertDialog(
          title: const Text('Edit Tipe Kamar'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                field(nameC, 'Nama tipe', Icons.bedroom_parent_outlined),
                field(priceC, 'Harga sewa / bulan', Icons.payments_outlined, type: TextInputType.number),
                field(discC, 'Diskon (%)', Icons.percent, type: TextInputType.number),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Ber-AC'),
                  value: ac,
                  onChanged: (v) => setDialog(() => ac = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('WC Dalam'),
                  value: wc,
                  onChanged: (v) => setDialog(() => wc = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );

    if (ok != true) return; // dibatalkan
    // Validasi input: harga > 0 dan diskon 0-100
    final price = double.tryParse(priceC.text.trim()) ?? 0;
    final disc = int.tryParse(discC.text.trim()) ?? -1;
    if (nameC.text.trim().isEmpty || price <= 0 || disc < 0 || disc > 100) {
      if (mounted) showMessage(context, 'Data tidak valid. Harga harus > 0 dan diskon 0-100%.');
      return;
    }

    setState(() {
      t.name = nameC.text.trim();
      t.price = price;
      t.discount = disc;
      t.ac = ac;
      t.wcDalam = wc;
    });
    notifyDataChanged();
    if (mounted) showMessage(context, 'Tipe kamar diperbarui. Tagihan yang sudah dibuat tidak berubah.');
  }

  // ---------- ADMIN: edit tarif listrik & air per bulan ----------
  Future<void> editUtilityFee() async {
    final c = TextEditingController(text: utilityFee.toStringAsFixed(0));
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tarif Listrik & Air'),
        content: field(c, 'Tarif tetap / bulan', Icons.bolt_outlined, type: TextInputType.number),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true) return;
    final v = double.tryParse(c.text.trim()) ?? 0;
    if (v < 0) {
      if (mounted) showMessage(context, 'Nominal tidak valid.');
      return;
    }
    setState(() => utilityFee = v);
    notifyDataChanged();
    if (mounted) showMessage(context, 'Tarif listrik & air diperbarui.');
  }

  // Chip kecil nomor kamar + status (hijau = bisa dibooking)
  Widget roomChip(Room r) {
    final c = roomColor(r.status);
    final canBook = r.status == 'Kosong' && !widget.isAdmin;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: canBook ? () => bookRoom(r) : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: 0.5)),
        ),
        child: Text(
          '${r.number} • ${r.status}',
          style: TextStyle(color: c, fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    expireBookingReservations(notify: false); // bersihkan booking kadaluarsa
    // Diskon terbesar dari semua tipe (untuk teks banner promo)
    final maxDisc = roomTypes.map((t) => t.discount).reduce((a, b) => a > b ? a : b);

    return Scaffold(
      appBar: AppBar(title: Text(widget.isAdmin ? 'Kamar & Harga (Admin)' : 'Cek Kamar & Harga')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner promo
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: primaryGreen, borderRadius: BorderRadius.circular(20)),
            child: Row(
              children: [
                const Icon(Icons.local_offer, color: Colors.white, size: 36),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    maxDisc > 0
                        ? 'Promo! Diskon hingga $maxDisc% untuk tipe kamar pilihan. Pembayaran booking harus lunas 100%.'
                        : 'Pembayaran booking harus lunas 100%. Listrik & air sudah termasuk di tagihan.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Info untuk pengunjung yang belum login
          if (widget.user == null && !widget.isAdmin)
            const Card(
              color: lightGreen,
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text('Untuk booking kamar, silakan login atau daftar akun terlebih dahulu.'),
              ),
            ),
          // Panel khusus admin: info edit + tarif listrik & air
          if (widget.isAdmin)
            Card(
              color: lightGreen,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.bolt_outlined, color: primaryGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Tarif Listrik & Air (tetap)', style: TextStyle(fontWeight: FontWeight.bold)),
                          Text('${formatRupiah(utilityFee)} / bulan • sudah masuk tagihan kamar'),
                          const Text('Ketuk ikon pensil di tiap tipe untuk mengubah harga/diskon.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    IconButton(onPressed: editUtilityFee, icon: const Icon(Icons.edit_outlined)),
                  ],
                ),
              ),
            ),
          // Kartu promo hemat
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Promo Hemat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.savings_outlined, color: primaryGreen),
                    title: Text('Sewa 6 bulan di muka'),
                    subtitle: Text('Diskon tambahan 8% dari sewa.'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.workspace_premium_outlined, color: primaryGreen),
                    title: Text('Sewa 12 bulan di muka'),
                    subtitle: Text('Diskon tambahan 15% dari sewa.'),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.confirmation_number_outlined, color: primaryGreen),
                    title: Text('Voucher KOSHEMAT5 / AJAKTEMAN10'),
                    subtitle: Text('Diskon 5% / 10%. Masukkan kode saat booking.'),
                  ),
                  Text(
                    'Promo pada versi demo belum terhubung ke backend. Listrik & air tidak kena diskon.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ),
          // Lokasi kos
          Card(
            child: ListTile(
              leading: const Icon(Icons.location_on_outlined, color: primaryGreen),
              title: const Text('Lokasi Kos', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text(kosLocationName),
              trailing: const Icon(Icons.open_in_new),
              onTap: () => openKosMap(context),
            ),
          ),
          const SizedBox(height: 4),
          // Tombol WhatsApp & lokasi
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                onPressed: () => openWhatsApp(context, message: 'Halo, saya ingin bertanya tentang harga dan ketersediaan kamar kos.'),
                icon: const Icon(Icons.chat),
                label: const Text('WhatsApp Pemilik'),
                style: ElevatedButton.styleFrom(backgroundColor: primaryGreen, foregroundColor: Colors.white),
              ),
              OutlinedButton.icon(
                onPressed: () => openKosMap(context),
                icon: const Icon(Icons.map_outlined),
                label: const Text('Buka Google Maps'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Kartu per tipe kamar (dibuat otomatis dari daftar roomTypes)
          ...List.generate(roomTypes.length, (i) {
            final t = roomTypes[i];
            final typeRooms = rooms.where((r) => r.typeIndex == i).toList();
            final vacant = vacantCount(i);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Foto kamar (ada fallback ikon jika gagal dimuat)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        photos[i % photos.length],
                        height: 150,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 150,
                          color: lightGreen,
                          child: const Center(child: Icon(Icons.bedroom_parent_outlined, size: 56, color: primaryGreen)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Nama tipe + diskon + tombol edit (khusus admin)
                    Row(
                      children: [
                        Expanded(child: Text(t.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                        if (t.discount > 0) Pill(text: 'Diskon ${t.discount}%', color: Colors.red),
                        if (widget.isAdmin)
                          IconButton(
                            tooltip: 'Edit tipe kamar',
                            onPressed: () => editType(i),
                            icon: const Icon(Icons.edit_outlined, color: primaryGreen),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      children: [
                        Pill(text: t.ac ? 'Ber-AC' : 'Tanpa AC', color: Colors.blue),
                        Pill(text: t.wcDalam ? 'WC Dalam' : 'WC Luar', color: Colors.teal),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Harga coret jika ada diskon
                    if (t.discount > 0)
                      Text(formatRupiah(t.price), style: const TextStyle(color: Colors.grey, decoration: TextDecoration.lineThrough)),
                    Text(
                      '${formatRupiah(t.finalPrice)} / bulan',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryGreen),
                    ),
                    Text(
                      '+ Listrik & air ${formatRupiah(utilityFee)} / bulan',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      vacant > 0 ? '$vacant dari ${typeRooms.length} kamar kosong' : 'Penuh',
                      style: TextStyle(color: vacant > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 6, runSpacing: 6, children: typeRooms.map(roomChip).toList()),
                    if (widget.user != null && vacant > 0)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text('Ketuk kamar berwarna hijau untuk booking.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                      ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
