part of '../main.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key, required this.users});
  final List<Map<String, dynamic>> users;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _search.addListener(_rebuild);
    session.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    session.removeListener(_rebuild);
    _search.removeListener(_rebuild);
    _search.dispose();
    super.dispose();
  }

  String _rolesOf(Map<String, dynamic> user) {
    final rawRoles = user['roles'];
    if (rawRoles is! List || rawRoles.isEmpty) return tr('مستخدم');
    return rawRoles
        .map((role) {
          final slug = role is Map ? textOf(role['slug'], textOf(role['name'])) : role.toString();
          return slug == 'admin' ? tr('مدير النظام') : tr('مستخدم');
        })
        .join(tr('، '));
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.users
        .where((u) => matchesQuery(_search.text, [u['username'], u['name'], u['id']]))
        .toList();

    return Scaffold(
      drawer: AppDrawer(pageContext: context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('المستخدمون المسجلون'),
        actions: const [MenuButton(), SizedBox(width: 6)],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SearchField(controller: _search, hint: 'ابحثي عن مستخدم...'),
          ),
          Expanded(
            child: widget.users.isEmpty
                ? const _EmptyState(
                    icon: Icons.people_outline_rounded,
                    title: 'ماكو مستخدمين مسجلين',
                    description: 'راح تظهر الحسابات هنا بعد تسجيل أسماء المستخدمين.',
                  )
                : list.isEmpty
                    ? const _EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'ما لقينا نتائج',
                        description: 'جربي كلمة بحث ثانية.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        itemCount: list.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final user = list[index];
                          return Card(
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(color: mint, borderRadius: BorderRadius.circular(15)),
                                child: const Icon(Icons.person_outline_rounded, color: brand),
                              ),
                              title: m.Text(
                                textOf(user['username'], textOf(user['name'], tr('مستخدم'))),
                                style: const TextStyle(fontWeight: FontWeight.w800, color: ink),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 5),
                                child: m.Text(
                                  '${tr('رقم المستخدم: ')}${user['id'] ?? '—'}  •  ${_rolesOf(user)}',
                                  style: const TextStyle(color: muted, fontSize: 12),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
