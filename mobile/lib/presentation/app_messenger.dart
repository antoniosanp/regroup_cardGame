import 'package:flutter/material.dart';

/// Root [ScaffoldMessengerState] key so error toasts (FE-09) can be shown
/// from anywhere — in particular from [AppRoot], which sits *above* both
/// the status screen and [MatchScreen]'s own [Scaffold]s, so
/// `ScaffoldMessenger.of(context)` from there would find no Scaffold
/// ancestor to attach to.
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
