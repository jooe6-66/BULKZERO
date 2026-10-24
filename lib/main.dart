import 'package:flutter/material.dart';
import 'models/food_item.dart';
import 'models/meal_log.dart';
import 'models/weight_log.dart';
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
      title: 'BulkZero',
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
        dialogTheme: const DialogThemeData(backgroundColor: Color(0xFF1F232B)),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF1F232B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
  DateTime _selectedDate = DateTime.now();
  List<MealLog> _logs = [];
  bool _isLoading = true;

  String _userName = '';
  double _userWeight = 60.0;
  double _userHeight = 170.0;
  int _userAge = 22;

  // Bulking targets (loaded from Isar)
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
    _initData();
  }

  Future<void> _initData() async {
    final settings = await DbService.getSettings();
    if (mounted) {
      setState(() {
        _userName = settings.name;
        _userWeight = settings.weight;
        _userHeight = settings.height;
        _userAge = settings.age;
        _targetCalories = settings.targetCalories;
        _targetProtein = settings.targetProtein;
      });
      if (!settings.isProfileCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openProfileDialog(isOnboarding: true);
        });
      }
    }
    _loadLogs();
  }

  void _openProfileDialog({bool isOnboarding = false}) {
    showDialog(
      context: context,
      barrierDismissible: !isOnboarding,
      builder: (ctx) => ProfileDialog(
        initialName: _userName,
        initialWeight: _userWeight,
        initialHeight: _userHeight,
        initialAge: _userAge,
        initialCalories: _targetCalories,
        initialProtein: _targetProtein,
        isOnboarding: isOnboarding,
        onSaved: (name, weight, height, age, cal, pro) {
          setState(() {
            _userName = name;
            _userWeight = weight;
            _userHeight = height;
            _userAge = age;
            _targetCalories = cal;
            _targetProtein = pro;
          });
        },
      ),
    );
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    final logs = await DbService.getLogsForDay(_selectedDate);
    setState(() {
      _logs = logs;
      _isLoading = false;
    });
  }

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void _changeDate(int offset) {
    setState(() {
      _selectedDate = _selectedDate.add(Duration(days: offset));
    });
    _loadLogs();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _loadLogs();
    }
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
      builder: (ctx) => LogMealSheet(
        initialSession: defaultSession ?? _sessions.first,
        sessions: _sessions,
        selectedDate: _selectedDate,
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

  Future<void> _deleteLog(MealLog log) async {
    final food = log.foodItem.value;
    final foodName = food?.name ?? 'Makanan';
    final session = log.mealSession;
    final portion = log.portionMultiplier;
    final date = log.date;

    await DbService.deleteMealLog(log.id);
    _loadLogs();

    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$foodName dihapus dari $session'),
        action: SnackBarAction(
          label: 'BATAL',
          textColor: Theme.of(context).colorScheme.primary,
          onPressed: () async {
            if (food != null) {
              await DbService.addMealLog(
                food: food,
                mealSession: session,
                portionMultiplier: portion,
                date: date,
              );
              _loadLogs();
            }
          },
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _copyYesterdaySession(String session) async {
    final count = await DbService.copySessionFromYesterday(session, _selectedDate);
    if (!mounted) return;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Tidak ada menu $session di hari kemarin.')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berhasil menyalin $count menu $session dari kemarin!')),
      );
      _loadLogs();
    }
  }

  void _openEditPortionDialog(MealLog log) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => EditPortionSheet(
        log: log,
        onSaved: _loadLogs,
      ),
    );
  }

  void _openWeightLogSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => WeightLogSheet(
        currentWeight: _userWeight,
        onWeightUpdated: (newWeight) {
          setState(() {
            _userWeight = newWeight;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BulkZero',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            if (_userName.isNotEmpty)
              Text(
                'Halo, $_userName',
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.monitor_weight_outlined),
            tooltip: 'Timbangan Berat Badan',
            onPressed: _openWeightLogSheet,
          ),
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Profil & BMI',
            onPressed: () => _openProfileDialog(isOnboarding: false),
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
                  'Ringkasan Nutrisi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF232730),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left, size: 20),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        tooltip: 'Hari Sebelumnya',
                        onPressed: () => _changeDate(-1),
                      ),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: _isToday
                                    ? Theme.of(context).colorScheme.primary
                                    : Colors.white70,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _isToday
                                    ? 'Hari Ini'
                                    : '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _isToday
                                      ? Theme.of(context).colorScheme.primary
                                      : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right, size: 20),
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                        tooltip: 'Hari Berikutnya',
                        onPressed: () => _changeDate(1),
                      ),
                    ],
                  ),
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
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFF333842),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 10,
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.history, size: 20),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Salin menu kemarin ke $session',
                      onPressed: () => _copyYesterdaySession(session),
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
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _openEditPortionDialog(log),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
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
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          color: Colors.white70,
                          tooltip: 'Ubah Porsi',
                          onPressed: () => _openEditPortionDialog(log),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          color: Colors.redAccent.withValues(alpha: 0.7),
                          tooltip: 'Hapus Log',
                          onPressed: () => _deleteLog(log),
                        ),
                      ],
                    ),
                  ),
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
  final DateTime selectedDate;
  final VoidCallback onSaved;

  const LogMealSheet({
    super.key,
    required this.initialSession,
    required this.sessions,
    required this.selectedDate,
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
      if (next >= 0.25) _portion = double.parse(next.toStringAsFixed(2));
    });
  }

  Future<void> _save() async {
    if (_selectedFood == null) return;
    final foodName = _selectedFood!.name;
    final session = _currentSession;
    await DbService.addMealLog(
      food: _selectedFood!,
      mealSession: _currentSession,
      portionMultiplier: _portion,
      date: widget.selectedDate,
    );
    widget.onSaved();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$foodName berhasil dicatat ke $session'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
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
                          width: 155,
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.22)
                                : const Color(0xFF232730),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : const Color(0xFF2E333D),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Stack(
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? Theme.of(context).colorScheme.primary
                                          : Colors.white,
                                    ),
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
                                      color: Colors.white70,
                                    ),
                                  ),
                                ],
                              ),
                              if (isSelected)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: Icon(
                                    Icons.check_circle,
                                    size: 16,
                                    color: Theme.of(context).colorScheme.primary,
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
                            onPressed: () => _adjustPortion(-0.25),
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
                            onPressed: () => _adjustPortion(0.25),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Quick portion presets (daily Indonesian terms)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        (0.5, '🥣 Setengah'),
                        (1.0, '🍽️ Pas (Standar)'),
                        (1.5, '🍲 Nambah'),
                        (2.0, '🥘 Jumbo'),
                        (3.0, '🏋️ Porsi Kuli'),
                      ].map((item) {
                        final val = item.$1;
                        final label = item.$2;
                        final isCurrent = (_portion - val).abs() < 0.05;
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
                              side: BorderSide(
                                color: isCurrent
                                    ? Theme.of(context).colorScheme.primary
                                    : const Color(0xFF333842),
                              ),
                            ),
                            onPressed: () => setState(() => _portion = val),
                            child: Text(label, style: const TextStyle(fontSize: 12)),
                          ),
                        );
                      }).toList(),
                    ),
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

class ProfileDialog extends StatefulWidget {
  final String initialName;
  final double initialWeight;
  final double initialHeight;
  final int initialAge;
  final double initialCalories;
  final double initialProtein;
  final bool isOnboarding;
  final void Function(
    String name,
    double weight,
    double height,
    int age,
    double calories,
    double protein,
  ) onSaved;

  const ProfileDialog({
    super.key,
    required this.initialName,
    required this.initialWeight,
    required this.initialHeight,
    required this.initialAge,
    required this.initialCalories,
    required this.initialProtein,
    required this.isOnboarding,
    required this.onSaved,
  });

  @override
  State<ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<ProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _weightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _calCtrl;
  late final TextEditingController _proCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _weightCtrl = TextEditingController(
      text: widget.initialWeight > 0 ? widget.initialWeight.toStringAsFixed(0) : '60',
    );
    _heightCtrl = TextEditingController(
      text: widget.initialHeight > 0 ? widget.initialHeight.toStringAsFixed(0) : '170',
    );
    _ageCtrl = TextEditingController(
      text: widget.initialAge > 0 ? widget.initialAge.toString() : '22',
    );
    _calCtrl = TextEditingController(
      text: widget.initialCalories.toInt().toString(),
    );
    _proCtrl = TextEditingController(
      text: widget.initialProtein.toInt().toString(),
    );
  }

  void _calculateTargets() {
    final w = double.tryParse(_weightCtrl.text) ?? 60.0;
    final h = double.tryParse(_heightCtrl.text) ?? 170.0;
    final a = int.tryParse(_ageCtrl.text) ?? 22;

    if (w <= 0 || h <= 0 || a <= 0) return;

    // Mifflin-St Jeor + bulking surplus (400 kcal) & 2.0g protein / kg
    final bmr = (10 * w) + (6.25 * h) - (5 * a) + 5;
    final tdee = bmr * 1.4;
    final bulkingCal = (tdee + 400).round();
    final bulkingPro = (w * 2.0).round();

    setState(() {
      _calCtrl.text = bulkingCal.toString();
      _proCtrl.text = bulkingPro.toString();
    });
  }

  double get _currentBmi {
    final w = double.tryParse(_weightCtrl.text) ?? 0;
    final h = double.tryParse(_heightCtrl.text) ?? 0;
    if (w <= 0 || h <= 0) return 0;
    final hm = h / 100;
    return w / (hm * hm);
  }

  String get _bmiCategory {
    final bmi = _currentBmi;
    if (bmi <= 0) return '-';
    if (bmi < 18.5) return 'Underweight';
    if (bmi < 25.0) return 'Normal';
    if (bmi < 30.0) return 'Overweight';
    return 'Obesitas';
  }

  Color get _bmiCategoryColor {
    final bmi = _currentBmi;
    if (bmi < 18.5) return Colors.blueAccent;
    if (bmi < 25.0) return const Color(0xFF4CAF50);
    if (bmi < 30.0) return const Color(0xFFE5A93C);
    return Colors.redAccent;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    final weight = double.tryParse(_weightCtrl.text) ?? 60;
    final height = double.tryParse(_heightCtrl.text) ?? 170;
    final age = int.tryParse(_ageCtrl.text) ?? 22;
    final cal = double.tryParse(_calCtrl.text) ?? 2500;
    final pro = double.tryParse(_proCtrl.text) ?? 140;

    await DbService.saveProfile(
      name: name,
      weight: weight,
      height: height,
      age: age,
      targetCalories: cal,
      targetProtein: pro,
    );

    widget.onSaved(name, weight, height, age, cal, pro);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bmi = _currentBmi;

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.fitness_center,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.isOnboarding ? 'Selamat Datang di BulkZero' : 'Profil & Target Bulking',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.isOnboarding)
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text(
                    'Isi data fisik kamu untuk menghitung BMI dan target kalori & protein bulking secara otomatis.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Panggilan',
                  hintText: 'Misal: Jooe',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _weightCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        setState(() {});
                        _calculateTargets();
                      },
                      decoration: const InputDecoration(
                        labelText: 'Berat Badan',
                        suffixText: 'kg',
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Wajib' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _heightCtrl,
                      keyboardType: TextInputType.number,
                      onChanged: (_) {
                        setState(() {});
                        _calculateTargets();
                      },
                      decoration: const InputDecoration(
                        labelText: 'Tinggi Badan',
                        suffixText: 'cm',
                      ),
                      validator: (val) =>
                          val == null || val.trim().isEmpty ? 'Wajib' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                onChanged: (_) {
                  setState(() {});
                  _calculateTargets();
                },
                decoration: const InputDecoration(
                  labelText: 'Umur',
                  suffixText: 'tahun',
                ),
                validator: (val) =>
                    val == null || val.trim().isEmpty ? 'Wajib' : null,
              ),
              const SizedBox(height: 14),
              // BMI & Bulking Calculation Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF262A32),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Estimasi BMI:',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        Text(
                          bmi > 0 ? '${bmi.toStringAsFixed(1)} • $_bmiCategory' : '-',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: _bmiCategoryColor,
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 14),
                    const Text(
                      'Rekomendasi Target Bulking:',
                      style: TextStyle(fontSize: 11, color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _calCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Target Kalori',
                              suffixText: 'kkal',
                              isDense: true,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _proCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Target Protein',
                              suffixText: 'g',
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (!widget.isOnboarding)
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: _submit,
          child: Text(
            widget.isOnboarding ? 'Mulai Bulking' : 'Simpan Profil',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}

class EditPortionSheet extends StatefulWidget {
  final MealLog log;
  final VoidCallback onSaved;

  const EditPortionSheet({
    super.key,
    required this.log,
    required this.onSaved,
  });

  @override
  State<EditPortionSheet> createState() => _EditPortionSheetState();
}

class _EditPortionSheetState extends State<EditPortionSheet> {
  late double _portion;
  late final TextEditingController _gramCtrl;

  static const List<(double, String, String, String)> _portionPresets = [
    (0.5, '🥣 Setengah', '0.5x', 'Dikit / ganjel'),
    (1.0, '🍽️ Pas (Standar)', '1.0x', 'Porsi normal'),
    (1.5, '🍲 Nambah', '1.5x', 'Nambah dikit'),
    (2.0, '🥘 Jumbo', '2.0x', 'Porsi dobel'),
    (3.0, '🏋️ Porsi Kuli', '3.0x', 'Super bulking'),
  ];

  @override
  void initState() {
    super.initState();
    _portion = widget.log.portionMultiplier;
    final stdGram = widget.log.foodItem.value?.estimatedGrams ?? 100.0;
    _gramCtrl = TextEditingController(
      text: (_portion * stdGram).round().toString(),
    );
  }

  @override
  void dispose() {
    _gramCtrl.dispose();
    super.dispose();
  }

  void _applyMultiplier(double mult) {
    setState(() {
      _portion = mult;
      final stdGram = widget.log.foodItem.value?.estimatedGrams ?? 100.0;
      _gramCtrl.text = (_portion * stdGram).round().toString();
    });
  }

  void _onGramChanged(String val) {
    final gram = double.tryParse(val.trim());
    final stdGram = widget.log.foodItem.value?.estimatedGrams ?? 100.0;
    if (gram != null && gram > 0 && stdGram > 0) {
      setState(() {
        _portion = double.parse((gram / stdGram).toStringAsFixed(2));
      });
    }
  }

  void _stepGram(double deltaGram) {
    final currentGram = double.tryParse(_gramCtrl.text) ??
        ((widget.log.foodItem.value?.estimatedGrams ?? 100.0) * _portion);
    final nextGram = currentGram + deltaGram;
    if (nextGram >= 5) {
      _gramCtrl.text = nextGram.round().toString();
      _onGramChanged(_gramCtrl.text);
    }
  }

  Future<void> _save() async {
    final foodName = widget.log.foodItem.value?.name ?? 'Makanan';
    await DbService.updateMealLogPortion(widget.log.id, _portion);
    widget.onSaved();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Porsi $foodName berhasil diperbarui'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final food = widget.log.foodItem.value;
    final stdGram = food?.estimatedGrams ?? 100.0;
    final currentGram = (_portion * stdGram).round();
    final cal = ((food?.calories ?? 0.0) * _portion).round();
    final pro = ((food?.protein ?? 0.0) * _portion).toStringAsFixed(1);
    final carbs = ((food?.carbs ?? 0.0) * _portion).toStringAsFixed(1);
    final fat = ((food?.fat ?? 0.0) * _portion).toStringAsFixed(1);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        food?.name ?? 'Makanan',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Porsi standar: 1 ${food?.portionUnit ?? 'porsi'} (~${stdGram.toInt()}g)',
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Macro Highlight Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF232730),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        '$cal',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const Text('Kalori (kkal)', style: TextStyle(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                  Container(width: 1, height: 32, color: const Color(0xFF333842)),
                  Column(
                    children: [
                      Text(
                        '${pro}g',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF4CAF50),
                        ),
                      ),
                      const Text('Protein', style: TextStyle(fontSize: 11, color: Colors.white70)),
                    ],
                  ),
                  Container(width: 1, height: 32, color: const Color(0xFF333842)),
                  Column(
                    children: [
                      Text(
                        '${currentGram}g',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '~${_portion.toStringAsFixed(1)} porsi',
                        style: const TextStyle(fontSize: 11, color: Colors.white70),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            // Preset Porsi Sehari-hari
            const Text(
              'PILIHAN PORSI MAKAN:',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _portionPresets.map((preset) {
                final isSelected = (_portion - preset.$1).abs() < 0.08;
                final optCal = ((food?.calories ?? 0.0) * preset.$1).round();
                final optGram = (stdGram * preset.$1).round();

                return InkWell(
                  onTap: () => _applyMultiplier(preset.$1),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                          : const Color(0xFF1B1E23),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFF2C313C),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          preset.$2,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? Theme.of(context).colorScheme.primary
                                : Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF262A32),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '~${optGram}g • $optCal kkal',
                            style: const TextStyle(fontSize: 10, color: Colors.white70),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 18),
            // Input Gramasi Langsung
            const Text(
              'ATAU TIMBANG LANGSUNG (GRAM):',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF1B1E23),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2C313C)),
              ),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    icon: const Icon(Icons.remove, size: 18),
                    tooltip: '-10g',
                    onPressed: () => _stepGram(-10),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _gramCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      onChanged: _onGramChanged,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 8),
                        suffixText: 'gram',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filledTonal(
                    icon: const Icon(Icons.add, size: 18),
                    tooltip: '+10g',
                    onPressed: () => _stepGram(10),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Karbohidrat: ${carbs}g • Lemak: ${fat}g',
                style: const TextStyle(fontSize: 11, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _save,
                child: Text(
                  'Simpan Porsi (${currentGram}g • $cal kkal)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WeightLogSheet extends StatefulWidget {
  final double currentWeight;
  final ValueChanged<double> onWeightUpdated;

  const WeightLogSheet({
    super.key,
    required this.currentWeight,
    required this.onWeightUpdated,
  });

  @override
  State<WeightLogSheet> createState() => _WeightLogSheetState();
}

class _WeightLogSheetState extends State<WeightLogSheet> {
  final TextEditingController _weightCtrl = TextEditingController();
  List<WeightLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.currentWeight > 0) {
      _weightCtrl.text = widget.currentWeight.toStringAsFixed(1);
    }
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final list = await DbService.getWeightLogs();
    if (mounted) {
      setState(() {
        _logs = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveWeight() async {
    final text = _weightCtrl.text.replaceAll(',', '.').trim();
    final val = double.tryParse(text);
    if (val == null || val <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan angka berat badan yang valid')),
      );
      return;
    }

    await DbService.addWeightLog(val, DateTime.now());
    widget.onWeightUpdated(val);
    await _loadLogs();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Berat badan ${val.toStringAsFixed(1)} kg berhasil dicatat!')),
      );
    }
  }

  Future<void> _confirmDeleteWeight(WeightLog log) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Catatan Berat?'),
        content: Text(
          'Catatan ${log.weight.toStringAsFixed(1)} kg pada tanggal ${log.date.day}/${log.date.month}/${log.date.year} akan dihapus.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DbService.deleteWeightLog(log.id);
      await _loadLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Catatan ${log.weight.toStringAsFixed(1)} kg dihapus'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
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
              Row(
                children: [
                  Icon(Icons.monitor_weight, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Log Berat Badan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Catat berat badan berkala untuk memantau progres bulking.',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Berat Badan Hari Ini',
                    suffixText: 'kg',
                    prefixIcon: Icon(Icons.fitness_center, size: 18),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _saveWeight,
                child: const Text('Catat', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text(
            'Riwayat Timbangan',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? const Center(
                        child: Text(
                          'Belum ada catatan timbangan.',
                          style: TextStyle(color: Colors.white60),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _logs.length,
                        separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFF262A32)),
                        itemBuilder: (ctx, index) {
                          final log = _logs[index];
                          double? delta;
                          if (index + 1 < _logs.length) {
                            delta = log.weight - _logs[index + 1].weight;
                          }

                          final dateStr =
                              '${log.date.day}/${log.date.month}/${log.date.year} ${log.date.hour.toString().padLeft(2, '0')}:${log.date.minute.toString().padLeft(2, '0')}';

                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              '${log.weight.toStringAsFixed(1)} kg',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            subtitle: Text(
                              dateStr,
                              style: const TextStyle(fontSize: 12, color: Colors.white70),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (delta != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: delta > 0
                                          ? Colors.green.withValues(alpha: 0.2)
                                          : delta < 0
                                              ? Colors.redAccent.withValues(alpha: 0.2)
                                              : Colors.grey.withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      delta > 0
                                          ? '+${delta.toStringAsFixed(1)} kg'
                                          : '${delta.toStringAsFixed(1)} kg',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: delta > 0
                                            ? Colors.greenAccent
                                            : delta < 0
                                                ? Colors.redAccent
                                                : Colors.white70,
                                      ),
                                    ),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 18),
                                  color: Colors.white60,
                                  tooltip: 'Hapus Catatan',
                                  onPressed: () => _confirmDeleteWeight(log),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

