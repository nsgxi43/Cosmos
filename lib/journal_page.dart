import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'main.dart'; // For StarryBackground

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage>
    with TickerProviderStateMixin {
  final TextEditingController _journalController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  String suggestion = "Journal Prompt";
  bool isLoadingSuggestion = false;

  late AnimationController _animationController;
  late Animation<double> _animation;

  // HARDCODED USER ID - Always use this specific user
  static const String HARDCODED_USER_ID = "demo_user";
  static const String BASE_URL = "https://cosmos-wellness.duckdns.org";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _fetchSuggestion();
  }

  @override
  void dispose() {
    _journalController.dispose();
    _titleController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // ---------------- FETCH SUGGESTION ----------------
  Future<void> _fetchSuggestion() async {
    setState(() {
      isLoadingSuggestion = true;
      suggestion = "Generating suggestion...";
    });
    _animationController.repeat();

    try {
      // Use the hardcoded user ID in the endpoint
      final response = await http.get(
        Uri.parse("$BASE_URL/suggestion/$HARDCODED_USER_ID"),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            suggestion =
                data['suggestion'] ?? "Take a moment to reflect on your day.";
            isLoadingSuggestion = false;
          });
          _animationController.stop();
          _animationController.reset();
        }
      } else {
        print("⚠️ Failed to fetch suggestion: ${response.statusCode}");
        if (mounted) {
          setState(() {
            suggestion = "Take a moment to reflect on your current feelings.";
            isLoadingSuggestion = false;
          });
          _animationController.stop();
          _animationController.reset();
        }
      }
    } catch (e) {
      print("⚠️ Failed to fetch suggestion: $e");
      if (mounted) {
        setState(() {
          suggestion = "What emotions are you experiencing right now?";
          isLoadingSuggestion = false;
        });
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  // ---------------- POST JOURNAL ----------------
  Future<void> _postJournal(
    String title,
    String content,
    String visibility,
  ) async {
    try {
      final response = await http.post(
        Uri.parse("$BASE_URL/journal"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "title": title,
          "content": content,
          "visibility": visibility,
          "user_id": HARDCODED_USER_ID, // Always send hardcoded user ID
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final finalVisibility = data['final_visibility'] ?? visibility;

        if (finalVisibility != visibility && visibility == "public") {
          // If backend downgraded to private
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: Colors.black.withOpacity(0.6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                'Cannot Publish',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              content: Text(
                'Sorry, this entry cannot be published publicly due to sensitive content. Saved privately instead.',
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'OK',
                    style: GoogleFonts.poppins(color: Colors.blue),
                  ),
                ),
              ],
            ),
          );
        } else {
          final snack = SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black87,
            content: Text(
              finalVisibility == 'private'
                  ? 'Saved privately ✓'
                  : 'Shared publicly ✓',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
            duration: const Duration(seconds: 2),
          );
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(snack);
        }

        // Clear fields and refresh suggestion
        _titleController.clear();
        _journalController.clear();
        _fetchSuggestion();
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      final snack = SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.redAccent,
        content: Text(
          "Failed to save journal. Please try again.",
          style: GoogleFonts.poppins(color: Colors.white),
        ),
        duration: const Duration(seconds: 3),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(snack);
      print("⚠️ Post journal error: $e");
    }
  }

  // ---------------- ON PRESS JOURNAL ----------------
  void _onJournalItPressed() async {
    // Check if there's content to save
    if (_titleController.text.trim().isEmpty &&
        _journalController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.orange,
          content: Text(
            "Please write something before journaling!",
            style: GoogleFonts.poppins(color: Colors.white),
          ),
        ),
      );
      return;
    }

    final visibility = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Share entry',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Do you want to keep this journal entry private or share it publicly with the community?',
          style: GoogleFonts.poppins(fontSize: 14, color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'private'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Keep Private',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'public'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF667eea), Color(0xFF764ba2)],
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Share Public',
                style: GoogleFonts.poppins(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );

    if (visibility != null) {
      await _postJournal(
        _titleController.text.trim().isEmpty
            ? "Untitled Entry"
            : _titleController.text,
        _journalController.text,
        visibility,
      );
    }
  }

  Widget _buildLoadingDots() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final delay = index * 0.3;
            final animationValue = (_animation.value + delay) % 1.0;
            final opacity = (animationValue < 0.5)
                ? (animationValue * 2)
                : (2 - animationValue * 2);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Opacity(
                opacity: opacity.clamp(0.3, 1.0),
                child: Text(
                  '•',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final accentGradient = const LinearGradient(
      colors: [
        Color.fromARGB(255, 135, 187, 222),
        Color.fromARGB(255, 164, 115, 201),
      ],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Journal',
              style: GoogleFonts.playfairDisplay(color: Colors.white),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Text(
                'User: $HARDCODED_USER_ID',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.blue.shade200,
                ),
              ),
            ),
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: StarryBackground()),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    Colors.black.withOpacity(0.0),
                    Colors.black.withOpacity(0.4),
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 18.0,
                vertical: 12,
              ),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // ---- SUGGESTION WITH LOADING ----
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 300),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color.fromARGB(255, 62, 34, 97),
                              Color.fromARGB(255, 97, 50, 150),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 8,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                isLoadingSuggestion
                                    ? "Journal Prompt"
                                    : suggestion,
                                softWrap: true,
                                overflow: TextOverflow.visible,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (isLoadingSuggestion) ...[
                              const SizedBox(width: 8),
                              _buildLoadingDots(),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: isLoadingSuggestion ? null : _fetchSuggestion,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: isLoadingSuggestion
                                  ? [Colors.grey.shade600, Colors.grey.shade700]
                                  : [
                                      const Color(0xFF4CAF50),
                                      const Color(0xFF45A049),
                                    ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    (isLoadingSuggestion
                                            ? Colors.grey.shade600
                                            : const Color(0xFF4CAF50))
                                        .withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 50),

                  // ---- TITLE ----
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final boxWidth =
                          constraints.maxWidth *
                          (constraints.maxWidth > 600 ? 0.7 : 0.92);
                      return Center(
                        child: Container(
                          width: boxWidth,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.08),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.purple.withOpacity(0.1),
                                blurRadius: 12,
                                spreadRadius: 4,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                              child: TextField(
                                controller: _titleController,
                                style: GoogleFonts.poppins(
                                  color: Colors.white.withOpacity(0.95),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  hintText: "Title",
                                  hintStyle: GoogleFonts.poppins(
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 12,
                                  ),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // ---- JOURNAL BODY ----
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final boxWidth =
                            constraints.maxWidth *
                            (constraints.maxWidth > 600 ? 0.7 : 0.92);
                        final boxHeight = constraints.maxHeight * 0.98;
                        return Center(
                          child: Container(
                            width: boxWidth,
                            height: boxHeight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.08),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.purple.withOpacity(0.12),
                                  blurRadius: 24,
                                  spreadRadius: 6,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 12,
                                  sigmaY: 12,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(18),
                                  color: Colors.white.withOpacity(0.02),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Align(
                                        alignment: Alignment.topCenter,
                                        child: Container(
                                          width: 60,
                                          height: 6,
                                          decoration: BoxDecoration(
                                            color: Colors.white.withOpacity(
                                              0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),
                                      Expanded(
                                        child: TextField(
                                          controller: _journalController,
                                          maxLines: null,
                                          expands: true,
                                          keyboardType: TextInputType.multiline,
                                          style: GoogleFonts.poppins(
                                            color: Colors.white.withOpacity(
                                              0.95,
                                            ),
                                            fontSize: 16,
                                          ),
                                          decoration: InputDecoration(
                                            hintText:
                                                "Write freely. Your thoughts are safe here...",
                                            hintStyle: GoogleFonts.poppins(
                                              color: Colors.white.withOpacity(
                                                0.5,
                                              ),
                                            ),
                                            border: InputBorder.none,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Align(
                                        alignment: Alignment.centerRight,
                                        child: GestureDetector(
                                          onTap: _onJournalItPressed,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 18,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(14),
                                              gradient: accentGradient,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.blueAccent
                                                      .withOpacity(0.18),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 6),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              'Journal it',
                                              style: GoogleFonts.poppins(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
