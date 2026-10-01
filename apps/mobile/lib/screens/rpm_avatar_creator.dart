import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/body_scan_service.dart';
import '../theme.dart';

class RpmAvatarCreatorScreen extends StatefulWidget {
  final BodyScanResult? bodyScanResult;
  const RpmAvatarCreatorScreen({super.key, this.bodyScanResult});

  @override
  State<RpmAvatarCreatorScreen> createState() =>
      _RpmAvatarCreatorScreenState();
}

class _RpmAvatarCreatorScreenState
    extends State<RpmAvatarCreatorScreen> {
  InAppWebViewController? _webCtrl;
  bool _isLoading = true;
  bool _hasError = false;
  bool _avatarReceived = false;
  String? _receivedAvatarUrl;
  late String _rpmUrl;

  @override
  void initState() {
    super.initState();
    _buildUrl();
  }

  Future<void> _buildUrl() async {
    final prefs = await SharedPreferences.getInstance();
    // Read gender from multiple possible pref keys
    final gender = prefs.getString('user_gender') ??
        prefs.getString('gender') ??
        prefs.getString('rpm_gender') ??
        'male';
    final bodyParam = widget.bodyScanResult?.rpmBodyParam ?? '';

    // RPM fullbody creator URL with gender and body preset
    var url =
        'https://demo.readyplayer.me/avatar?frameApi'
        '&clearCache'
        '&bodyType=fullbody'
        '&quality=high'
        '&gender=$gender';
    if (bodyParam.isNotEmpty && bodyParam != 'default') {
      url += '&bodyShape=$bodyParam';
    }
    if (mounted) setState(() => _rpmUrl = url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surface,
        foregroundColor: VColor.text,
        title: const Text(
          '3D Coach Avatar Studio',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: VColor.accent, strokeWidth: 2),
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Icon(Icons.threed_rotation_rounded,
                  color: VColor.accent),
            ),
        ],
      ),
      body: _hasError ? _buildErrorView() : _buildWebView(),
    );
  }

  Widget _buildWebView() {
    return Stack(
      children: [
        Column(
          children: [
            // ── Tip banner ──────────────────────────────────────────────────
            widget.bodyScanResult != null
                ? Container(
                    color: VColor.accent.withValues(alpha: 0.15),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: VColor.accent, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Body type "${widget.bodyScanResult!.bodyTypeLabel}" pre-configured',
                          style: const TextStyle(
                              color: VColor.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                : Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    color: VColor.accent.withValues(alpha: 0.1),
                    child: const Text(
                      '✨ Use selfie option for a face that looks like you!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: VColor.accent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),

            // ── WebView ─────────────────────────────────────────────────────
            Expanded(
              child: InAppWebView(
                initialUrlRequest:
                    URLRequest(url: WebUri(_rpmUrl)),
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  allowsInlineMediaPlayback: true,
                  transparentBackground: false,
                  useShouldOverrideUrlLoading: false,
                  mixedContentMode:
                      MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  cacheEnabled: true,
                  domStorageEnabled: true,
                  databaseEnabled: true,
                  allowFileAccessFromFileURLs: true,
                  allowUniversalAccessFromFileURLs: true,
                  javaScriptCanOpenWindowsAutomatically: true,
                ),
                onWebViewCreated: (ctrl) {
                  _webCtrl = ctrl;
                  // Register Flutter handler to receive avatar URL from JS
                  _webCtrl!.addJavaScriptHandler(
                    handlerName: 'rpmAvatarExported',
                    callback: (args) {
                      if (args.isNotEmpty) {
                        _onAvatarExported(args[0].toString());
                      }
                    },
                  );
                },
                onLoadStart: (ctrl, url) {
                  if (mounted) setState(() => _isLoading = true);
                },
                onLoadStop: (ctrl, url) async {
                  if (mounted) setState(() => _isLoading = false);
                  // Inject JS to listen for RPM avatar export event
                  await ctrl.evaluateJavascript(source: r'''
                    (function() {
                      window.addEventListener('message', function(event) {
                        try {
                          var data = typeof event.data === 'string'
                              ? JSON.parse(event.data)
                              : event.data;
                          if (data && data.source === 'readyplayerme') {
                            if (data.eventName === 'v1.avatar.exported') {
                              var avatarUrl = data.data && data.data.url
                                  ? data.data.url
                                  : data.url;
                              if (avatarUrl) {
                                window.flutter_inappwebview.callHandler(
                                    'rpmAvatarExported', avatarUrl);
                              }
                            }
                          }
                        } catch(e) {}
                      });
                      // Subscribe to avatar export event via postMessage
                      try {
                        var iframe = document.querySelector('iframe');
                        if (iframe) {
                          iframe.contentWindow.postMessage(
                            JSON.stringify({
                              target: 'readyplayerme',
                              type: 'subscribe',
                              eventName: 'v1.avatar.exported'
                            }), '*');
                        }
                      } catch(e) {}
                    })();
                  ''');
                },
                onProgressChanged: (ctrl, progress) {
                  if (progress == 100 && mounted) {
                    setState(() => _isLoading = false);
                  }
                },
                onReceivedError: (ctrl, req, err) {
                  // Only show error for main frame (not sub-resources)
                  if (req.isForMainFrame == true) {
                    if (mounted) {
                      setState(() {
                        _isLoading = false;
                        _hasError = true;
                      });
                    }
                  }
                },
              ),
            ),
          ],
        ),

        // ── Loading overlay ─────────────────────────────────────────────────
        if (_isLoading)
          Container(
            color: VColor.bg.withValues(alpha: 0.92),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: VColor.accent),
                  SizedBox(height: 16),
                  Text(
                    'Loading 3D Avatar Creator...',
                    style: TextStyle(
                        color: VColor.textMuted, fontSize: 14),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Make sure you are connected to internet',
                    style: TextStyle(
                        color: VColor.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),

        // ── Avatar ready banner ─────────────────────────────────────────────
        if (_avatarReceived)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: VColor.accent,
                boxShadow: [
                  BoxShadow(
                    color: VColor.accent.withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.black, size: 24),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '🎉 Avatar Ready!',
                          style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 16),
                        ),
                        Text(
                          'Tap Save to use this avatar in VYRA',
                          style: TextStyle(
                              color: Colors.black87, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _saveAndReturn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: VColor.accent,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Save',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ── Error view — shown when internet is not available ──────────────────────
  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: VColor.critSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.wifi_off_rounded,
                  color: VColor.crit, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Internet Connection',
              style: TextStyle(
                  color: VColor.text,
                  fontSize: 20,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Ready Player Me 3D avatar creator needs internet. '
              'Please connect to WiFi or mobile data and try again.',
              style: TextStyle(
                  color: VColor.textMid, fontSize: 14, height: 1.5),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VColor.accent,
                  foregroundColor: VColor.textOnAccent,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () {
                  setState(() {
                    _hasError = false;
                    _isLoading = true;
                  });
                  _webCtrl?.reload();
                },
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back',
                  style: TextStyle(color: VColor.textMuted)),
            ),
          ],
        ),
      ),
    );
  }

  void _onAvatarExported(String url) {
    if (!mounted) return;
    // Ensure URL ends with .glb for model viewer
    final glbUrl = url.contains('.glb') ? url : '$url.glb';
    setState(() {
      _avatarReceived = true;
      _receivedAvatarUrl = glbUrl;
    });
  }

  Future<void> _saveAndReturn() async {
    if (_receivedAvatarUrl == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rpm_avatar_url', _receivedAvatarUrl!);
    await prefs.setString(
        'rpm_avatar_updated_at', DateTime.now().toIso8601String());
    if (!mounted) return;
    Navigator.pop(context, _receivedAvatarUrl);
  }
}
