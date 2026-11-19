import 'package:flutter/material.dart';

import 'staff_api.dart';
import 'staff_notifications.dart';
import 'staff_product.dart';

class StaffCatalog extends StatefulWidget {
  const StaffCatalog({
    super.key,
    required this.api,
    required this.token,
    required this.profile,
    required this.notifications,
    required this.onLogout,
    required this.onExpired,
  });

  final StaffApi api;
  final String token;
  final StaffProfile profile;
  final StaffNotifications notifications;
  final Future<void> Function() onLogout;
  final Future<void> Function() onExpired;

  @override
  State<StaffCatalog> createState() => _StaffCatalogState();
}

class _StaffCatalogState extends State<StaffCatalog> {
  List<CatalogEntry> _entries = const [];
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await widget.api.catalog(widget.token);
      if (mounted) setState(() => _entries = entries);
    } on StaffApiError catch (error) {
      if (!mounted) return;
      if (error.status == 401) {
        await widget.onExpired();
        return;
      }
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open(CatalogEntry item) async {
    final expired = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => StaffProduct(
          api: widget.api,
          token: widget.token,
          entry: item,
          canUpload: widget.profile.canUpload,
          notifications: widget.notifications,
        ),
      ),
    );
    if (!mounted) return;
    if (expired == true) {
      await widget.onExpired();
    } else {
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestão do cardápio'),
        actions: [
          IconButton(
            tooltip: 'Atualizar cardápio',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text(widget.profile.email, style: theme.textTheme.titleMedium),
                Text(
                  widget.profile.canUpload
                      ? 'Perfil de funcionário'
                      : 'Perfil de consulta',
                ),
                const SizedBox(height: 16),
                Text('Produtos', style: theme.textTheme.headlineSmall),
                if (_loading) const LinearProgressIndicator(),
                if (_error != null) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                  OutlinedButton(
                    onPressed: _load,
                    child: const Text('Tentar novamente'),
                  ),
                ],
                if (!_loading && _error == null && _entries.isEmpty)
                  const Text('Nenhum produto disponível.'),
                for (final item in _entries)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Card(
                      child: ListTile(
                        leading: Icon(
                          item.attachments.containsKey(AttachmentKind.photo)
                              ? Icons.image_outlined
                              : Icons.fastfood_outlined,
                        ),
                        title: Text(item.product.name),
                        subtitle: Text(
                          [
                            item.product.categoryId,
                            if (item.attachments.containsKey(
                              AttachmentKind.photo,
                            ))
                              'Foto',
                            if (item.attachments.containsKey(
                              AttachmentKind.sheet,
                            ))
                              'Ficha técnica',
                          ].join(' · '),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _open(item),
                      ),
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
