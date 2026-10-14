part of '../main.dart';

const Color brand = Color(0xFF147D73);
const Color brandDark = Color(0xFF0D5F58);
const Color pageBg = Color(0xFFF4F7F8);
const Color ink = Color(0xFF1D2939);
const Color muted = Color(0xFF667085);
const Color line = Color(0xFFE4E9EC);
const Color mint = Color(0xFFE5F4F1);

// Can be overridden when running Flutter:
// flutter run --dart-define=WAREHOUSE_API_URL=http://192.168.x.x:8000/api
const String apiDefault = String.fromEnvironment(
  'WAREHOUSE_API_URL',
  defaultValue: 'http://192.168.0.103:8000/api',
);

Map<String, dynamic> toMap(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

List<Map<String, dynamic>> toList(dynamic value) =>
    value is List ? value.map(toMap).toList() : <Map<String, dynamic>>[];

bool truthy(dynamic value) => value == true || value == 1 || value == '1';

String textOf(dynamic value, [String fallback = '']) {
  final text = value?.toString() ?? '';
  return text.trim().isEmpty ? fallback : text;
}

String apiErrorMessage(Object error) {
  final raw = error.toString().replaceFirst('Exception: ', '').trim();
  if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
    return 'تعذّر الاتصال بالخادم. تأكدي أن السيرفر يعمل وأن الموبايل والحاسبة على نفس شبكة Wi-Fi.';
  }
  if (raw.contains('TimeoutException') || raw.contains('Timed out')) {
    return 'انتهت مهلة الاتصال بالخادم. حاولي مرة ثانية.';
  }
  return raw.isEmpty ? 'حدث خطأ غير متوقع. حاولي مرة ثانية.' : raw;
}

void showMessage(BuildContext context, Object error) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(apiErrorMessage(error)),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF344054),
      ),
    );
}

Future<String?> askText(
  BuildContext context, {
  required String title,
  required String label,
  String initial = '',
  bool secret = false,
  String confirmLabel = 'متابعة',
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AskTextDialog(
      title: title,
      label: label,
      initial: initial,
      secret: secret,
      confirmLabel: confirmLabel,
    ),
  );
}

class _AskTextDialog extends StatefulWidget {
  const _AskTextDialog({
    required this.title,
    required this.label,
    required this.initial,
    required this.secret,
    required this.confirmLabel,
  });

  final String title;
  final String label;
  final String initial;
  final bool secret;
  final String confirmLabel;

  @override
  State<_AskTextDialog> createState() => _AskTextDialogState();
}

class _AskTextDialogState extends State<_AskTextDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initial);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title, textAlign: TextAlign.right),
      content: TextField(
        controller: _controller,
        autofocus: true,
        obscureText: widget.secret,
        textDirection: TextDirection.rtl,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (value) => Navigator.pop(context, value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _controller.text.trim()),
          child: Text(widget.confirmLabel),
        ),
      ],
    );
  }
}

Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'حذف',
}) async {
  return await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: confirmLabel == 'حذف'
                    ? const Color(0xFFB42318)
                    : brand,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(confirmLabel),
            ),
          ],
        ),
      ) ??
      false;
}

class Api {
  Api(this.baseUrl);

  final String baseUrl;
  String? token;

  Future<dynamic> request(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final uri = Uri.parse(
      '${baseUrl.replaceAll(RegExp(r'/+$'), '')}/'
      '${path.replaceAll(RegExp(r'^/+'), '')}',
    );
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json; charset=UTF-8',
      if (token != null) 'Authorization': 'Bearer $token',
    };
    final encoded = jsonEncode(body ?? <String, dynamic>{});
    late http.Response response;

    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
          break;
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 15));
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 15));
          break;
        case 'PUT':
          response = await http
              .put(uri, headers: headers, body: encoded)
              .timeout(const Duration(seconds: 15));
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
          break;
        default:
          throw Exception('نوع الطلب غير مدعوم.');
      }
    } on SocketException {
      throw Exception(
        'تعذّر الاتصال بالخادم. تأكدي من عنوان API وتشغيل Laravel واتصال الجهازين بنفس الشبكة.',
      );
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال بالخادم. حاولي مرة ثانية.');
    }

    dynamic data;
    try {
      data = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } catch (_) {
      data = {'message': response.body};
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final payload = toMap(data);
      final errors = toMap(payload['errors']);
      String? detail;
      for (final entry in errors.entries) {
        final value = entry.value;
        if (value is List && value.isNotEmpty) {
          detail =
              '${entry.key.replaceFirst('values.', '')}: ${serverText(value.first.toString())}';
          break;
        }
      }
      throw Exception(
        detail ??
            serverText(
              textOf(
                payload['message'],
                'تعذّر إكمال الطلب (${response.statusCode}).',
              ),
            ),
      );
    }
    return data;
  }
}
