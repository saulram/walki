import 'dart:async';
import 'dart:io';
import 'package:mcp_server/mcp_server.dart';
import 'package:walki/src/mcp/walki_tools.dart';

void main(List<String> args) async {
  final useHttp = args.contains('--http');
  final portIndex = args.indexOf('--port');
  final port = portIndex != -1 && portIndex + 1 < args.length
      ? int.tryParse(args[portIndex + 1]) ?? 8080
      : 8080;

  final server = McpServer.createServer(
    McpServerConfig(
      name: 'walki',
      version: '0.1.1',
      capabilities: ServerCapabilities.simple(tools: true),
    ),
  );

  registerWalkiTools(server);

  if (useHttp) {
    final transportResult = await McpServer.createStreamableHttpTransportAsync(port);
    if (transportResult is Success<StreamableHttpServerTransport, Exception>) {
      server.connect(transportResult.value);
      stdout.writeln('Walki MCP server running on HTTP port $port');
      await _waitForShutdown();
    } else {
      stderr.writeln('Failed to create HTTP transport');
      exit(1);
    }
  } else {
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
}

Future<void> _waitForShutdown() async {
  final completer = Completer<void>();
  ProcessSignal.sigint.watch().listen((_) {
    completer.complete();
  });
  await completer.future;
}