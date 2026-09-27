import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/verifiable_credential.dart';
import '../../services/storage_service.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../screens/login_screen.dart';

class StudentWalletScreen extends StatefulWidget {
  final VoidCallback onSwitchMode;
  final bool isGuardianView;
  final String? childName;
  final String? gradeLevel;
  final Map<String, dynamic>? overrideCredential;

  const StudentWalletScreen({
    super.key,
    required this.onSwitchMode,
    this.isGuardianView = false,
    this.childName,
    this.gradeLevel,
    this.overrideCredential,
  });

  @override
  State<StudentWalletScreen> createState() => _StudentWalletScreenState();
}

class _StudentWalletScreenState extends State<StudentWalletScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _credentialData;
  VerifiableCredential? _parsedVC;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _loadCredential();
  }

  Future<void> _loadCredential() async {
    setState(() {
      _isLoading = true;
    });

    if (widget.overrideCredential != null) {
      _credentialData = widget.overrideCredential;
      _initParsedVC(widget.overrideCredential!);
      setState(() {
        _isLoading = false;
        _isOffline = false;
      });
      return;
    }

    final cached = await StorageService.getCachedCredential();
    final user = await StorageService.getUser();

    if (cached != null) {
      _credentialData = cached;
      _initParsedVC(cached);
    }

    // Try refreshing from backend if student ID available
    if (user != null && user['id'] != null) {
      try {
        final freshData = await ApiService.fetchStudentBlockchainID(user['id'].toString());
        setState(() {
          _credentialData = freshData;
          _isOffline = false;
          _initParsedVC(freshData);
          _isLoading = false;
        });
        return;
      } catch (e) {
        // Fall back to offline cached
        _isOffline = true;
      }
    } else if (cached == null) {
      // Load default demo credential (Alice Walker)
      _loadDemoCredential();
      return;
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _loadDemoCredential() {
    const demoData = {
      "student_id": "4f703f66-22d3-4514-b5cc-1b449d3f1313",
      "student_name": "Alice Walker",
      "student_email": "student.alice@edu.local",
      "did": "did:edu:mm:013:MMR013001001-PV01-2026-STU4883",
      "blockchain_address": "0x217ff15fe5d8cee90f957185c8dd580f57347d20",
      "public_key": "5bf5fb13c1d233b8241382355718e439ac282133083c37b1668e5a00d9a6aaad",
      "credential_hash": "0xae5becb56ee81d0284cb147d654636ad074b76d13d750c75cc515ebd701a5ab4",
      "merkle_root": "0xae5becb56ee81d0284cb147d654636ad074b76d13d750c75cc515ebd701a5ab4",
      "polygon_tx_hash": "0xecf2696e698380a9a6c05030be5a23d4b6c9a9578895d5b3d64e10b675db699b",
      "anchor_status": "anchored",
      "issuer_school": "Yangon Academy High School",
      "school_code": "MMR013001001-PV01",
      "region": "Yangon Region",
      "township": "Dagon",
      "raw_credential_json": {
        "@context": [
          "https://www.w3.org/ns/credentials/v2",
          "https://schema.edu.gov.mm/credentials/v2"
        ],
        "id": "urn:uuid:4f703f66-22d3-4514-b5cc-1b449d3f1313",
        "type": ["VerifiableCredential", "StudentIdentityCredential"],
        "issuer": "did:edu:school:MMR013001001-PV01",
        "validFrom": "2026-09-24T05:53:29Z",
        "credentialSubject": {
          "academic_year": "2026-2027",
          "id": "did:edu:mm:013:MMR013001001-PV01-2026-STU4883",
          "public_key": "5bf5fb13c1d233b8241382355718e439ac282133083c37b1668e5a00d9a6aaad",
          "region": "Yangon Region",
          "school_code": "MMR013001001-PV01",
          "school_name": "Yangon Academy High School",
          "student_id": "4f703f66-22d3-4514-b5cc-1b449d3f1313",
          "student_roll_number": "ROLL-4883",
          "township": "Dagon"
        },
        "proof": {
          "type": "DataIntegrityProof",
          "cryptosuite": "eddsa-jcs-2022",
          "created": "2026-09-24T05:53:29Z",
          "verificationMethod": "did:edu:school:MMR013001001-PV01#key-1",
          "proofPurpose": "assertionMethod",
          "proofValue": "be0ea8168eb7ee6ab75d97b8c0eb65517197d8938f4578e266850806dc5c43b24b2a02403e31d959cf1a6544e8f4c40a1a47f939e15ba40193c65366b3e40d07"
        }
      },
      "digital_signature": "be0ea8168eb7ee6ab75d97b8c0eb65517197d8938f4578e266850806dc5c43b24b2a02403e31d959cf1a6544e8f4c40a1a47f939e15ba40193c65366b3e40d07",
      "issued_at": "2026-09-24T05:53:29Z",
      "is_revoked": false
    };

    _credentialData = demoData;
    _initParsedVC(demoData);
    setState(() {
      _isLoading = false;
      _isOffline = true;
    });
  }

  void _initParsedVC(Map<String, dynamic> data) {
    if (data['raw_credential_json'] != null) {
      try {
        final raw = data['raw_credential_json'];
        final map = raw is String ? json.decode(raw) : raw;
        _parsedVC = VerifiableCredential.fromJson(map as Map<String, dynamic>);
      } catch (_) {}
    }
  }

  bool _isFastScanMode = true;

  String get _qrPayload {
    if (_isFastScanMode) {
      return _credentialData?['did']?.toString() ?? 'did:edu:mm:013:MMR013034-PV02-2026-STU4883';
    }
    if (_parsedVC != null) {
      return json.encode(_parsedVC!.toJson());
    }
    return _credentialData?['did']?.toString() ?? 'did:edu:mm:013:MMR013034-PV02-2026-STU4883';
  }

  void _showRawJsonDialog() {
    if (_credentialData == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'W3C VC 2.0 Credential (JSON-LD)',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, color: Colors.indigoAccent, size: 20),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                          text: const JsonEncoder.withIndent('  ')
                              .convert(_credentialData!['raw_credential_json'] ?? _credentialData!)));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('W3C JSON Credential copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
              const Divider(color: Colors.white12),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SelectableText(
                    const JsonEncoder.withIndent('  ')
                        .convert(_credentialData!['raw_credential_json'] ?? _credentialData!),
                    style: const TextStyle(
                      color: Color(0xFFA5B4FC),
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studentName = _credentialData?['student_name'] ?? 'Alice Walker';
    final schoolName = _credentialData?['issuer_school'] ?? 'Yangon Academy High School';
    final schoolCode = _credentialData?['school_code'] ?? 'MMR013001001-PV01';
    final did = _credentialData?['did'] ?? 'did:edu:mm:...';
    final anchorStatus = _credentialData?['anchor_status'] ?? 'unanchored';
    final isAnchored = anchorStatus == 'anchored';

    final displayName = widget.childName ?? studentName;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isGuardianView ? 'Guardian Supervised ID Pass' : 'Student ID Wallet',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            Text(
              widget.isGuardianView
                  ? 'Viewing Child: $displayName (${widget.gradeLevel ?? "Enrolled"})'
                  : (_isOffline ? 'Offline Mode (Hardware Protected)' : 'Live Connected to EduPlatform'),
              style: TextStyle(
                fontSize: 11,
                color: widget.isGuardianView
                    ? AppTheme.primary
                    : (_isOffline ? Colors.amber.shade800 : AppTheme.secondary),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Switch to Gate Inspector Mode',
            icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primary),
            onPressed: widget.onSwitchMode,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (val) {
              if (val == 'inspect') {
                widget.onSwitchMode();
              } else if (val == 'json') {
                _showRawJsonDialog();
              } else if (val == 'login') {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ).then((_) => _loadCredential());
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'inspect',
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Switch to Inspector Mode'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'json',
                child: Row(
                  children: [
                    Icon(Icons.code, size: 18),
                    SizedBox(width: 8),
                    Text('View W3C VC 2.0 JSON'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'login',
                child: Row(
                  children: [
                    Icon(Icons.account_circle_outlined, size: 18),
                    SizedBox(width: 8),
                    Text('Switch Student Account'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadCredential,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    // Modern Holographic-style Student ID Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF1E1B4B), // Indigo 950
                            Color(0xFF0F172A), // Slate 900
                            Color(0xFF312E81), // Indigo 900
                          ],
                        ),
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.indigo.shade900.withValues(alpha: 0.35),
                            blurRadius: 28,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Card Top Bar
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.school, color: Colors.white, size: 22),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            'REPUBLIC OF THE UNION OF MYANMAR',
                                            style: TextStyle(
                                              color: Colors.white70,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                              letterSpacing: 0.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            schoolName,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w800,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isAnchored
                                      ? const Color(0xFF10B981).withValues(alpha: 0.2)
                                      : Colors.amber.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isAnchored ? const Color(0xFF10B981) : Colors.amber,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  isAnchored ? 'L2 ANCHORED' : 'LOCAL CERTIFIED',
                                  style: TextStyle(
                                    color: isAnchored ? const Color(0xFF34D399) : Colors.amberAccent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Density Mode Toggle (Fast Pass vs Full W3C)
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  GestureDetector(
                                    onTap: () => setState(() => _isFastScanMode = true),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: _isFastScanMode ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.bolt,
                                            size: 14,
                                            color: _isFastScanMode ? AppTheme.primary : Colors.white70,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Fast Pass (DID)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: _isFastScanMode ? AppTheme.primary : Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => setState(() => _isFastScanMode = false),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: !_isFastScanMode ? Colors.white : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.verified_outlined,
                                            size: 14,
                                            color: !_isFastScanMode ? AppTheme.primary : Colors.white70,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            'Full W3C VC',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w800,
                                              color: !_isFastScanMode ? AppTheme.primary : Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // QR Code Center
                          Center(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.2),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: QrImageView(
                                data: _qrPayload,
                                version: QrVersions.auto,
                                size: 160,
                                gapless: false,
                                errorCorrectionLevel: QrErrorCorrectLevel.M,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Center(
                            child: Column(
                              children: [
                                Text(
                                  _isFastScanMode
                                      ? '⚡ RAPID ENTRANCE PASS (VERSION 2 QR)'
                                      : '📄 FULL W3C VERIFIABLE CREDENTIAL',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isFastScanMode
                                      ? 'Optimized for budget phones (Instant <50ms scan)'
                                      : 'High-density matrix for cross-district audit',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.5),
                                    fontSize: 9,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Student Name & Details
                          Text(
                            studentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'P-Code: $schoolCode • ${_credentialData?['township'] ?? 'Dagon'}',
                            style: const TextStyle(
                              color: Color(0xFFA5B4FC),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // DID Strip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.fingerprint, color: Color(0xFFA5B4FC), size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    did,
                                    style: const TextStyle(
                                      color: Color(0xFFE0E7FF),
                                      fontFamily: 'monospace',
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Clipboard.setData(ClipboardData(text: did));
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('DID copied to clipboard')),
                                    );
                                  },
                                  child: const Icon(Icons.copy, color: Colors.white60, size: 14),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Quick Actions / Inspection Trigger
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: widget.onSwitchMode,
                            icon: const Icon(Icons.qr_code_scanner, size: 18),
                            label: const Text('Open Gate Verifier'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton(
                          onPressed: _showRawJsonDialog,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppTheme.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          ),
                          child: const Icon(Icons.data_object, color: AppTheme.primary),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Security & Cryptographic Specifications Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.verified_user_outlined, color: AppTheme.secondary, size: 18),
                                SizedBox(width: 8),
                                Text(
                                  'Security & Compliance Specs',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            _buildSpecRow('Standard', 'W3C Verifiable Credentials 2.0'),
                            _buildSpecRow('Identifier', 'W3C Decentralized Identifier (DID v1.0)'),
                            _buildSpecRow('Signature', 'Ed25519 (DataIntegrityProof / eddsa-jcs-2022)'),
                            _buildSpecRow('Blockchain Proof', 'Polygon Amoy Layer-2 Merkle Tree'),
                            _buildSpecRow('Privacy Mode', 'Zero PII on-chain (Cryptographic Root only)'),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMuted, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 11, color: AppTheme.textMain, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
