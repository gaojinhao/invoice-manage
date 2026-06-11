import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/email_service.dart';

/// 邮箱配置页
class EmailConfigScreen extends StatefulWidget {
  const EmailConfigScreen({super.key});

  @override
  State<EmailConfigScreen> createState() => _EmailConfigScreenState();
}

class _EmailConfigScreenState extends State<EmailConfigScreen> {
  final _storage = const FlutterSecureStorage();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _sendToCtrl = TextEditingController();
  final EmailService _emailService = EmailService();
  bool _loading = true;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _sendToCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    final email = await _storage.read(key: 'email_addr') ?? '';
    final password = await _storage.read(key: 'email_pass') ?? '';
    final sendTo = await _storage.read(key: 'send_to') ?? '';

    _emailCtrl.text = email;
    _passwordCtrl.text = password;
    _sendToCtrl.text = sendTo;

    if (email.isNotEmpty && password.isNotEmpty) {
      _emailService.configure(
        EmailConfig(
          email: email,
          password: password,
          imapServer: _emailService.getImapServer(email),
          sendTo: sendTo.isNotEmpty ? sendTo : null,
        ),
      );
    }

    setState(() => _loading = false);
  }

  Future<void> _saveConfig() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请填写邮箱和授权码')));
      return;
    }

    final email = _emailCtrl.text.trim();
    final sendTo = _sendToCtrl.text.trim();

    await _storage.write(key: 'email_addr', value: email);
    await _storage.write(key: 'email_pass', value: _passwordCtrl.text);
    await _storage.write(key: 'send_to', value: sendTo);

    _emailService.configure(
      EmailConfig(
        email: email,
        password: _passwordCtrl.text,
        imapServer: _emailService.getImapServer(email),
        sendTo: sendTo.isNotEmpty ? sendTo : null,
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('配置已保存 ✓')));
    }
  }

  Future<void> _testConnection() async {
    if (_emailCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请先填写邮箱和授权码')));
      return;
    }

    setState(() => _testing = true);

    try {
      final email = _emailCtrl.text.trim();
      final result = await _emailService.verifyConnectionDetailed(
        email,
        _passwordCtrl.text,
        _emailService.getImapServer(email),
        _emailService.getImapPort(email),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.isSuccess ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('连接异常: $e'), backgroundColor: Colors.red),
        );
      }
    }

    if (mounted) {
      setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('邮箱配置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 说明卡片
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        '配置说明',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'App 通过 IMAP 协议直接从手机连接您的邮箱。\n'
                    '请使用邮箱授权码而非登录密码（QQ邮箱/163邮箱需开启 IMAP 服务获取授权码）。',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _emailCtrl,
            decoration: const InputDecoration(
              labelText: '邮箱地址',
              hintText: 'yourname@qq.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _passwordCtrl,
            decoration: const InputDecoration(
              labelText: '授权码',
              hintText: 'QQ邮箱/163邮箱的授权码',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.lock),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 12),

          TextField(
            controller: _sendToCtrl,
            decoration: const InputDecoration(
              labelText: '月报发送目标邮箱（可选）',
              hintText: 'monthly_reports@example.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.send),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 8),
          Text(
            '如果不填，默认发送到配置的邮箱地址',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _testConnection,
                  icon:
                      _testing
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.wifi_find),
                  label: const Text('测试连接'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _saveConfig,
                  icon: const Icon(Icons.save),
                  label: const Text('保存配置'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
