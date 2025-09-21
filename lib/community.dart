import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:ui';
import 'dart:math';
import 'dart:async';

// Journal model
class Journal {
  final String id;
  final String title;
  final String content;
  final DateTime timestamp;
  final String? userId;

  Journal({
    required this.id,
    required this.title,
    required this.content,
    required this.timestamp,
    this.userId,
  });

  factory Journal.fromJson(Map<String, dynamic> json) {
    print('--- RECEIVED JSON FOR JOURNAL: $json');
    return Journal(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      timestamp: DateTime.parse(
        json['timestamp'] ?? DateTime.now().toIso8601String(),
      ),
      userId: json['user_id'], // This should work
    );
  }
}

// Journal service
class JournalService {
  static const String BASE_URL = 'https://cosmos-wellness.duckdns.org';

  static Future<List<Journal>> getJournals(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/journals/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      print(' Fetching journals for user: $userId');
      print(' Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<Journal> journals = [];
          for (var journalData in data['journals']) {
            journals.add(Journal.fromJson(journalData));
          }
          print(' Loaded ${journals.length} journals for user $userId');
          return journals;
        }
      }
      return [];
    } catch (e) {
      print(' Error fetching journals for user $userId: $e');
      return [];
    }
  }

  static Future<List<Journal>> getPublicJournals() async {
    try {
      final response = await http.get(
        Uri.parse('$BASE_URL/public_journals'),
        headers: {'Content-Type': 'application/json'},
      );

      print(' Fetching public journals');
      print(' Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          List<Journal> journals = [];
          for (var journalData in data['journals']) {
            journals.add(Journal.fromJson(journalData));
          }
          print('Loaded ${journals.length} public journals');
          return journals;
        }
      }
      return [];
    } catch (e) {
      print(' Error fetching public journals: $e');
      return [];
    }
  }
}

class CommunityPage extends StatefulWidget {
  final String? currentUserId;
  const CommunityPage({super.key, this.currentUserId});

  @override
  _CommunityPageState createState() => _CommunityPageState();
}

class _CommunityPageState extends State<CommunityPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  List<Journal> journals = [];
  bool isLoadingJournals = true;
  String currentUserId = 'demo_user';

  int currentJournalIndex = 0;
  Timer? _slideTimer;
  bool _isPaused = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _initializeUser();
    _loadJournals();
  }

  void _initAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutQuad),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _fadeController.forward();
    _slideController.forward();
  }

  Future<void> _initializeUser() async {
    if (widget.currentUserId != null) {
      setState(() {
        currentUserId = widget.currentUserId!;
      });
    }
  }

  void _startAutoRotation() {
    _slideTimer?.cancel();
    if (journals.length > 1 && !_isPaused) {
      _slideTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
        if (mounted && journals.isNotEmpty && !_isPaused) {
          setState(() {
            currentJournalIndex = (currentJournalIndex + 1) % journals.length;
          });
        }
      });
    }
  }

  void _stopAutoRotation() {
    _slideTimer?.cancel();
  }

  void _pauseAutoRotation() {
    setState(() {
      _isPaused = true;
    });
    _stopAutoRotation();

    Timer(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _isPaused = false;
        });
        _startAutoRotation();
      }
    });
  }

  Future<void> _loadJournals() async {
    try {
      setState(() {
        isLoadingJournals = true;
      });

      print('📱 Loading public journals from server...');
      final fetchedJournals = await JournalService.getPublicJournals();

      if (mounted) {
        setState(() {
          journals = fetchedJournals;
          currentJournalIndex = 0;
          isLoadingJournals = false;
        });

        if (fetchedJournals.isNotEmpty) {
          _startAutoRotation();
        }

        print(
          '📱 Successfully loaded ${fetchedJournals.length} public journals',
        );
      }
    } catch (e) {
      print('❌ Error loading journals: $e');
      if (mounted) {
        setState(() {
          isLoadingJournals = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load public journals'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _nextJournal() {
    _pauseAutoRotation();
    if (journals.isNotEmpty) {
      setState(() {
        currentJournalIndex = (currentJournalIndex + 1) % journals.length;
      });
    }
  }

  void _previousJournal() {
    _pauseAutoRotation();
    if (journals.isNotEmpty) {
      setState(() {
        currentJournalIndex = currentJournalIndex > 0
            ? currentJournalIndex - 1
            : journals.length - 1;
      });
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _slideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 360;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: StarryBackground()),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16 : 20,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 16),
                        _buildHeader(isSmallScreen),
                        const SizedBox(height: 32),
                        _buildConnectSection(isSmallScreen),
                        const SizedBox(height: 24),
                        _buildFeaturedSection(isSmallScreen),
                        const SizedBox(height: 24),
                        _buildCommunitiesSection(isSmallScreen),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isSmallScreen) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () {
            Navigator.pop(context);
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.1),
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Text(
            'ID: $currentUserId',
            style: TextStyle(
              color: Colors.white,
              fontSize: isSmallScreen ? 10 : 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _loadJournals,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF4CAF50), Color(0xFF45A049)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4CAF50).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: isSmallScreen ? 18 : 22,
              backgroundColor: Colors.transparent,
              child: Icon(
                Icons.refresh,
                color: Colors.white,
                size: isSmallScreen ? 18 : 20,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notifications opened!'),
                backgroundColor: Color(0xFF667eea),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF667eea), Color(0xFF764ba2)],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667eea).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: isSmallScreen ? 20 : 25,
              backgroundColor: Colors.transparent,
              child: Icon(
                Icons.notifications_none,
                color: Colors.white,
                size: isSmallScreen ? 20 : 24,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Connect with People',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('See all people...'),
                    backgroundColor: Color(0xFF64B5F6),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Text(
                'See all',
                style: TextStyle(
                  color: const Color(0xFF64B5F6),
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: isSmallScreen ? 100 : 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 8,
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Connection request has been sent!'),
                      backgroundColor: Color(0xFF4CAF50),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: Container(
                  width: isSmallScreen ? 65 : 80,
                  margin: EdgeInsets.only(right: isSmallScreen ? 12 : 16),
                  child: Column(
                    children: [
                      Container(
                        width: isSmallScreen ? 50 : 65,
                        height: isSmallScreen ? 50 : 65,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: _getRandomGradient(),
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _getRandomGradient()[0].withOpacity(0.4),
                              blurRadius: 15,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Stack(
                          children: [
                            const Center(
                              child: Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 30,
                              ),
                            ),
                            if (index < 3)
                              Positioned(
                                right: 0,
                                top: 0,
                                child: Container(
                                  width: isSmallScreen ? 14 : 18,
                                  height: isSmallScreen ? 14 : 18,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4CAF50),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF1A1A2E),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'user_${index + 1}',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: isSmallScreen ? 10 : 12,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Featured Stories',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (journals.isNotEmpty)
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (_isPaused) {
                        setState(() {
                          _isPaused = false;
                        });
                        _startAutoRotation();
                      } else {
                        _pauseAutoRotation();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isPaused
                              ? const [Color(0xFF4CAF50), Color(0xFF45A049)]
                              : const [Color(0xFFFF9800), Color(0xFFF57C00)],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                (_isPaused
                                        ? const Color(0xFF4CAF50)
                                        : const Color(0xFFFF9800))
                                    .withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isPaused ? Icons.play_arrow : Icons.pause,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${currentJournalIndex + 1} of ${journals.length}',
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (isLoadingJournals)
          const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667eea)),
            ),
          )
        else if (journals.isNotEmpty)
          Column(
            children: [
              GestureDetector(
                onTap: _nextJournal,
                onLongPress: () {
                  if (_isPaused) {
                    setState(() {
                      _isPaused = false;
                    });
                    _startAutoRotation();
                  } else {
                    _pauseAutoRotation();
                  }
                },
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                        return SlideTransition(
                          position: animation.drive(
                            Tween(
                              begin: const Offset(0.3, 0.0),
                              end: const Offset(0.0, 0.0),
                            ).chain(CurveTween(curve: Curves.easeInOut)),
                          ),
                          child: FadeTransition(
                            opacity: animation,
                            child: child,
                          ),
                        );
                      },
                  child: Container(
                    key: ValueKey(currentJournalIndex),
                    child: _buildJournalCard(
                      journals[currentJournalIndex],
                      isSmallScreen,
                      showUserId: true,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(math.min(journals.length, 5), (index) {
                  bool isActive = index == currentJournalIndex;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 1000),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: isActive ? 12 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: isActive
                          ? const LinearGradient(
                              colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                            )
                          : null,
                      color: isActive ? null : Colors.white30,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 8),
              if (journals.length > 1)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isPaused
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_filled,
                      color: _isPaused ? Colors.orange : Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
            ],
          )
        else
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.white.withOpacity(0.1),
                  Colors.white.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: const Padding(
              padding: EdgeInsets.all(40),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.book, color: Colors.white60, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'No public stories available',
                      style: TextStyle(color: Colors.white60, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildJournalCard(
    Journal journal,
    bool isSmallScreen, {
    required bool showUserId,
  }) {
    final gradientColors = _getRandomGradient();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(colors: gradientColors),
                    boxShadow: [
                      BoxShadow(
                        color: gradientColors[0].withOpacity(0.3),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person,
                    color: Colors.white,
                    size: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  journal.userId ?? '', // Null-aware fallback
                  style: const TextStyle(
                    color: Color(0xFF4ECDC4),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatDate(journal.timestamp),
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Colors.white, Colors.white70],
              ).createShader(bounds),
              child: Text(
                journal.title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 16 : 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              journal.content,
              style: TextStyle(
                color: Colors.white70,
                fontSize: isSmallScreen ? 12 : 14,
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommunitiesSection(bool isSmallScreen) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Communities',
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 18 : 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            GestureDetector(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Create new community...'),
                    backgroundColor: Color(0xFF667eea),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 8 : 12,
                  vertical: isSmallScreen ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add,
                      color: Colors.white,
                      size: isSmallScreen ? 14 : 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Create',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: isSmallScreen ? 10 : 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: isSmallScreen ? 10 : 15,
          mainAxisSpacing: isSmallScreen ? 10 : 15,
          childAspectRatio: isSmallScreen ? 0.85 : 0.9,
          children: [
            _buildCommunityCard(
              'Mindful Living',
              Icons.self_improvement,
              const [Color(0xFF667eea), Color(0xFF764ba2)],
              '12.4k',
              isSmallScreen,
            ),
            _buildCommunityCard(
              'Anxiety Support',
              Icons.psychology,
              const [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
              '8.7k',
              isSmallScreen,
            ),
            _buildCommunityCard(
              'Study Buddies',
              Icons.school,
              const [Color(0xFF4ECDC4), Color(0xFF44A08D)],
              '15.2k',
              isSmallScreen,
            ),
            _buildCommunityCard(
              'Wellness Journey',
              Icons.spa,
              const [Color(0xFFFF8A80), Color(0xFFFF5722)],
              '9.1k',
              isSmallScreen,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommunityCard(
    String title,
    IconData icon,
    List<Color> gradientColors,
    String memberCount,
    bool isSmallScreen,
  ) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Joined $title community!'),
            backgroundColor: gradientColors[0],
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isSmallScreen ? 45 : 60,
                height: isSmallScreen ? 45 : 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: gradientColors),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors[0].withOpacity(0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isSmallScreen ? 22 : 28,
                ),
              ),
              SizedBox(height: isSmallScreen ? 10 : 15),
              Text(
                title,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isSmallScreen ? 12 : 14,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                '$memberCount members',
                style: TextStyle(
                  color: Colors.white60,
                  fontSize: isSmallScreen ? 10 : 12,
                ),
              ),
              SizedBox(height: isSmallScreen ? 6 : 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  3,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    width: isSmallScreen ? 18 : 24,
                    height: isSmallScreen ? 18 : 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: _getRandomGradient()),
                      border: Border.all(
                        color: const Color(0xFF1A1A2E),
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      Icons.person,
                      color: Colors.white,
                      size: isSmallScreen ? 10 : 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Color> _getRandomGradient() {
    List<List<Color>> gradients = [
      const [Color(0xFF667eea), Color(0xFF764ba2)],
      const [Color(0xFFFF6B6B), Color(0xFFFFE66D)],
      const [Color(0xFF4ECDC4), Color(0xFF44A08D)],
      const [Color(0xFFFF8A80), Color(0xFFFF5722)],
      const [Color(0xFFBA68C8), Color(0xFF9C27B0)],
      const [Color(0xFF64B5F6), Color(0xFF42A5F5)],
    ];
    return gradients[Random().nextInt(gradients.length)];
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
}

// Starry Background Widget
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
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

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
