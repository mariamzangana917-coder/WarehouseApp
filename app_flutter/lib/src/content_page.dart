part of '../main.dart';

class ContentPage extends StatefulWidget {
  const ContentPage({super.key, required this.content});

  final Map<String, dynamic> content;

  @override
  State<ContentPage> createState() => _ContentPageState();
}

class _ContentPageState extends State<ContentPage> {
  final TextEditingController _search = TextEditingController();
  List<Map<String, dynamic>> columns = [];
  List<Map<String, dynamic>> rows = [];
  List<Map<String, dynamic>> items = [];
  bool loading = true;
  String? pageError;

  bool get admin => session.admin;

  List<Map<String, dynamic>> get shownItems => items
      .where(
        (item) => matchesQuery(_search.text, [
          item['label'],
          ...toMap(item['data']).entries.expand((e) => [e.key, e.value]),
        ]),
      )
      .toList();

  List<Map<String, dynamic>> get shownRows => rows
      .where((row) => matchesQuery(_search.text, toMap(row['values']).values))
      .toList();

  void _rebuild() {
    if (mounted) setState(() {});
  }

  String _keyOf(Map<String, dynamic> column) =>
      textOf(column['column_key'], 'column_${column['id']}');

  String get contentId => widget.content['id'].toString();
  bool get isList => widget.content['content_type'] == 'list';

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
        await session.api.request(
          'GET',
          isList ? 'contents/$contentId/items' : 'contents/$contentId/rows',
        ),
      );
      if (mounted) {
        setState(() {
          if (isList) {
            items = toList(result['data']);
          } else {
            columns = toList(result['columns']);
            rows = toList(result['data']);
          }
        });
      }
    } catch (error) {
      if (mounted) setState(() => pageError = apiErrorMessage(error));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  List<String> _optionsOf(Map<String, dynamic> column) {
    final settings = toMap(column['settings']);
    final raw = settings['options'];
    if (raw is List) {
      return raw
          .map((e) => e.toString())
          .where((e) => e.trim().isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// نموذج الصف: كل عمود ياخذ حقل مناسب لنوعه (نص، رقم، تاريخ، نعم/لا، اختيار).
  Future<Map<String, dynamic>?> rowForm({
    required String title,
    Map<String, dynamic>? initial,
  }) async {
    final controllers = <String, TextEditingController>{};
    final flags = <String, String>{};
    for (final column in columns) {
      final key = _keyOf(column);
      final old = initial?[key]?.toString() ?? '';
      controllers[key] = TextEditingController(text: old);
      flags[key] = old.toLowerCase() == 'true' || old == '1'
          ? 'true'
          : (old.toLowerCase() == 'false' || old == '0' ? 'false' : '');
    }

    Widget fieldFor(
      BuildContext dialogContext,
      StateSetter update,
      Map<String, dynamic> column,
    ) {
      final key = _keyOf(column);
      final type = textOf(column['data_type'], 'text');
      final label =
          '${textOf(column['name'], key)}${truthy(column['is_required']) ? ' *' : ''}';
      final controller = controllers[key]!;

      switch (type) {
        case 'boolean':
          return SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: m.Text(label),
            subtitle: flags[key] == ''
                ? null
                : Text(flags[key] == 'true' ? 'نعم' : 'لا'),
            value: flags[key] == 'true',
            onChanged: (value) =>
                update(() => flags[key] = value ? 'true' : 'false'),
          );
        case 'date':
          return TextField(
            controller: controller,
            readOnly: true,
            decoration: InputDecoration(
              labelText: label,
              suffixIcon: const Icon(Icons.calendar_month_outlined),
            ),
            onTap: () async {
              final now = DateTime.now();
              final parsed = DateTime.tryParse(controller.text);
              final picked = await showDatePicker(
                context: dialogContext,
                initialDate: parsed ?? now,
                firstDate: DateTime(1990),
                lastDate: DateTime(2100),
              );
              if (picked != null) {
                final mm = picked.month.toString().padLeft(2, '0');
                final dd = picked.day.toString().padLeft(2, '0');
                controller.text = '${picked.year}-$mm-$dd';
              }
            },
          );
        case 'select':
          final options = _optionsOf(column);
          if (options.isNotEmpty) {
            final current = controller.text;
            return DropdownButtonFormField<String>(
              value: options.contains(current) ? current : null,
              decoration: InputDecoration(labelText: label),
              hint: const Text('اختاري'),
              items: [
                for (final option in options)
                  DropdownMenuItem(value: option, child: m.Text(option)),
              ],
              onChanged: (value) => update(() => controller.text = value ?? ''),
            );
          }
          return TextField(
            controller: controller,
            decoration: InputDecoration(labelText: label),
          );
        case 'number':
          return TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: label),
          );
        case 'decimal':
          return TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: label),
          );
        default:
          return TextField(
            controller: controller,
            decoration: InputDecoration(labelText: label),
          );
      }
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final column in columns)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: fieldFor(context, update, column),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                for (final column in columns)
                  _keyOf(column): textOf(column['data_type']) == 'boolean'
                      ? flags[_keyOf(column)]
                      : controllers[_keyOf(column)]!.text.trim(),
              }),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    for (final controller in controllers.values) {
      controller.dispose();
    }
    return result;
  }

  Future<void> addColumn() async {
    final name = await askText(
      context,
      title: 'إضافة عمود',
      label: 'اسم العمود',
      confirmLabel: 'متابعة',
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    String type = 'text';
    bool requiredField = false;
    final optionsController = TextEditingController();
    final settings = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: const Text('إعدادات العمود'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: type,
                decoration: InputDecoration(labelText: tr('نوع البيانات')),
                items: const [
                  DropdownMenuItem(value: 'text', child: Text('نص')),
                  DropdownMenuItem(value: 'number', child: Text('عدد صحيح')),
                  DropdownMenuItem(value: 'decimal', child: Text('عدد عشري')),
                  DropdownMenuItem(value: 'date', child: Text('تاريخ')),
                  DropdownMenuItem(value: 'boolean', child: Text('نعم / لا')),
                  DropdownMenuItem(value: 'select', child: Text('اختيار')),
                ],
                onChanged: (value) {
                  if (value != null) update(() => type = value);
                },
              ),
              if (type == 'select') ...[
                const SizedBox(height: 12),
                TextField(
                  controller: optionsController,
                  decoration: InputDecoration(
                    labelText: tr('الخيارات (افصلي بينها بفاصلة)'),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: requiredField,
                title: const Text('هذا الحقل مطلوب'),
                onChanged: (value) =>
                    update(() => requiredField = value ?? false),
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
                final options = optionsController.text
                    .split(RegExp(r'[,،]'))
                    .map((e) => e.trim())
                    .where((e) => e.isNotEmpty)
                    .toList();
                Navigator.pop(dialogContext, {
                  'data_type': type,
                  'is_required': requiredField,
                  if (type == 'select' && options.isNotEmpty)
                    'settings': {'options': options},
                });
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    optionsController.dispose();
    if (!mounted || settings == null) return;
    try {
      await session.api.request(
        'POST',
        'contents/$contentId/columns',
        body: {
          'name': name.trim(),
          ...settings,
          'sort_order': columns.length + 1,
        },
      );
      await load();
      if (mounted) _toast('تمت إضافة العمود.');
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  Future<void> editColumn(Map<String, dynamic> column) async {
    final name = await askText(
      context,
      title: 'تعديل العمود',
      label: 'اسم العمود',
      initial: textOf(column['name']),
      confirmLabel: 'حفظ',
    );
    if (!mounted || name == null || name.trim().isEmpty) return;
    try {
      await session.api.request(
        'PATCH',
        'contents/$contentId/columns/${column['id']}',
        body: {'name': name.trim()},
      );
      await load();
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  Future<void> deleteColumn(Map<String, dynamic> column) async {
    final yes = await confirmAction(
      context,
      title: 'حذف العمود',
      message: 'سيتم حذف قيم هذا العمود من الصفوف أيضاً. هل تريدين المتابعة؟',
    );
    if (!mounted || !yes) return;
    try {
      await session.api.request(
        'DELETE',
        'contents/$contentId/columns/${column['id']}',
      );
      await load();
      if (mounted) _toast('تم حذف العمود.');
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  Future<void> saveRow({Map<String, dynamic>? row}) async {
    if (columns.isEmpty) {
      showMessage(
        context,
        Exception('أضيفي عموداً واحداً على الأقل قبل إضافة الصفوف.'),
      );
      return;
    }
    final initial = row == null ? <String, dynamic>{} : toMap(row['values']);
    final values = await rowForm(
      title: row == null ? 'إضافة صف' : 'تعديل الصف',
      initial: initial,
    );
    if (!mounted || values == null) return;
    try {
      if (row == null) {
        await session.api.request(
          'POST',
          'contents/$contentId/rows',
          body: {'values': values, 'sort_order': rows.length + 1},
        );
      } else {
        await session.api.request(
          'PATCH',
          'contents/$contentId/rows/${row['id']}',
          body: {'values': values},
        );
      }
      await load();
      if (mounted) _toast(row == null ? 'تمت إضافة الصف.' : 'تم تعديل الصف.');
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  Future<void> deleteRow(Map<String, dynamic> row) async {
    final yes = await confirmAction(
      context,
      title: 'حذف الصف',
      message: 'هل تريدين حذف هذا الصف؟',
    );
    if (!mounted || !yes) return;
    try {
      await session.api.request(
        'DELETE',
        'contents/$contentId/rows/${row['id']}',
      );
      await load();
      if (mounted) _toast('تم حذف الصف.');
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  Future<void> saveItem({Map<String, dynamic>? item}) async {
    final oldData = item == null ? <String, dynamic>{} : toMap(item['data']);
    final entries = oldData.entries.toList();
    final keyControllers = <TextEditingController>[];
    final valueControllers = <TextEditingController>[];
    for (final entry in entries) {
      keyControllers.add(TextEditingController(text: entry.key));
      valueControllers.add(
        TextEditingController(text: entry.value?.toString() ?? ''),
      );
    }
    if (entries.isEmpty) {
      keyControllers.add(TextEditingController());
      valueControllers.add(TextEditingController());
    }
    final labelController = TextEditingController(text: textOf(item?['label']));
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(item == null ? 'إضافة عنصر للقائمة' : 'تعديل العنصر'),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: labelController,
                    decoration: InputDecoration(
                      labelText: tr('عنوان العنصر (اختياري)'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ...List.generate(
                    keyControllers.length,
                    (index) => Padding(
                      padding: const EdgeInsets.only(bottom: 9),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: keyControllers[index],
                              decoration: InputDecoration(
                                labelText: tr('اسم الحقل'),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: valueControllers[index],
                              decoration: InputDecoration(
                                labelText: tr('القيمة'),
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: tr('إزالة الحقل'),
                            onPressed: keyControllers.length <= 1
                                ? null
                                : () {
                                    final removedKey = keyControllers.removeAt(
                                      index,
                                    );
                                    final removedValue = valueControllers
                                        .removeAt(index);
                                    update(() {});
                                    WidgetsBinding.instance
                                        .addPostFrameCallback((_) {
                                          removedKey.dispose();
                                          removedValue.dispose();
                                        });
                                  },
                            icon: const Icon(
                              Icons.remove_circle_outline,
                              color: Color(0xFFB42318),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        keyControllers.add(TextEditingController());
                        valueControllers.add(TextEditingController());
                        update(() {});
                      },
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إضافة حقل'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final data = <String, dynamic>{};
                for (var i = 0; i < keyControllers.length; i++) {
                  final key = keyControllers[i].text.trim();
                  if (key.isNotEmpty)
                    data[key] = valueControllers[i].text.trim();
                }
                if (data.isEmpty) return;
                Navigator.pop(dialogContext, {
                  'label': labelController.text.trim(),
                  'data': data,
                });
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    labelController.dispose();
    for (final controller in keyControllers) {
      controller.dispose();
    }
    for (final controller in valueControllers) {
      controller.dispose();
    }
    if (!mounted || result == null) return;
    final body = <String, dynamic>{
      'label': (result['label'] as String).trim().isEmpty
          ? null
          : result['label'],
      'data': result['data'],
    };
    try {
      if (item == null) {
        body['sort_order'] = items.length + 1;
        await session.api.request(
          'POST',
          'contents/$contentId/items',
          body: body,
        );
      } else {
        await session.api.request('PATCH', 'items/${item['id']}', body: body);
      }
      await load();
      if (mounted)
        _toast(item == null ? 'تمت إضافة العنصر.' : 'تم تعديل العنصر.');
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  Future<void> deleteItem(Map<String, dynamic> item) async {
    final yes = await confirmAction(
      context,
      title: 'حذف العنصر',
      message: 'هل تريدين حذف هذا العنصر؟',
    );
    if (!mounted || !yes) return;
    try {
      await session.api.request('DELETE', 'items/${item['id']}');
      await load();
      if (mounted) _toast('تم حذف العنصر.');
    } catch (error) {
      if (mounted) showMessage(context, error);
    }
  }

  void _toast(String value) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
  );

  Widget _buildItems() {
    if (items.isEmpty) {
      return _EmptyState(
        icon: Icons.list_alt_rounded,
        title: 'القائمة فارغة',
        description: admin
            ? 'أضيفي أول عنصر، ويمكنك تحديد حقول مختلفة لكل عنصر.'
            : 'لم تتم إضافة عناصر لهذه القائمة بعد.',
        action: admin
            ? FilledButton.icon(
                onPressed: saveItem,
                icon: const Icon(Icons.add),
                label: const Text('إضافة عنصر'),
              )
            : null,
      );
    }
    final list = shownItems;
    if (list.isEmpty) {
      return const _EmptyState(
        icon: Icons.search_off_rounded,
        title: 'ما لقينا نتائج',
        description: 'جربي كلمة بحث ثانية.',
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = list[index];
        final data = toMap(item['data']);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: mint,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.description_outlined,
                        color: brand,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        textOf(item['label'], 'عنصر ${index + 1}'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color: ink,
                        ),
                      ),
                    ),
                    if (admin)
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') saveItem(item: item);
                          if (value == 'delete') deleteItem(item);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('تعديل')),
                          PopupMenuItem(value: 'delete', child: Text('حذف')),
                        ],
                      ),
                  ],
                ),
                if (data.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Divider(height: 1, color: line),
                  ),
                  ...data.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              entry.key,
                              style: const TextStyle(
                                color: muted,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: Text(
                              entry.value?.toString() ?? '—',
                              style: const TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTable() {
    final tableWidth = 72.0 + columns.length * 180.0 + (admin ? 96.0 : 0.0);

    Widget buildCell(Widget child, {bool header = false}) {
      return Container(
        constraints: const BoxConstraints(minHeight: 52),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        color: header ? mint : null,
        child: child,
      );
    }

    Widget headerCell(String label) {
      return buildCell(
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(color: ink, fontWeight: FontWeight.w800),
        ),
        header: true,
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      children: [
        if (admin)
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'أعمدة الجدول',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Text(
                        '${columns.length} عمود',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  if (columns.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'ابدأ بإضافة الأعمدة المطلوبة لهذا الجدول.',
                        style: TextStyle(color: muted),
                      ),
                    ),
                  ...columns.map(
                    (column) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(
                        Icons.view_column_outlined,
                        color: brand,
                      ),
                      title: Text(
                        textOf(column['name'], 'عمود'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        '${textOf(column['data_type'], 'text')}'
                        '${truthy(column['is_required']) ? ' • مطلوب' : ''}',
                        style: const TextStyle(color: muted, fontSize: 12),
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'edit') editColumn(column);
                          if (value == 'delete') deleteColumn(column);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'edit',
                            child: Text('تعديل الاسم'),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text('حذف العمود'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: addColumn,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('إضافة عمود'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (columns.isEmpty)
          const _InlineNotice(
            text: 'لا توجد أعمدة معرّفة لهذا الجدول حتى الآن.',
          ),
        if (rows.isEmpty)
          _EmptyState(
            icon: Icons.table_chart_outlined,
            title: 'لا توجد صفوف حتى الآن',
            description: admin
                ? 'بعد إضافة الأعمدة، أضف الصف الأول إلى الجدول.'
                : 'لم تتم إضافة بيانات لهذا الجدول بعد.',
            action: admin && columns.isNotEmpty
                ? FilledButton.icon(
                    onPressed: saveRow,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة صف'),
                  )
                : null,
          )
        else if (shownRows.isEmpty)
          const _EmptyState(
            icon: Icons.search_off_rounded,
            title: 'لم يتم العثور على نتائج',
            description: 'جرّب كلمة بحث أخرى.',
          )
        else
          Card(
            margin: const EdgeInsets.only(top: 10),
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: tableWidth,
                child: Table(
                  border: TableBorder.all(color: line, width: 0.8),
                  defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                  columnWidths: <int, TableColumnWidth>{
                    0: const FixedColumnWidth(72),
                    for (var i = 0; i < columns.length; i++)
                      i + 1: const FixedColumnWidth(180),
                    if (admin) columns.length + 1: const FixedColumnWidth(96),
                  },
                  children: [
                    TableRow(
                      children: [
                        headerCell('التسلسل'),
                        ...columns.map(
                          (column) =>
                              headerCell(textOf(column['name'], 'عمود')),
                        ),
                        if (admin) headerCell('الإجراءات'),
                      ],
                    ),
                    ...shownRows.map((row) {
                      final index = rows.indexOf(row);
                      final values = toMap(row['values']);

                      return TableRow(
                        children: [
                          buildCell(
                            Text(
                              '${index + 1}',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: brandDark,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          ...columns.map((column) {
                            final key = textOf(
                              column['column_key'],
                              'column_${column['id']}',
                            );

                            return buildCell(
                              Text(
                                textOf(values[key], '—'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: ink,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }),
                          if (admin)
                            buildCell(
                              PopupMenuButton<String>(
                                tooltip: 'إجراءات الصف',
                                onSelected: (value) {
                                  if (value == 'edit') saveRow(row: row);
                                  if (value == 'delete') deleteRow(row);
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('تعديل الصف'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('حذف الصف'),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final noData = isList ? items.isEmpty : (rows.isEmpty && columns.isEmpty);
    Widget body;
    if (loading && noData) {
      body = const Center(child: CircularProgressIndicator(color: brand));
    } else if (pageError != null && noData) {
      body = Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: _ErrorCard(message: pageError!, onRetry: load),
        ),
      );
    } else {
      body = isList ? _buildItems() : _buildTable();
    }

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
        title: Text(textOf(widget.content['name'], 'المحتوى')),
        actions: [
          if (admin && !isList)
            IconButton(
              tooltip: tr('إضافة عمود'),
              onPressed: addColumn,
              icon: const Icon(Icons.view_column_outlined),
            ),
          const MenuButton(),
          const SizedBox(width: 6),
        ],
      ),
      floatingActionButton: admin
          ? FloatingActionButton.extended(
              onPressed: isList ? saveItem : saveRow,
              backgroundColor: brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: Text(isList ? 'إضافة عنصر' : 'إضافة صف'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: SearchField(
              controller: _search,
              hint: 'ابحثي في هذا المحتوى...',
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
