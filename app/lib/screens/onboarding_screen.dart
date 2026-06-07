import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../services/trip_tracker.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// First-run onboarding. The final page primes the user for the
/// "Allow all the time" location prompt BEFORE the system dialog appears —
/// the single biggest lever for Play approval and opt-in rate, since
/// background-location is the #1 rejection cause for this app type.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  bool _busy = false;

  static const _slides = [
    _Slide(
      svg: true,
      title: 'Turn your miles into cash',
      body: 'MileWorth automatically tracks your drives and turns business '
          'miles into tax deductions — with zero manual effort.',
    ),
    _Slide(
      icon: Icons.gps_fixed,
      title: 'Drives track themselves',
      body: 'No start button. MileWorth detects when you begin and end a '
          'drive, then you swipe to mark each trip business or personal.',
    ),
    _Slide(
      icon: Icons.picture_as_pdf,
      title: 'Reports your accountant will love',
      body: 'One tap exports an accountant-ready PDF or CSV of your '
          'deductions, ready to share at tax time.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish({bool requestPermission = false}) async {
    setState(() => _busy = true);
    final tracker = context.read<TripTracker>();
    final appState = context.read<AppState>();
    if (requestPermission) {
      // Show the OS prompt now that the user understands why.
      await tracker.ensureBackgroundPermission();
    }
    await appState.completeOnboarding();
    // AuthGate rebuilds and routes to login once onboarding is marked seen.
  }

  void _next() {
    _controller.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLastInfo = _page == _slides.length; // the priming page
    final totalPages = _slides.length + 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _busy ? null : () => _finish(),
                child: const Text('Skip'),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  ..._slides.map((s) => s.build(context)),
                  _buildPrimingPage(context),
                ],
              ),
            ),
            _Dots(count: totalPages, index: _page),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.all(24),
              child: isLastInfo
                  ? Column(
                      children: [
                        FilledButton(
                          onPressed: _busy
                              ? null
                              : () => _finish(requestPermission: true),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Enable automatic tracking'),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy ? null : () => _finish(),
                          child: const Text('Set up later'),
                        ),
                      ],
                    )
                  : FilledButton(
                      onPressed: _busy ? null : _next,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Next'),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimingPage(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.location_on, size: 88, color: AppColors.navy),
          const SizedBox(height: 24),
          Text('Allow location all the time',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(
            'To detect drives in the background — even when the app is closed — '
            'Android will ask you to choose "Allow all the time".\n\n'
            'Your location data stays private to your account and is never sold '
            'or shared. You can turn tracking off anytime in Settings.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _Slide {
  final IconData? icon;
  final bool svg;
  final String title;
  final String body;

  const _Slide({this.icon, this.svg = false, required this.title, required this.body});

  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (svg)
            SvgPicture.asset('assets/brand/icon.svg', height: 110)
          else
            Icon(icon, size: 96, color: AppColors.navy),
          const SizedBox(height: 32),
          Text(title,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Text(body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.4)),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int index;
  const _Dots({required this.count, required this.index});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active ? AppColors.navy : Colors.grey.shade300,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}
