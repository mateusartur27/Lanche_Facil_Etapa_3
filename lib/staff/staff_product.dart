import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'staff_api.dart';
import 'staff_notifications.dart';

class StaffProduct extends StatefulWidget {
  const StaffProduct({
    super.key,
    required this.api,
    required this.token,
    required this.entry,
    required this.canUpload,
    required this.notifications,
  });

  final StaffApi api;
  final String token;
  final CatalogEntry entry;
  final bool canUpload;
  final StaffNotifications notifications;

  @override
  State<StaffProduct> createState() => _StaffProductState();
}

class _StaffProductState extends State<StaffProduct> {
  late final Map<AttachmentKind, Attachment> _attachments;
  Uint8List? _photo;
  ({String name, Uint8List bytes})? _selection;
  AttachmentKind _kind = AttachmentKind.photo;
  bool _picking = false;
  bool _uploading = false;
  bool _downloading = false;
  bool _offeringPermission = false;
  double? _progress;
  String? _message;
  bool _error = false;

  String get _productId => widget.entry.product.id;
  bool get _busy => _picking || _uploading || _downloading || _offeringPermission;

  @override
  void initState() {
    super.initState();
    _attachments = Map.of(widget.entry.attachments);
    if (_attachments.containsKey(AttachmentKind.photo)) {
      _loadPhoto();
    }
  }

  void _feedback(String message, {bool error = false}) {
    if (mounted) setState(() {
      _message = message;
      _error = error;
    });
  }

  void _apiError(StaffApiError error) {
    if (!mounted) return;
    if (error.status == 401) {
      Navigator.of(context).pop(true);
    } else {
      _feedback(error.toString(), error: true);
    }
  }

  Future<void> _loadPhoto() async {
    try {
      final previous = _attachments[AttachmentKind.photo];
      final bytes = await widget.api.download(widget.token, _productId, AttachmentKind.photo);
      if (mounted && identical(previous, _attachments[AttachmentKind.photo])) {
        setState(() => _photo = bytes);
      }
    } on StaffApiError catch (error) {
      _apiError(error);
    }
  }

  Future<void> _pick() async {
    if (_busy) return;
    setState(() {
      _picking = true;
      _message = null;
    });
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _kind.extensions,
        withData: kIsWeb,
      );
      if (!mounted || result == null) return;
      setState(() => _selection = null);
      final file = result.files.single;
      if (file.size <= 0 || file.size > StaffApi.maxBytes) {
        _feedback(
          file.size <= 0 ? 'O arquivo está vazio.' : 'O arquivo excede o limite de 1 MiB.',
          error: true,
        );
        return;
      }
      final extension = file.extension?.toLowerCase();
      if (!_kind.extensions.contains(extension) || file.name.length > 160) {
        _feedback('Escolha um arquivo em um dos formatos indicados e com nome de até 160 caracteres.', error: true);
        return;
      }
      final bytes = file.bytes ?? await result.xFiles.single.readAsBytes();
      if (bytes.isEmpty || bytes.length > StaffApi.maxBytes) {
        _feedback('O arquivo deve ter entre 1 byte e 1 MiB.', error: true);
        return;
      }
      if (mounted) setState(() => _selection = (name: file.name, bytes: bytes));
    } catch (_) {
      _feedback('Não foi possível abrir o arquivo selecionado.', error: true);
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  Future<void> _upload() async {
    final file = _selection;
    if (_busy || file == null || !widget.canUpload) return;
    final kind = _kind;
    setState(() {
      _uploading = true;
      _progress = 0;
      _message = null;
    });
    try {
      final sent = await widget.api.upload(
        widget.token, _productId, kind, file.name, file.bytes,
        (count, total) {
          if (mounted && total > 0) {
            setState(() => _progress = (count / total).clamp(0.0, 1.0).toDouble());
          }
        },
      );
      if (!mounted) return;
      setState(() {
        _attachments[kind] = sent;
        _selection = null;
        if (kind == AttachmentKind.photo) _photo = file.bytes;
      });
      final notified = await widget.notifications.showSuccess(widget.entry.product.name, kind.label);
      _feedback(widget.notifications.supported && !notified
          ? 'Arquivo salvo no servidor. Habilite as notificações no Android para receber o aviso.'
          : 'Arquivo salvo no servidor.');
    } on StaffApiError catch (error) {
      _apiError(error);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _saveSheet(Attachment sheet) async {
    setState(() {
      _downloading = true;
      _message = null;
    });
    try {
      final bytes = await widget.api.download(widget.token, _productId, AttachmentKind.sheet);
      if (!mounted) return;
      final path = await FilePicker.saveFile(
        dialogTitle: 'Salvar ficha técnica',
        fileName: sheet.name,
        type: FileType.custom,
        allowedExtensions: AttachmentKind.sheet.extensions,
        bytes: bytes,
      );
      if (path != null || kIsWeb) _feedback('Ficha técnica salva.');
    } on StaffApiError catch (error) {
      _apiError(error);
    } catch (_) {
      _feedback('Não foi possível salvar a ficha técnica.', error: true);
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  Future<void> _enableNotifications() async {
    setState(() => _offeringPermission = true);
    final allowed = await widget.notifications.requestPermission();
    if (!mounted) return;
    setState(() => _offeringPermission = false);
    _feedback(allowed
        ? 'Notificações ativadas.'
        : 'Para receber o aviso, permita notificações nas configurações do Android.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final product = widget.entry.product;
    final sheet = _attachments[AttachmentKind.sheet];
    final photo = _attachments[AttachmentKind.photo];
    final file = _selection;
    final progress = _progress;
    return PopScope(
      canPop: !_uploading,
      child: Scaffold(
        appBar: AppBar(title: Text(product.name)),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(product.categoryId, style: theme.textTheme.titleMedium),
                Text(product.description),
                const SizedBox(height: 14),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      if (_photo != null)
                        Image.memory(
                          _photo!,
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) => const SizedBox(
                            height: 90,
                            child: Center(child: Text('Não foi possível exibir a imagem.')),
                          ),
                        ),
                      ListTile(
                        leading: const Icon(Icons.image_outlined),
                        title: const Text('Foto do produto'),
                        subtitle: Text(photo == null ? 'Nenhuma foto enviada' : photo.name),
                      ),
                      ListTile(
                        leading: const Icon(Icons.picture_as_pdf_outlined),
                        title: const Text('Ficha técnica'),
                        subtitle: Text(sheet == null ? 'Nenhuma ficha enviada' : sheet.name),
                        trailing: sheet == null
                            ? null
                            : IconButton(
                                tooltip: 'Baixar ficha técnica',
                                onPressed: _busy ? null : () => _saveSheet(sheet),
                                icon: const Icon(Icons.download),
                              ),
                      ),
                    ],
                  ),
                ),
                if (widget.canUpload) ...[
                  const SizedBox(height: 24),
                  Text('Enviar arquivo', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      for (final kind in AttachmentKind.values)
                        ChoiceChip(
                          label: Text(kind.label),
                          selected: _kind == kind,
                          onSelected: _busy ? null : (selected) {
                            if (selected && _kind != kind) {
                              setState(() {
                                _kind = kind;
                                _selection = null;
                                _message = null;
                              });
                            }
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_kind == AttachmentKind.photo ? 'PNG ou JPG · até 1 MiB' : 'PDF · até 1 MiB'),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _pick,
                    icon: const Icon(Icons.attach_file),
                    label: const Text('Selecionar arquivo'),
                  ),
                  if (file != null) Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('${file.name} · ${Attachment.formatSize(file.bytes.length)}'),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: _busy || file == null ? null : _upload,
                    icon: const Icon(Icons.cloud_upload_outlined),
                    label: const Text('Enviar'),
                  ),
                  if (_uploading) ...[
                    const SizedBox(height: 12),
                    LinearProgressIndicator(value: progress == 1 ? null : progress),
                    Text(progress == 1
                        ? 'Aguardando confirmação do servidor…'
                        : 'Enviando… ${((progress ?? 0) * 100).round()}%'),
                  ],
                  if (widget.notifications.supported)
                    TextButton.icon(
                      onPressed: _busy ? null : _enableNotifications,
                      icon: const Icon(Icons.notifications_outlined),
                      label: const Text('Ativar notificações'),
                    ),
                ] else ...[
                  const SizedBox(height: 16),
                  const Text('Somente consulta. O envio de arquivos exige permissão de funcionário.'),
                ],
                if (_message != null) Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _message!,
                    style: TextStyle(color: _error ? theme.colorScheme.error : theme.colorScheme.onSurface),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
