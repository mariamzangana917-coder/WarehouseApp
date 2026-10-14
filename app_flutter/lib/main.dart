import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart' hide Text;
import 'package:flutter/material.dart' as m show Text;
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

part 'src/core.dart';
part 'src/l10n.dart';
part 'src/session.dart';
part 'src/app.dart';
part 'src/home_page.dart';
part 'src/contents_page.dart';
part 'src/content_page.dart';
part 'src/users_page.dart';
part 'src/widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await session.restore();
  runApp(const WarehouseApp());
}
