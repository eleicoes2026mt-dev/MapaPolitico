import 'package:flutter/material.dart';

/// Navigator do [ShellRoute] (conteúdo ao lado do menu). Usar para `showDialog`/`Overlay`
/// quando `useRootNavigator: true` coloca o diálogo atrás do shell na web.
final shellNavigatorKey = GlobalKey<NavigatorState>();
