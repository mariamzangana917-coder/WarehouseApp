part of '../main.dart';

class ContentsPage extends StatefulWidget {
  const ContentsPage({super.key, required this.section});

  final Map<String, dynamic> section;

  @override
  State<ContentsPage> createState() => _ContentsPageState();
}

class _ContentsPageState extends State<ContentsPage> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> contents = [];
  bool loading = true;
  String? pageError;

  bool get admin => session.admin;

  List<Map<String, dynamic>> get shown => contents
      .where(
        (c) => matchesQuery(_search.text, [
          c['name'],
          c['content_type'] == 'list' ? 'قائمة list' : 'جدول table',
        ]),
      )
      .toList();

  void _rebuild() {
    if (mounted) setState(() {});
  }

  String get sectionId => widget.section['id'].toString();

  @override
  void initState() {
    super.initState();
    session.addListener(_rebuild);
    _search.addListener(_rebuild);
    load();
  }

  @override
  void dispose() {
    session.removeListener(_rebuild);
    _search.removeListener(_rebuild);
    _search.dispose();
    super.dispose();
  }

  Future<void> load() async {
    if (mounted)
      setState(() {
        loading = true;
        pageError = null;
      });
    try {
      final result = toMap(
        await session.api.request('GET', 'sections/$sectionId/contents'),
      );
      if (mounted) setState(() => contents = toList(result['data']));
    } catch (error) {
      if (mounted) setState(() => pageError = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> addContent() async {
    final nameController = TextEditingController();
    String type = 'table';
    final data = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('إضافة محتوى جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: tr('اسم القائمة أو الجدول'),
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                value: type,
                decoration: InputDecoration(labelText: tr('نوع المحتوى')),
                items: const [
                  DropdownMenuItem(value: 'list', child: Text('قائمة مرنة')),
                  DropdownMenuItem(value: 'table', child: Text('جدول بأعمدة')),
                ],
                onChanged: (value) {
                  if (value != null) update(() => type = value);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('اكتبي اسم القائمة أو الجدول أولاً'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, {
                  'name': nameController.text.trim(),
                  'content_type': type,
                });
              },
              child: const Text('إنشاء'),
            ),
          ],
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 300));
    nameController.dispose();
    if (!mounted || data == null) return;
    try {
      await session.api.request(
        'POST',
        'sections/$sectionId/contents',
        body: data,
      );
      await load();
      if (mounted) _toast('تم إنشاء المحتوى.');
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  Future<void> renameContent(Map<String, dynamic> content) async {
    final name = await askText(
      context,
      title: 'تعديل اسم المحتوى',
      label: 'الاسم الجديد',
      initial: textOf(content['name']),
      confirmLabel: 'حفظ',
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    try {
      await session.api.request(
        'PATCH',
        'contents/${content['id']}',
        body: {'name': name.trim()},
      );
      await load();
      if (mounted) _toast('تم تعديل اسم المحتوى.');
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  Future<void> deleteContent(Map<String, dynamic> content) async {
    final yes = await confirmAction(
      context,
      title: 'حذف المحتوى',
      message:
          'هل تريدين حذف «${textOf(content['name'], 'المحتوى')}»؟ تأكدي من عدم حاجتك للبيانات التابعة له.',
    );
    if (!mounted || !yes) return;
    try {
      await session.api.request('DELETE', 'contents/${content['id']}');
      await load();
      if (mounted) _toast('تم حذف المحتوى.');
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  void _toast(String value) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
  );

  Widget _body() {
    final list = shown;
    if (loading && contents.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: brand));
    }
    if (pageError != null && contents.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: _ErrorCard(message: pageError!, onRetry: load),
        ),
      );
    }
    if (contents.isEmpty) {
      return _EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'القسم فارغ حالياً',
        description: admin
            ? 'أضيفي قائمة مرنة أو جدولاً لهذا القسم.'
            : 'ما تمت إضافة محتويات لهذا القسم بعد.',
        action: admin
            ? FilledButton.icon(
                onPressed: addContent,
                icon: const Icon(Icons.add),
                label: const Text('إضافة محتوى'),
              )
            : null,
      );
    }
    if (list.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'ما لقينا نتائج',
        description: 'جربي كلمة بحث ثانية.',
      );
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        itemCount: list.length + (pageError == null ? 0 : 1),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= list.length) {
            return _ErrorCard(message: pageError!, onRetry: load);
          }
          final content = list[index];
          final isList = content['content_type'] == 'list';
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 9,
              ),
              leading: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: mint,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(
                  isList ? Icons.list_alt_rounded : Icons.table_chart_rounded,
                  color: brand,
                ),
              ),
              title: Text(
                textOf(content['name'], 'محتوى'),
                style: const TextStyle(fontWeight: FontWeight.w800, color: ink),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  isList ? 'قائمة مرنة' : 'جدول قابل للتخصيص',
                  style: const TextStyle(color: muted, fontSize: 12),
                ),
              ),
              trailing: admin
                  ? PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'rename') renameContent(content);
                        if (value == 'delete') deleteContent(content);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'rename',
                          child: Text('تعديل الاسم'),
                        ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Text('حذف المحتوى'),
                        ),
                      ],
                    )
                  : const Icon(Icons.chevron_left_rounded, color: muted),
              onTap: () => Navigator.push<void>(
                context,
                MaterialPageRoute(
                  builder: (_) => ContentPage(content: content),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sectionName = textOf(widget.section['name'], 'القسم');
    return Scaffold(
      drawer: AppDrawer(pageContext: context, onRefresh: load),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        centerTitle: true,
        leading: IconButton(
          tooltip: 'رجوع',
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(sectionName),
        actions: const [MenuButton(), SizedBox(width: 6)],
      ),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: addContent,
              backgroundColor: brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('إضافة محتوى'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
            child: SearchField(
              controller: _search,
              hint: 'ابحثي في المحتويات...',
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }
}
