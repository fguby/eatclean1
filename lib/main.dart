import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lottie/lottie.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:shake/shake.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

part 'parts/core.dart';
part 'parts/models.dart';
part 'parts/stores.dart';
part 'parts/screens_onboarding.dart';
part 'parts/screens_dashboard.dart';
part 'parts/screens_profile.dart';
part 'parts/screens_discover.dart';
part 'parts/screens_records.dart';
part 'parts/screens_scan.dart';
part 'parts/widgets_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_allowBadCertificates) {
    HttpOverrides.global = _DevHttpOverrides();
  }
  await NotificationService.instance.initialize();
  await ThemeStore.instance.ensureLoaded();
  unawaited(SubscriptionService.instance.initialize());
  runApp(const EatCleanApp());
}
