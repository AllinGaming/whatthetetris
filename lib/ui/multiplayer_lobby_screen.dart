import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../game/coop_game_screen.dart';
import '../models/coop_variant.dart';
import '../services/audio_service.dart';
import '../services/high_score_service.dart';
import '../services/live_services.dart';
import '../services/multiplayer_session_service.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import 'account_screen.dart';
import 'widgets/menu_backdrop.dart';
import 'widgets/share_dialog.dart';

class MultiplayerLobbyScreen extends StatefulWidget {
  const MultiplayerLobbyScreen({
    super.key,
    this.variant = CoopVariant.fixed,
    required this.live,
    required this.theme,
    required this.audio,
    required this.settings,
    required this.highScores,
  });

  final CoopVariant variant;
  final LiveServices live;
  final ThemeService theme;
  final AudioService audio;
  final SettingsService settings;
  final HighScoreService highScores;

  @override
  State<MultiplayerLobbyScreen> createState() => _MultiplayerLobbyScreenState();
}

class _MultiplayerLobbyScreenState extends State<MultiplayerLobbyScreen> {
  late final MultiplayerSessionService _session;
  final _codeController = TextEditingController();
  bool _openingGame = false;
  bool _connectionResultLogged = false;
  DateTime? _connectionAttemptStartedAt;
  MultiplayerConnectionStatus _lastStatus = MultiplayerConnectionStatus.idle;

  CoopVariant get _activeVariant =>
      _session.roomCode == null ? widget.variant : _session.variant;

  bool get _busy => switch (_session.status) {
    MultiplayerConnectionStatus.creatingRoom ||
    MultiplayerConnectionStatus.joiningRoom ||
    MultiplayerConnectionStatus.connecting => true,
    _ => false,
  };

  int get _connectionWaitMs {
    final startedAt = _connectionAttemptStartedAt;
    if (startedAt == null) return 0;
    return DateTime.now().difference(startedAt).inMilliseconds;
  }

  @override
  void initState() {
    super.initState();
    unawaited(widget.audio.playMusic(MusicTrack.menu));
    _session = MultiplayerSessionService(widget.live.auth)
      ..addListener(_onSessionChanged);
    unawaited(widget.live.analytics.screenViewed('multiplayer_lobby'));
    unawaited(
      widget.live.analytics.multiplayerLobbyViewed(
        available: _session.available,
        variant: widget.variant.analyticsName,
      ),
    );
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    _codeController.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (!mounted) return;
    final status = _session.status;
    if (status != _lastStatus) {
      _lastStatus = status;
      if (status == MultiplayerConnectionStatus.connected &&
          !_connectionResultLogged) {
        _connectionResultLogged = true;
        unawaited(
          widget.live.analytics.multiplayerConnection(
            result: 'success',
            role: _session.player?.name ?? 'unknown',
            waitMs: _connectionWaitMs,
            variant: _session.variant.analyticsName,
          ),
        );
      } else if (status == MultiplayerConnectionStatus.failed &&
          !_connectionResultLogged) {
        _connectionResultLogged = true;
        unawaited(
          widget.live.analytics.multiplayerConnection(
            result: 'failed',
            role: _session.player?.name ?? 'unknown',
            waitMs: _connectionWaitMs,
            variant: _activeVariant.analyticsName,
          ),
        );
      }
    }
    setState(() {});
    if (_session.connected && !_openingGame) {
      _openingGame = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted || !_session.connected) {
          _openingGame = false;
          return;
        }
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => CoopGameScreen(
              session: _session,
              theme: widget.theme,
              analytics: widget.live.analytics,
              audio: widget.audio,
              settings: widget.settings,
              highScores: widget.highScores,
              leaderboard: widget.live.leaderboard,
            ),
          ),
        );
        if (mounted) {
          setState(() => _openingGame = false);
        }
      });
    }
  }

  Future<void> _createRoom() async {
    unawaited(widget.audio.play(Sfx.menuTap));
    FocusScope.of(context).unfocus();
    _connectionAttemptStartedAt = DateTime.now();
    _connectionResultLogged = false;
    unawaited(
      widget.live.analytics.multiplayerLobbyAction(
        action: 'create_room',
        result: 'attempted',
        variant: widget.variant.analyticsName,
      ),
    );
    try {
      await _session.createRoom(variant: widget.variant);
      unawaited(
        widget.live.analytics.multiplayerLobbyAction(
          action: 'create_room',
          result: 'created',
          variant: _session.variant.analyticsName,
        ),
      );
    } catch (_) {
      unawaited(
        widget.live.analytics.multiplayerLobbyAction(
          action: 'create_room',
          result: 'failed',
          variant: widget.variant.analyticsName,
        ),
      );
    }
  }

  Future<void> _joinRoom() async {
    unawaited(widget.audio.play(Sfx.menuTap));
    FocusScope.of(context).unfocus();
    _connectionAttemptStartedAt = DateTime.now();
    _connectionResultLogged = false;
    unawaited(
      widget.live.analytics.multiplayerLobbyAction(
        action: 'join_room',
        result: 'attempted',
        variant: widget.variant.analyticsName,
      ),
    );
    try {
      await _session.joinRoom(_codeController.text);
      unawaited(
        widget.live.analytics.multiplayerLobbyAction(
          action: 'join_room',
          result: 'claimed',
          variant: _session.variant.analyticsName,
        ),
      );
    } catch (_) {
      unawaited(
        widget.live.analytics.multiplayerLobbyAction(
          action: 'join_room',
          result: 'failed',
          variant: _activeVariant.analyticsName,
        ),
      );
    }
  }

  Future<void> _copyCode() async {
    final code = _session.roomCode;
    if (code == null) return;
    unawaited(widget.audio.play(Sfx.menuTap));
    await Clipboard.setData(ClipboardData(text: code));
    unawaited(
      widget.live.analytics.multiplayerLobbyAction(
        action: 'share_code',
        result: 'copied',
        variant: _session.variant.analyticsName,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Room code copied.')));
  }

  Future<void> _shareCode() async {
    final code = _session.roomCode;
    if (code == null) return;
    unawaited(widget.audio.play(Sfx.menuTap));
    final message =
        'Join my What The Triangle ${_session.variant.title} room: $code';
    final result = await showTriangleShareDialog(
      context,
      title: 'Share room $code',
      message: message,
      copyLabel: 'Copy invite',
      copyText: '$message\n$triangleGameUrl',
    );
    if (result != null) {
      unawaited(
        widget.live.analytics.multiplayerLobbyAction(
          action: 'share_code',
          result: result.name,
          variant: _session.variant.analyticsName,
        ),
      );
    }
  }

  Future<void> _openAccount() async {
    unawaited(widget.audio.play(Sfx.menuTap));
    unawaited(widget.live.analytics.featureSelected('account_suggestion'));
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => AccountScreen(live: widget.live)));
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(_activeVariant.title)),
      body: Stack(
        children: [
          MenuBackdrop(theme: widget.theme.current, reduceMotion: true),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _LobbyHero(accent: accent),
                      const SizedBox(height: 20),
                      Text(
                        'Build one board together',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        switch (_activeVariant) {
                          CoopVariant.fixed =>
                            'The host is red, the guest is blue. Both players get their own pieces on the same board, and neither player can mirror them. Each starts with one cavity fill.',
                          CoopVariant.mirror =>
                            'The host is red and the guest is blue. Both players can mirror their own falling pieces while keeping their color. Each starts with one cavity fill.',
                          CoopVariant.puzzle =>
                            'Work together on a shared 2–7-row formation. Mirror your own pieces and reduce the stack to one occupied row to win. Each player starts with two fills.',
                        },
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                      if (widget.live.auth.available &&
                          widget.live.auth.isAnonymous) ...[
                        const SizedBox(height: 16),
                        _LoginCard(onOpen: _openAccount),
                      ],
                      const SizedBox(height: 24),
                      if (!_session.available)
                        const _UnavailableCard()
                      else if (_session.status ==
                              MultiplayerConnectionStatus.waitingForPeer ||
                          (_session.roomCode != null &&
                              _session.status ==
                                  MultiplayerConnectionStatus.connecting))
                        _WaitingCard(
                          code: _session.roomCode!,
                          connecting:
                              _session.status ==
                              MultiplayerConnectionStatus.connecting,
                          onCopy: _copyCode,
                          onShare: _shareCode,
                        )
                      else
                        _RoomActions(
                          controller: _codeController,
                          busy: _busy,
                          onCreate: _createRoom,
                          onJoin: _joinRoom,
                        ),
                      if (_session.error != null) ...[
                        const SizedBox(height: 14),
                        Text(
                          _session.error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) => _LobbyCard(
    child: Row(
      children: [
        const Icon(Icons.shield_outlined, color: Colors.cyanAccent, size: 28),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Log in', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text(
                'Optional: use email and password for a reusable leaderboard '
                'identity.',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: onOpen, child: const Text('Log in')),
      ],
    ),
  );
}

class _LobbyHero extends StatelessWidget {
  const _LobbyHero({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 150,
    height: 76,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 18,
          child: Icon(
            Icons.change_history,
            size: 70,
            color: Colors.redAccent,
            shadows: [Shadow(color: Colors.redAccent, blurRadius: 18)],
          ),
        ),
        Positioned(
          right: 18,
          child: Transform.rotate(
            angle: 3.141592653589793,
            child: Icon(
              Icons.change_history,
              size: 70,
              color: Colors.lightBlueAccent,
              shadows: [Shadow(color: Colors.lightBlueAccent, blurRadius: 18)],
            ),
          ),
        ),
        Icon(Icons.link, color: accent, size: 30),
      ],
    ),
  );
}

class _UnavailableCard extends StatelessWidget {
  const _UnavailableCard();

  @override
  Widget build(BuildContext context) => _LobbyCard(
    child: Column(
      children: [
        const Icon(Icons.cloud_off_outlined, size: 34),
        const SizedBox(height: 12),
        Text(
          'Online rooms are not configured yet',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text(
          'Connect this build to Firebase to create and join shared room-code '
          'lobbies. Classic and Daily still work offline.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white60),
        ),
      ],
    ),
  );
}

class _WaitingCard extends StatelessWidget {
  const _WaitingCard({
    required this.code,
    required this.connecting,
    required this.onCopy,
    required this.onShare,
  });

  final String code;
  final bool connecting;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) => _LobbyCard(
    child: Column(
      children: [
        Text(
          connecting ? 'Connecting players...' : 'Share this room code',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        SelectableText(
          code,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 8,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy),
              label: const Text('Copy code'),
            ),
            FilledButton.icon(
              onPressed: onShare,
              icon: const Icon(Icons.share),
              label: const Text('Share outside game'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const CircularProgressIndicator(),
        const SizedBox(height: 10),
        Text(
          connecting
              ? 'Establishing the direct connection'
              : 'Waiting for blue',
          style: const TextStyle(color: Colors.white60),
        ),
      ],
    ),
  );
}

class _RoomActions extends StatelessWidget {
  const _RoomActions({
    required this.controller,
    required this.busy,
    required this.onCreate,
    required this.onJoin,
  });

  final TextEditingController controller;
  final bool busy;
  final VoidCallback onCreate;
  final VoidCallback onJoin;

  @override
  Widget build(BuildContext context) => _LobbyCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.icon(
          onPressed: busy ? null : onCreate,
          icon: const Icon(Icons.add_link),
          label: const Text('Create room'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 16),
          child: Row(
            children: [
              Expanded(child: Divider()),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR', style: TextStyle(color: Colors.white54)),
              ),
              Expanded(child: Divider()),
            ],
          ),
        ),
        TextField(
          controller: controller,
          enabled: !busy,
          autocorrect: false,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.done,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp('[A-HJ-NP-Z2-9]')),
            _UpperCaseFormatter(),
          ],
          decoration: const InputDecoration(
            labelText: 'Room code',
            hintText: 'ABC234',
            prefixIcon: Icon(Icons.meeting_room_outlined),
          ),
          onSubmitted: (_) => onJoin(),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : onJoin,
          icon: busy
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.login),
          label: const Text('Join room'),
        ),
      ],
    ),
  );
}

class _LobbyCard extends StatelessWidget {
  const _LobbyCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.32),
      border: Border.all(color: Colors.white24),
      borderRadius: BorderRadius.circular(18),
    ),
    child: child,
  );
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) => newValue.copyWith(
    text: newValue.text.toUpperCase(),
    selection: newValue.selection,
    composing: TextRange.empty,
  );
}
