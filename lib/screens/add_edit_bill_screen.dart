

// lib/screens/add_edit_bill_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../db/database_helper.dart';
import '../models.dart';
import '../utils.dart';

// ─────────────────────────────────────────────────────────────────────────────
class _C {
  static const bg = Color(0xFF14151A);           // Slightly lighter background
  static const surface = Color(0xFF1E2029);      // Lighter card surface
  static const surfaceElevated = Color(0xFF292C38); // Lighter inputs
  static const border = Color(0xFF3E4355);       // Brighter borders for prominence
  static const primary = Color(0xFF4D8EFF);
  static const textPrimary = Color(0xFFFFFFFF);  // Pure white text
  static const textSecondary = Color(0xFFA0ABC0);
  static const textMuted = Color(0xFF6B768A);
  static const success = Color(0xFF4CAF7D);
  static const danger = Color(0xFFFF6B6B);
  static const warning = Color(0xFFFFAA44);
  static const accent = Color(0xFFB57BFF);
}

const _numKb = TextInputType.numberWithOptions(decimal: true);
final _numFmt = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
];

double _p(String s, [double def = 0]) => double.tryParse(s.trim()) ?? def;

// ─────────────────────────────────────────────────────────────────────────────
class RoomEntry {
  String name;
  final List<Wall> walls = [];
  double wallRatePerSqFt = 0;
  bool hasCeiling = false;
  final List<Extra> ceilingItems = [];
  bool hasRoof = false;
  final List<Extra> roofItems = [];
  double additionalCharges = 0;
  bool isSubmitted = false;
  bool isExpanded = true;

  final TextEditingController nameController;
  final TextEditingController wallRateController;
  final TextEditingController additionalChargesController;
  final List<TextEditingController> wallDescControllers = [];
  final List<TextEditingController> wallWidthControllers = [];
  final List<TextEditingController> wallHeightControllers = [];
  final List<TextEditingController> wallQtyControllers = [];
  final List<TextEditingController> ceilDescControllers = [];
  final List<TextEditingController> ceilLenControllers = [];
  final List<TextEditingController> ceilWidthControllers = [];
  final List<TextEditingController> ceilQtyControllers = [];
  final List<TextEditingController> ceilRateControllers = [];
  final List<TextEditingController> roofDescControllers = [];
  final List<TextEditingController> roofLenControllers = [];
  final List<TextEditingController> roofWidthControllers = [];
  final List<TextEditingController> roofQtyControllers = [];
  final List<TextEditingController> roofRateControllers = [];

  RoomEntry({required this.name})
      : nameController = TextEditingController(text: name),
        wallRateController = TextEditingController(),
        additionalChargesController = TextEditingController();

  double get totalWallSqFt => walls.fold(0.0, (s, w) => s + w.sqft);
  double get wallTotal => totalWallSqFt * wallRatePerSqFt;
  double get ceilingTotal =>
      hasCeiling ? ceilingItems.fold(0.0, (s, c) => s + c.total) : 0.0;
  double get roofTotal =>
      hasRoof ? roofItems.fold(0.0, (s, r) => s + r.total) : 0.0;
  double get roomTotal =>
      wallTotal + ceilingTotal + roofTotal + additionalCharges;

  void dispose() {
    nameController.dispose();
    wallRateController.dispose();
    additionalChargesController.dispose();
    for (final list in [
      wallDescControllers, wallWidthControllers, wallHeightControllers,
      wallQtyControllers, ceilDescControllers, ceilLenControllers,
      ceilWidthControllers, ceilQtyControllers, ceilRateControllers,
      roofDescControllers, roofLenControllers, roofWidthControllers,
      roofQtyControllers, roofRateControllers,
    ]) {
      for (final c in list) { c.dispose(); }
    }
  }

  Room toRoom() => Room(
    name: name,
    wallRate: wallRatePerSqFt,
    additional: additionalCharges,
    hasCeiling: hasCeiling,
    hasRoof: hasRoof,
    walls: List.of(walls),
    ceilings: List.of(ceilingItems),
    roofs: List.of(roofItems),
    submitted: isSubmitted,
    expanded: isExpanded,
  );
}

class _Cell {
  final TextEditingController c;
  final String label;
  final bool num;
  final int flex;
  _Cell(this.c, this.label, {this.num = true, this.flex = 1});
}

// ─────────────────────────────────────────────────────────────────────────────
class AddEditBillScreen extends StatefulWidget {
  final int? billId;
  const AddEditBillScreen({super.key, this.billId});

  @override
  State<AddEditBillScreen> createState() => _AddEditBillScreenState();
}

class _AddEditBillScreenState extends State<AddEditBillScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _partyController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  Party? _selectedParty;
  List<Category> _categories = [];
  int? _selectedCategoryId;
  List<Party> _parties = [];
  bool _isPartySearchActive = false;

  // Regular items
  final List<BillItem> _regularItems = [];
  final List<TextEditingController> _regDescControllers = [];
  final List<TextEditingController> _regQtyControllers = [];
  final List<TextEditingController> _regRateControllers = [];
  final List<TextEditingController> _regDiscControllers = [];
  final List<String> _regDiscTypes = [];

  bool _regularExpanded = true;
  bool _roomsExpanded = true;

  // Rooms
  final List<RoomEntry> _rooms = [];

  // Overall
  double _overallDiscount = 0.0;
  String _overallDiscountType = 'none';
  final TextEditingController _overallDiscountController = TextEditingController();
  double _advanceAmount = 0.0;
  final TextEditingController _advanceController = TextEditingController();
  final TextEditingController _additionalChargesController = TextEditingController();

  bool _initializing = true;
  bool _isLoading = false;
  late final bool _isEditing = widget.billId != null;

  // ─────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _dateController.text = DateFormat('dd-MMM-yyyy').format(_selectedDate);
    _init();
  }

  Future<void> _init() async {
    final cats = await DB.I.getCategories();
    final bill = widget.billId == null ? null : await DB.I.getBill(widget.billId!);
    final party = bill == null ? null : await DB.I.getParty(bill.partyId);
    if (!mounted) return;

    if (widget.billId != null && bill == null) {
      _showSnack('Bill not found', _C.danger);
      Navigator.pop(context);
      return;
    }

    _categories = cats;

    if (bill == null) {
      _selectedCategoryId = cats.isNotEmpty ? cats.first.id : null;
      _addRegularItem();
      _addRoom();
      await _loadPartiesByCategory();
      setState(() => _initializing = false);
      return;
    }

    setState(() {
      _selectedDate = bill.date;
      _dateController.text = DateFormat('dd-MMM-yyyy').format(_selectedDate);
      _notesController.text = bill.notes;

      _selectedParty = party ?? Party(id: bill.partyId, name: bill.partyName);
      _partyController.text = _selectedParty!.name;
      final catId = party?.categoryId ?? bill.categoryId;
      _selectedCategoryId = cats.any((c) => c.id == catId)
          ? catId
          : (cats.isNotEmpty ? cats.first.id : null);

      for (final item in bill.items) {
        _regularItems.add(item);
        _regDescControllers.add(TextEditingController(text: item.description));
        _regQtyControllers.add(TextEditingController(text: numText(item.qty)));
        _regRateControllers.add(TextEditingController(text: numText(item.rate)));
        _regDiscControllers.add(TextEditingController(text: numText(item.discValue)));
        _regDiscTypes.add(
            const ['none', 'rupees', 'percentage'].contains(item.discType)
                ? item.discType
                : 'none');
      }

      _overallDiscountType =
      const ['none', 'rupees', 'percentage'].contains(bill.discountType)
          ? bill.discountType
          : 'none';
      if (_overallDiscountType != 'none' && bill.discountValue > 0) {
        _overallDiscount = bill.discountValue;
        _overallDiscountController.text = numText(bill.discountValue);
      }
      if (bill.paidAmount > 0) {
        _advanceAmount = bill.paidAmount;
        _advanceController.text = numText(bill.paidAmount);
      }
      if (bill.additionalCharges > 0) {
        _additionalChargesController.text = numText(bill.additionalCharges);
      }

      for (final r in bill.rooms) {
        _rooms.add(_entryFromRoom(r));
      }
      if (_rooms.isEmpty) _rooms.add(_newRoom());
      _initializing = false;
    });

    await _loadPartiesByCategory();
  }

  RoomEntry _entryFromRoom(Room r) {
    final e = RoomEntry(name: r.name);
    e.wallRatePerSqFt = r.wallRate;
    e.wallRateController.text = numText(r.wallRate, blankZero: true);
    e.additionalCharges = r.additional;
    e.additionalChargesController.text = numText(r.additional, blankZero: true);
    e.hasCeiling = r.hasCeiling;
    e.hasRoof = r.hasRoof;
    e.isSubmitted = true;
    e.isExpanded = false;

    for (final w in r.walls) { _addWallToRoom(e, w); }
    if (e.walls.isEmpty) _addWallToRoom(e);

    if (e.hasCeiling) {
      for (final c in r.ceilings) { _addCeilingToRoom(e, c); }
      if (e.ceilingItems.isEmpty) _addCeilingToRoom(e);
    }
    if (e.hasRoof) {
      for (final c in r.roofs) { _addRoofToRoom(e, c); }
      if (e.roofItems.isEmpty) _addRoofToRoom(e);
    }
    return e;
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _loadPartiesByCategory() async {
    if (_selectedCategoryId == null) {
      setState(() {
        _parties = [];
        _isPartySearchActive = false;
      });
      return;
    }
    final parties = await DB.I.getParties(categoryId: _selectedCategoryId);
    if (!mounted) return;
    setState(() {
      _parties = parties;
      _isPartySearchActive = true; // Always active so you can click to add or select
    });
  }

  // ─────────────────────────────────────────────────────────────────────────
  void _addRegularItem() {
    setState(() {
      _regularItems.add(BillItem());
      _regDescControllers.add(TextEditingController());
      _regQtyControllers.add(TextEditingController(text: '1'));
      _regRateControllers.add(TextEditingController(text: '0'));
      _regDiscControllers.add(TextEditingController(text: '0'));
      _regDiscTypes.add('none');
    });
  }

  void _removeRegularItem(int index) {
    setState(() {
      _regDescControllers[index].dispose();
      _regQtyControllers[index].dispose();
      _regRateControllers[index].dispose();
      _regDiscControllers[index].dispose();
      _regDescControllers.removeAt(index);
      _regQtyControllers.removeAt(index);
      _regRateControllers.removeAt(index);
      _regDiscControllers.removeAt(index);
      _regDiscTypes.removeAt(index);
      _regularItems.removeAt(index);
    });
  }

  void _updateRegularItem(int index) {
    setState(() {
      _regularItems[index] = BillItem(
        description: _regDescControllers[index].text,
        qty: _p(_regQtyControllers[index].text),
        rate: _p(_regRateControllers[index].text),
        discType: _regDiscTypes[index],
        discValue: _p(_regDiscControllers[index].text),
      );
    });
  }

  double get regularItemsTotal => _regularItems.fold(0.0, (s, i) => s + i.amount);

  // ─────────────────────────────────────────────────────────────────────────
  RoomEntry _newRoom() {
    final room = RoomEntry(name: 'Room ${_rooms.length + 1}');
    _addWallToRoom(room);
    return room;
  }

  void _addRoom() => setState(() => _rooms.add(_newRoom()));

  void _addWallToRoom(RoomEntry room, [Wall? w]) {
    w ??= Wall();
    room.walls.add(w);
    room.wallDescControllers.add(TextEditingController(text: w.description));
    room.wallWidthControllers.add(TextEditingController(text: numText(w.width)));
    room.wallHeightControllers.add(TextEditingController(text: numText(w.height)));
    room.wallQtyControllers.add(TextEditingController(text: numText(w.qty)));
  }

  void _removeWallFromRoom(RoomEntry room, int index) {
    room.wallDescControllers[index].dispose();
    room.wallWidthControllers[index].dispose();
    room.wallHeightControllers[index].dispose();
    room.wallQtyControllers[index].dispose();
    room.wallDescControllers.removeAt(index);
    room.wallWidthControllers.removeAt(index);
    room.wallHeightControllers.removeAt(index);
    room.wallQtyControllers.removeAt(index);
    room.walls.removeAt(index);
  }

  void _updateWallInRoom(RoomEntry room, int index) {
    room.walls[index] = Wall(
      description: room.wallDescControllers[index].text,
      width: _p(room.wallWidthControllers[index].text),
      height: _p(room.wallHeightControllers[index].text),
      qty: _p(room.wallQtyControllers[index].text, 1),
    );
  }

  void _addCeilingToRoom(RoomEntry room, [Extra? e]) {
    e ??= Extra();
    room.ceilingItems.add(e);
    room.ceilDescControllers.add(TextEditingController(text: e.description));
    room.ceilLenControllers.add(TextEditingController(text: numText(e.length)));
    room.ceilWidthControllers.add(TextEditingController(text: numText(e.width)));
    room.ceilQtyControllers.add(TextEditingController(text: numText(e.qty)));
    room.ceilRateControllers.add(TextEditingController(text: numText(e.rate)));
  }

  void _removeCeilingFromRoom(RoomEntry room, int index) {
    room.ceilDescControllers[index].dispose();
    room.ceilLenControllers[index].dispose();
    room.ceilWidthControllers[index].dispose();
    room.ceilQtyControllers[index].dispose();
    room.ceilRateControllers[index].dispose();
    room.ceilDescControllers.removeAt(index);
    room.ceilLenControllers.removeAt(index);
    room.ceilWidthControllers.removeAt(index);
    room.ceilQtyControllers.removeAt(index);
    room.ceilRateControllers.removeAt(index);
    room.ceilingItems.removeAt(index);
  }

  void _updateCeilingInRoom(RoomEntry room, int index) {
    room.ceilingItems[index] = Extra(
      description: room.ceilDescControllers[index].text,
      length: _p(room.ceilLenControllers[index].text),
      width: _p(room.ceilWidthControllers[index].text),
      qty: _p(room.ceilQtyControllers[index].text, 1),
      rate: _p(room.ceilRateControllers[index].text),
    );
  }

  void _addRoofToRoom(RoomEntry room, [Extra? e]) {
    e ??= Extra();
    room.roofItems.add(e);
    room.roofDescControllers.add(TextEditingController(text: e.description));
    room.roofLenControllers.add(TextEditingController(text: numText(e.length)));
    room.roofWidthControllers.add(TextEditingController(text: numText(e.width)));
    room.roofQtyControllers.add(TextEditingController(text: numText(e.qty)));
    room.roofRateControllers.add(TextEditingController(text: numText(e.rate)));
  }

  void _removeRoofFromRoom(RoomEntry room, int index) {
    room.roofDescControllers[index].dispose();
    room.roofLenControllers[index].dispose();
    room.roofWidthControllers[index].dispose();
    room.roofQtyControllers[index].dispose();
    room.roofRateControllers[index].dispose();
    room.roofDescControllers.removeAt(index);
    room.roofLenControllers.removeAt(index);
    room.roofWidthControllers.removeAt(index);
    room.roofQtyControllers.removeAt(index);
    room.roofRateControllers.removeAt(index);
    room.roofItems.removeAt(index);
  }

  void _updateRoofInRoom(RoomEntry room, int index) {
    room.roofItems[index] = Extra(
      description: room.roofDescControllers[index].text,
      length: _p(room.roofLenControllers[index].text),
      width: _p(room.roofWidthControllers[index].text),
      qty: _p(room.roofQtyControllers[index].text, 1),
      rate: _p(room.roofRateControllers[index].text),
    );
  }

  void _submitRoom(int roomIndex) {
    final room = _rooms[roomIndex];
    room.name = room.nameController.text.trim().isEmpty
        ? 'Room ${roomIndex + 1}'
        : room.nameController.text.trim();
    setState(() {
      room.isSubmitted = true;
      room.isExpanded = false;
    });
    _showSnack('${room.name} submitted', _C.success);
  }

  double get allRoomsTotal => _rooms.fold(0.0, (s, r) => s + r.roomTotal);

  // ─────────────────────────────────────────────────────────────────────────
  double get grandTotalBeforeDiscount =>
      regularItemsTotal +
          allRoomsTotal +
          _p(_additionalChargesController.text);

  double get overallDiscountAmount {
    if (_overallDiscountType == 'none') return 0;
    if (_overallDiscountType == 'rupees') {
      return _overallDiscount.clamp(0, grandTotalBeforeDiscount).toDouble();
    }
    if (_overallDiscountType == 'percentage') {
      return grandTotalBeforeDiscount * (_overallDiscount.clamp(0, 100) / 100);
    }
    return 0;
  }

  double get netAmount => grandTotalBeforeDiscount - overallDiscountAmount;
  double get remainingBalance => netAmount - _advanceAmount;

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _saveBill() async {
    if (!_formKey.currentState!.validate()) {
      _showSnack('Please fill required fields', Colors.orange);
      return;
    }
    if (_selectedParty?.id == null) {
      _showSnack('Please select a customer', Colors.orange);
      return;
    }

    final items = _regularItems
        .where((i) => i.description.trim().isNotEmpty || i.amount > 0)
        .toList();

    final rooms = <Room>[];
    for (int i = 0; i < _rooms.length; i++) {
      final r = _rooms[i];
      final n = r.nameController.text.trim();
      r.name = n.isEmpty ? 'Room ${i + 1}' : n;
      if (r.roomTotal > 0) rooms.add(r.toRoom());
    }

    final additional = _p(_additionalChargesController.text);
    if (items.isEmpty && rooms.isEmpty && additional <= 0) {
      _showSnack('Add at least one item or room with an amount', Colors.orange);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final bill = Bill(
        id: widget.billId,
        partyId: _selectedParty!.id!,
        date: _selectedDate,
        notes: _notesController.text.trim(),
        additionalCharges: additional,
        discountType: _overallDiscountType,
        discountValue: _overallDiscountType == 'none' ? 0 : _overallDiscount,
        totalAmount: grandTotalBeforeDiscount,
        totalDiscount: overallDiscountAmount,
        paidAmount: _advanceAmount,
        remaining: remainingBalance,
        items: items,
        rooms: rooms,
      );
      await DB.I.saveBill(bill);
      if (!mounted) return;
      _showSnack(_isEditing ? 'Bill updated' : 'Bill saved', _C.success);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showSnack('Error: $e', _C.danger);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  void dispose() {
    _dateController.dispose();
    _partyController.dispose();
    _notesController.dispose();
    _overallDiscountController.dispose();
    _advanceController.dispose();
    _additionalChargesController.dispose();
    for (final list in [_regDescControllers, _regQtyControllers, _regRateControllers, _regDiscControllers]) {
      for (final c in list) { c.dispose(); }
    }
    for (final r in _rooms) { r.dispose(); }
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top + kToolbarHeight + 14;
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: _C.bg,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _C.surfaceElevated,
          labelStyle: const TextStyle(color: _C.textSecondary, fontSize: 12),
          hintStyle: const TextStyle(color: _C.textMuted, fontSize: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _C.border),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _C.border),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: _C.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
      child: Scaffold(
        backgroundColor: _C.bg,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(
            _isEditing ? 'Edit Entry' : 'New Entry',
            style: const TextStyle(color: _C.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          backgroundColor: _C.surface,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, color: _C.textSecondary, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: ElevatedButton.icon(
                onPressed: (_isLoading || _initializing) ? null : _saveBill,
                icon: const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: _C.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        body: _initializing
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(16, topPad, 16, 40),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Form(
                key: _formKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isDesktop = constraints.maxWidth > 850;
                    if (isDesktop) {
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildTopFields(),
                                const SizedBox(height: 16),
                                _buildRegularBillSection(),
                                const SizedBox(height: 16),
                                _buildOverallSummary(),
                                const SizedBox(height: 16),
                                _buildNotesAndSave(),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 5,
                            child: Column(
                              children: [
                                _buildRoomsSection(),
                              ],
                            ),
                          ),
                        ],
                      );
                    } else {
                      return Column(
                        children: [
                          _buildTopFields(),
                          const SizedBox(height: 16),
                          _buildRegularBillSection(),
                          const SizedBox(height: 16),
                          _buildRoomsSection(),
                          const SizedBox(height: 16),
                          _buildOverallSummary(),
                          const SizedBox(height: 16),
                          _buildNotesAndSave(),
                        ],
                      );
                    }
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(colorScheme: const ColorScheme.dark(primary: _C.primary)),
        child: child!,
      ),
    );
    if (date != null) {
      setState(() {
        _selectedDate = date;
        _dateController.text = DateFormat('dd-MMM-yyyy').format(date);
      });
    }
  }

  // Dialog to select customer AND register new
  void _showPartyDialog() {
    showDialog<Party>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                const Text('Select Customer', style: TextStyle(color: _C.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx); // Close selection dialog
                    _showAddNewCustomerDialog(); // Open registration dialog
                  },
                  icon: const Icon(Icons.add_circle_outline, size: 16),
                  label: const Text('New Customer'),
                  style: TextButton.styleFrom(foregroundColor: _C.success),
                ),
              ],
            ),
          ),
          const Divider(color: _C.border, height: 1),
          if (_parties.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No customers found.\nClick "New Customer" to add.', textAlign: TextAlign.center, style: TextStyle(color: _C.textSecondary)),
            )
          else
            LimitedBox(
              maxHeight: 320,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _parties.length,
                itemBuilder: (_, i) => ListTile(
                  leading: CircleAvatar(
                    backgroundColor: _C.primary.withOpacity(0.2),
                    child: Text(_parties[i].name.isNotEmpty ? _parties[i].name[0].toUpperCase() : '?',
                        style: const TextStyle(color: _C.primary, fontWeight: FontWeight.w600)),
                  ),
                  title: Text(_parties[i].name, style: const TextStyle(color: _C.textPrimary, fontSize: 14)),
                  subtitle: Text(_parties[i].phone, style: const TextStyle(color: _C.textMuted, fontSize: 12)),
                  onTap: () => Navigator.pop(ctx, _parties[i]),
                ),
              ),
            ),
        ]),
      ),
    ).then((selected) {
      if (selected != null && mounted) {
        setState(() {
          _selectedParty = selected;
          _partyController.text = selected.name;
        });
      }
    });
  }

  // Register new customer dialog
  Future<void> _showAddNewCustomerDialog() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<Party>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _C.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Register New Customer', style: TextStyle(color: _C.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameCtrl,
                  style: const TextStyle(color: _C.textPrimary),
                  decoration: const InputDecoration(labelText: 'Customer Name *', prefixIcon: Icon(Icons.person, size: 18)),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Enter name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: phoneCtrl,
                  style: const TextStyle(color: _C.textPrimary),
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone (optional)', prefixIcon: Icon(Icons.phone, size: 18)),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: _C.textSecondary)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () async {
                        if (!formKey.currentState!.validate()) return;
                        final newParty = Party(
                          name: nameCtrl.text.trim(),
                          phone: phoneCtrl.text.trim(),
                          categoryId: _selectedCategoryId,
                        );
                        try {
                          final newId = await DB.I.saveParty(newParty);
                          newParty.id = newId;
                          if (ctx.mounted) Navigator.pop(ctx, newParty);
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: _C.danger));
                          }
                        }
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: _C.primary, foregroundColor: Colors.white),
                      child: const Text('Save & Select'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result != null && mounted) {
      await _loadPartiesByCategory(); // Refresh list
      setState(() {
        _selectedParty = result;
        _partyController.text = result.name;
      });
      _showSnack('Customer registered & selected', _C.success);
    }
  }

  Widget _buildTopFields() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Full width Date Row (Paid/Unpaid removed)
          TextFormField(
            controller: _dateController,
            readOnly: true,
            style: const TextStyle(color: _C.textPrimary, fontSize: 14),
            onTap: _pickDate,
            decoration: InputDecoration(
              labelText: 'Date',
              prefixIcon: const Icon(Icons.calendar_today_rounded, color: _C.primary, size: 16),
              suffixIcon: IconButton(
                icon: const Icon(Icons.edit_calendar_rounded, color: _C.primary, size: 16),
                onPressed: _pickDate,
              ),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 16),

          // Party Type Dropdown
          DropdownButtonFormField<int>(
            value: _selectedCategoryId,
            isExpanded: true,
            dropdownColor: _C.surface,
            style: const TextStyle(color: _C.textPrimary, fontSize: 14),
            items: _categories.map((c) => DropdownMenuItem(
                value: c.id,
                child: Text(c.name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _C.textPrimary)))).toList(),
            onChanged: (id) async {
              if (id == _selectedCategoryId) return;
              setState(() {
                _selectedCategoryId = id;
                _selectedParty = null;
                _partyController.clear();
                _parties = [];
              });
              await _loadPartiesByCategory();
            },
            decoration: const InputDecoration(
              labelText: 'Party Type *',
              prefixIcon: Icon(Icons.badge_rounded, color: _C.primary, size: 16),
              suffixIcon: Icon(Icons.search_rounded, color: _C.textMuted, size: 18),
            ),
            validator: (v) => v == null ? 'Select a party type' : null,
          ),
          const SizedBox(height: 16),

          // Party Dropdown
          TextFormField(
            controller: _partyController,
            readOnly: true,
            style: const TextStyle(color: _C.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              labelText: 'Party *',
              prefixIcon: const Icon(Icons.person_rounded, color: _C.primary, size: 16),
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Select or Add Customer',
                    icon: const Icon(Icons.search_rounded, color: _C.primary, size: 18),
                    onPressed: _showPartyDialog,
                  ),
                ],
              ),
            ),
            validator: (v) => v == null || v.isEmpty ? 'Select a party' : null,
            onTap: _showPartyDialog,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRegularBillSection() {
    return _card(
      child: Column(children: [
        _sectionToggleHeader(
          icon: Icons.receipt_long_rounded,
          title: 'Regular Bill',
          badge: '${_regularItems.length} items',
          badgeColor: _C.primary,
          isExpanded: _regularExpanded,
          onTap: () => setState(() => _regularExpanded = !_regularExpanded),
        ),
        if (_regularExpanded) ...[
          const SizedBox(height: 12),
          ...List.generate(_regularItems.length, (i) => _buildRegularItemRow(i)),
          _addButton('Add Item', _addRegularItem),
          const SizedBox(height: 12),
          _buildRegularSummary(),
        ],
      ]),
    );
  }

  Widget _buildRegularItemRow(int i) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.border),
      ),
      child: Column(children: [
        Row(children: [
          Text('Item ${i + 1}', style: const TextStyle(color: _C.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          const Spacer(),
          GestureDetector(
            onTap: () => _removeRegularItem(i),
            child: const Icon(Icons.delete_outline_rounded, color: _C.danger, size: 16),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            flex: 3,
            child: _tf(_regDescControllers[i], 'Description *', onChanged: (_) => _updateRegularItem(i)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _tf(_regQtyControllers[i], 'Qty *', num: true, onChanged: (_) => _updateRegularItem(i)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _tf(_regRateControllers[i], 'Rate', num: true, onChanged: (_) => _updateRegularItem(i)),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _regDiscTypes[i],
              isExpanded: true,
              dropdownColor: _C.surface,
              style: const TextStyle(color: _C.textPrimary, fontSize: 12),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('No Disc')),
                DropdownMenuItem(value: 'rupees', child: Text('Rs.')),
                DropdownMenuItem(value: 'percentage', child: Text('%')),
              ],
              onChanged: (v) {
                _regDiscTypes[i] = v!;
                _updateRegularItem(i);
              },
              decoration: const InputDecoration(labelText: 'Disc'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _tf(_regDiscControllers[i], 'Disc Amt/%', num: true, onChanged: (_) => _updateRegularItem(i)),
          ),
          const SizedBox(width: 16),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const Text('Net', style: TextStyle(color: _C.textMuted, fontSize: 11)),
            Text('Rs. ${_regularItems[i].amount.toStringAsFixed(2)}',
                style: const TextStyle(color: _C.success, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ]),
      ]),
    );
  }

  Widget _buildRegularSummary() {
    final rawTotal = _regularItems.fold(0.0, (s, i) => s + i.gross);
    final discTotal = rawTotal - regularItemsTotal;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.border),
      ),
      child: Column(children: [
        _sumRow('Items subtotal', 'Rs. ${rawTotal.toStringAsFixed(2)}'),
        if (discTotal > 0)
          _sumRow('Total discount', '- Rs. ${discTotal.toStringAsFixed(2)}', valColor: _C.success),
        const Divider(color: _C.border, height: 16),
        _sumRow('Regular bill total', 'Rs. ${regularItemsTotal.toStringAsFixed(2)}', bold: true),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildRoomsSection() {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionToggleHeader(
          icon: Icons.dashboard_customize_rounded,
          title: 'Fixed/Wallpaper Details',
          badge: '${_rooms.length} rooms',
          badgeColor: _C.success,
          isExpanded: _roomsExpanded,
          onTap: () => setState(() => _roomsExpanded = !_roomsExpanded),
        ),
        if (_roomsExpanded) ...[
          const SizedBox(height: 12),
          ...List.generate(_rooms.length, (i) => _buildRoomCard(i)),
          _addButton('Add New Room', _addRoom),
          if (_rooms.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildAllRoomsSummary(),
          ],
        ],
      ]),
    );
  }

  Widget _buildRoomCard(int roomIndex) {
    final room = _rooms[roomIndex];
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _C.surfaceElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: room.isSubmitted ? _C.success.withOpacity(0.5) : _C.border),
      ),
      child: Column(children: [
        InkWell(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
          onTap: () => setState(() => room.isExpanded = !room.isExpanded),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _C.surface,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(10),
                bottom: room.isExpanded ? Radius.zero : const Radius.circular(10),
              ),
            ),
            child: Row(children: [
              if (room.isSubmitted)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.check_circle_rounded, color: _C.success, size: 16),
                ),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    room.nameController.text.isEmpty ? 'Room ${roomIndex + 1}' : room.nameController.text,
                    style: const TextStyle(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text('Total: Rs. ${room.roomTotal.toStringAsFixed(2)}',
                      style: const TextStyle(color: _C.textSecondary, fontSize: 11)),
                ]),
              ),
              GestureDetector(
                onTap: () => _confirmRemoveRoom(roomIndex),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.delete_outline_rounded, color: _C.danger, size: 16),
                ),
              ),
              Icon(
                room.isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                color: _C.textSecondary,
                size: 20,
              ),
            ]),
          ),
        ),
        if (room.isExpanded)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _tf(room.nameController, 'Room Name *', fs: 13, onChanged: (_) => setState(() {})),
              const SizedBox(height: 16),

              // Walls
              _subHeader('Walls', Icons.wallpaper_rounded, _C.primary),
              ...List.generate(room.walls.length, (i) => _buildWallRow(room, i)),
              _addButton('Add Wall', () => setState(() => _addWallToRoom(room))),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _tf(room.wallRateController, 'Wall Rate (per sq.ft) *',
                      num: true, prefixText: 'Rs. ', onChanged: (v) => setState(() => room.wallRatePerSqFt = _p(v))),
                ),
                const SizedBox(width: 16),
                Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  const Text('Wall Total', style: TextStyle(color: _C.textMuted, fontSize: 11)),
                  Text('Rs. ${room.wallTotal.toStringAsFixed(2)}',
                      style: const TextStyle(color: _C.primary, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
              ]),
              const SizedBox(height: 16),

              // Ceiling
              Row(children: [
                Checkbox(
                  value: room.hasCeiling,
                  activeColor: _C.primary,
                  side: const BorderSide(color: _C.border),
                  onChanged: (v) => setState(() {
                    room.hasCeiling = v!;
                    if (room.hasCeiling && room.ceilingItems.isEmpty) {
                      _addCeilingToRoom(room);
                    }
                  }),
                ),
                _subHeader('Has Ceiling', Icons.roofing_rounded, _C.warning),
              ]),
              if (room.hasCeiling) ...[
                ...List.generate(room.ceilingItems.length, (i) => _buildCeilingRow(room, i)),
                _addButton('Add Ceiling Item', () => setState(() => _addCeilingToRoom(room))),
              ],
              const SizedBox(height: 8),

              // Roof
              Row(children: [
                Checkbox(
                  value: room.hasRoof,
                  activeColor: _C.primary,
                  side: const BorderSide(color: _C.border),
                  onChanged: (v) => setState(() {
                    room.hasRoof = v!;
                    if (room.hasRoof && room.roofItems.isEmpty) {
                      _addRoofToRoom(room);
                    }
                  }),
                ),
                _subHeader('Has Roof', Icons.house_rounded, _C.accent),
              ]),
              if (room.hasRoof) ...[
                ...List.generate(room.roofItems.length, (i) => _buildRoofRow(room, i)),
                _addButton('Add Roof Item', () => setState(() => _addRoofToRoom(room))),
              ],
              const SizedBox(height: 16),

              // Room-level additional charges
              _tf(room.additionalChargesController, 'Additional Charges (optional)',
                  num: true, prefixText: 'Rs. ', onChanged: (v) => setState(() => room.additionalCharges = _p(v))),
              const SizedBox(height: 16),

              _buildRoomSummary(room),
              const SizedBox(height: 12),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _submitRoom(roomIndex),
                  icon: Icon(room.isSubmitted ? Icons.check_circle_rounded : Icons.done_all_rounded, size: 16),
                  label: Text(room.isSubmitted
                      ? 'Submit ${room.nameController.text.isEmpty ? 'Room' : room.nameController.text}'
                      : 'Submit ${room.nameController.text.isEmpty ? 'Room' : room.nameController.text}'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _C.success,
                    side: const BorderSide(color: _C.success),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ]),
          ),
      ]),
    );
  }

  Future<void> _confirmRemoveRoom(int index) async {
    final ok = await confirmDialog(context, 'Remove Room',
        'Remove "${_rooms[index].nameController.text.isEmpty ? 'Room ${index + 1}' : _rooms[index].nameController.text}" from this bill?',
        okText: 'Remove');
    if (!ok || !mounted) return;
    late final RoomEntry removed;
    setState(() => removed = _rooms.removeAt(index));
    WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
  }

  Widget _buildWallRow(RoomEntry room, int i) {
    return _dimRow(
      title: 'Wall ${i + 1}',
      footer: 'Sq.ft: ${room.walls[i].sqft.toStringAsFixed(2)}',
      onRemove: () => setState(() => _removeWallFromRoom(room, i)),
      onChanged: () => setState(() => _updateWallInRoom(room, i)),
      cells: [
        _Cell(room.wallDescControllers[i], 'Description (optional)', num: false, flex: 2),
        _Cell(room.wallWidthControllers[i], 'W (ft)'),
        _Cell(room.wallHeightControllers[i], 'H (ft)'),
        _Cell(room.wallQtyControllers[i], 'Qty'),
      ],
    );
  }

  Widget _buildCeilingRow(RoomEntry room, int i) {
    return _dimRow(
      title: 'Ceiling ${i + 1}',
      footer: 'Total: Rs. ${room.ceilingItems[i].total.toStringAsFixed(2)}',
      onRemove: () => setState(() => _removeCeilingFromRoom(room, i)),
      onChanged: () => setState(() => _updateCeilingInRoom(room, i)),
      cells: [
        _Cell(room.ceilDescControllers[i], 'Description', num: false, flex: 2),
        _Cell(room.ceilLenControllers[i], 'Len (ft)'),
        _Cell(room.ceilWidthControllers[i], 'W (ft)'),
        _Cell(room.ceilQtyControllers[i], 'Qty'),
        _Cell(room.ceilRateControllers[i], 'Rate'),
      ],
    );
  }

  Widget _buildRoofRow(RoomEntry room, int i) {
    return _dimRow(
      title: 'Roof ${i + 1}',
      footer: 'Total: Rs. ${room.roofItems[i].total.toStringAsFixed(2)}',
      onRemove: () => setState(() => _removeRoofFromRoom(room, i)),
      onChanged: () => setState(() => _updateRoofInRoom(room, i)),
      cells: [
        _Cell(room.roofDescControllers[i], 'Description', num: false, flex: 2),
        _Cell(room.roofLenControllers[i], 'Len (ft)'),
        _Cell(room.roofWidthControllers[i], 'W (ft)'),
        _Cell(room.roofQtyControllers[i], 'Qty'),
        _Cell(room.roofRateControllers[i], 'Rate'),
      ],
    );
  }

  Widget _dimRow({
    required String title,
    required String footer,
    required VoidCallback onRemove,
    required VoidCallback onChanged,
    required List<_Cell> cells,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.border),
      ),
      child: Column(children: [
        Row(children: [
          Text(title, style: const TextStyle(color: _C.textMuted, fontSize: 11, fontWeight: FontWeight.w500)),
          const Spacer(),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded, color: _C.danger, size: 16),
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          for (int k = 0; k < cells.length; k++) ...[
            if (k > 0) const SizedBox(width: 8),
            Expanded(
              flex: cells[k].flex,
              child: _tf(cells[k].c, cells[k].label, num: cells[k].num, fs: 12, onChanged: (_) => onChanged()),
            ),
          ],
        ]),
        const SizedBox(height: 6),
        Align(
          alignment: Alignment.centerRight,
          child: Text(footer, style: const TextStyle(color: _C.textSecondary, fontSize: 11)),
        ),
      ]),
    );
  }

  Widget _buildRoomSummary(RoomEntry room) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.border),
      ),
      child: Column(children: [
        _sumRow('Walls (${room.totalWallSqFt.toStringAsFixed(1)} sq.ft)', 'Rs. ${room.wallTotal.toStringAsFixed(2)}'),
        if (room.hasCeiling) _sumRow('Ceiling', 'Rs. ${room.ceilingTotal.toStringAsFixed(2)}'),
        if (room.hasRoof) _sumRow('Roof', 'Rs. ${room.roofTotal.toStringAsFixed(2)}'),
        if (room.additionalCharges > 0) _sumRow('Additional', 'Rs. ${room.additionalCharges.toStringAsFixed(2)}'),
        const Divider(color: _C.border, height: 12),
        _sumRow('Room Total', 'Rs. ${room.roomTotal.toStringAsFixed(2)}', bold: true, valColor: _C.primary),
      ]),
    );
  }

  Widget _buildAllRoomsSummary() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.surfaceElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _C.border),
      ),
      child: Column(children: [
        const Row(children: [
          Icon(Icons.summarize_rounded, color: _C.accent, size: 14),
          SizedBox(width: 8),
          Text('All Rooms Summary', style: TextStyle(color: _C.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 12),
        ...List.generate(
          _rooms.length,
              (i) => _sumRow(
            _rooms[i].nameController.text.isEmpty ? 'Room ${i + 1}' : _rooms[i].nameController.text,
            'Rs. ${_rooms[i].roomTotal.toStringAsFixed(2)}',
          ),
        ),
        const Divider(color: _C.border, height: 16),
        _sumRow('Total (all rooms)', 'Rs. ${allRoomsTotal.toStringAsFixed(2)}', bold: true, valColor: _C.success),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  Widget _buildOverallSummary() {
    return _card(
      child: Column(children: [
        const Row(children: [
          Icon(Icons.calculate_rounded, color: _C.primary, size: 16),
          SizedBox(width: 8),
          Text('Overall Summary', style: TextStyle(color: _C.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Column 1: Subtotals
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Subtotals', style: TextStyle(color: _C.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  _sumRow('Regular Bill', 'Rs. ${regularItemsTotal.toStringAsFixed(2)}'),
                  _sumRow('All Rooms', 'Rs. ${allRoomsTotal.toStringAsFixed(2)}'),
                  const SizedBox(height: 8),
                  _tf(_additionalChargesController, 'Additional Charges', num: true, prefixText: 'Rs. ', onChanged: (_) => setState(() {})),
                  const Divider(color: _C.border, height: 20),
                  _sumRow('Subtotal', 'Rs. ${grandTotalBeforeDiscount.toStringAsFixed(2)}', bold: true, valColor: _C.primary),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Column 2: Adjustments
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Adjustments', style: TextStyle(color: _C.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Row(children: [
                    const Text('Discount', style: TextStyle(color: _C.textSecondary, fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _overallDiscountType,
                        isExpanded: true,
                        dropdownColor: _C.surface,
                        style: const TextStyle(color: _C.textPrimary, fontSize: 12),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('None')),
                          DropdownMenuItem(value: 'rupees', child: Text('Rs.')),
                          DropdownMenuItem(value: 'percentage', child: Text('%')),
                        ],
                        onChanged: (v) => setState(() {
                          _overallDiscountType = v!;
                          if (v == 'none') {
                            _overallDiscount = 0;
                            _overallDiscountController.clear();
                          }
                        }),
                        decoration: const InputDecoration(),
                      ),
                    ),
                  ]),
                  if (_overallDiscountType != 'none') ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _overallDiscountController,
                      keyboardType: _numKb,
                      inputFormatters: _numFmt,
                      style: const TextStyle(color: _C.textPrimary, fontSize: 12),
                      onChanged: (v) => setState(() => _overallDiscount = _p(v)),
                      decoration: InputDecoration(
                        suffixText: _overallDiscountType == 'percentage' ? '%' : null,
                        prefixText: _overallDiscountType == 'rupees' ? 'Rs. ' : null,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(children: [
                    const Text('Advance', style: TextStyle(color: _C.textSecondary, fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _advanceController,
                        keyboardType: _numKb,
                        inputFormatters: _numFmt,
                        style: const TextStyle(color: _C.textPrimary, fontSize: 12),
                        onChanged: (v) => setState(() => _advanceAmount = _p(v)),
                        decoration: const InputDecoration(prefixText: 'Rs. '),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 16),
            // Column 3: Net
            Expanded(
              flex: 3,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _C.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _C.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Net', style: TextStyle(color: _C.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    _sumRow('Net Amount', 'Rs. ${netAmount.toStringAsFixed(2)}'),
                    const SizedBox(height: 8),
                    if (overallDiscountAmount > 0)
                      _sumRow('Discount applied', '- Rs. ${overallDiscountAmount.toStringAsFixed(2)}', valColor: _C.success),
                    const SizedBox(height: 8),
                    _sumRow('Advance', 'Rs. ${_advanceAmount.toStringAsFixed(2)}', valColor: _C.warning),
                    const Divider(color: _C.border, height: 20),
                    const Text('Balance Due', style: TextStyle(color: _C.textSecondary, fontSize: 12)),
                    const SizedBox(height: 4),
                    Text('Rs. ${remainingBalance.toStringAsFixed(2)}',
                        style: TextStyle(
                            color: remainingBalance > 0 ? _C.danger : _C.success,
                            fontSize: 16,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _buildNotesAndSave() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _card(
            child: TextFormField(
              controller: _notesController,
              maxLines: 3,
              style: const TextStyle(color: _C.textPrimary, fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 40),
                  child: Icon(Icons.sticky_note_2_rounded, color: _C.primary, size: 18),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _saveBill,
            icon: _isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_rounded, size: 18),
            label: Text(_isEditing ? 'Update Bill' : 'Save Bill', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Shared helpers ────────────────────────────────────────────────────────
  Widget _tf(
      TextEditingController c,
      String? label, {
        bool num = false,
        double fs = 13,
        String? prefixText,
        String? hint,
        IconData? icon,
        Color iconColor = _C.primary,
        ValueChanged<String>? onChanged,
      }) {
    return TextFormField(
      controller: c,
      keyboardType: num ? _numKb : TextInputType.text,
      inputFormatters: num ? _numFmt : null,
      style: TextStyle(color: _C.textPrimary, fontSize: fs),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixText: prefixText,
        prefixIcon: icon == null ? null : Icon(icon, color: iconColor, size: 18),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: child,
    );
  }

  Widget _sectionToggleHeader({
    required IconData icon,
    required String title,
    required String badge,
    required Color badgeColor,
    required bool isExpanded,
    required VoidCallback onTap,
  }) {
    return Row(children: [
      Icon(icon, color: badgeColor, size: 18),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(color: _C.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: badgeColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
        child: Text(badge, style: TextStyle(color: badgeColor, fontSize: 10, fontWeight: FontWeight.w600)),
      ),
      const Spacer(),
      Transform.scale(
        scale: 0.8,
        child: Switch(
          value: isExpanded,
          onChanged: (v) => onTap(),
          activeColor: badgeColor,
          inactiveThumbColor: _C.textMuted,
          inactiveTrackColor: _C.surfaceElevated,
        ),
      ),
    ]);
  }

  Widget _subHeader(String title, IconData icon, Color color) {
    return Row(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 6),
      Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
    ]);
  }

  Widget _addButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: _C.border, style: BorderStyle.solid),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.add_rounded, color: _C.textSecondary, size: 16),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: _C.textSecondary, fontSize: 13)),
        ]),
      ),
    );
  }

  Widget _sumRow(String label, String value, {bool bold = false, Color? valColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Flexible(
          child: Text(label,
              style: TextStyle(
                  color: bold ? _C.textPrimary : _C.textSecondary,
                  fontSize: 12,
                  fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        ),
        const SizedBox(width: 8),
        Text(value,
            style: TextStyle(
                color: valColor ?? _C.textPrimary,
                fontSize: 13,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
      ]),
    );
  }
}