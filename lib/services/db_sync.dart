// Laravel API repository adapter.
// The old implementation polled sync.php and wrote whole table rows from the client.
// This class now only reads authorized API resources. Every write must call a business endpoint.


import '../core/constants.dart';
import '../data/data.dart';
import '../models/models.dart';
import 'api_service.dart';
import 'auth_session.dart';

class DbSync {
  DbSync._();

  static String? lastError;

  static int _int(dynamic value, [int fallback = 0]) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static bool _bool(dynamic value) => value == true || value == 1 || value == '1';

  static DateTime? _date(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static String _dateLabel(dynamic value) {
    final date = _date(value);
    if (date == null) return value?.toString() ?? '-';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  static String _roomStatus(dynamic value) => switch ((value ?? '').toString().toLowerCase()) {
        'available' => 'Kosong',
        'booked' => 'Dipesan',
        'occupied' => 'Terisi',
        'maintenance' => 'Perbaikan',
        _ => (value ?? 'Kosong').toString(),
      };

  static String _billStatus(dynamic value) => switch ((value ?? '').toString().toLowerCase()) {
        'unpaid' => stBelum,
        'pending' => stProses,
        'paid' => stLunas,
        'expired' => stKadaluarsa,
        _ => (value ?? stBelum).toString(),
      };

  static String _billKindLabel(Map<String, dynamic> bill) {
    final kind = (bill['kind'] ?? 'monthly').toString();
    final months = _int(bill['duration_months'], 1);
    final extensions = _int(bill['extend_months'], months);
    return switch (kind) {
      'booking' => 'Sewa $months Bulan',
      'extension' => 'Perpanjang $extensions Bulan',
      _ => 'Iuran Bulanan',
    };
  }

  static String? _paymentMethodLabel(dynamic value) => switch ((value ?? '').toString()) {
        'bank_transfer' => 'Transfer Bank',
        'cash' => 'Tunai (via telepon)',
        'ewallet' => 'QRIS',
        'other' => 'Lainnya',
        '' => null,
        _ => value.toString(),
      };

  static String _transactionType(dynamic value) => (value ?? '').toString().toLowerCase() == 'income'
      ? 'Pemasukan'
      : 'Pengeluaran';

  static String _complaintStatus(dynamic value) => switch ((value ?? '').toString().toLowerCase()) {
        'open' => 'Menunggu',
        'in_progress' => 'Diproses',
        'resolved' => 'Selesai',
        'rejected' => 'Ditolak',
        _ => (value ?? 'Menunggu').toString(),
      };

  static Future<Map<String, dynamic>> _get(String path) => ApiService.get(path);

  static Future<List<Map<String, dynamic>>> _list(String path) async {
    final response = await _get(path);
    final data = response['data'];
    if (data is! List) return <Map<String, dynamic>>[];
    return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  static Future<List<Map<String, dynamic>>> _allPages(String path) async {
    final result = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;
    do {
      final separator = path.contains('?') ? '&' : '?';
      final response = await _get('$path${separator}per_page=100&page=$page');
      final data = response['data'];
      if (data is List) {
        result.addAll(data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)));
      }
      final meta = response['meta'];
      lastPage = meta is Map ? _int(meta['last_page'], 1) : 1;
      page++;
    } while (page <= lastPage);
    return result;
  }

  /// Loads public room catalog only; used by the guest room browsing screen.
  static Future<void> loadPublicCatalog() async {
    final results = await Future.wait([
      _list('room-types'),
      _allPages('rooms'),
      _get('settings'),
    ]);
    _applyRoomTypes(results[0] as List<Map<String, dynamic>>);
    _applyRooms(results[1] as List<Map<String, dynamic>>);
    _applySettings((results[2] as Map<String, dynamic>)['data']);
    lastError = null;
    notifyDataChanged();
  }

  /// Loads the API resources permitted for the current signed-in user.
  static Future<void> loadAll() async {
    if (AuthSession.currentUser == null || await ApiService.getToken() == null) {
      await loadPublicCatalog();
      return;
    }

    try {
      final admin = AuthSession.currentUser!.role == 'Admin';
      final futures = <Future<dynamic>>[
        _list('room-types'),
        _allPages('rooms'),
        _get('settings'),
        _allPages('bills'),
        _allPages('complaints'),
        _allPages('announcements'),
        _allPages('notifications'),
      ];
      if (admin) {
        futures.add(_allPages('transactions'));
        futures.add(_allPages('users'));
      }
      final results = await Future.wait(futures);
      var index = 0;
      final types = results[index++] as List<Map<String, dynamic>>;
      final roomRows = results[index++] as List<Map<String, dynamic>>;
      final settingResponse = results[index++] as Map<String, dynamic>;
      final billRows = results[index++] as List<Map<String, dynamic>>;
      final complaintRows = results[index++] as List<Map<String, dynamic>>;
      final announcementRows = results[index++] as List<Map<String, dynamic>>;
      final notificationRows = results[index++] as List<Map<String, dynamic>>;

      _applyRoomTypes(types);
      _applyRooms(roomRows);
      _applySettings(settingResponse['data']);
      _applyBills(billRows);
      _applyComplaints(complaintRows);
      _applyAnnouncements(announcementRows);
      _applyNotifications(notificationRows, admin: admin);
      if (admin) {
        _applyTransactions(results[index++] as List<Map<String, dynamic>>);
        _applyAccounts(results[index] as List<Map<String, dynamic>>);
      } else {
        accounts
          ..clear()
          ..add(AuthSession.currentUser!);
        transactions.clear();
      }
      lastError = null;
      notifyDataChanged();
    } catch (error) {
      lastError = error.toString();
      rethrow;
    }
  }

  static void _applySettings(dynamic data) {
    if (data is Map) utilityFee = _double(data['utility_fee']);
  }

  static void _applyRoomTypes(List<Map<String, dynamic>> rows) {
    roomTypes
      ..clear()
      ..addAll(rows.map((row) => RoomType(
            id: _int(row['id']),
            name: (row['name'] ?? '').toString(),
            ac: _bool(row['has_ac']),
            wcDalam: _bool(row['has_private_bathroom']),
            price: _double(row['price']),
            discount: _double(row['discount_percent']).round(),
          )));
  }

  static void _applyRooms(List<Map<String, dynamic>> rows) {
    rooms
      ..clear()
      ..addAll(rows.map((row) {
        final roomType = row['room_type'] is Map ? Map<String, dynamic>.from(row['room_type']) : <String, dynamic>{};
        final resident = row['resident'] is Map ? Map<String, dynamic>.from(row['resident']) : <String, dynamic>{};
        final roomTypeId = _int(roomType['id'], -1);
        final typeIndex = roomTypes.indexWhere((type) => type.id == roomTypeId);
        return Room(
          id: _int(row['id']),
          residentId: resident['id'] == null ? null : _int(resident['id']),
          roomTypeId: roomTypeId < 0 ? null : roomTypeId,
          number: (row['number'] ?? '').toString(),
          typeIndex: typeIndex < 0 ? 0 : typeIndex,
          status: _roomStatus(row['status']),
          residentName: resident['name']?.toString(),
          checkIn: _date(row['check_in']),
          checkOut: _date(row['check_out']),
        );
      }));
  }

  static void _applyBills(List<Map<String, dynamic>> rows) {
    iuranList
      ..clear()
      ..addAll(rows.map((row) {
        final room = row['room'] is Map ? Map<String, dynamic>.from(row['room']) : <String, dynamic>{};
        final resident = row['resident'] is Map ? Map<String, dynamic>.from(row['resident']) : <String, dynamic>{};
        final roomId = room['id'] == null ? null : _int(room['id']);
        final userId = resident['id'] == null ? null : _int(resident['id']);
        final kind = (row['kind'] ?? 'monthly').toString();
        final method = row['payment_method'];
        final bill = IuranData(
          id: _int(row['id']),
          residentName: (resident['name'] ?? '').toString(),
          roomNumber: (room['number'] ?? '').toString(),
          iuranType: _billKindLabel(row),
          amount: _double(row['amount']),
          dueDate: _dateLabel(row['due_date']),
          status: _billStatus(row['status']),
          paymentMethod: _paymentMethodLabel(method),
          bookingDeadline: _date(row['booking_deadline']),
          isBooking: kind == 'booking',
          extendMonths: _int(row['extend_months']),
          roomId: roomId,
          userId: userId,
          kind: kind,
        );
        bill.rejectNote = row['reject_note']?.toString();
        bill.paidAt = _date(row['paid_at']);
        return bill;
      }));
  }

  static void _applyTransactions(List<Map<String, dynamic>> rows) {
    transactions
      ..clear()
      ..addAll(rows.map((row) {
        final id = _int(row['id']);
        final billId = row['bill_id'] == null ? null : _int(row['bill_id']);
        return TransactionData(
          id: id,
          billId: billId,
          sourceIuranId: billId,
          date: _dateLabel(row['date']),
          description: (row['description'] ?? '').toString(),
          category: (row['category'] ?? '').toString(),
          type: _transactionType(row['type']),
          amount: _double(row['amount']),
        );
      }));
  }

  static void _applyComplaints(List<Map<String, dynamic>> rows) {
    complaints
      ..clear()
      ..addAll(rows.map((row) {
        final resident = row['resident'] is Map ? Map<String, dynamic>.from(row['resident']) : <String, dynamic>{};
        final room = row['room'] is Map ? Map<String, dynamic>.from(row['room']) : <String, dynamic>{};
        return ComplaintData(
          id: _int(row['id']),
          residentName: (resident['name'] ?? '').toString(),
          roomNumber: (room['number'] ?? '').toString(),
          category: (row['category'] ?? '').toString(),
          description: (row['description'] ?? '').toString(),
          createdAt: _date(row['created_at']) ?? DateTime.now(),
          photoAvailable: _bool(row['photo_available']),
          status: _complaintStatus(row['status']),
        );
      }));
  }

  static void _applyAnnouncements(List<Map<String, dynamic>> rows) {
    announcements
      ..clear()
      ..addAll(rows.map((row) => AnnouncementData(
            id: _int(row['id']),
            title: (row['title'] ?? '').toString(),
            body: (row['body'] ?? '').toString(),
            createdAt: _date(row['created_at']) ?? DateTime.now(),
          )));
  }

  static void _applyNotifications(List<Map<String, dynamic>> rows, {required bool admin}) {
    final userName = AuthSession.currentUser?.name ?? '';
    if (admin) {
      adminNotifications
        ..clear()
        ..addAll(rows.map((row) => AdminNotificationData(
              id: _int(row['id']),
              type: (row['type'] ?? '').toString(),
              title: (row['title'] ?? '').toString(),
              message: (row['message'] ?? '').toString(),
              createdAt: _date(row['created_at']) ?? DateTime.now(),
              isRead: _bool(row['is_read']),
            )));
      residentNotifications.clear();
    } else {
      residentNotifications
        ..clear()
        ..addAll(rows.map((row) => ResidentNotificationData(
              id: _int(row['id']),
              residentName: userName,
              title: (row['title'] ?? '').toString(),
              message: (row['message'] ?? '').toString(),
              createdAt: _date(row['created_at']) ?? DateTime.now(),
              isRead: _bool(row['is_read']),
            )));
      adminNotifications.clear();
    }
  }

  static void _applyAccounts(List<Map<String, dynamic>> rows) {
    accounts
      ..clear()
      ..addAll(rows.map((row) => AuthSession.userFromJson(row)));
  }

  /// Compatibility method: writes are not automatically synchronized anymore.
  /// This intentionally performs no network write; use API action endpoints instead.
  @Deprecated('Call the corresponding Laravel endpoint for each write action.')
  static Future<void> flush() async {}

  /// Compatibility method for existing call sites. No polling or generic table writes are used.
  static void start() {}

  static Future<void> refresh() => loadAll();
}
