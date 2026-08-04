import 'package:go_router/go_router.dart';
import 'screens/slap_screen.dart';
import 'screens/screens.dart';

// Slimmed down: the app is now ONLY a slap-capture → preprocess → minutiae
// visualizer. Enroll / authenticate / verify / matching have been removed.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/',         builder: (context, state) => const SlapScreen()),
    GoRoute(path: '/settings', builder: (context, state) => const SettingsScreen()),
  ],
);
