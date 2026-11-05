import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/services/egov_api.dart';

/// A shared base class/widget for building API demo screens.
/// Each screen extends this widget to show consistent UI: description, call button, response viewer.

class ApiDemoScaffold extends StatefulWidget {
  final String apiName;
  final String apiSubtitle;
  final String description;
  final List<Color> gradient;
  final IconData icon;
  final Future<EGovResponse> Function() callApi;
  final List<Widget> inputWidgets;

  const ApiDemoScaffold({
    super.key,
    required this.apiName,
    required this.apiSubtitle,
    required this.description,
    required this.gradient,
    required this.icon,
    required this.callApi,
    this.inputWidgets = const [],
  });

  @override
  State<ApiDemoScaffold> createState() => _ApiDemoScaffoldState();
}

class _ApiDemoScaffoldState extends State<ApiDemoScaffold> {
  bool _loading = false;
  EGovResponse? _response;

  Future<void> _call() async {
    setState(() {
      _loading = true;
      _response = null;
    });
    try {
      final res = await widget.callApi();
      setState(() => _response = res);
    } catch (e) {
      setState(() {
        _response = EGovResponse(
          success: false,
          requestId: 'local-error',
          timestamp: DateTime.now(),
          isLive: false,
          data: {},
          errorMessage: e.toString(),
        );
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08142B),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(widget.apiName,
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFFBBF24).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFBBF24).withOpacity(0.3)),
            ),
            child: Text('MOCK', style: GoogleFonts.jetBrainsMono(
                color: const Color(0xFFFBBF24), fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: widget.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: widget.gradient.last.withOpacity(0.25), blurRadius: 20, offset: const Offset(0, 6)),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.apiName,
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                        Text(widget.apiSubtitle,
                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Description
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1F3C),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: widget.gradient.last, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(widget.description,
                      style: GoogleFonts.inter(color: Colors.white.withOpacity(0.7), fontSize: 13, height: 1.5)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Input widgets (custom per screen)
            if (widget.inputWidgets.isNotEmpty) ...[
              Text('Request Parameters',
                style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 11,
                    fontWeight: FontWeight.w700, letterSpacing: 1.2)),
              const SizedBox(height: 12),
              ...widget.inputWidgets,
              const SizedBox(height: 20),
            ],

            // Call button
            GestureDetector(
              onTap: _loading ? null : _call,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: _loading
                      ? LinearGradient(colors: [Colors.grey.shade800, Colors.grey.shade700])
                      : LinearGradient(colors: widget.gradient, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: _loading ? [] : [
                    BoxShadow(color: widget.gradient.last.withOpacity(0.35), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_loading) ...[
                      const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                      const SizedBox(width: 12),
                      Text('Calling API...', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    ] else ...[
                      const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                      const SizedBox(width: 10),
                      Text('Call ${widget.apiName} API',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                    ],
                  ],
                ),
              ),
            ),

            // Response viewer
            if (_response != null) ...[
              const SizedBox(height: 24),
              _ResponseViewer(response: _response!, accentColor: widget.gradient.last),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResponseViewer extends StatelessWidget {
  final EGovResponse response;
  final Color accentColor;
  const _ResponseViewer({required this.response, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final jsonStr = response.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: response.success ? const Color(0xFF34D399) : const Color(0xFFEF4444),
                    boxShadow: [
                      BoxShadow(
                        color: response.success ? const Color(0xFF34D399) : const Color(0xFFEF4444),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  response.success ? '200 OK' : '422 Error',
                  style: GoogleFonts.jetBrainsMono(
                    color: response.success ? const Color(0xFF34D399) : const Color(0xFFEF4444),
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: jsonStr));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Copied to clipboard', style: GoogleFonts.inter()),
                    backgroundColor: const Color(0xFF0D1F3C),
                    duration: const Duration(seconds: 1),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: accentColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.copy_rounded, size: 12, color: accentColor),
                    const SizedBox(width: 4),
                    Text('Copy', style: GoogleFonts.inter(color: accentColor, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF030D1F),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.06)),
          ),
          child: SelectableText(
            jsonStr,
            style: GoogleFonts.jetBrainsMono(
              color: const Color(0xFF93C5FD),
              fontSize: 12,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

/// Reusable dark input field
class EGovInputField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final IconData icon;
  final Color color;

  const EGovInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 12, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D1F3C),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: GoogleFonts.jetBrainsMono(
                        color: Colors.white.withOpacity(0.25), fontSize: 13),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
