import 'package:flutter/material.dart';
import '../theme.dart';
import 'session_config_screen.dart';
import 'vocab_practice_config_screen.dart';

class UntargetedPracticeScreen extends StatefulWidget {
  const UntargetedPracticeScreen({super.key});

  @override
  State<UntargetedPracticeScreen> createState() => _UntargetedPracticeScreenState();
}

class _UntargetedPracticeScreenState extends State<UntargetedPracticeScreen> {
  final _pageController = PageController();
  int _page = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    _pageController.animateToPage(page,
      duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        automaticallyImplyLeading: false,
        leading: _page == 1
          ? IconButton(
              icon: Icon(Icons.arrow_back_ios, color: AppColors.accent),
              onPressed: () => _goTo(0),
            )
          : IconButton(
              icon: Icon(Icons.arrow_back, color: AppColors.fg),
              onPressed: () => Navigator.pop(context),
            ),
        title: Text(_page == 0 ? 'Kanji' : 'Vocabulary',
          style: TextStyle(color: AppColors.fg)),
        actions: [
          if (_page == 0)
            IconButton(
              icon: Icon(Icons.arrow_forward_ios, color: AppColors.accent),
              onPressed: () => _goTo(1),
            ),
        ],
        iconTheme: IconThemeData(color: AppColors.fg),
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (p) => setState(() => _page = p),
        children: const [
          _KanjiPracticeBody(),
          _VocabPracticeBody(),
        ],
      ),
    );
  }
}

class _KanjiPracticeBody extends StatelessWidget {
  const _KanjiPracticeBody();

  @override
  Widget build(BuildContext context) {
    return const SessionConfigBody();
  }
}

class _VocabPracticeBody extends StatelessWidget {
  const _VocabPracticeBody();

  @override
  Widget build(BuildContext context) {
    return const VocabPracticeConfigBody(targetOnly: false);
  }
}
