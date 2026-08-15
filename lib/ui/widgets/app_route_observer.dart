import 'package:flutter/material.dart';

/// Shared across the app (registered on `MaterialApp.navigatorObservers` in
/// main.dart) so any screen buried under another pushed route — e.g. the
/// start screen once a game or Settings is pushed on top of it — can tell
/// when it's covered and pause its own decorative looping animations
/// instead of ticking forever off-screen for the rest of the session.
final appRouteObserver = RouteObserver<PageRoute<dynamic>>();
