import 'dart:io';
import 'package:mcp_server/mcp_server.dart';
import 'package:walki/src/mcp/walki_tools.dart';

void main(List<String> args) async {
  if (args.contains('--http') ||
      args.contains('--port') ||
      args.contains('--host') ||
      args.contains('--allow-remote-http') ||
      args.contains('--auth-token')) {
    stderr.writeln(
      'HTTP transport has been removed for security. '
      'Run walki-mcp without HTTP flags (STDIO only).',
    );
    exit(64);
  }

  final server = McpServer.createServer(
    McpServerConfig(
      name: 'walki',
      version: '0.4.2',
      capabilities: ServerCapabilities.simple(tools: true),
    ),
  );

  registerWalkiTools(server);

  final transportResult = McpServer.createStdioTransport();
  if (transportResult is Success<StdioServerTransport, Exception>) {
    server.connect(transportResult.value);
    // STDIO transport reads from stdin, blocks until closed
    await transportResult.value.onClose;
  } else {
    stderr.writeln('Failed to create stdio transport');
    exit(1);
  }
}
