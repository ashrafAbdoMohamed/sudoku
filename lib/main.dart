import 'dart:async';
import 'package:flutter/material.dart';

import 'game/ui_kit.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'state/game_store.dart';
import 'state/game_state.dart';
import 'services/sound_service.dart';
import 'services/ad_service.dart';
import 'services/analytics_service.dart';
import 'services/notification_service.dart';
import 'services/deep_link_service.dart';
import 'screens/splash_screen.dart';
import 'screens/home_screen.dart';
import 'widgets/gdpr_consent_dialog.dart';
import 'widgets/legal_modal.dart';
import 'theme/app_theme.dart';

bool _firebaseInitialized = false;

Future<void> _initializeFirebase() async {
  try {
    // Check if Firebase is already initialized
    if (Firebase.apps.isNotEmpty) {
      _firebaseInitialized = true;
      return;
    }

    // Initialize Firebase with platform-specific options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    _firebaseInitialized = true;
    debugPrint('Firebase initialized successfully');
  } catch (e) {
    _firebaseInitialized = false;
    debugPrint('Firebase initialization failed: $e');
  }
}

bool get isFirebaseAvailable => _firebaseInitialized;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await _initializeFirebase();
  runApp(const SudokuApp());
}

class SudokuApp extends StatefulWidget {
  const SudokuApp({super.key});

  @override
  State<SudokuApp> createState() => _SudokuAppState();
}

class _SudokuAppState extends State<SudokuApp> with WidgetsBindingObserver {
  final GameStore _store = GameStore();
  final GameState _gameState = GameState();
  bool _showSplash = true;
  bool _loaded = false;
  bool _showGdprConsent = false;

  // Deep link handling
  final DeepLinkService _deepLinkService = DeepLinkService();
  StreamSubscription<DeepLinkData>? _deepLinkSubscription;
  String? _pendingChallengePin;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store.load().then((_) async {
      await SoundService().init(_store);
      await _applyAnalyticsConsent();

      // Rebuild the week of daily reminders from current streak/progress
      await NotificationService().reschedule(_store);

      // Ads start once the consent dialog has been answered
      if (_store.gdprConsentGiven) {
        await _initializeAds();
      }

      // Initialize deep links
      await _deepLinkService.initialize();
      _deepLinkSubscription = _deepLinkService.linkStream.listen(_handleDeepLink);

      setState(() {
        _loaded = true;
        _showGdprConsent = _store.needsGdprConsent;
      });
    });
    _store.addListener(() {
      // Update sound service when settings change
      SoundService().updateSettings(
        sound: _store.soundEnabled,
        haptic: _store.hapticEnabled,
      );
      _applyAnalyticsConsent();
      AdService().setPersonalized(_store.adsConsent);
      setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The app can sit in memory across days - refresh reminders on return
    if (state == AppLifecycleState.resumed && _loaded) {
      NotificationService().onResumed();
      NotificationService().reschedule(_store);
    }
  }

  void _handleDeepLink(DeepLinkData data) {
    debugPrint('Main: Handling deep link - $data');

    if (data.type == DeepLinkType.challenge && data.challengePin != null) {
      // Store the pin and show challenge dialog when ready
      _pendingChallengePin = data.challengePin;

      // If app is loaded and not showing splash, show the challenge dialog
      if (_loaded && !_showSplash && !_showGdprConsent && navigatorKey.currentContext != null) {
        _showChallengeFromDeepLink();
      }
    }
  }

  void _showChallengeFromDeepLink() {
    if (_pendingChallengePin == null) return;

    // Rebuild the home screen with the challenge PIN
    // This will trigger the modal to show automatically
    setState(() {});
  }

  /// Everyone who answered the consent dialog gets ads; only those who
  /// allowed "Personalized Ads" get personalized ones
  Future<void> _initializeAds() async {
    await AdService().initialize(personalized: _store.adsConsent);
    // The home banner was built before the SDK was ready - rebuild it
    if (mounted) setState(() {});
  }

  Future<void> _applyAnalyticsConsent() => AnalyticsService().applyConsent(
        analytics: _store.gdprConsentGiven && _store.analyticsConsent,
        ads: _store.gdprConsentGiven && _store.adsConsent,
      );

  void _toggleTheme() {
    _store.toggleTheme();
  }

  AppColorScheme get _colors {
    return AppColors.cartoon;
  }

  void _showPrivacyPolicy() {
    showDialog(
      context: navigatorKey.currentContext!,
      builder: (_) => LegalModal(
        colors: _colors,
        documentType: LegalDocumentType.privacyPolicy,
      ),
    );
  }

  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sudoku',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: kBodyFont,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8E5BEA)),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF3D2B7A),
          contentTextStyle: TextStyle(fontFamily: kBodyFont, fontWeight: FontWeight.w600, fontSize: 15, color: Colors.white),
          shape: StadiumBorder(),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.all(Colors.white),
          trackColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? const Color(0xFF3FB26B) : const Color(0xFFD9D4E2),
          ),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      home: _showSplash
          ? SplashScreen(onComplete: () => setState(() => _showSplash = false))
          : !_loaded
              ? const Scaffold(body: Center(child: CircularProgressIndicator()))
              : _buildHomeWithGdpr(),
    );
  }

  Widget _buildHomeWithGdpr() {
    // Show GDPR consent dialog on first launch
    if (_showGdprConsent) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_showGdprConsent && navigatorKey.currentContext != null) {
          showDialog(
            context: navigatorKey.currentContext!,
            barrierDismissible: false,
            builder: (_) => GdprConsentDialog(
              colors: _colors,
              onAccept: (analytics, ads) {
                _store.acceptConsent(analytics: analytics, ads: ads);
                setState(() => _showGdprConsent = false);
                Navigator.pop(navigatorKey.currentContext!);
                _initializeAds();
              },
              onAcceptEssential: () {
                _store.acceptEssentialOnly();
                setState(() => _showGdprConsent = false);
                Navigator.pop(navigatorKey.currentContext!);
                _initializeAds(); // Non-personalized
              },
              onShowPrivacyPolicy: _showPrivacyPolicy,
            ),
          );
        }
      });
    }

    // Consume the pending challenge PIN
    final challengePin = _pendingChallengePin;
    _pendingChallengePin = null;

    return HomeScreen(
      store: _store,
      gameState: _gameState,
      onToggleTheme: _toggleTheme,
      initialChallengePin: challengePin,
    );
  }
}
