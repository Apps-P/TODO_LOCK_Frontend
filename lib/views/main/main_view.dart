import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';


class MainView extends StatelessWidget {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('AppBar Demo')),
      body: Center(child: Text('Main View')),

      // For overlay test. only in android vm. 차후에 삭제합시다.
      bottomNavigationBar: BottomAppBar(
        child: ElevatedButton(onPressed: ()async {
          final status = await FlutterOverlayWindow.isPermissionGranted();
          log("Is Permission Granted: $status");
          if(status == false) {
            await FlutterOverlayWindow.requestPermission();
            log("req permission");
            return;
          }

          if (await FlutterOverlayWindow.isActive()) return;
          await FlutterOverlayWindow.showOverlay(
            enableDrag: false,
            overlayTitle: "overlay test",
            overlayContent: 'Overlay Enabled',
            flag: OverlayFlag.defaultFlag,
            visibility: NotificationVisibility.visibilityPublic,
            positionGravity: PositionGravity.auto,
            height: WindowSize.matchParent,
            width: WindowSize.matchParent,
            startPosition: const OverlayPosition(0, 0),
          );
        }, child: const Text("Show Overlay")
        ),
      ),
    );
  }
}
