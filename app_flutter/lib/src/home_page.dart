part of '../main.dart';

class PublicHome extends StatefulWidget {
  const PublicHome({super.key});

  @override
  State<PublicHome> createState() => _PublicHomeState();
}

class _PublicHomeState extends State<PublicHome> {
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> sections = [];
  bool loading = true;
  bool _showSearch = false;
  bool get admin => session.admin;
  String? pageError;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_rebuild);
    session.addListener(_rebuild);
    session.loadAdminUsername();
    loadSections();
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    session.removeListener(_rebuild);
    _searchController.removeListener(_rebuild);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> loadSections() async {
    if (mounted) {
      setState(() {
        loading = true;
        pageError = null;
      });
    }
    try {
      final response = toMap(await session.api.request('GET', 'sections'));
      if (mounted) setState(() => sections = toList(response['data']));
    } catch (error) {
      if (mounted) {
        setState(() => pageError = apiErrorMessage(error));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addSection() async {
    final name = await askText(context, title: 'قسم جديد', label: 'اسم القسم');
    if (!mounted || name == null || name.trim().isEmpty) return;
    try {
      await session.api.request('POST', 'sections', body: {'name': name.trim()});
      await loadSections();
      if (mounted) _success('تمت إضافة القسم.');
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  Future<void> editSection(Map<String, dynamic> section) async {
    final name = await askText(
      context,
      title: 'تعديل القسم',
      label: 'اسم القسم',
      initial: textOf(section['name']),
      confirmLabel: 'حفظ',
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    try {
      await session.api.request(
        'PATCH',
        'sections/${section['id']}',
        body: {'name': name.trim()},
      );
      await loadSections();
      if (mounted) _success('تم تعديل اسم القسم.');
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  Future<void> deleteSection(Map<String, dynamic> section) async {
    final confirmed = await confirmAction(
      context,
      title: 'حذف القسم',
      message: 'هل تريدين حذف «${textOf(section['name'], 'القسم')}»؟ إذا كان يحتوي على بيانات فقد يرفض الخادم الحذف لحمايتها.',
    );
    if (!mounted || !confirmed) return;
    try {
      await session.api.request('DELETE', 'sections/${section['id']}');
      await loadSections();
      if (mounted) _success('تم حذف القسم.');
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  void _success(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
    );
  }

  List<Map<String, dynamic>> get visibleSections {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return sections;
    return sections.where((section) {
      return textOf(section['name']).toLowerCase().contains(query) ||
          section['id']?.toString().contains(query) == true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visible = visibleSections;
    return Scaffold(
      drawer: AppDrawer(pageContext: context, onRefresh: loadSections),
      appBar: AppBar(
        titleSpacing: 8,
        centerTitle: true,
        title: const Text('الرئيسية'),
        actions: [
          if (admin)
            const Padding(
              padding: EdgeInsetsDirectional.only(end: 4),
              child: Icon(Icons.admin_panel_settings_rounded, color: brand),
            ),
          IconButton(
            tooltip: 'بحث',
            onPressed: () {
              setState(() {
                _showSearch = !_showSearch;
                if (!_showSearch) _searchController.clear();
              });
            },
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: addSection,
              backgroundColor: brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة قسم'),
            )
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 8, 18, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [brand, brandDark],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [

                              const Text(
                                'كل المخزن بمكان واحد',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 21,
                                  height: 1.3,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                admin
                                    ? 'يمكنك إدارة الأقسام والمحتويات.'
                                    : 'تصفّح الأقسام والمعلومات بسهولة.',
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 65,
                          height: 65,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .13),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: Colors.white,
                            size: 35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_showSearch)
                    TextField(
                      controller: _searchController,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: tr('ابحثي عن قسم أو رقم القسم...'),
                        prefixIcon: const Icon(Icons.search_rounded, color: muted),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: tr('مسح البحث'),
                                onPressed: _searchController.clear,
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'أقسام المخزن',
                      style: TextStyle(
                        color: ink,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: mint,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      '$sectionCountLabel${sections.length}',
                      style: const TextStyle(
                        color: brandDark,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildSectionsBody(visible),
            ),
          ],
        ),
      ),
    );
  }

  String get sectionCountLabel => 'عدد الأقسام: ';

  Widget _buildSectionsBody(List<Map<String, dynamic>> visible) {
    if (loading && sections.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: brand),
            SizedBox(height: 14),
            Text('جاري تحميل الأقسام...', style: TextStyle(color: muted)),
          ],
        ),
      );
    }
    if (pageError != null && sections.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _ErrorCard(message: pageError!, onRetry: loadSections),
        ),
      );
    }
    if (visible.isEmpty) {
      final searching = _searchController.text.trim().isNotEmpty;
      return ListView(
        padding: const EdgeInsets.fromLTRB(24, 25, 24, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(27),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: line),
            ),
            child: Column(
              children: [
                Container(
                  width: 74,
                  height: 74,
                  decoration: const BoxDecoration(color: mint, shape: BoxShape.circle),
                  child: Icon(
                    searching ? Icons.search_off_rounded : Icons.folder_open_rounded,
                    color: brand,
                    size: 36,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  searching ? 'لم يتم العثور على نتائج' : 'لا توجد أقسام حتى الآن',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 7),
                Text(
                  searching
                      ? 'جرّب كلمة بحث أخرى.'
                      : admin
                          ? 'ابدأ بإضافة القسم الأول إلى المخزن.'
                          : 'التصفّح متاح للجميع. ستظهر الأقسام هنا عند إضافتها.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: muted, height: 1.5),
                ),
                if (searching) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _searchController.clear,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('مسح البحث'),
                  ),
                ],
                if (pageError != null) ...[
                  const SizedBox(height: 12),
                  Text(pageError!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFB42318))),
                  TextButton.icon(onPressed: loadSections, icon: const Icon(Icons.refresh), label: const Text('إعادة المحاولة')),
                ],
              ],
            ),
          ),
        ],
      );
    }

    return RefreshIndicator(
      color: brand,
      onRefresh: loadSections,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 105),
        itemCount: visible.length + (pageError == null ? 0 : 1),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= visible.length) {
            return _ErrorCard(message: pageError!, onRetry: loadSections);
          }
          final section = visible[index];
          return _SectionCard(
            section: section,
            admin: admin,
            onTap: () => Navigator.push<void>(
              context,
              MaterialPageRoute(
                builder: (_) => ContentsPage(section: section),
              ),
            ),
            onEdit: () => editSection(section),
            onDelete: () => deleteSection(section),
          );
        },
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.section,
    required this.admin,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final Map<String, dynamic> section;
  final bool admin;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: mint,
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(Icons.folder_copy_outlined, color: brand, size: 27),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      textOf(section['name'], 'قسم بلا اسم'),
                      style: const TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'رقم القسم ${section['id'] ?? '—'}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('عرض المحتويات', style: TextStyle(color: brand, fontSize: 12, fontWeight: FontWeight.w700)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_back_rounded, size: 14, color: brand),
                      ],
                    ),
                  ],
                ),
              ),
              if (admin)
                PopupMenuButton<String>(
                  tooltip: tr('إدارة القسم'),
                  onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 19), SizedBox(width: 8), Text('تعديل الاسم')])),
                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, color: Color(0xFFB42318), size: 19), SizedBox(width: 8), Text('حذف القسم')])),
                  ],
                )
              else
                const Icon(Icons.chevron_left_rounded, color: muted),
            ],
          ),
        ),
      ),
    );
  }
}
