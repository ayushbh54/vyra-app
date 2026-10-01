import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/body_scan_service.dart';
import '../theme.dart';

class RpmAvatarCreatorScreen extends StatefulWidget {
  final BodyScanResult? bodyScanResult;
  const RpmAvatarCreatorScreen({super.key, this.bodyScanResult});

  @override
  State<RpmAvatarCreatorScreen> createState() => _RpmAvatarCreatorScreenState();
}

class _RpmAvatarCreatorScreenState extends State<RpmAvatarCreatorScreen> {
  InAppWebViewController? _webCtrl;
  bool _isLoading = true;
  bool _avatarReceived = false;
  String? _receivedAvatarUrl;
  String _rpmUrl = 'https://demo.readyplayer.me/avatar?frameApi&clearCache&bodyType=fullbody';

  @override
  void initState() {
    super.initState();
    _loadUrl();
  }

  Future<void> _loadUrl() async {
    final bodyParam = widget.bodyScanResult?.rpmBodyParam ?? 'default';
    setState(() {
      _rpmUrl = 'https://demo.readyplayer.me/avatar?frameApi&clearCache&bodyType=fullbody&bodyParam=$bodyParam';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VColor.bg,
      appBar: AppBar(
        backgroundColor: VColor.surface,
        foregroundColor: VColor.text,
        title: const Text('3D Coach Avatar Studio',
            style: TextStyle(fontWeight: FontWeight.w700)),
        centerTitle: true,
        actions: const [
          Icon(Icons.threed_rotation_rounded, color: VColor.accent),
          SizedBox(width: 16),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (widget.bodyScanResult != null)
                Container(
                  color: VColor.accent.withValues(alpha: 0.15),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: VColor.accent, size: 16),
                      const SizedBox(width: 8),
                      Text('Body type "${widget.bodyScanResult!.bodyTypeLabel}" pre-configured',
                        style: const TextStyle(color: VColor.accent, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  color: VColor.accent.withValues(alpha: 0.1),
                  child: const Text(
                    'Tip: Use selfie option in creator for a face that looks like you!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: VColor.accent, fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
              Expanded(
                child: InAppWebView(
                  initialUrlRequest: URLRequest(url: WebUri(_rpmUrl)),
                  initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    mediaPlaybackRequiresUserGesture: false,
                    allowsInlineMediaPlayback: true,
                    transparentBackground: false,
                    useShouldOverrideUrlLoading: false,
                  ),
                  onWebViewCreated: (ctrl) {
                    _webCtrl = ctrl;
                    _webCtrl!.addJavaScriptHandler(
                      handlerName: 'rpmAvatarExported',
                      callback: (args) {
                        if (args.isNotEmpty) {
                          _onAvatarExported(args[0].toString());
                        }
                      },
                    );
                  },
                  onLoadStop: (ctrl, url) async {
                    setState(() => _isLoading = false);
                    await ctrl.evaluateJavascript(source: '''
                      window.addEventListener('message', function(event) {
                        try {
                          var json = typeof event.data === 'string' ? JSON.parse(event.data) : event.data;
                          if (json?.source === 'readyplayerme') {
                            if (json.eventName === 'v1.avatar.exported') {
                              window.flutter_inappwebview.callHandler('rpmAvatarExported', json.data.url);
                            }
                          }
                        } catch(e) {}
                      });
                      document.querySelector("iframe") && document.querySelector("iframe").contentWindow.postMessage(
                        JSON.stringify({target: 'readyplayerme', type: 'subscribe', eventName: 'v1.avatar.exported'}),
                        '*'
                      );
                    ''');
                  },
                  onProgressChanged: (ctrl, progress) {
                    if (progress == 100 && mounted) {
                      setState(() => _isLoading = false);
                    }
                  },
                ),
              ),
            ],
          ),

          if (_isLoading)
            Container(
              color: VColor.bg,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: VColor.accent),
                    SizedBox(height: 16),
                    Text('Personalizing your avatar...',
                        style: TextStyle(color: VColor.textMuted, fontSize: 14)),
                  ],
                ),
              ),
            ),

          if (_avatarReceived)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(16),
                color: VColor.accent.withValues(alpha: 0.95),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.black),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('Avatar Ready!',
                          style: TextStyle(
                              color: Colors.black, fontWeight: FontWeight.w700)),
                    ),
                    ElevatedButton(
                      onPressed: _saveAndReturn,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: VColor.accent),
                      child: const Text('Save'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _onAvatarExported(String url) {
    if (!mounted) return;
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
    await prefs.setString('rpm_avatar_updated_at', DateTime.now().toIso8601String());
    await prefs.setString('rpm_gender', 'unspecified');
    if (mounted) Navigator.pop(context, _receivedAvatarUrl);
  }
}
