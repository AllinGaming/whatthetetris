import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../firebase_options.dart';
import '../game/coop_game_engine.dart';
import 'cloud_auth_service.dart';

enum MultiplayerConnectionStatus {
  idle,
  creatingRoom,
  waitingForPeer,
  joiningRoom,
  connecting,
  connected,
  disconnected,
  failed,
}

/// Firestore carries only the room-code lookup and one gathered SDP
/// offer/answer per player. ICE candidates are bundled into those descriptions
/// instead of being written as individual documents. Once connected, all game
/// inputs and snapshots travel over an ordered WebRTC data channel directly
/// between the two devices.
class MultiplayerSessionService extends ChangeNotifier {
  MultiplayerSessionService(this._auth, {FirebaseFirestore? firestore})
    : _firestore = firestore;

  static const _alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  static const _roomLifetime = Duration(hours: 2);
  static final _validCode = RegExp(r'^[A-HJ-NP-Z2-9]{6}$');

  final CloudAuthService _auth;
  final FirebaseFirestore? _firestore;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  RTCPeerConnection? _peerConnection;
  RTCDataChannel? _dataChannel;
  DocumentReference<Map<String, dynamic>>? _room;
  bool _remoteDescriptionSet = false;
  bool _settingRemoteDescription = false;
  bool _signalingComplete = false;
  bool _disposed = false;
  MultiplayerConnectionStatus _status = MultiplayerConnectionStatus.idle;
  CoopPlayer? _player;
  String? _roomCode;
  String? _error;

  bool get available => isFirebaseMultiplayerConfigured && _auth.available;
  MultiplayerConnectionStatus get status => _status;
  CoopPlayer? get player => _player;
  String? get roomCode => _roomCode;
  String? get error => _error;
  bool get connected => _status == MultiplayerConnectionStatus.connected;
  Stream<Map<String, dynamic>> get messages => _messages.stream;

  FirebaseFirestore get _db => _firestore ?? FirebaseFirestore.instance;

  static String generateRoomCode([Random? random]) {
    final rng = random ?? Random.secure();
    return List.generate(
      6,
      (_) => _alphabet[rng.nextInt(_alphabet.length)],
    ).join();
  }

  static bool isValidRoomCode(String code) =>
      _validCode.hasMatch(code.trim().toUpperCase());

  Future<String> createRoom() async {
    _requireAvailable();
    await close();
    _setStatus(MultiplayerConnectionStatus.creatingRoom);
    _player = CoopPlayer.red;
    try {
      final uid = _auth.uid!;
      DocumentReference<Map<String, dynamic>>? room;
      for (int attempt = 0; attempt < 8 && room == null; attempt++) {
        final code = generateRoomCode();
        final candidate = _db.collection('multiplayerRooms').doc(code);
        final created = await _db.runTransaction<bool>((transaction) async {
          final snapshot = await transaction.get(candidate);
          if (snapshot.exists) return false;
          transaction.set(candidate, {
            'hostUid': uid,
            'status': 'waiting',
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
            'expiresAt': Timestamp.fromDate(DateTime.now().add(_roomLifetime)),
          });
          return true;
        });
        if (created) room = candidate;
      }
      if (room == null) {
        throw StateError('Could not reserve a unique room code.');
      }
      _room = room;
      _roomCode = room.id;
      await _createPeerConnection();
      final channel = await _peerConnection!.createDataChannel(
        'whatthetriangle-coop',
        RTCDataChannelInit()..ordered = true,
      );
      _attachDataChannel(channel);

      final offer = await _peerConnection!.createOffer({});
      await _peerConnection!.setLocalDescription(offer);
      final gatheredOffer = await _gatheredLocalDescription(offer);
      await room.update({
        'offer': {'sdp': gatheredOffer.sdp, 'type': gatheredOffer.type},
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _listenToRoomAsHost(room);
      _setStatus(MultiplayerConnectionStatus.waitingForPeer);
      return room.id;
    } catch (error) {
      _fail(error);
      rethrow;
    }
  }

  Future<void> joinRoom(String rawCode) async {
    _requireAvailable();
    final code = rawCode.trim().toUpperCase();
    if (!isValidRoomCode(code)) {
      throw const FormatException('Enter a valid 6-character room code.');
    }
    await close();
    _setStatus(MultiplayerConnectionStatus.joiningRoom);
    _player = CoopPlayer.blue;
    _roomCode = code;
    try {
      final room = _db.collection('multiplayerRooms').doc(code);
      final uid = _auth.uid!;
      final roomData = await _db.runTransaction<Map<String, dynamic>>((
        transaction,
      ) async {
        final snapshot = await transaction.get(room);
        if (!snapshot.exists) throw StateError('Room not found.');
        final data = snapshot.data()!;
        final expiresAt = data['expiresAt'] as Timestamp?;
        if (expiresAt != null && expiresAt.toDate().isBefore(DateTime.now())) {
          throw StateError('That room has expired.');
        }
        if (data['status'] != 'waiting' || data['guestUid'] != null) {
          throw StateError('That room is already full or closed.');
        }
        if (data['offer'] is! Map) {
          throw StateError('The host is not ready yet.');
        }
        transaction.update(room, {
          'guestUid': uid,
          'status': 'connecting',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return Map<String, dynamic>.from(data);
      });

      _room = room;
      await _createPeerConnection();
      _peerConnection!.onDataChannel = _attachDataChannel;
      final offer = Map<String, dynamic>.from(
        roomData['offer'] as Map<dynamic, dynamic>,
      );
      await _setRemoteDescription(
        RTCSessionDescription(offer['sdp'] as String, offer['type'] as String),
      );
      _listenToRoomForClosure(room);

      final answer = await _peerConnection!.createAnswer({});
      await _peerConnection!.setLocalDescription(answer);
      final gatheredAnswer = await _gatheredLocalDescription(answer);
      await room.update({
        'answer': {'sdp': gatheredAnswer.sdp, 'type': gatheredAnswer.type},
        'status': 'connecting',
        'updatedAt': FieldValue.serverTimestamp(),
      });
      _setStatus(MultiplayerConnectionStatus.connecting);
    } catch (error) {
      _fail(error);
      rethrow;
    }
  }

  Future<void> _createPeerConnection() async {
    _peerConnection = await createPeerConnection({
      'iceServers': [
        {'urls': 'stun:stun.l.google.com:19302'},
        {'urls': 'stun:stun1.l.google.com:19302'},
        {'urls': 'stun:stun2.l.google.com:19302'},
        {'urls': 'stun:stun.ekiga.net'},
        {'urls': 'stun:stun.voiparound.com'},
        {'urls': 'stun:stun.voipbuster.com'},
        {'urls': 'stun:stun.voipstunt.com'},
        {'urls': 'stun:stun.voxgratia.org'},
        {
          'urls': 'turn:turn.anyfirewall.com:443?transport=tcp',
          'username': 'webrtc',
          'credential': 'webrtc',
        },
        {
          'urls': 'turn:turn.bistri.com:80',
          'username': 'homeo',
          'credential': 'homeo',
        },
        {
          'urls': 'turn:numb.viagenie.ca:3478?transport=udp',
          'username': 'webrtc@live.com',
          'credential': 'muazkh',
        },
      ],
      'sdpSemantics': 'unified-plan',
    });
    _peerConnection!.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        _setStatus(MultiplayerConnectionStatus.disconnected);
      }
    };
  }

  /// Waits briefly for ICE gathering so candidates are embedded in the SDP.
  /// This turns an unbounded number of candidate-document writes into the one
  /// offer or answer update the lobby already needs. On a slow network the
  /// latest partial description is used after the timeout.
  Future<RTCSessionDescription> _gatheredLocalDescription(
    RTCSessionDescription fallback,
  ) async {
    final peer = _peerConnection!;
    if (await peer.getIceGatheringState() !=
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      final gathered = Completer<void>();
      peer.onIceGatheringState = (state) {
        if (state == RTCIceGatheringState.RTCIceGatheringStateComplete &&
            !gathered.isCompleted) {
          gathered.complete();
        }
      };
      if (await peer.getIceGatheringState() ==
              RTCIceGatheringState.RTCIceGatheringStateComplete &&
          !gathered.isCompleted) {
        gathered.complete();
      }
      await gathered.future.timeout(
        const Duration(seconds: 8),
        onTimeout: () {},
      );
      peer.onIceGatheringState = null;
    }
    return await peer.getLocalDescription() ?? fallback;
  }

  void _listenToRoomAsHost(DocumentReference<Map<String, dynamic>> room) {
    _subscriptions.add(
      room.snapshots().listen((snapshot) async {
        final data = snapshot.data();
        if (data == null ||
            _remoteDescriptionSet ||
            _settingRemoteDescription) {
          return;
        }
        final rawAnswer = data['answer'];
        if (rawAnswer is! Map) return;
        _settingRemoteDescription = true;
        try {
          final answer = Map<String, dynamic>.from(rawAnswer);
          await _setRemoteDescription(
            RTCSessionDescription(
              answer['sdp'] as String,
              answer['type'] as String,
            ),
          );
          _setStatus(MultiplayerConnectionStatus.connecting);
        } finally {
          _settingRemoteDescription = false;
        }
      }),
    );
  }

  void _listenToRoomForClosure(DocumentReference<Map<String, dynamic>> room) {
    _subscriptions.add(
      room.snapshots().listen((snapshot) {
        final roomStatus = snapshot.data()?['status'];
        if (roomStatus == 'closed' && !connected) {
          _setStatus(MultiplayerConnectionStatus.disconnected);
        }
      }),
    );
  }

  Future<void> _setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
    _remoteDescriptionSet = true;
  }

  void _attachDataChannel(RTCDataChannel channel) {
    _dataChannel = channel;
    channel.onDataChannelState = (state) {
      if (state == RTCDataChannelState.RTCDataChannelOpen) {
        _signalingComplete = true;
        _setStatus(MultiplayerConnectionStatus.connected);
        unawaited(_cancelSignalingSubscriptions());
      } else if (state == RTCDataChannelState.RTCDataChannelClosed) {
        _setStatus(MultiplayerConnectionStatus.disconnected);
      }
    };
    channel.onMessage = (message) {
      if (_disposed || message.isBinary) return;
      try {
        final decoded = jsonDecode(message.text);
        if (decoded is Map) {
          _messages.add(Map<String, dynamic>.from(decoded));
        }
      } catch (_) {
        // Ignore malformed peer traffic rather than taking down the session.
      }
    };
  }

  Future<void> send(Map<String, dynamic> message) async {
    final channel = _dataChannel;
    if (channel == null ||
        channel.state != RTCDataChannelState.RTCDataChannelOpen) {
      throw StateError('The other player is not connected.');
    }
    await channel.send(RTCDataChannelMessage(jsonEncode(message)));
  }

  void _requireAvailable() {
    if (!available) {
      throw StateError(
        'Online rooms need a configured Firebase project and connection.',
      );
    }
  }

  void _setStatus(MultiplayerConnectionStatus value) {
    if (_disposed) return;
    if (_status == value) return;
    _status = value;
    notifyListeners();
  }

  void _fail(Object error) {
    _error = error.toString().replaceFirst('Bad state: ', '');
    _setStatus(MultiplayerConnectionStatus.failed);
  }

  Future<void> close() async {
    if (_disposed) return;
    await _closeResources(notify: true);
  }

  Future<void> _closeResources({required bool notify}) async {
    final room = _room;
    if (room != null && _auth.uid != null && !_signalingComplete) {
      try {
        await room.update({
          'status': 'closed',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        // The room may already be gone or this device may be offline.
      }
    }
    await _cancelSignalingSubscriptions();
    await _dataChannel?.close();
    await _peerConnection?.close();
    await _peerConnection?.dispose();
    _dataChannel = null;
    _peerConnection = null;
    _room = null;
    _roomCode = null;
    _player = null;
    _remoteDescriptionSet = false;
    _settingRemoteDescription = false;
    _signalingComplete = false;
    _error = null;
    _status = MultiplayerConnectionStatus.idle;
    if (notify && !_disposed) notifyListeners();
  }

  Future<void> _cancelSignalingSubscriptions() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    unawaited(_closeResources(notify: false));
    unawaited(_messages.close());
    super.dispose();
  }
}
