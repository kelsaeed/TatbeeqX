import 'package:flutter/material.dart';

// Non-web platforms (Windows desktop, iOS, Android): there's no <iframe>
// equivalent worth shoehorning in. Show a placeholder box of the
// configured height so the surrounding layout doesn't shift between
// platforms.
Widget buildIframeBlock({required String? url, required double height}) {
  return Builder(
    builder: (context) => Container(
      height: height,
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).dividerColor)),
      child: const Center(
        child: Text(
          'iframe blocks render in web builds only',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    ),
  );
}
