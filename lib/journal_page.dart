import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main.dart'; // to reuse StarryBackground

class JournalPage extends StatefulWidget {
  const JournalPage({super.key});

  @override
  State<JournalPage> createState() => _JournalPageState();
}

class _JournalPageState extends State<JournalPage> {
  final TextEditingController _journalController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  @override
  void dispose() {
    _journalController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _onJournalItPressed() async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black.withOpacity(0.6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Share entry', style: GoogleFonts.poppins()),
        content: Text(
          'Do you want to keep this journal entry private or public?',
          style: GoogleFonts.poppins(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'private'),
            child: Text('Private', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'public'),
            child: Text('Public', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (result != null) {
      final snack = SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.black87,
        content: Text(
          result == 'private' ? 'Saved privately ✨' : 'Shared publicly 🌟',
          style: GoogleFonts.poppins(),
        ),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(snack);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gradient for Journal it button → same as accent chip
    final accentGradient = const LinearGradient(
      colors: [
        Color.fromARGB(255, 135, 187, 222),
        Color.fromARGB(255, 164, 115, 201),
      ],
    );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Journal', style: GoogleFonts.playfairDisplay()),
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
              padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 12),
              child: Column(
                children: [
                  const SizedBox(height: 8),

                  // ✨ Single AI-like prompt at the top
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                            )
                          ],
                        ),
                        child: Text(
                          "How was your day today!",
                          style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 50),

                  // 📝 Title input box
                  // 📝 Title input box
LayoutBuilder(
  builder: (context, constraints) {
    final boxWidth =
        constraints.maxWidth * (constraints.maxWidth > 600 ? 0.7 : 0.92);

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
            )
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

                  // Journal input box
                  Expanded(
                    child: LayoutBuilder(builder: (context, constraints) {
                      final boxWidth =
                          constraints.maxWidth * (constraints.maxWidth > 600 ? 0.7 : 0.92);
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
                              )
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                              child: Container(
                                padding: const EdgeInsets.all(18),
                                color: Colors.white.withOpacity(0.02),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Align(
                                      alignment: Alignment.topCenter,
                                      child: Container(
                                        width: 60,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.12),
                                          borderRadius: BorderRadius.circular(6),
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
                                          color: Colors.white.withOpacity(0.95),
                                          fontSize: 16,
                                        ),
                                        decoration: InputDecoration(
                                          hintText:
                                              "Write freely. Your thoughts are safe here...",
                                          hintStyle: GoogleFonts.poppins(
                                            color: Colors.white.withOpacity(0.5),
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
                                              horizontal: 18, vertical: 12),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(14),
                                            gradient: accentGradient,
                                            boxShadow: [
                                              BoxShadow(
                                                color:
                                                    Colors.blueAccent.withOpacity(0.18),
                                                blurRadius: 16,
                                                offset: const Offset(0, 6),
                                              )
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
                    }),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
