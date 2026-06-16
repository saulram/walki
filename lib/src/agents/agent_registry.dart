import 'dart:io';

import '../config/agent_config.dart';

/// Known AI agent CLIs that Walki can configure during init.
class AgentDefinition {
  /// Creates an agent definition entry.
  const AgentDefinition({
    required this.id,
    required this.binaryNames,
    required this.defaultConfig,
  });

  /// Stable Walki agent identifier.
  final String id;

  /// Executable names that can identify this agent on PATH.
  final List<String> binaryNames;

  /// Default role, description, and permissions for this agent.
  final AgentConfig defaultConfig;
}

/// Result of checking whether an agent CLI exists on PATH.
class DetectedAgent {
  /// Creates an installed agent result.
  const DetectedAgent({
    required this.definition,
    required this.command,
    required this.path,
  });

  /// Definition matched by the detected executable.
  final AgentDefinition definition;

  /// Executable name that was found.
  final String command;

  /// Absolute executable path reported by `which`.
  final String path;
}

/// Built-in agent CLIs that the init wizard can auto-detect.
const supportedAgentDefinitions = <AgentDefinition>[
  AgentDefinition(
    id: 'claude',
    binaryNames: ['claude'],
    defaultConfig: AgentConfig(
      role: 'reviewer',
      description:
          'Claude Code reviewer focused on architecture and correctness.',
      can: [
        'read',
        'append',
        'challenge_decision',
        'propose_decision',
        'propose_task',
      ],
    ),
  ),
  AgentDefinition(
    id: 'codex',
    binaryNames: ['codex'],
    defaultConfig: AgentConfig(
      role: 'implementer',
      description: 'Codex implementer focused on code changes and tests.',
      can: ['read', 'append', 'propose_decision', 'propose_task'],
    ),
  ),
  AgentDefinition(
    id: 'gemini',
    binaryNames: ['gemini'],
    defaultConfig: AgentConfig(
      role: 'reviewer',
      description: 'Gemini reviewer focused on planning and second opinions.',
      can: [
        'read',
        'append',
        'challenge_decision',
        'propose_decision',
        'propose_task',
      ],
    ),
  ),
  AgentDefinition(
    id: 'opencode',
    binaryNames: ['opencode'],
    defaultConfig: AgentConfig(
      role: 'implementer',
      description: 'opencode implementer focused on repository-aware changes.',
      can: ['read', 'append', 'propose_decision', 'propose_task'],
    ),
  ),
];

/// Detects supported agent CLIs available on PATH.
class AgentRegistry {
  /// Creates an agent registry.
  const AgentRegistry();

  /// Returns supported agents whose executable is available on PATH.
  List<DetectedAgent> detectInstalled() {
    final detected = <DetectedAgent>[];
    for (final definition in supportedAgentDefinitions) {
      for (final command in definition.binaryNames) {
        final path = _which(command);
        if (path != null) {
          detected.add(
            DetectedAgent(
              definition: definition,
              command: command,
              path: path,
            ),
          );
          break;
        }
      }
    }
    return detected;
  }

  /// Finds a supported agent definition by ID.
  AgentDefinition? definitionFor(String id) {
    for (final definition in supportedAgentDefinitions) {
      if (definition.id == id) {
        return definition;
      }
    }
    return null;
  }

  String? _which(String command) {
    final result = Process.runSync('which', [command]);
    if (result.exitCode != 0) {
      return null;
    }
    final output = result.stdout.toString().trim();
    return output.isEmpty ? null : output;
  }
}
