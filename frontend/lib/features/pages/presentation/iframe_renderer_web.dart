// This file is loaded only on Flutter web (via conditional import in
// iframe_renderer.dart), so the web-only library lints don't apply.
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';

// View factories must be registered exactly once per viewType, so we
// memoize by URL hash.
final Set<String> _registeredViewTypes = <String>{};

Widget buildIframeBlock({required String? url, required double height}) {
  if (url == null || url.trim().isEmpty) {
    return Builder(
      builder: (context) => Container(
        height: height,
        decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor)),
        child: const Center(
          child: Text(
            'iframe URL not configured',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      ),
    );
  }
  final viewType = 'mc-iframe-${url.hashCode}';
  if (!_registeredViewTypes.contains(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      final el = html.IFrameElement();
      el.src = url;
      el.style.border = 'none';
      el.style.width = '100%';
      el.style.height = '100%';
      return el;
    });
    _registeredViewTypes.add(viewType);
  }
  return SizedBox(
    height: height,
    child: HtmlElementView(viewType: viewType),
  );
}
