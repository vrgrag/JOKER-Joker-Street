import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../theme/palette.dart';

/// Generic in-app browser used for both the Privacy Policy and Support
/// pages. Handles loading state and gracefully reports connectivity
/// problems since the game itself must keep working fully offline even
/// though these two pages need a live connection.
class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key, required this.title, required this.url});

  final String title;
  final String url;

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _isLoading = false);
          },
          onWebResourceError: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _hasError = true;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _reload() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Palette.deepPurple,
        foregroundColor: Palette.cream,
        title: Text(
          widget.title,
          style: Palette.display.copyWith(fontSize: 18, color: Palette.gold),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            if (!_hasError) WebViewWidget(controller: _controller),
            if (_isLoading && !_hasError)
              const Center(
                child: CircularProgressIndicator(color: Palette.gold),
              ),
            if (_hasError)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.cloud_off_rounded,
                        color: Palette.gold,
                        size: 56,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Couldn't load this page.\nPlease check your internet connection.",
                        textAlign: TextAlign.center,
                        style: Palette.body.copyWith(color: Palette.cream),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _reload,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Palette.gold,
                          foregroundColor: Palette.nightPurple,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
