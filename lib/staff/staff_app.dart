import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'staff_api.dart';
import 'staff_catalog.dart';
import 'staff_notifications.dart';

class StaffApp extends StatefulWidget {
  const StaffApp({super.key});

  @override
  State<StaffApp> createState() => _StaffAppState();
}

class _StaffAppState extends State<StaffApp> {
  static const _sessionKey = 'staff.session';
  final _storage = const FlutterSecureStorage();
  final _api = StaffApi();
  final _notifications = StaffNotifications();
  StaffProfile? _profile;
  String? _token;
  String? _message;
  bool _loading = true;
  bool _restoreFailed = false;

  bool get _persistSession =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    setState(() {
      _loading = true;
      _restoreFailed = false;
      _message = null;
    });
    try {
      final token = _persistSession
          ? await _storage.read(key: _sessionKey)
          : null;
      if (token == null || !mounted) return;
      try {
        final profile = await _api.profile(token);
        if (!mounted) return;
        _token = token;
        _profile = profile;
      } on StaffApiError catch (error) {
        if (error.status != 401) rethrow;
        await _storage.delete(key: _sessionKey);
        _message = error.toString();
      }
    } catch (error) {
      _restoreFailed = true;
      _message = error is StaffApiError
          ? error.toString()
          : 'Não foi possível ler a sessão armazenada.';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _login(String email, String password, bool signup) async {
    final result = await _api.signIn(email, password, signup: signup);
    if (_persistSession) {
      try {
        await _storage.write(key: _sessionKey, value: result.token);
      } catch (_) {
        throw const StaffApiError(
          null,
          'Não foi possível guardar a sessão no dispositivo.',
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _token = result.token;
      _profile = result.profile;
      _message = null;
    });
  }

  Future<void> _endSession({bool expired = false}) async {
    if (_loading) return;
    final token = _token;
    setState(() => _loading = true);
    String? message = expired ? 'Sua sessão expirou. Entre novamente.' : null;
    var storageCleared = true;
    try {
      if (_persistSession) await _storage.delete(key: _sessionKey);
    } catch (_) {
      storageCleared = false;
    }
    if (!expired && token != null) {
      try {
        await _api.logout(token);
      } on StaffApiError catch (error) {
        if (error.status != 401) {
          message =
              'Você saiu do aplicativo. O servidor não confirmou o encerramento da sessão.';
        } else {
          storageCleared = true;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _token = null;
      _profile = null;
      _loading = false;
      _restoreFailed = !storageCleared;
      _message = storageCleared
          ? message
          : 'Não foi possível remover a sessão do dispositivo. Tente limpar a sessão novamente.';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_restoreFailed) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_message ?? 'Falha ao abrir a sessão.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: _restore,
                  child: const Text('Tentar novamente'),
                ),
                TextButton(
                  onPressed: () => _endSession(expired: true),
                  child: const Text('Limpar sessão'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final profile = _profile;
    if (profile == null) {
      return _LoginForm(submit: _login, sessionMessage: _message);
    }
    return StaffCatalog(
      api: _api,
      token: _token!,
      profile: profile,
      notifications: _notifications,
      onLogout: _endSession,
      onExpired: () => _endSession(expired: true),
    );
  }
}

class _LoginForm extends StatefulWidget {
  const _LoginForm({required this.submit, required this.sessionMessage});

  final Future<void> Function(String, String, bool) submit;
  final String? sessionMessage;

  @override
  State<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<_LoginForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _signup = false;
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.submit(_email.text.trim(), _password.text, _signup);
    } on StaffApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = _error ?? widget.sessionMessage;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: AutofillGroup(
                    child: Form(
                      key: _form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Image.asset(
                              'assets/icons/app_icon.png',
                              width: 56,
                              height: 56,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Lanche Fácil',
                            style: theme.textTheme.headlineMedium,
                          ),
                          const Text('Gestão do cardápio'),
                          const SizedBox(height: 24),
                          Text(
                            _signup ? 'Criar conta' : 'Entrar',
                            style: theme.textTheme.titleLarge,
                          ),
                          if (_signup)
                            const Text(
                              'Use um e-mail válido. A conta fica pronta na hora.',
                            ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _email,
                            enabled: !_busy,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'E-mail',
                            ),
                            validator: (value) {
                              final email = value?.trim() ?? '';
                              if (email.length > 254 ||
                                  !RegExp(
                                    r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                  ).hasMatch(email)) {
                                return 'Informe um e-mail válido.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _password,
                            enabled: !_busy,
                            obscureText: _obscure,
                            onFieldSubmitted: (_) => _submit(),
                            autofillHints: [
                              _signup
                                  ? AutofillHints.newPassword
                                  : AutofillHints.password,
                            ],
                            decoration: InputDecoration(
                              labelText: 'Senha',
                              suffixIcon: IconButton(
                                onPressed: _busy
                                    ? null
                                    : () =>
                                          setState(() => _obscure = !_obscure),
                                tooltip: _obscure
                                    ? 'Mostrar senha'
                                    : 'Ocultar senha',
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                ),
                              ),
                            ),
                            validator: (value) {
                              final length = value?.length ?? 0;
                              return length < 8 || length > 128
                                  ? 'Use de 8 a 128 caracteres.'
                                  : null;
                            },
                          ),
                          if (message != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              message,
                              style: TextStyle(color: theme.colorScheme.error),
                            ),
                          ],
                          const SizedBox(height: 18),
                          FilledButton(
                            onPressed: _busy ? null : _submit,
                            child: Text(
                              _busy
                                  ? 'Aguarde…'
                                  : _signup
                                  ? 'Cadastrar e entrar'
                                  : 'Entrar',
                            ),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => setState(() {
                                    _signup = !_signup;
                                    _error = null;
                                  }),
                            child: Text(
                              _signup ? 'Já tenho conta' : 'Criar conta',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
