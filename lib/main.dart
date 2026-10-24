import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'models/food_item.dart';
import 'models/meal_log.dart';
import 'models/weight_log.dart';
import 'services/db_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DbService.init();
  await NotificationService.init();
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

/// Default meal session for the given hour of day.
String sessionForHour(int hour) {
  if (hour < 11) return 'Makan 1';
  if (hour < 15) return 'Makan 2';
  if (hour < 18) return 'Camilan';
  return 'Makan 3';
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
  double _targetWeight = 68.0;
  double _userHeight = 170.0;
  int _userAge = 22;
  int _activityLevel = 1;

  // Bulking targets (loaded from Isar)
  double _targetCalories = 2500;
  double _targetProtein = 140;
  bool _remindersEnabled = false;
  List<({DateTime date, double calories})> _weeklyCalories = [];

  static const List<String> _sessions = [
    'Makan 1',
    'Makan 2',
    'Makan 3',
    'Camilan',
  ];

  String _selectedSession = sessionForHour(DateTime.now().hour);

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
        _targetWeight = settings.targetWeight;
        _userHeight = settings.height;
        _userAge = settings.age;
        _activityLevel = settings.activityLevel;
        _targetCalories = settings.targetCalories;
        _targetProtein = settings.targetProtein;
        _remindersEnabled = settings.remindersEnabled;
      });
      if (settings.remindersEnabled) {
        NotificationService.setDailyReminders(true);
      }
        if (!settings.isProfileCompleted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _openProfileDialog(isOnboarding: true);
        });
      }
    }
    await _loadLogs();
  }

  void _openProfileDialog({bool isOnboarding = false}) {
    showDialog(
      context: context,
      barrierDismissible: !isOnboarding,
      builder: (ctx) => ProfileDialog(
        initialName: _userName,
        initialWeight: _userWeight,
        initialTargetWeight: _targetWeight,
        initialHeight: _userHeight,
        initialAge: _userAge,
        initialActivityLevel: _activityLevel,
        initialCalories: _targetCalories,
        initialProtein: _targetProtein,
        isOnboarding: isOnboarding,
        onSaved: (name, weight, targetWeight, height, age, activity, cal, pro) {
          setState(() {
            _userName = name;
            _userWeight = weight;
            _targetWeight = targetWeight;
            _userHeight = height;
            _userAge = age;
            _activityLevel = activity;
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
    final weekly = await DbService.getWeeklyCalories(_selectedDate);
    if (!mounted) return;
    setState(() {
      _logs = logs;
      _weeklyCalories = weekly;
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
        targetWeight: _targetWeight,
        onWeightUpdated: (newWeight) {
          setState(() {
            _userWeight = newWeight;
          });
        },
      ),
    );
  }

  void _openSettingsSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DataReminderSheet(
        remindersEnabled: _remindersEnabled,
        onRemindersChanged: (val) {
          setState(() => _remindersEnabled = val);
        },
        onRestored: () async {
          await _initData();
          await NotificationService.setDailyReminders(_remindersEnabled);
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
          IconButton(
            icon: Icon(
              _remindersEnabled ? Icons.notifications_active_outlined : Icons.settings_backup_restore,
            ),
            tooltip: 'Backup & Pengingat Makan',
            onPressed: _openSettingsSheet,
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
                    'Sesi Makan',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  _buildSessionTabs(),
                  const SizedBox(height: 12),
                  _buildSessionCard(_selectedSession),
                ],
              ),
            ),
    );
  }

  Widget _buildDailyProgressCard() {
    final calRatio = _targetCalories > 0 ? _totalCalories / _targetCalories : 0.0;
    final proRatio = _targetProtein > 0 ? _totalProtein / _targetProtein : 0.0;
    final calLeft = _targetCalories - _totalCalories;
    final proLeft = _targetProtein - _totalProtein;
    final totalCarbs = _logs.fold(0.0, (acc, item) => acc + item.totalCarbs);
    final totalFat = _logs.fold(0.0, (acc, item) => acc + item.totalFat);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Flexible(
                  child: Text(
                    'Ringkasan Nutrisi',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF232730),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_left, size: 20),
                        tooltip: 'Hari Sebelumnya',
                        onPressed: () => _changeDate(-1),
                      ),
                      InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
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
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.chevron_right, size: 20),
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
                    ratio: calRatio,
                    remaining: calLeft > 0
                        ? 'Kurang ${calLeft.toInt()} kkal'
                        : 'Lebih ${(-calLeft).toInt()} kkal',
                    progressColor: const Color(0xFFE5A93C),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildMetricTile(
                    label: 'Protein',
                    current: '${_totalProtein.toStringAsFixed(1)}g',
                    target: '${_targetProtein.toInt()}g',
                    ratio: proRatio,
                    remaining: proLeft > 0
                        ? 'Kurang ${proLeft.toStringAsFixed(1)}g'
                        : 'Lebih ${(-proLeft).toStringAsFixed(1)}g',
                    progressColor: const Color(0xFF4CAF50),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Karbo ${totalCarbs.toStringAsFixed(1)}g • Lemak ${totalFat.toStringAsFixed(1)}g',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            if (_weeklyCalories.isNotEmpty) ...[
              const Divider(height: 24),
              _buildWeeklySummaryRow(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeeklySummaryRow() {
    const dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    final loggedDays = _weeklyCalories.where((d) => d.calories > 0).toList();
    final avgCal = loggedDays.isEmpty
        ? 0
        : (loggedDays.fold(0.0, (a, b) => a + b.calories) / loggedDays.length).round();

    var streak = 0;
    final daysForStreak = _weeklyCalories.isNotEmpty &&
            _targetCalories > 0 &&
            _weeklyCalories.last.calories < _targetCalories * 0.9
        ? _weeklyCalories.sublist(0, _weeklyCalories.length - 1).reversed
        : _weeklyCalories.reversed;
    for (final d in daysForStreak) {
      if (_targetCalories > 0 && d.calories >= _targetCalories * 0.9) {
        streak++;
      } else {
        break;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                '7 Hari Terakhir • Rata-rata $avgCal kkal/hari',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: streak > 0
                    ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.18)
                    : const Color(0xFF232730),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '🔥 Streak $streak hari',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: streak > 0 ? Theme.of(context).colorScheme.primary : Colors.white60,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _weeklyCalories.map((entry) {
            final ratio = _targetCalories > 0
                ? (entry.calories / _targetCalories).clamp(0.0, 1.0)
                : 0.0;
            final hit = _targetCalories > 0 && entry.calories >= _targetCalories * 0.9;
            final isSelectedDay = entry.date.year == _selectedDate.year &&
                entry.date.month == _selectedDate.month &&
                entry.date.day == _selectedDate.day;
            final label = dayLabels[entry.date.weekday - 1];

            return GestureDetector(
              onTap: () {
                setState(() => _selectedDate = entry.date);
                _loadLogs();
              },
              child: Column(
                children: [
                  Container(
                    width: 28,
                    height: 32,
                    alignment: Alignment.bottomCenter,
                    decoration: BoxDecoration(
                      color: const Color(0xFF232730),
                      borderRadius: BorderRadius.circular(6),
                      border: isSelectedDay
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1)
                          : null,
                    ),
                    child: FractionallySizedBox(
                      heightFactor: entry.calories > 0 ? ratio.clamp(0.15, 1.0) : 0.0,
                      widthFactor: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          color: hit
                              ? const Color(0xFF4CAF50)
                              : Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isSelectedDay ? FontWeight.bold : FontWeight.normal,
                      color: isSelectedDay ? Theme.of(context).colorScheme.primary : Colors.white60,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String current,
    required String target,
    required double ratio,
    required String remaining,
    required Color progressColor,
  }) {
    final percent = (ratio * 100).round();
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
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
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
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              backgroundColor: const Color(0xFF333842),
              valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ratio >= 1 ? 'Target tercapai' : remaining,
            style: TextStyle(
              fontSize: 11,
              color: ratio >= 1 ? progressColor : Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: _sessions.map((s) {
          final cal = _logs
              .where((l) => l.mealSession == s)
              .fold(0.0, (acc, item) => acc + item.totalCalories);
          final selected = s == _selectedSession;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              showCheckmark: false,
              onSelected: (_) => setState(() => _selectedSession = s),
              avatar: Icon(
                s == 'Camilan' ? Icons.cookie_outlined : Icons.restaurant,
                size: 16,
              ),
              label: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    '${cal.toInt()} kkal',
                    style: TextStyle(
                      fontSize: 11,
                      color: selected ? null : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
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
              children: [
                Icon(
                  session.contains('Camilan')
                      ? Icons.cookie_outlined
                      : Icons.restaurant,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${sessionCal.round()} kkal • ${sessionPro.toStringAsFixed(1)}g pro',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.history, size: 20),
                  tooltip: 'Salin menu kemarin ke $session',
                  onPressed: () => _copyYesterdaySession(session),
                ),
                IconButton(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Tambah ke $session',
                  onPressed: () => _openAddLogSheet(defaultSession: session),
                ),
              ],
            ),
            const Divider(height: 20),
            if (sessionLogs.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  children: [
                    Text(
                      'Belum ada makanan di $session',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Makanan'),
                      onPressed: () => _openAddLogSheet(defaultSession: session),
                    ),
                  ],
                ),
              ),
            ...sessionLogs.map((log) {
              final food = log.foodItem.value;
              final estGram = ((food?.estimatedGrams ?? 0) * log.portionMultiplier).round();
              final roundedMult = (log.portionMultiplier * 100).round() / 100;
              final multiplierStr = roundedMult % 1 == 0
                  ? roundedMult.toInt().toString()
                  : roundedMult.toString();

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
                                '$multiplierStr ${food?.portionUnit ?? 'porsi'} (~${estGram}g) • ${log.totalCalories.round()} kkal • ${log.totalProtein.toStringAsFixed(1)}g P',
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
  bool _showAll = false;
  List<FoodItem> _recentFoods = [];

  bool get _isSnackSession => _currentSession == 'Camilan';

  @override
  void initState() {
    super.initState();
    _currentSession = widget.initialSession;
    _loadFoods('');
    _loadRecent();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _changeSession(String session) {
    setState(() => _currentSession = session);
    _loadFoods(_searchCtrl.text);
    _loadRecent();
  }

  Future<void> _loadRecent() async {
    final list = await DbService.getRecentFoods(_currentSession);
    if (mounted) setState(() => _recentFoods = list);
  }

  Future<void> _loadFoods(String query) async {
    final list = await DbService.searchFoods(
      query,
      isSnack: _showAll ? null : _isSnackSession,
    );
    if (!mounted) return;
    setState(() {
      _allFoods = list;
      if (_selectedFood == null || !list.any((f) => f.id == _selectedFood!.id)) {
        _selectedFood = list.isNotEmpty ? list.first : null;
      }
    });
  }

  void _adjustPortion(double delta) {
    setState(() {
      final next = _portion + delta;
      if (next >= 0.25) _portion = double.parse(next.toStringAsFixed(2));
    });
  }

  Future<void> _openCustomFoodActions(FoodItem item) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(item.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Menu Makanan Kustom'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit Makanan Kustom'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Hapus Makanan Kustom', style: TextStyle(color: Colors.redAccent)),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || action == null) return;
    if (action == 'edit') {
      await showDialog(
        context: context,
        builder: (_) => AddCustomFoodDialog(existingFood: item),
      );
      await _loadFoods(_searchCtrl.text);
      await _loadRecent();
      widget.onSaved();
    } else if (action == 'delete') {
      await DbService.deleteCustomFood(item.id);
      if (_selectedFood?.id == item.id) _selectedFood = null;
      await _loadFoods(_searchCtrl.text);
      await _loadRecent();
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${item.name} dihapus dari daftar kustom')),
        );
      }
    }
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

    final bottomInset = math.max(
      MediaQuery.of(context).viewInsets.bottom,
      MediaQuery.of(context).viewPadding.bottom,
    );

    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 20,
        bottom: bottomInset + 20,
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
                      if (val) _changeSession(s);
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
            onChanged: (q) {
              setState(() {});
              _loadFoods(q);
            },
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Cari semua makanan (misal: telur, ayam, nasi)...',
            ),
          ),
          const SizedBox(height: 12),
          if (_searchCtrl.text.trim().isEmpty) ...[
            if (_recentFoods.isNotEmpty) ...[
              const Text(
                'Terakhir dimakan di sesi ini',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _recentFoods
                    .map((f) => ChoiceChip(
                          label: Text(f.name),
                          selected: _selectedFood?.id == f.id,
                          onSelected: (_) => setState(() => _selectedFood = f),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                ChoiceChip(
                  label: Text(_isSnackSession ? 'Camilan' : 'Makanan'),
                  selected: !_showAll,
                  onSelected: (_) {
                    setState(() => _showAll = false);
                    _loadFoods('');
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Semua'),
                  selected: _showAll,
                  onSelected: (_) {
                    setState(() => _showAll = true);
                    _loadFoods('');
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
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
                        onLongPress: item.isCustom ? () => _openCustomFoodActions(item) : null,
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
                                )
                              else if (item.isCustom)
                                Positioned(
                                  top: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: () => _openCustomFoodActions(item),
                                    child: const Icon(
                                      Icons.more_horiz,
                                      size: 16,
                                      color: Colors.white54,
                                    ),
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
                    children: [
                      Expanded(
                        child: Text(
                          'Porsi (${food.portionUnit})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
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
                      Text('~${totalGram.round()} Gram'),
                      Text(
                        '${totalCal.round()} kkal',
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
  final FoodItem? existingFood;
  const AddCustomFoodDialog({super.key, this.existingFood});

  @override
  State<AddCustomFoodDialog> createState() => _AddCustomFoodDialogState();
}

class _AddCustomFoodDialogState extends State<AddCustomFoodDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _unitCtrl;
  late final TextEditingController _gramCtrl;
  late final TextEditingController _calCtrl;
  late final TextEditingController _proCtrl;
  bool _isSnack = false;

  @override
  void initState() {
    super.initState();
    final f = widget.existingFood;
    _nameCtrl = TextEditingController(text: f?.name ?? '');
    _unitCtrl = TextEditingController(text: f?.portionUnit ?? 'porsi');
    _gramCtrl = TextEditingController(
      text: f != null ? f.estimatedGrams.toInt().toString() : '100',
    );
    _calCtrl = TextEditingController(
      text: f != null ? f.calories.toInt().toString() : '',
    );
    _proCtrl = TextEditingController(
      text: f != null ? f.protein.toString() : '',
    );
    _isSnack = f?.isSnack ?? false;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _unitCtrl.dispose();
    _gramCtrl.dispose();
    _calCtrl.dispose();
    _proCtrl.dispose();
    super.dispose();
  }

  double _parseNum(String text, double fallback) =>
      double.tryParse(text.replaceAll(',', '.').trim()) ?? fallback;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    await DbService.addCustomFood(
      id: widget.existingFood?.id,
      isSnack: _isSnack,
      name: _nameCtrl.text,
      portionUnit: _unitCtrl.text,
      estimatedGrams: _parseNum(_gramCtrl.text, 100),
      calories: _parseNum(_calCtrl.text, 0),
      protein: _parseNum(_proCtrl.text, 0),
    );

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.existingFood != null
                ? 'Menu kustom berhasil diperbarui'
                : 'Menu makanan kustom berhasil ditambahkan',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existingFood != null ? 'Edit Makanan Kustom' : 'Tambah Makanan Kustom'),
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
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('Makanan'), icon: Icon(Icons.restaurant)),
                  ButtonSegment(value: true, label: Text('Camilan'), icon: Icon(Icons.cookie_outlined)),
                ],
                selected: {_isSnack},
                onSelectionChanged: (v) => setState(() => _isSnack = v.first),
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
  final double initialTargetWeight;
  final double initialHeight;
  final int initialAge;
  final int initialActivityLevel;
  final double initialCalories;
  final double initialProtein;
  final bool isOnboarding;
  final void Function(
    String name,
    double weight,
    double targetWeight,
    double height,
    int age,
    int activityLevel,
    double calories,
    double protein,
  ) onSaved;

  const ProfileDialog({
    super.key,
    required this.initialName,
    required this.initialWeight,
    required this.initialTargetWeight,
    required this.initialHeight,
    required this.initialAge,
    required this.initialActivityLevel,
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
  late final TextEditingController _targetWeightCtrl;
  late final TextEditingController _heightCtrl;
  late final TextEditingController _ageCtrl;
  late final TextEditingController _calCtrl;
  late final TextEditingController _proCtrl;
  late int _activityLevel;

  static const _activityMultipliers = [1.3, 1.5, 1.725];

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _weightCtrl = TextEditingController(
      text: widget.initialWeight > 0 ? widget.initialWeight.toStringAsFixed(0) : '60',
    );
    _targetWeightCtrl = TextEditingController(
      text: widget.initialTargetWeight > 0 ? widget.initialTargetWeight.toStringAsFixed(0) : '68',
    );
    _heightCtrl = TextEditingController(
      text: widget.initialHeight > 0 ? widget.initialHeight.toStringAsFixed(0) : '170',
    );
    _ageCtrl = TextEditingController(
      text: widget.initialAge > 0 ? widget.initialAge.toString() : '22',
    );
    _activityLevel = widget.initialActivityLevel.clamp(0, 2);
    _calCtrl = TextEditingController(
      text: widget.initialCalories.toInt().toString(),
    );
    _proCtrl = TextEditingController(
      text: widget.initialProtein.toInt().toString(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _targetWeightCtrl.dispose();
    _heightCtrl.dispose();
    _ageCtrl.dispose();
    _calCtrl.dispose();
    _proCtrl.dispose();
    super.dispose();
  }

  double _parseNum(String text, double fallback) =>
      double.tryParse(text.replaceAll(',', '.').trim()) ?? fallback;

  void _calculateTargets() {
    final w = _parseNum(_weightCtrl.text, 60.0);
    final h = _parseNum(_heightCtrl.text, 170.0);
    final a = int.tryParse(_ageCtrl.text.trim()) ?? 22;

    if (w <= 0 || h <= 0 || a <= 0) return;

    // Mifflin-St Jeor + activity multiplier + bulking surplus (400 kcal) & 2.0g protein / kg
    final bmr = (10 * w) + (6.25 * h) - (5 * a) + 5;
    final tdee = bmr * _activityMultipliers[_activityLevel.clamp(0, 2)];
    final bulkingCal = (tdee + 400).round();
    final bulkingPro = (w * 2.0).round();

    setState(() {
      _calCtrl.text = bulkingCal.toString();
      _proCtrl.text = bulkingPro.toString();
    });
  }

  double get _currentBmi {
    final w = _parseNum(_weightCtrl.text, 0);
    final h = _parseNum(_heightCtrl.text, 0);
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
    final weight = _parseNum(_weightCtrl.text, 60);
    final targetWeight = _parseNum(_targetWeightCtrl.text, weight + 8);
    final height = _parseNum(_heightCtrl.text, 170);
    final age = int.tryParse(_ageCtrl.text.trim()) ?? 22;
    final cal = _parseNum(_calCtrl.text, 2500);
    final pro = _parseNum(_proCtrl.text, 140);

    await DbService.saveProfile(
      name: name,
      weight: weight,
      targetWeight: targetWeight,
      height: height,
      age: age,
      activityLevel: _activityLevel,
      targetCalories: cal,
      targetProtein: pro,
    );

    widget.onSaved(name, weight, targetWeight, height, age, _activityLevel, cal, pro);
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
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _targetWeightCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Target Berat',
                        suffixText: 'kg',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
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
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Tingkat Aktivitas Harian:',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 6),
              SegmentedButton<int>(
                segments: const [
                  ButtonSegment(value: 0, label: Text('Ringan', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 1, label: Text('Gym 3-4x', style: TextStyle(fontSize: 11))),
                  ButtonSegment(value: 2, label: Text('Berat', style: TextStyle(fontSize: 11))),
                ],
                selected: {_activityLevel},
                onSelectionChanged: (v) {
                  setState(() => _activityLevel = v.first);
                  _calculateTargets();
                },
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

  double get _stdGram {
    final g = widget.log.foodItem.value?.estimatedGrams ?? 100.0;
    return g > 0 ? g : 100.0;
  }

  @override
  void initState() {
    super.initState();
    _portion = widget.log.portionMultiplier;
    _gramCtrl = TextEditingController(
      text: (_portion * _stdGram).round().toString(),
    );
  }

  @override
  void dispose() {
    _gramCtrl.dispose();
    super.dispose();
  }

  void _applyMultiplier(double mult) {
    FocusScope.of(context).unfocus();
    setState(() {
      _portion = mult;
      _gramCtrl.text = (_portion * _stdGram).round().toString();
    });
  }

  void _onGramChanged(String val) {
    final gram = double.tryParse(val.replaceAll(',', '.').trim());
    if (gram != null && gram > 0) {
      setState(() {
        _portion = gram / _stdGram;
      });
    }
  }

  void _stepGram(double deltaGram) {
    FocusScope.of(context).unfocus();
    final currentGram = double.tryParse(_gramCtrl.text.replaceAll(',', '.').trim()) ??
        (_stdGram * _portion);
    final nextGram = (currentGram + deltaGram).round();
    if (nextGram >= 5) {
      _gramCtrl.text = nextGram.toString();
      setState(() {
        _portion = nextGram / _stdGram;
      });
    }
  }

  Future<void> _save() async {
    final typedGram = double.tryParse(_gramCtrl.text.replaceAll(',', '.').trim());
    if (typedGram == null || typedGram <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan berat gram porsi yang valid')),
      );
      return;
    }
    final portionToSave = (typedGram - (_portion * _stdGram).round()).abs() < 1
        ? _portion
        : typedGram / _stdGram;
    final foodName = widget.log.foodItem.value?.name ?? 'Makanan';
    await DbService.updateMealLogPortion(widget.log.id, portionToSave);
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
    final stdGram = _stdGram;
    final currentGram = (_portion * stdGram).round();
    final cal = ((food?.calories ?? 0.0) * _portion).round();
    final pro = ((food?.protein ?? 0.0) * _portion).toStringAsFixed(1);
    final carbs = ((food?.carbs ?? 0.0) * _portion).toStringAsFixed(1);
    final fat = ((food?.fat ?? 0.0) * _portion).toStringAsFixed(1);
    final bottomInset = math.max(
      MediaQuery.of(context).viewInsets.bottom,
      MediaQuery.of(context).viewPadding.bottom,
    );

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: bottomInset + 20,
        ),
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
                  Expanded(
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '$cal',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        const Text('Kalori (kkal)', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: const Color(0xFF333842)),
                  Expanded(
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${pro}g',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                        const Text('Protein', style: TextStyle(fontSize: 11, color: Colors.white70)),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 32, color: const Color(0xFF333842)),
                  Expanded(
                    child: Column(
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${currentGram}g',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Text(
                          '~${_portion.toStringAsFixed(1)} porsi',
                          style: const TextStyle(fontSize: 11, color: Colors.white70),
                        ),
                      ],
                    ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _save,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Simpan Porsi (${currentGram}g • $cal kkal)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
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
  final double targetWeight;
  final ValueChanged<double> onWeightUpdated;

  const WeightLogSheet({
    super.key,
    required this.currentWeight,
    required this.targetWeight,
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

  @override
  void dispose() {
    _weightCtrl.dispose();
    super.dispose();
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
      if (_logs.isNotEmpty) {
        widget.onWeightUpdated(_logs.first.weight);
      }
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
    final bottomInset = math.max(
      MediaQuery.of(context).viewInsets.bottom,
      MediaQuery.of(context).viewPadding.bottom,
    );
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: bottomInset + 20,
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
            if (widget.targetWeight > 0) ...[
              const SizedBox(height: 10),
              Builder(
                builder: (context) {
                  final latest = _logs.isNotEmpty ? _logs.first.weight : widget.currentWeight;
                  final gap = widget.targetWeight - latest;
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF232730),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Target Bulking: ${widget.targetWeight.toStringAsFixed(1)} kg',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            gap > 0
                                ? 'Kurang ${gap.toStringAsFixed(1)} kg lagi'
                                : 'Target berat tercapai! 🎉',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: gap > 0
                                  ? Theme.of(context).colorScheme.primary
                                  : const Color(0xFF4CAF50),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
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
            const SizedBox(height: 16),
            if (_logs.length >= 2) ...[
              _buildWeightChart(),
              const SizedBox(height: 16),
            ],
            const Text(
              'Riwayat Timbangan',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
            ),
            const SizedBox(height: 8),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_logs.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    'Belum ada catatan timbangan.',
                    style: TextStyle(color: Colors.white60),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
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
          ],
        ),
      ),
    );
  }

  Widget _buildWeightChart() {
    // Take up to 14 most recent entries in chronological order.
    final points = _logs.take(14).toList().reversed.toList();
    final weights = points.map((e) => e.weight).toList();
    final minW = weights.reduce(math.min);
    final maxW = weights.reduce(math.max);
    final diff = weights.last - weights.first;
    final diffStr = diff >= 0 ? '+${diff.toStringAsFixed(1)} kg' : '${diff.toStringAsFixed(1)} kg';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF232730),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Tren Berat (${points.length} catatan) • Min ${minW.toStringAsFixed(1)} – Maks ${maxW.toStringAsFixed(1)} kg',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                diffStr,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: diff >= 0 ? Colors.greenAccent : Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(
              painter: _WeightTrendPainter(
                weights: weights,
                minWeight: minW,
                maxWeight: maxW,
                lineColor: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '${points.first.date.day}/${points.first.date.month} (${points.first.weight.toStringAsFixed(1)} kg)',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  '${points.last.date.day}/${points.last.date.month} (${points.last.weight.toStringAsFixed(1)} kg)',
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(fontSize: 11, color: Colors.white60),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WeightTrendPainter extends CustomPainter {
  final List<double> weights;
  final double minWeight;
  final double maxWeight;
  final Color lineColor;

  _WeightTrendPainter({
    required this.weights,
    required this.minWeight,
    required this.maxWeight,
    required this.lineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (weights.length < 2) return;
    final range = (maxWeight - minWeight).abs() < 0.1 ? 1.0 : (maxWeight - minWeight);
    const padY = 10.0;
    final usableH = size.height - padY * 2;

    Offset pointAt(int i) {
      final x = (i / (weights.length - 1)) * size.width;
      final norm = (weights[i] - minWeight) / range;
      final y = size.height - padY - (norm * usableH);
      return Offset(x, y);
    }

    final gridPaint = Paint()
      ..color = const Color(0xFF333842)
      ..strokeWidth = 1;
    for (final frac in [0.0, 0.5, 1.0]) {
      final y = padY + usableH * frac;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < weights.length; i++) {
      final p = pointAt(i);
      path.lineTo(p.dx, p.dy);
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          lineColor.withValues(alpha: 0.32),
          lineColor.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = lineColor;
    for (var i = 0; i < weights.length; i++) {
      canvas.drawCircle(pointAt(i), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightTrendPainter oldDelegate) =>
      oldDelegate.weights != weights || oldDelegate.lineColor != lineColor;
}

class DataReminderSheet extends StatefulWidget {
  final bool remindersEnabled;
  final ValueChanged<bool> onRemindersChanged;
  final VoidCallback onRestored;

  const DataReminderSheet({
    super.key,
    required this.remindersEnabled,
    required this.onRemindersChanged,
    required this.onRestored,
  });

  @override
  State<DataReminderSheet> createState() => _DataReminderSheetState();
}

class _DataReminderSheetState extends State<DataReminderSheet> {
  late bool _remindersEnabled;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _remindersEnabled = widget.remindersEnabled;
  }

  Future<void> _toggleReminders(bool val) async {
    setState(() => _remindersEnabled = val);
    await DbService.setRemindersEnabled(val);
    final ok = await NotificationService.setDailyReminders(val);
    widget.onRemindersChanged(val);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          val
              ? (ok
                  ? 'Pengingat makan harian diaktifkan (08:00, 13:00, 16:30, 19:30)'
                  : 'Pengingat disimpan (notifikasi tidak tersedia di perangkat ini)')
              : 'Pengingat makan harian dimatikan',
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    setState(() => _busy = true);
    try {
      final jsonStr = await DbService.exportBackupJson();
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final stamp =
          '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
      final file = File('${dir.path}/bulkzero_backup_$stamp.json');
      await file.writeAsString(jsonStr);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/json')],
          subject: 'Backup Data BulkZero ($stamp)',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengekspor backup: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _importBackup() async {
    setState(() => _busy = true);
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked.isEmpty) return;
      final pf = picked.first;
      final content = pf.path != null
          ? await File(pf.path!).readAsString()
          : utf8.decode(await pf.xFile.readAsBytes());
      await DbService.importBackupJson(content);
      widget.onRestored();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data backup berhasil dipulihkan!')),
        );
      }
    } on FormatException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mengimpor backup: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = math.max(
      MediaQuery.of(context).viewInsets.bottom,
      MediaQuery.of(context).viewPadding.bottom,
    );
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: bottomInset + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Pengingat & Backup Data',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF232730),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SwitchListTile(
              title: const Text(
                'Pengingat Makan Harian',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Notifikasi otomatis: 08:00 (Makan 1), 13:00 (Makan 2), 16:30 (Camilan), 19:30 (Makan 3)',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              value: _remindersEnabled,
              onChanged: _toggleReminders,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Backup & Restore Offline (JSON)',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white70),
          ),
          const SizedBox(height: 6),
          const Text(
            'Simpan seluruh profil, makanan kustom, log makan, dan catatan berat badan ke file JSON agar aman saat ganti HP.',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _busy ? null : _exportBackup,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Export JSON', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _busy ? null : _importBackup,
                  icon: const Icon(Icons.download),
                  label: const Text('Import JSON', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

