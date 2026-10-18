import 'package:flutter/material.dart';
import 'models/food_item.dart';
import 'models/meal_log.dart';
import 'services/db_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DbService.init();
  runApp(const BulkingTrackerApp());
}

class BulkingTrackerApp extends StatelessWidget {
  const BulkingTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bulking Tracker',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121417),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE5A93C), // Warm gold/orange for energy/bulking
          secondary: Color(0xFF4CAF50), // Fresh green for protein/growth
          surface: Color(0xFF1B1E23),
          surfaceContainerHighest: Color(0xFF262A32),
          onSurface: Color(0xFFEDEDED),
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFF1B1E23),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFF2C313C), width: 1),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF262A32),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final DateTime _selectedDate = DateTime.now();
  List<MealLog> _logs = [];
  bool _isLoading = true;

  // Bulking default targets
  double _targetCalories = 2500;
  double _targetProtein = 140;

  static const List<String> _sessions = [
    'Makan 1',
    'Makan 2',
    'Makan 3',
    'Camilan',
  ];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await DbService.getLogsForDay(_selectedDate);
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  double get _totalCalories =>
      _logs.fold(0.0, (acc, item) => acc + item.totalCalories);

  double get _totalProtein =>
      _logs.fold(0.0, (acc, item) => acc + item.totalProtein);

  void _openAddLogSheet({String? defaultSession}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1A1D23),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => LogMealSheet(
        initialSession: defaultSession ?? _sessions.first,
        sessions: _sessions,
        onSaved: _loadLogs,
      ),
    );
  }

  void _openAddCustomFoodDialog() {
    showDialog(
      context: context,
      builder: (ctx) => const AddCustomFoodDialog(),
    );
  }

  void _openEditTargetDialog() {
    final calCtrl = TextEditingController(text: _targetCalories.toInt().toString());
    final proCtrl = TextEditingController(text: _targetProtein.toInt().toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1F232B),
        title: const Text('Target Harian Bulking'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: calCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target Kalori (kkal)',
                suffixText: 'kkal',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: proCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Target Protein (g)',
                suffixText: 'gram',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              final cal = double.tryParse(calCtrl.text) ?? _targetCalories;
              final pro = double.tryParse(proCtrl.text) ?? _targetProtein;
              setState(() {
                _targetCalories = cal;
                _targetProtein = pro;
              });
              Navigator.pop(ctx);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteLog(MealLog log) async {
    await DbService.deleteMealLog(log.id);
    _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bulking Tracker',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Ubah Target',
            onPressed: _openEditTargetDialog,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Tambah Makanan Kustom',
            onPressed: _openAddCustomFoodDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLogs,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildDailyProgressCard(),
                  const SizedBox(height: 20),
                  const Text(
                    'Sesi Makan Hari Ini',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ..._sessions.map((session) => _buildSessionCard(session)),
                  const SizedBox(height: 60),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add),
        label: const Text('Catat Makan', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _openAddLogSheet(),
      ),
    );
  }

  Widget _buildDailyProgressCard() {
    final calProgress = (_totalCalories / _targetCalories).clamp(0.0, 1.0);
    final proProgress = (_totalProtein / _targetProtein).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ringkasan Hari Ini',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Text(
                  '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricTile(
                    label: 'Kalori',
                    current: _totalCalories.toInt().toString(),
                    target: '${_targetCalories.toInt()} kkal',
                    progress: calProgress,
                    progressColor: const Color(0xFFE5A93C),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Protein',
                    current: '${_totalProtein.toStringAsFixed(1)}g',
                    target: '${_targetProtein.toInt()}g',
                    progress: proProgress,
                    progressColor: const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String current,
    required String target,
    required double progress,
    required Color progressColor,
  }) {
    final percent = (progress * 100).toInt();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF232730),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white70,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$percent%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: progressColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                current,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/ $target',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white54,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF333842),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionCard(String session) {
    final sessionLogs = _logs.where((l) => l.mealSession == session).toList();
    final sessionCal = sessionLogs.fold(0.0, (acc, item) => acc + item.totalCalories);
    final sessionPro = sessionLogs.fold(0.0, (acc, item) => acc + item.totalProtein);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      session.contains('Camilan')
                          ? Icons.cookie_outlined
                          : Icons.restaurant,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      session,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text(
                      '${sessionCal.toInt()} kkal • ${sessionPro.toStringAsFixed(1)}g pro',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton(
                      icon: const Icon(Icons.add, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Tambah ke $session',
                      onPressed: () => _openAddLogSheet(defaultSession: session),
                    ),
                  ],
                ),
              ],
            ),
            if (sessionLogs.isNotEmpty) const Divider(height: 20),
            ...sessionLogs.map((log) {
              final food = log.foodItem.value;
              final estGram = (food?.estimatedGrams ?? 0) * log.portionMultiplier;
              final multiplierStr = log.portionMultiplier % 1 == 0
                  ? log.portionMultiplier.toInt().toString()
                  : log.portionMultiplier.toString();

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            food?.name ?? 'Makanan',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            '$multiplierStr ${food?.portionUnit ?? 'porsi'} (~${estGram.toInt()}g) • ${log.totalCalories.toInt()} kkal • ${log.totalProtein.toStringAsFixed(1)}g P',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      color: Colors.redAccent.withValues(alpha: 0.7),
                      onPressed: () => _deleteLog(log),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class LogMealSheet extends StatefulWidget {
  final String initialSession;
  final List<String> sessions;
  final VoidCallback onSaved;

  const LogMealSheet({
    super.key,
    required this.initialSession,
    required this.sessions,
    required this.onSaved,
  });

  @override
  State<LogMealSheet> createState() => _LogMealSheetState();
}

class _LogMealSheetState extends State<LogMealSheet> {
  late String _currentSession;
  List<FoodItem> _allFoods = [];
  FoodItem? _selectedFood;
  double _portion = 1.0;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _currentSession = widget.initialSession;
    _loadFoods('');
  }

  Future<void> _loadFoods(String query) async {
    final list = await DbService.searchFoods(query);
    setState(() {
      _allFoods = list;
      if (_selectedFood == null && list.isNotEmpty) {
        _selectedFood = list.first;
      }
    });
  }

  void _adjustPortion(double delta) {
    setState(() {
      final next = _portion + delta;
      if (next >= 0.5) _portion = next;
    });
  }

  Future<void> _save() async {
    if (_selectedFood == null) return;
    await DbService.addMealLog(
      food: _selectedFood!,
      mealSession: _currentSession,
      portionMultiplier: _portion,
    );
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final food = _selectedFood;
    final totalCal = (food?.calories ?? 0) * _portion;
    final totalPro = (food?.protein ?? 0) * _portion;
    final totalGram = (food?.estimatedGrams ?? 0) * _portion;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Catat Porsi Makan (URT)',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Sesi Makan Picker
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: widget.sessions.map((s) {
                final isSelected = s == _currentSession;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: isSelected,
                    onSelected: (val) {
                      if (val) setState(() => _currentSession = s);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          // Search Bar
          TextField(
            controller: _searchCtrl,
            onChanged: _loadFoods,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cari makanan (misal: telur, ayam, nasi)...',
            ),
          ),
          const SizedBox(height: 12),
          // Food List Horizontal / Compact Picker
          SizedBox(
            height: 90,
            child: _allFoods.isEmpty
                ? const Center(child: Text('Tidak ada makanan ditemukan'))
                : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _allFoods.length,
                    itemBuilder: (ctx, i) {
                      final item = _allFoods[i];
                      final isSelected = _selectedFood?.id == item.id;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedFood = item),
                        child: Container(
                          width: 140,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                                : const Color(0xFF232730),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '1 ${item.portionUnit}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                ),
                              ),
                              Text(
                                '${item.calories.toInt()} kkal • ${item.protein}g P',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
          // Portion Counter & Chips
          if (food != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF232730),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Porsi (${food.portionUnit})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () => _adjustPortion(-0.5),
                          ),
                          Text(
                            _portion % 1 == 0
                                ? _portion.toInt().toString()
                                : _portion.toString(),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () => _adjustPortion(0.5),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Quick multiplier chips
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [0.5, 1.0, 1.5, 2.0, 3.0].map((val) {
                      final isCurrent = _portion == val;
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(44, 32),
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            backgroundColor: isCurrent
                                ? Theme.of(context).colorScheme.primary
                                : null,
                            foregroundColor: isCurrent ? Colors.black : Colors.white,
                          ),
                          onPressed: () => setState(() => _portion = val),
                          child: Text('${val % 1 == 0 ? val.toInt() : val}x'),
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(height: 20),
                  // URT Conversion Preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text('~${totalGram.toInt()} Gram'),
                      Text(
                        '${totalCal.toInt()} kkal',
                        style: const TextStyle(
                          color: Color(0xFFE5A93C),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${totalPro.toStringAsFixed(1)}g Protein',
                        style: const TextStyle(
                          color: Color(0xFF4CAF50),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _save,
                child: const Text(
                  'Simpan ke Log Harian',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class AddCustomFoodDialog extends StatefulWidget {
  const AddCustomFoodDialog({super.key});

  @override
  State<AddCustomFoodDialog> createState() => _AddCustomFoodDialogState();
}

class _AddCustomFoodDialogState extends State<AddCustomFoodDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _unitCtrl = TextEditingController(text: 'porsi');
  final _gramCtrl = TextEditingController(text: '100');
  final _calCtrl = TextEditingController();
  final _proCtrl = TextEditingController();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await DbService.addCustomFood(
      name: _nameCtrl.text,
      portionUnit: _unitCtrl.text,
      estimatedGrams: double.tryParse(_gramCtrl.text) ?? 100,
      calories: double.tryParse(_calCtrl.text) ?? 0,
      protein: double.tryParse(_proCtrl.text) ?? 0,
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Menu makanan kustom berhasil ditambahkan')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1F232B),
      title: const Text('Tambah Makanan Kustom'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Makanan',
                  hintText: 'Misal: Susu Whey, Ikan Nila',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _unitCtrl,
                decoration: const InputDecoration(
                  labelText: 'Satuan Porsi URT',
                  hintText: 'Misal: scoop, mangkuk kecil, ekor',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _gramCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Estimasi Berat (gram)',
                  suffixText: 'g',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _calCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Kalori per Porsi',
                  suffixText: 'kkal',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _proCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Protein per Porsi',
                  suffixText: 'g',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Wajib diisi' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: const Text('Simpan'),
        ),
      ],
    );
  }
}
