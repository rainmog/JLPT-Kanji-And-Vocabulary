import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../theme.dart';
import '../utils/app_route.dart';
import '../widgets/logo_widget.dart';
import 'credits_screen.dart';

class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen> {
  String _version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (mounted) setState(() => _version = info.version);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        title: Text('About', style: TextStyle(color: AppColors.fg)),
        iconTheme: IconThemeData(color: AppColors.fg),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LogoWidget(size: 140),
              const SizedBox(height: 24),
              Text(
                'JLPT Kanji & Vocabulary',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.fg,
                ),
              ),
              if (_version.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'Version $_version',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'A JLPT kanji and vocabulary study app.\nPractice, test, and track your progress offline.',
                style: TextStyle(fontSize: 15, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Not affiliated with or endorsed by JEES or the Japan Foundation.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Divider(color: AppColors.pillBg),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.btnBg,
                  foregroundColor: AppColors.fg,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                  ),
                ),
                onPressed: () => Navigator.push(context, AppRoute.to(const CreditsScreen())),
                child: const Text('Credits'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
