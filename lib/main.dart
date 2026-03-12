import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import 'src/common/service/background_service.dart';
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
  await BgService.instance.init();

  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

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