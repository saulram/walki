import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';
import 'package:walki/src/mcp/mcp_config_installer.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('walki_mcp_test_');
  });

  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('install creates Claude project MCP JSON config', () {
    final result = const McpConfigInstaller().install(
      agent: 'claude',
      projectDir: tempDir.path,
    );

    expect(result.created, isTrue);
    expect(result.path, endsWith('.mcp.json'));

    final json = jsonDecode(File(result.path).readAsStringSync())
        as Map<String, dynamic>;
    final servers = json['mcpServers'] as Map<String, dynamic>;
    final walki = servers['walki'] as Map<String, dynamic>;
    expect(walki['command'], equals('walki-mcp'));
    expect(walki['args'], equals(<dynamic>[]));
  });

  test('install preserves existing JSON servers', () {
    final file = File(p.join(tempDir.path, 'opencode.json'));
    file.writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert({
        'mcpServers': {
          'other': {
            'command': 'other-mcp',
            'args': <String>[],
          },
        },
      }),
    );

    const McpConfigInstaller().install(
      agent: 'opencode',
      projectDir: tempDir.path,
    );

    final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final servers = json['mcpServers'] as Map<String, dynamic>;
    expect(servers, contains('other'));
    expect(servers, contains('walki'));
  });

  test('install refuses to overwrite existing server without force', () {
    const installer = McpConfigInstaller();
    installer.install(agent: 'claude', projectDir: tempDir.path);

    expect(
      () => installer.install(agent: 'claude', projectDir: tempDir.path),
      throwsStateError,
    );
  });

  test('install replaces existing server with force', () {
    const installer = McpConfigInstaller();
    installer.install(agent: 'claude', projectDir: tempDir.path);
    installer.install(
      agent: 'claude',
      projectDir: tempDir.path,
      command: 'custom-walki-mcp',
      force: true,
    );

    final json =
        jsonDecode(File(p.join(tempDir.path, '.mcp.json')).readAsStringSync())
            as Map<String, dynamic>;
    final servers = json['mcpServers'] as Map<String, dynamic>;
    final walki = servers['walki'] as Map<String, dynamic>;
    expect(walki['command'], equals('custom-walki-mcp'));
  });

  test('install creates Codex TOML config', () {
    final result = const McpConfigInstaller().install(
      agent: 'codex',
      projectDir: tempDir.path,
    );

    expect(result.path, endsWith(p.join('.codex', 'config.toml')));
    final content = File(result.path).readAsStringSync();
    expect(content, contains('[mcp_servers.walki]'));
    expect(content, contains('command = "walki-mcp"'));
  });
}
