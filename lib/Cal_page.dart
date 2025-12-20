import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.dart'; // Ensure this points to your StarryBackground file

class MonthlyMoodPage extends StatefulWidget {
  final DateTime initialMonth;

  const MonthlyMoodPage({super.key, required this.initialMonth});

  @override
  State<MonthlyMoodPage> createState() => _MonthlyMoodPageState();
}

class _MonthlyMoodPageState extends State<MonthlyMoodPage> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  /// 🔥 Persistent mood map (String key = yyyy-mm-dd)
  Map<String, String> _moods = {};

  @override
  void initState() {
    super.initState();
    _focusedDay = widget.initialMonth;
    _loadMoods();
  }

  /// 📅 Date → String key
  String _dateKey(DateTime d) => "${d.year}-${d.month}-${d.day}";

  /// 💾 Load moods
  Future<void> _loadMoods() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('mood_map');
    if (raw != null) {
      setState(() {
        _moods = Map<String, String>.from(json.decode(raw));
      });
    }
  }

  /// 💾 Save moods
  Future<void> _saveMoods() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('mood_map', json.encode(_moods));
  }

  /// 😊 Emoji picker + ❌ remove
  void _pickMood(DateTime day) {
    final key = _dateKey(day);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 20, 10, 60),
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Wrap(
          spacing: 16,
          runSpacing: 16,
          children: [
            ...["😊", "😢", "😡", "😌", "😴", "😍", "😐", "😭"].map(
              (emoji) => GestureDetector(
                onTap: () async {
                  setState(() {
                    _moods[key] = emoji;
                  });
                  await _saveMoods();
                  Navigator.pop(context);
                },
                child: Text(emoji, style: const TextStyle(fontSize: 32)),
              ),
            ),

            /// ❌ Remove emoji
            GestureDetector(
              onTap: () async {
                setState(() {
                  _moods.remove(key);
                });
                await _saveMoods();
                Navigator.pop(context);
              },
              child: const Text("❌", style: TextStyle(fontSize: 32)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 1, 36),
      body: Stack(
        children: [
          // Ensure StarryBackground is defined in main.dart or remove if not needed
          const Positioned.fill(child: StarryBackground()),

          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 16),

                /// 🔙 Back + Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios_new,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        "Monthly Mood",
                        style: GoogleFonts.playfairDisplay(
                          fontSize: 28,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                /// 📈 THE NEW GLOWING GRAPH
                MoodFlowGraph(
                  moods: _moods,
                  month: _focusedDay,
                ),
                const SizedBox(height: 20),

                /// 🌙 REAL CALENDAR
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.15),
                            ),
                          ),
                          child: TableCalendar(
                            firstDay: DateTime.utc(2020, 1, 1),
                            lastDay: DateTime.utc(2035, 12, 31),
                            focusedDay: _focusedDay,
                            calendarFormat: CalendarFormat.month,

                            headerStyle: const HeaderStyle(
                              titleCentered: true,
                              formatButtonVisible: false,
                              leftChevronIcon:
                                  Icon(Icons.chevron_left, color: Colors.white),
                              rightChevronIcon:
                                  Icon(Icons.chevron_right, color: Colors.white),
                              titleTextStyle: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),

                            daysOfWeekStyle: const DaysOfWeekStyle(
                              weekdayStyle: TextStyle(color: Colors.white70),
                              weekendStyle: TextStyle(color: Colors.white70),
                            ),

                            calendarStyle: CalendarStyle(
                              outsideDaysVisible: false,
                              defaultTextStyle:
                                  const TextStyle(color: Colors.white),
                              weekendTextStyle:
                                  const TextStyle(color: Colors.white),
                              todayDecoration: BoxDecoration(
                                color: Colors.purpleAccent.withOpacity(0.4),
                                shape: BoxShape.circle,
                              ),
                              selectedDecoration: const BoxDecoration(
                                color: Colors.purpleAccent,
                                shape: BoxShape.circle,
                              ),
                            ),

                            selectedDayPredicate: (day) =>
                                isSameDay(_selectedDay, day),

                            onDaySelected: (selected, focused) {
                              setState(() {
                                _selectedDay = selected;
                                _focusedDay = focused;
                              });
                              _pickMood(selected);
                            },

                            calendarBuilders: CalendarBuilders(
                              markerBuilder: (context, day, _) {
                                final emoji = _moods[_dateKey(day)];
                                if (emoji == null) return null;
                                return Center(
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 18),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                /// ℹ Hint
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "Tap a date to log or remove your mood ✨",
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------
//  ✨ NEW OPTIMIZED GRAPH LOGIC STARTS HERE
// ---------------------------------------------------------

class MoodFlowGraph extends StatefulWidget {
  final Map<String, String> moods;
  final DateTime month;

  const MoodFlowGraph({
    super.key,
    required this.moods,
    required this.month,
  });

  @override
  State<MoodFlowGraph> createState() => _MoodFlowGraphState();
}

class _MoodFlowGraphState extends State<MoodFlowGraph>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Filter and Sort Data
    final monthMoods = widget.moods.entries
        .map((e) {
          final parts = e.key.split('-');
          // Handle potential parse errors safely if needed, assuming correct format here
          return MapEntry(
              DateTime(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2])),
              e.value);
        })
        .where((e) =>
            e.key.month == widget.month.month && e.key.year == widget.month.year)
        .toList()
      ..sort((a, b) => a.key.day.compareTo(b.key.day));

    // Get exact days in month for X-axis scaling
    final daysInMonth = DateUtils.getDaysInMonth(widget.month.year, widget.month.month);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 220, // Taller for better visualization
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (_, __) {
              return CustomPaint(
                painter: _MoodGraphPainter(
                  moods: monthMoods,
                  daysInMonth: daysInMonth,
                  pulse: _controller.value,
                ),
                size: Size.infinite,
              );
            },
          ),
        ),
      ),
    );
  }
}

class _MoodGraphPainter extends CustomPainter {
  final List<MapEntry<DateTime, String>> moods;
  final int daysInMonth;
  final double pulse;

  _MoodGraphPainter({
    required this.moods,
    required this.daysInMonth,
    required this.pulse,
  });

  int _moodValue(String emoji) {
    switch (emoji) {
      case "😡": return 1;
      case "😭": return 1;
      case "😢": return 2;
      case "🤯": return 3;
      case "😴": return 3;
      case "😌": return 4;
      case "😊": return 5;
      case "😍": return 6;
      default: return 3;
    }
  }

  Color _moodColor(String emoji) {
    switch (emoji) {
      case "😡": return const Color(0xFFFF5252);
      case "😭": return const Color(0xFF536DFE);
      case "😢": return const Color(0xFF448AFF);
      case "😴": return const Color(0xFFB0BEC5);
      case "😌": return const Color(0xFF69F0AE);
      case "😊": return const Color(0xFFFFD740);
      case "😍": return const Color(0xFFFF4081);
      default: return Colors.white;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    const leftPadding = 40.0; 
    const rightPadding = 20.0;
    const bottomPadding = 30.0;
    const topPadding = 20.0;

    final graphWidth = size.width - leftPadding - rightPadding;
    final graphHeight = size.height - bottomPadding - topPadding;

    // 1. Draw Grid & Labels
    final axisPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..strokeWidth = 1;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Y-Axis Labels (Emojis) - mapped to 1-6 scale
    final yLabels = {1: "😡", 2: "😢", 3: "😐", 4: "😌", 5: "😊", 6: "😍"};
    
    for (int i = 1; i <= 6; i++) {
      final y = size.height - bottomPadding - ((i - 1) / 5) * graphHeight;
      
      // Grid line
      canvas.drawLine(
        Offset(leftPadding, y), 
        Offset(size.width - rightPadding, y), 
        axisPaint
      );

      // Emoji Label
      textPainter.text = TextSpan(text: yLabels[i] ?? "", style: const TextStyle(fontSize: 14));
      textPainter.layout();
      textPainter.paint(canvas, Offset(8, y - 10)); 
    }

    if (moods.isEmpty) return;

    // 2. Calculate Points
    final points = <Offset>[];
    final colors = <Color>[];

    for (var entry in moods) {
      // Scale X based on actual days in month (e.g., 28, 30, 31)
      final x = leftPadding + ((entry.key.day - 1) / (daysInMonth - 1)) * graphWidth;
      
      // Scale Y based on mood value (1-6)
      final value = _moodValue(entry.value);
      final y = size.height - bottomPadding - ((value - 1) / 5) * graphHeight;
      
      points.add(Offset(x, y));
      colors.add(_moodColor(entry.value));
    }

    // 3. Draw Smooth Curve (Cubic Bezier)
    final path = Path();
    if (points.isNotEmpty) {
      path.moveTo(points.first.dx, points.first.dy);

      for (int i = 0; i < points.length - 1; i++) {
        final p0 = points[i];
        final p1 = points[i + 1];

        // S-Curve Control Points
        final cp1 = Offset((p0.dx + p1.dx) / 2, p0.dy);
        final cp2 = Offset((p0.dx + p1.dx) / 2, p1.dy);

        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p1.dx, p1.dy);
      }
    }

    // 4. Draw Gradient Fill ("Nebula" look)
    if (points.length > 1) {
      final fillPath = Path.from(path);
      fillPath.lineTo(points.last.dx, size.height - bottomPadding);
      fillPath.lineTo(points.first.dx, size.height - bottomPadding);
      fillPath.close();

      final fillGradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.purpleAccent.withOpacity(0.2),
          Colors.purpleAccent.withOpacity(0.0),
        ],
      );

      canvas.drawPath(
        fillPath, 
        Paint()..shader = fillGradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height)
        )
      );
    }

    // 5. Draw the Glowing Line
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..color = Colors.white
      ..strokeCap = StrokeCap.round;

    // Add glow shadow
    canvas.drawShadow(path, Colors.purpleAccent, 4, true);
    canvas.drawPath(path, linePaint);

    // 6. Draw Dots
    for (int i = 0; i < points.length; i++) {
      // Glow ring
      canvas.drawCircle(
        points[i], 
        6 + pulse * 2, 
        Paint()..color = colors[i].withOpacity(0.3)
      );
      // Solid center
      canvas.drawCircle(
        points[i], 
        4, 
        Paint()..color = colors[i]
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MoodGraphPainter oldDelegate) => true;
}