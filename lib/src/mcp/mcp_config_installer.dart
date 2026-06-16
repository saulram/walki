import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

/// Supported project-level MCP config target.
class McpAgentTarget {
  /// Creates an MCP agent target.
  const McpAgentTarget({
    required this.agent,
    required this.path,
    required this.format,
  });

  /// Agent identifier.
  final String agent;

  /// Project-relative config path.
  final String path;

  /// Config format used by the target file.
  final McpConfigFormat format;
}

/// MCP config file format.
enum McpConfigFormat {
  /// JSON config with `mcpServers`.
  json,

  /// TOML config with `[mcp_servers.walki]`.
  toml,
}

/// Result of installing Walki MCP config.
class McpInstallResult {
  /// Creates an install result.
  const McpInstallResult({
    required this.agent,
    required this.path,
    required this.created,
    required this.updated,
  });

  /// Target agent.
  final String agent;

  /// Config file path written.
  final String path;

  /// Whether the config file was created.
  final bool created;

  /// Whether an existing config was updated.
  final bool updated;
}

/// Installs project-level config for the Walki MCP server.
class McpConfigInstaller {
  /// Creates an installer.
  const McpConfigInstaller();

  /// Supported targets keyed by Walki agent ID.
  static const targets = <String, McpAgentTarget>{
    'claude': McpAgentTarget(
      agent: 'claude',
      path: '.mcp.json',
      format: McpConfigFormat.json,
    ),
    'opencode': McpAgentTarget(
      agent: 'opencode',
      path: 'opencode.json',
      format: McpConfigFormat.json,
    ),
    'gemini': McpAgentTarget(
      agent: 'gemini',
      path: '.gemini/settings.json',
      format: McpConfigFormat.json,
    ),
    'codex': McpAgentTarget(
      agent: 'codex',
      path: '.codex/config.toml',
      format: McpConfigFormat.toml,
    ),
  };

  /// Returns the supported target for [agent], if any.
  McpAgentTarget? targetFor(String agent) => targets[agent];

  /// Installs the Walki MCP server config for [agent].
  McpInstallResult install({
    required String agent,
    String projectDir = '.',
    String command = 'walki-mcp',
    bool force = false,
  }) {
    final target = targetFor(agent);
    if (target == null) {
      throw ArgumentError.value(
        agent,
        'agent',
        'Unsupported MCP target. Supported: ${targets.keys.join(', ')}',
      );
    }

    final file = File(p.join(projectDir, target.path));
    final created = !file.existsSync();
    file.parent.createSync(recursive: true);

    switch (target.format) {
      case McpConfigFormat.json:
        _installJson(file, command: command, force: force);
      case McpConfigFormat.toml:
        _installToml(file, command: command, force: force);
    }

    return McpInstallResult(
      agent: agent,
      path: file.path,
      created: created,
      updated: !created,
    );
  }

  void _installJson(
    File file, {
    required String command,
    required bool force,
  }) {
    final root = <String, dynamic>{};
    final existingContent = file.existsSync() ? file.readAsStringSync() : '';
    if (existingContent.trim().isNotEmpty) {
      final decoded = jsonDecode(existingContent);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected root JSON object.');
      }
      root.addAll(decoded);
    }

    final existingServers = root['mcpServers'];
    final servers = existingServers is Map<String, dynamic>
        ? Map<String, dynamic>.from(existingServers)
        : <String, dynamic>{};
    if (servers.containsKey('walki') && !force) {
      throw StateError(
        'MCP server "walki" already exists in ${file.path}. Use --force to replace it.',
      );
    }
    servers['walki'] = {
      'command': command,
      'args': <String>[],
    };
    root['mcpServers'] = servers;
    file.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(root)}\n');
  }

  void _installToml(
    File file, {
    required String command,
    required bool force,
  }) {
    var content = file.existsSync() ? file.readAsStringSync() : '';
    final blockPattern = RegExp(
      r'^\[mcp_servers\.walki\]\s*.*?(?=^\[|(?![\s\S]))',
      multiLine: true,
      dotAll: true,
    );
    final escapedCommand = _tomlBasicString(command);
    final block = '''[mcp_servers.walki]
command = "$escapedCommand"
args = []
''';

    if (blockPattern.hasMatch(content)) {
      if (!force) {
        throw StateError(
          'MCP server "walki" already exists in ${file.path}. Use --force to replace it.',
        );
      }
      content = content.replaceFirst(blockPattern, block);
    } else {
      if (content.isNotEmpty && !content.endsWith('\n')) {
        content += '\n';
      }
      if (content.isNotEmpty && !content.endsWith('\n\n')) {
        content += '\n';
      }
      content += block;
    }
    file.writeAsStringSync(content);
  }

  String _tomlBasicString(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('"', r'\"')
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r')
        .replaceAll('\t', r'\t');
  }
}
