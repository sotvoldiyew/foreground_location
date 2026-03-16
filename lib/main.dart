import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'src/common/service/location_service.dart';
import 'src/common/service/notification_service.dart';
import 'src/feature/tracking/bloc/tracking_bloc.dart';
import 'src/feature/tracking/screen/map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor:          Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  await Permission.notification.request();
  await NotificationService.instance.init();

  await LocationService.instance.init();

  runApp(const App());
}

class App extends StatefulWidget {
  const App({super.key});
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      LocationService.instance.onResume();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => TrackingBloc(),
      child: MaterialApp(
        title:                      'Location Tracker',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor:  const Color(0xFF1565C0),
            brightness: Brightness.light,
          ),
          useMaterial3:            true,
          scaffoldBackgroundColor: Colors.grey.shade900,
        ),
        home: const MapScreen(),
      ),
    );
  }
}