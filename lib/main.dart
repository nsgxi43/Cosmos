import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'ai_page.dart';
import 'login.dart'; // make sure this file exists
import 'journal_page.dart';
import 'dart:ui';
import 'community.dart'; // Correctly import your community_page code

void main() {
  runApp(const CosmosApp());
}

class CosmosApp extends StatelessWidget {
  const CosmosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      // Start with NicknamePage as you have it set up
      home: const NicknamePage(),
    );
  }
}

// ================== HOME PAGE ==================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  DateTime selectedDate = DateTime.now();
  late AnimationController _breathingController;
  late Animation<double> _scaleAnimation;
  int _bottomNavIndex = 0;

  int pendingCount = 5;
  int finishedCount = 0;

  final List<String> tasks = [
    "Finish project report",
    "Workout session",
    "Read a book",
    "Meditation",
    "Plan tomorrow"
  ];

  final List<Color> taskColors = [
    Colors.teal,
    Colors.blueAccent,
    Colors.green,
    Colors.deepPurple,
    Colors.pinkAccent
  ];

  @override
  void initState() {
    super.initState();

    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 0.97).animate(
      CurvedAnimation(parent: _breathingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 7, 1, 36),
      body: Stack(
        children: [
          // 🌌 Starry calm background
          const Positioned.fill(child: StarryBackground()),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Header COSMOS
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [
                        Color.fromARGB(255, 152, 83, 204),
                        Color.fromARGB(255, 162, 114, 199),
                        Color.fromARGB(255, 226, 128, 229),
                        Color.fromARGB(255, 212, 128, 229),
                        Color.fromARGB(255, 135, 187, 222),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ).createShader(bounds),
                    child: Text(
                      "COSMOS",
                      style: GoogleFonts.pacifico(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                // Horizontal Calendar
                SizedBox(
                  height: 100,
                  child: WeekCalendar(
                    selectedDate: selectedDate,
                    onDateChange: (date) {
                      setState(() {
                        selectedDate = date;
                      });
                    },
                  ),
                ),

                const SizedBox(height: 50),

                // POLARIS Card → Tap to open AI Page
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const AiPage()),
                    );
                  },
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: AnimatedContainer(
                      duration: const Duration(seconds: 1),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.purple.withOpacity(0.15),
                            blurRadius: 18,
                            spreadRadius: 6,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.all(24),
                            color: Colors.white.withOpacity(0.05),
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    "POLARIS",
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: 25,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.95),
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Your star awaits you",
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white.withOpacity(0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 100),

                // 🌈 Stacked Tasks
                const SizedBox(height: 20),
                Text(
                  "Come on, let's finish these tasks!!",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0),
                    child: ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      itemCount: tasks.length,
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        final color = taskColors[index % taskColors.length];

                        return Dismissible(
                          key: Key(task),
                          background: Container(
                            alignment: Alignment.centerLeft,
                            padding: const EdgeInsets.only(left: 20),
                            color: Colors.orange.withOpacity(0.8),
                            child: const Icon(Icons.watch_later, color: Colors.white),
                          ),
                          secondaryBackground: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.green.withOpacity(0.8),
                            child: const Icon(Icons.check, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            setState(() {
                              tasks.removeAt(index);
                              if (direction == DismissDirection.startToEnd) {
                                tasks.add(task);
                              } else {
                                finishedCount++;
                                pendingCount--;
                              }
                            });
                          },
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            color: color.withOpacity(0.9),
                            margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                            child: ListTile(
                              title: Text(
                                task,
                                style: GoogleFonts.inter(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Counters
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _counterBox("Pending", pendingCount, Colors.orange),
                    const SizedBox(width: 20),
                    _counterBox("Finished", finishedCount, Colors.green),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),

      // Bottom Navigation Bar
      // Bottom Navigation Bar
bottomNavigationBar: BottomNavigationBar(
  backgroundColor: Colors.black,
  selectedItemColor: Colors.purpleAccent,
  unselectedItemColor: Colors.grey,
  currentIndex: _bottomNavIndex,
  onTap: (index) {
    if (index == 0) {
      // If the user taps Home, set the index to 0 and don't navigate further.
      setState(() {
        _bottomNavIndex = 0;
      });
      return;
    }
    
    // Temporarily set the selected tab as active before navigation.
    setState(() {
      _bottomNavIndex = index;
    });

    if (index == 1) {
      // Navigate to the JournalPage and wait for it to be popped.
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const JournalPage()),
      ).then((_) {
        // When the user returns, set the index back to 0 (Home).
        setState(() {
          _bottomNavIndex = 0;
        });
      });
    } else if (index == 2) {
      // Navigate to the CommunityPage and wait for it to be popped.
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const CommunityPage()),
      ).then((_) {
        // When the user returns, set the index back to 0 (Home).
        setState(() {
          _bottomNavIndex = 0;
        });
      });
    }
  },
  items: const [
    BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
    BottomNavigationBarItem(icon: Icon(Icons.book), label: "Journal"),
    BottomNavigationBarItem(icon: Icon(Icons.group), label: "Community"),
  ],
),
    );
  }

  Widget taskCard(String task, Color color, {bool isDragging = false}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      color: color,
      elevation: isDragging ? 12 : 8,
      child: Container(
        width: 280,
        height: 160,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        child: Text(
          task,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

Widget _counterBox(String title, int count, Color color) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: color, width: 2),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ],
    ),
  );
}

// ================== WEEK CALENDAR ==================
class WeekCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final Function(DateTime) onDateChange;

  const WeekCalendar({
    super.key,
    required this.selectedDate,
    required this.onDateChange,
  });

  List<DateTime> get weekDates {
    return List.generate(7, (i) => selectedDate.add(Duration(days: i - 3)));
  }

  bool isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: weekDates.map((date) {
        bool isSelected = isSameDay(date, selectedDate);

        return Expanded(
          child: GestureDetector(
            onTap: () => onDateChange(date),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 10),
              height: isSelected ? 100 : 80,
              decoration: BoxDecoration(
                color: isSelected ? Colors.purple : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: Colors.purpleAccent.withOpacity(0.6),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        )
                      ]
                    : [],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    "${date.day}",
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : Colors.grey.shade700,
                      fontSize: isSelected ? 20 : 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                        [date.weekday - 1],
                    style: GoogleFonts.poppins(
                      fontSize: isSelected ? 14 : 12,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ================== STARRY BACKGROUND ==================
class StarryBackground extends StatefulWidget {
  const StarryBackground({super.key});

  @override
  State<StarryBackground> createState() => _StarryBackgroundState();
}

class _StarryBackgroundState extends State<StarryBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final Random _random = Random();
  final List<Offset> _stars = [];

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 6))
          ..repeat(reverse: true);

    for (int i = 0; i < 120; i++) {
      _stars.add(Offset(_random.nextDouble(), _random.nextDouble()));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(255, 7, 1, 36),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            painter: StarPainter(
              stars: _stars,
              opacity: 0.4 + 0.6 * _controller.value,
            ),
            size: MediaQuery.of(context).size,
          );
        },
      ),
    );
  }
}

class StarPainter extends CustomPainter {
  final List<Offset> stars;
  final double opacity;

  StarPainter({required this.stars, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(opacity);

    for (final pos in stars) {
      final dx = pos.dx * size.width;
      final dy = pos.dy * size.height;
      final radius = 0.5 + Random().nextDouble() * 1.2;
      canvas.drawCircle(Offset(dx, dy), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}