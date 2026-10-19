import 'utils.dart';

class Category {
  int? id;
  String name;
  int count;
  Category({this.id, required this.name, this.count = 0});
  factory Category.fromMap(Map<String, Object?> m) => Category(
        id: m['id'] as int,
        name: m['name'] as String,
        count: (m['cnt'] as int?) ?? 0,
      );
}

class Party {
  int? id;
  String name;
  String phone;
  String address;
  String email;
  int? categoryId;
  String categoryName;
  Party({
    this.id,
    required this.name,
    this.phone = '',
    this.address = '',
    this.email = '',
    this.categoryId,
    this.categoryName = '',
  });

  factory Party.fromMap(Map<String, Object?> m) => Party(
        id: m['id'] as int,
        name: m['name'] as String,
        phone: (m['phone'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        categoryId: m['category_id'] as int?,
        categoryName: (m['category_name'] as String?) ?? '',
      );

  Map<String, Object?> toMap() => {
        'name': name,
        'phone': phone,
        'address': address,
        'email': email,
        'category_id': categoryId,
      };
}

// ───────────────────────── Bill parts ─────────────────────────
class BillItem {
  String description;
  double qty;
  double rate;
  String discType; // none | rupees | percentage
  double discValue;
  BillItem({
    this.description = '',
    this.qty = 1,
    this.rate = 0,
    this.discType = 'none',
    this.discValue = 0,
  });

  double get gross => qty * rate;
  double get discAmount {
    switch (discType) {
      case 'rupees':
        return discValue;
      case 'percentage':
        return gross * discValue / 100;
      default:
        return 0;
    }
  }

  double get amount {
    final v = gross - discAmount;
    return v < 0 ? 0 : v;
  }

  Map<String, Object?> toMap(int billId) => {
        'bill_id': billId,
        'description': description,
        'qty': qty,
        'rate': rate,
        'disc_type': discType,
        'disc_value': discValue,
        'amount': amount,
      };

  factory BillItem.fromMap(Map<String, Object?> m) => BillItem(
        description: (m['description'] as String?) ?? '',
        qty: toD(m['qty']),
        rate: toD(m['rate']),
        discType: (m['disc_type'] as String?) ?? 'none',
        discValue: toD(m['disc_value']),
      );
}

class Wall {
  String description;
  double width;
  double height;
  double qty;
  Wall({this.description = '', this.width = 0, this.height = 0, this.qty = 1});
  double get sqft => width * height * qty;

  Map<String, Object?> toMap(int roomId) => {
        'room_id': roomId,
        'description': description,
        'width': width,
        'height': height,
        'qty': qty,
        'sqft': sqft,
      };

  factory Wall.fromMap(Map<String, Object?> m) => Wall(
        description: (m['description'] as String?) ?? '',
        width: toD(m['width']),
        height: toD(m['height']),
        qty: toD(m['qty']),
      );
}

/// Used for both ceiling and roof lines.
class Extra {
  String description;
  double length;
  double width;
  double qty;
  double rate;
  Extra(
      {this.description = '',
      this.length = 0,
      this.width = 0,
      this.qty = 1,
      this.rate = 0});
  double get total => length * width * qty * rate;

  Map<String, Object?> toMap(int roomId, String kind) => {
        'room_id': roomId,
        'kind': kind,
        'description': description,
        'length': length,
        'width': width,
        'qty': qty,
        'rate': rate,
        'total': total,
      };

  factory Extra.fromMap(Map<String, Object?> m) => Extra(
        description: (m['description'] as String?) ?? '',
        length: toD(m['length']),
        width: toD(m['width']),
        qty: toD(m['qty']),
        rate: toD(m['rate']),
      );
}

class Room {
  String name;
  double wallRate;
  double additional;
  bool hasCeiling;
  bool hasRoof;
  final List<Wall> walls;
  final List<Extra> ceilings;
  final List<Extra> roofs;
  bool submitted;
  bool expanded;

  Room({
    this.name = '',
    this.wallRate = 0,
    this.additional = 0,
    this.hasCeiling = false,
    this.hasRoof = false,
    List<Wall>? walls,
    List<Extra>? ceilings,
    List<Extra>? roofs,
    this.submitted = false,
    this.expanded = true,
  })  : walls = walls ?? [],
        ceilings = ceilings ?? [],
        roofs = roofs ?? [];

  double get wallSqFt => walls.fold(0.0, (s, w) => s + w.sqft);
  double get wallTotal => wallSqFt * wallRate;
  double get ceilingTotal =>
      hasCeiling ? ceilings.fold(0.0, (s, e) => s + e.total) : 0.0;
  double get roofTotal =>
      hasRoof ? roofs.fold(0.0, (s, e) => s + e.total) : 0.0;
  double get total => wallTotal + ceilingTotal + roofTotal + additional;

  Map<String, Object?> toMap(int billId) => {
        'bill_id': billId,
        'name': name,
        'wall_rate': wallRate,
        'additional': additional,
        'has_ceiling': hasCeiling ? 1 : 0,
        'has_roof': hasRoof ? 1 : 0,
      };

  factory Room.fromMap(Map<String, Object?> m) => Room(
        name: (m['name'] as String?) ?? '',
        wallRate: toD(m['wall_rate']),
        additional: toD(m['additional']),
        hasCeiling: (m['has_ceiling'] as int?) == 1,
        hasRoof: (m['has_roof'] as int?) == 1,
      );
}

class Bill {
  int? id;
  int partyId;
  String partyName;
  int? categoryId;
  String categoryName;
  DateTime date;
  String notes;
  double additionalCharges;
  String discountType;
  double discountValue;
  double totalAmount; // before discount
  double totalDiscount;
  double paidAmount; // advance
  double remaining;
  List<BillItem> items;
  List<Room> rooms;

  Bill({
    this.id,
    required this.partyId,
    this.partyName = '',
    this.categoryId,
    this.categoryName = '',
    required this.date,
    this.notes = '',
    this.additionalCharges = 0,
    this.discountType = 'none',
    this.discountValue = 0,
    this.totalAmount = 0,
    this.totalDiscount = 0,
    this.paidAmount = 0,
    this.remaining = 0,
    List<BillItem>? items,
    List<Room>? rooms,
  })  : items = items ?? [],
        rooms = rooms ?? [];

  String get number => id == null ? '#New' : '#${id.toString().padLeft(4, '0')}';
  double get net => totalAmount - totalDiscount;

  Map<String, Object?> toMap() => {
        'party_id': partyId,
        'date': date.toIso8601String(),
        'notes': notes,
        'additional_charges': additionalCharges,
        'discount_type': discountType,
        'discount_value': discountValue,
        'total_amount': totalAmount,
        'total_discount': totalDiscount,
        'paid_amount': paidAmount,
        'remaining': remaining,
      };

  factory Bill.fromMap(Map<String, Object?> m) => Bill(
        id: m['id'] as int?,
        partyId: m['party_id'] as int,
        partyName: (m['party_name'] as String?) ?? '',
        categoryId: m['category_id'] as int?,
        categoryName: (m['category_name'] as String?) ?? '',
        date: DateTime.parse(m['date'] as String),
        notes: (m['notes'] as String?) ?? '',
        additionalCharges: toD(m['additional_charges']),
        discountType: (m['discount_type'] as String?) ?? 'none',
        discountValue: toD(m['discount_value']),
        totalAmount: toD(m['total_amount']),
        totalDiscount: toD(m['total_discount']),
        paidAmount: toD(m['paid_amount']),
        remaining: toD(m['remaining']),
      );
}

// ───────────────────────── Payments / Discounts ─────────────────────────
class Payment {
  int? id;
  int partyId;
  String partyName;
  DateTime date;
  double amount;
  double discount;
  String method;
  String reference;
  String notes;
  Payment({
    this.id,
    required this.partyId,
    this.partyName = '',
    required this.date,
    this.amount = 0,
    this.discount = 0,
    this.method = 'Cash',
    this.reference = '',
    this.notes = '',
  });

  Map<String, Object?> toMap() => {
        'party_id': partyId,
        'date': date.toIso8601String(),
        'amount': amount,
        'discount': discount,
        'method': method,
        'reference': reference,
        'notes': notes,
      };

  factory Payment.fromMap(Map<String, Object?> m) => Payment(
        id: m['id'] as int?,
        partyId: m['party_id'] as int,
        partyName: (m['party_name'] as String?) ?? '',
        date: DateTime.parse(m['date'] as String),
        amount: toD(m['amount']),
        discount: toD(m['discount']),
        method: (m['method'] as String?) ?? 'Cash',
        reference: (m['reference'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
      );
}

class DiscountRec {
  int? id;
  int partyId;
  String partyName;
  DateTime date;
  double amount;
  String reference;
  String notes;
  DiscountRec({
    this.id,
    required this.partyId,
    this.partyName = '',
    required this.date,
    this.amount = 0,
    this.reference = '',
    this.notes = '',
  });

  Map<String, Object?> toMap() => {
        'party_id': partyId,
        'date': date.toIso8601String(),
        'amount': amount,
        'reference': reference,
        'notes': notes,
      };

  factory DiscountRec.fromMap(Map<String, Object?> m) => DiscountRec(
        id: m['id'] as int?,
        partyId: m['party_id'] as int,
        partyName: (m['party_name'] as String?) ?? '',
        date: DateTime.parse(m['date'] as String),
        amount: toD(m['amount']),
        reference: (m['reference'] as String?) ?? '',
        notes: (m['notes'] as String?) ?? '',
      );
}

// ───────────────────────── Ledger ─────────────────────────
class LedgerEntry {
  final DateTime date;
  final String description;
  final String type; // bill | discount | advance | payment | closed
  final double debit;
  final double credit;
  final double balance;
  final String note;
  final int? billId;
  final int? paymentId;
  final int? discountId;
  LedgerEntry({
    required this.date,
    required this.description,
    required this.type,
    required this.debit,
    required this.credit,
    required this.balance,
    this.note = '',
    this.billId,
    this.paymentId,
    this.discountId,
  });
}
