part of '../main.dart';

// ---------------------------------------------------------------------------
// حالة التطبيق المشتركة بين كل الصفحات: المستخدم، الأدمن، اللغة، الاتصال.
// ---------------------------------------------------------------------------

class Session extends ChangeNotifier {
  Session(this.api);

  final Api api;
  String? username;
  bool admin = false;
  String lang = 'ar'; // 'ar' أو 'ckb'
  String adminUsername = 'warehouse_admin';

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _usernameStorageKey = 'warehouse_username';
  static const String _adminTokenStorageKey = 'warehouse_admin_token';

  /// Restore the saved identity and validate a stored administrator session.
  Future<void> restore() async {
    try {
      final savedUsername = await _storage.read(key: _usernameStorageKey);
      if (savedUsername != null && savedUsername.trim().isNotEmpty) {
        username = savedUsername.trim().toLowerCase();
      }

      final savedToken = await _storage.read(key: _adminTokenStorageKey);
      if (savedToken != null && savedToken.trim().isNotEmpty) {
        api.token = savedToken;
        admin = true;
        unawaited(_validateStoredAdminSession());
      }
    } catch (_) {
      // Storage failure must not prevent the app from opening.
    }
    changed();
  }

  Future<void> _validateStoredAdminSession() async {
    try {
      final profile = toMap(await api.request('GET', 'auth/me'));

      if (profile['is_admin_session'] != true) {
        await clearAdminSession(clearUsername: true);
        return;
      }

      final user = toMap(profile['user']);
      final savedName = textOf(
        user['username'],
        username ?? adminUsername,
      ).trim().toLowerCase();

      if (savedName.isNotEmpty) {
        username = savedName;
        await _storage.write(key: _usernameStorageKey, value: savedName);
      }
      changed();
    } catch (error) {
      final message = error.toString().toLowerCase();
      if (message.contains('unauthenticated') ||
          message.contains('unauthorized') ||
          message.contains('401') ||
          message.contains('غير مصرح')) {
        await clearAdminSession(clearUsername: true);
      }
      // Do not erase a saved token because of a temporary network failure.
      // Laravel still validates every protected API request.
    }
  }

  Future<void> saveUsername(String value) async {
    final normalized = value.trim().toLowerCase();
    username = normalized.isEmpty ? null : normalized;

    if (username == null) {
      await _storage.delete(key: _usernameStorageKey);
    } else {
      await _storage.write(key: _usernameStorageKey, value: username!);
    }
    changed();
  }

  Future<void> saveAdminSession(String token, String accountName) async {
    final normalized = accountName.trim().toLowerCase();

    await _storage.write(key: _adminTokenStorageKey, value: token);
    await _storage.write(key: _usernameStorageKey, value: normalized);

    api.token = token;
    username = normalized;
    admin = true;
    changed();
  }

  Future<void> clearAdminSession({bool clearUsername = false}) async {
    await _storage.delete(key: _adminTokenStorageKey);
    api.token = null;
    admin = false;

    if (clearUsername) {
      username = null;
      await _storage.delete(key: _usernameStorageKey);
    }
    changed();
  }

  void changed() => notifyListeners();

  void setLang(String value) {
    if (lang == value) return;
    lang = value;
    notifyListeners();
  }

  /// اسم الأدمن يجي من الخادم (حتى لو تغيّر بالإعدادات).
  Future<bool> loadAdminUsername() async {
    try {
      final result = toMap(await api.request('GET', 'auth/admin-identifier'));
      final name = textOf(result['username'])
          .replaceAll(RegExp(r'[\u200B-\u200F\u202A-\u202E\u2060\uFEFF]'), '')
          .trim()
          .toLowerCase();

      if (!RegExp(r'^[a-z][a-z0-9_]{2,39}$').hasMatch(name)) {
        return false;
      }

      adminUsername = name;
      return true;
    } catch (_) {
      return false;
    }
  }
}

final Session session = Session(Api(apiDefault));

void _toastGlobal(BuildContext context, String text) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
}

/// إضافة اسم مستخدم. إذا الاسم هو اسم الأدمن تطلع شاشة كود الأدمن.
Future<void> identifyUser(BuildContext context) async {
  String normalizeUsername(String value) {
    return value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9_]'),
      '',
    );
  }

  final entered = await askText(
    context,
    title: 'اسم المستخدم',
    label: 'اكتب اسم المستخدم',
    initial: session.username ?? '',
  );

  if (!context.mounted || entered == null) return;

  final normalized = normalizeUsername(entered);
  if (normalized.isEmpty) return;

  try {
    final loaded = await session.loadAdminUsername();

    if (!loaded) {
      throw Exception(
        'تعذّر جلب اسم الإدارة من الخادم. تحقق من اتصال التطبيق بالسيرفر.',
      );
    }

    final configuredAdmin = normalizeUsername(session.adminUsername);
    final isAdminName = normalized == configuredAdmin;

    debugPrint(
      'WAREHOUSE_AUTH: adminMatch=$isAdminName, '
      'inputLength=${normalized.length}, '
      'serverNameLength=${configuredAdmin.length}',
    );

    if (isAdminName) {
      final code = await askText(
        context,
        title: 'دخول الإدارة',
        label: 'كود دخول الأدمن',
        secret: true,
      );

      if (!context.mounted || code == null || code.trim().isEmpty) return;

      final result = toMap(
        await session.api.request(
          'POST',
          'auth/admin-activate',
          body: {'username': configuredAdmin, 'code': code.trim()},
        ),
      );

      final token = result['token']?.toString();

      if (token == null || token.isEmpty) {
        throw Exception('لم يستلم التطبيق رمز الإدارة من الخادم.');
      }

      await session.saveAdminSession(token, configuredAdmin);

      if (context.mounted) {
        _toastGlobal(context, 'تم دخول وضع الإدارة بنجاح.');
      }
      return;
    }

    if (normalized == session.username) {
      await session.saveUsername(normalized);

      if (context.mounted) {
        _toastGlobal(context, 'تم استرجاع اسم المستخدم المحفوظ.');
      }
      return;
    }

    await session.api.request(
      'POST',
      'users/username',
      body: {'username': normalized},
    );

    await session.saveUsername(normalized);

    if (context.mounted) {
      _toastGlobal(context, 'تم تسجيل اسم المستخدم.');
    }
  } catch (error) {
    if (context.mounted) {
      showMessage(context, error);
    }
  }
}

Future<void> logoutAdmin(BuildContext context) async {
  try {
    await session.api.request('POST', 'auth/logout');
  } catch (_) {
    // نمسح الجلسة محلياً حتى لو الخادم مو متاح.
  }
  await session.clearAdminSession(clearUsername: true);
  _toastGlobal(context, 'تم الخروج من وضع الإدارة.');
}

Future<void> openUsers(BuildContext context) async {
  try {
    final users = <Map<String, dynamic>>[];
    var page = 1;
    var lastPage = 1;
    do {
      final response = toMap(
        await session.api.request('GET', 'admin/users?page=$page'),
      );
      users.addAll(toList(response['data']));
      lastPage = int.tryParse(textOf(response['last_page'], '1')) ?? 1;
      page++;
    } while (page <= lastPage && page <= 40);

    if (!context.mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => UsersPage(users: users)),
    );
  } catch (error) {
    if (context.mounted) showMessage(context, error);
  }
}

// ---------------------------------------------------------------------------
// القائمة الجانبية (الثلاثة خطوط) + زر القائمة + حقل البحث. تنستخدم بكل صفحة.
// ---------------------------------------------------------------------------

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key, required this.pageContext, this.onRefresh});

  /// سياق الصفحة (مو سياق القائمة) حتى تشتغل الحوارات بعد إغلاق القائمة.
  final BuildContext pageContext;
  final Future<void> Function()? onRefresh;

  void _run(BuildContext drawerContext, Future<void> Function() action) {
    Navigator.pop(drawerContext);
    action();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        final who = session.admin
            ? 'مدير النظام'
            : (session.username == null
                  ? 'زائر'
                  : 'مسجّل باسم: ${session.username}');
        return Drawer(
          backgroundColor: pageBg,
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.all(14),
              children: [
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [brand, brandDark],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .15),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Icon(
                          session.admin
                              ? Icons.admin_panel_settings_rounded
                              : Icons.person_outline_rounded,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'مخزني',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              who,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                ListTile(
                  leading: const Icon(
                    Icons.person_add_alt_1_rounded,
                    color: brand,
                  ),
                  title: const Text('إضافة اسم مستخدم'),
                  onTap: () => _run(context, () => identifyUser(pageContext)),
                ),
                if (session.admin)
                  ListTile(
                    leading: const Icon(
                      Icons.people_alt_outlined,
                      color: brand,
                    ),
                    title: const Text('المستخدمون'),
                    onTap: () => _run(context, () => openUsers(pageContext)),
                  ),
                const Divider(height: 26, color: line),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: Text(
                    'اللغة',
                    style: TextStyle(color: muted, fontWeight: FontWeight.w800),
                  ),
                ),
                _langTile(context, 'ar', 'العربية'),
                _langTile(context, 'ckb', 'کوردی سۆرانی'),
                if (session.admin) ...[
                  const Divider(height: 26, color: line),
                  ListTile(
                    leading: const Icon(
                      Icons.logout_rounded,
                      color: Color(0xFFB42318),
                    ),
                    title: const Text('الخروج من الإدارة'),
                    onTap: () => _run(context, () => logoutAdmin(pageContext)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _langTile(BuildContext context, String code, String label) {
    final selected = session.lang == code;
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
        color: selected ? brand : muted,
      ),
      // اسم اللغة بلغته نفسها، فنستخدم Text الأصلية بدون ترجمة.
      title: m.Text(label),
      onTap: () {
        session.setLang(code);
        Navigator.pop(context);
      },
    );
  }
}

class MenuButton extends StatelessWidget {
  const MenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tr('القائمة'),
      icon: const Icon(Icons.menu_rounded),
      onPressed: () => Scaffold.of(context).openDrawer(),
    );
  }
}

class SearchField extends StatelessWidget {
  const SearchField({super.key, required this.controller, required this.hint});

  final TextEditingController controller;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([controller, session]),
      builder: (context, _) => TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: tr(hint),
          prefixIcon: const Icon(Icons.search_rounded, color: muted),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: tr('مسح البحث'),
                  onPressed: controller.clear,
                  icon: const Icon(Icons.close_rounded),
                ),
        ),
      ),
    );
  }
}

/// هل النص يحتوي على كلمة البحث (بدون حساسية لحالة الأحرف).
bool matchesQuery(String query, Iterable<Object?> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return fields.any((f) => (f?.toString() ?? '').toLowerCase().contains(q));
}
