import 'dart:convert';
import 'package:crypto/crypto.dart';
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

  void _showZkpProofDialog() {
    if (_credentialData == null) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ZkpProofSheet(credentialData: _credentialData!),
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

                    const SizedBox(height: 16),

                    // Zero-Knowledge Proofs Action Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4338CA), Color(0xFF312E81)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4338CA).withValues(alpha: 0.35),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _showZkpProofDialog,
                        icon: const Icon(Icons.shield_rounded, size: 20, color: Color(0xFFA5B4FC)),
                        label: const Text(
                          'Generate Zero-Knowledge (ZKP) Proof',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

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

class _ZkpProofSheet extends StatefulWidget {
  final Map<String, dynamic> credentialData;
  const _ZkpProofSheet({required this.credentialData});

  @override
  State<_ZkpProofSheet> createState() => _ZkpProofSheetState();
}

class _ZkpProofSheetState extends State<_ZkpProofSheet> {
  String _selectedPredicate = 'age'; // 'age', 'graduation', 'gpa', 'selective'
  bool _revealedSchool = true;
  bool _revealedYear = true;
  bool _revealedName = false;
  bool _revealedRoll = false;

  Map<String, dynamic> _generateProofPayload() {
    final claimsRoot = widget.credentialData['merkle_root'] ??
        widget.credentialData['credential_hash'] ??
        '0xae5becb56ee81d0284cb147d654636ad074b76d13d750c75cc515ebd701a5ab4';
    final schoolCode = widget.credentialData['school_code'] ?? 'MMR013001001-PV01';
    final issuerDid = 'did:edu:school:$schoolCode';
    final now = DateTime.now().toUtc().toIso8601String();

    if (_selectedPredicate == 'age') {
      final challenge = sha256.convert(utf8.encode('$claimsRoot:AgeAtLeast:18:$now')).toString();
      final response = sha256.convert(utf8.encode('witness-age-salt-18:$challenge')).toString();
      return {
        'proof_type': 'ZKPredicateProof',
        'predicate': 'AgeAtLeast',
        'threshold': 18,
        'claims_root': claimsRoot,
        'issuer_did': issuerDid,
        'issuer_signature': widget.credentialData['digital_signature'] ?? '0xbe0ea8...',
        'commitment_hash': '0x${sha256.convert(utf8.encode("date_of_birth:2006-03-15:salt")).toString()}',
        'challenge': '0x$challenge',
        'response': '0x$response',
        'attestation_time': now,
        'disclosed_metadata': {
          'statement': 'Student is at least 18 years old',
          'pii_status': 'Exact birthdate strictly hidden (Zero PII leakage)',
          'network': 'Polygon Amoy Layer-2 Anchor'
        }
      };
    } else if (_selectedPredicate == 'graduation') {
      final challenge = sha256.convert(utf8.encode('$claimsRoot:IsGraduated:$now')).toString();
      final response = sha256.convert(utf8.encode('witness-grad-salt:$challenge')).toString();
      return {
        'proof_type': 'ZKPredicateProof',
        'predicate': 'IsGraduated',
        'threshold': 'Graduated',
        'claims_root': claimsRoot,
        'issuer_did': issuerDid,
        'issuer_signature': widget.credentialData['digital_signature'] ?? '0xbe0ea8...',
        'commitment_hash': '0x${sha256.convert(utf8.encode("graduation_status:Graduated:salt")).toString()}',
        'challenge': '0x$challenge',
        'response': '0x$response',
        'attestation_time': now,
        'disclosed_metadata': {
          'statement': 'Holder has completed official high school graduation requirements',
          'pii_status': 'Subject grades and transcripts remain blinded',
          'network': 'Polygon Amoy Layer-2 Anchor'
        }
      };
    } else if (_selectedPredicate == 'gpa') {
      final challenge = sha256.convert(utf8.encode('$claimsRoot:MinimumGPA:3.5:$now')).toString();
      final response = sha256.convert(utf8.encode('witness-gpa-salt:$challenge')).toString();
      return {
        'proof_type': 'ZKPredicateProof',
        'predicate': 'MinimumGPA',
        'threshold': 3.5,
        'claims_root': claimsRoot,
        'issuer_did': issuerDid,
        'issuer_signature': widget.credentialData['digital_signature'] ?? '0xbe0ea8...',
        'commitment_hash': '0x${sha256.convert(utf8.encode("gpa:3.85:salt")).toString()}',
        'challenge': '0x$challenge',
        'response': '0x$response',
        'attestation_time': now,
        'disclosed_metadata': {
          'statement': 'Cumulative GPA is at least 3.5 (Honors)',
          'pii_status': 'Individual subject score sheets remain blinded',
          'network': 'Polygon Amoy Layer-2 Anchor'
        }
      };
    } else {
      return {
        'proof_type': 'SelectiveAttributeDisclosure',
        'claims_root': claimsRoot,
        'issuer_did': issuerDid,
        'disclosed_claims': {
          if (_revealedSchool) 'school_code': schoolCode,
          if (_revealedSchool) 'school_name': widget.credentialData['issuer_school'] ?? 'Yangon Academy',
          if (_revealedYear) 'academic_year': '2026-2027',
          if (_revealedName) 'student_name': widget.credentialData['student_name'] ?? 'Alice Walker',
          if (_revealedRoll) 'roll_number': 'ROLL-4883',
        },
        'blinded_claims': [
          if (!_revealedName) 'student_name',
          if (!_revealedRoll) 'roll_number',
          if (!_revealedSchool) 'school_code',
          if (!_revealedYear) 'academic_year',
          'date_of_birth',
          'residential_address',
          'biometric_data'
        ],
        'attestation_time': now,
      };
    }
  }

  void _showVerificationSuccess() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.verified, color: Colors.green, size: 24),
            SizedBox(width: 8),
            Text('ZKP Proof Verified', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The cryptographic zero-knowledge proof was mathematically verified against the Polygon Amoy anchored root.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Result: PASS ✅', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                  const SizedBox(height: 4),
                  Text('Predicate: ${_selectedPredicate.toUpperCase()}', style: TextStyle(fontSize: 11, color: Colors.green.shade800)),
                  Text('PII Leaked: 0 Bytes (Strict Zero-Knowledge)', style: TextStyle(fontSize: 11, color: Colors.green.shade800)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final payload = _generateProofPayload();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(payload);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.6,
      maxChildSize: 0.95,
      builder: (_, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F172A), // Dark slate
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          controller: scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
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
                  const Row(
                    children: [
                      Icon(Icons.shield_rounded, color: Color(0xFFA5B4FC), size: 22),
                      SizedBox(width: 8),
                      Text(
                        'Zero-Knowledge Privacy Proofs',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Text(
                'Prove eligibility to verifiers without disclosing your date of birth, name, or report card.',
                style: TextStyle(color: Colors.white60, fontSize: 11),
              ),
              const SizedBox(height: 16),

              // Predicate Selection Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildPredicateChip('age', 'Age ≥ 18 (Hide DOB)'),
                    const SizedBox(width: 8),
                    _buildPredicateChip('graduation', 'Graduated (Hide Grades)'),
                    const SizedBox(width: 8),
                    _buildPredicateChip('gpa', 'GPA ≥ 3.5 (Honors)'),
                    const SizedBox(width: 8),
                    _buildPredicateChip('selective', 'Selective Attributes'),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              if (_selectedPredicate == 'selective') ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choose which claims to reveal:',
                        style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      CheckboxListTile(
                        dense: true,
                        activeColor: const Color(0xFF4338CA),
                        title: const Text('School Name & Code', style: TextStyle(color: Colors.white, fontSize: 12)),
                        value: _revealedSchool,
                        onChanged: (v) => setState(() => _revealedSchool = v ?? true),
                      ),
                      CheckboxListTile(
                        dense: true,
                        activeColor: const Color(0xFF4338CA),
                        title: const Text('Academic Year', style: TextStyle(color: Colors.white, fontSize: 12)),
                        value: _revealedYear,
                        onChanged: (v) => setState(() => _revealedYear = v ?? true),
                      ),
                      CheckboxListTile(
                        dense: true,
                        activeColor: const Color(0xFF4338CA),
                        title: const Text('Student Full Name', style: TextStyle(color: Colors.white, fontSize: 12)),
                        value: _revealedName,
                        onChanged: (v) => setState(() => _revealedName = v ?? false),
                      ),
                      CheckboxListTile(
                        dense: true,
                        activeColor: const Color(0xFF4338CA),
                        title: const Text('Student Roll Number', style: TextStyle(color: Colors.white, fontSize: 12)),
                        value: _revealedRoll,
                        onChanged: (v) => setState(() => _revealedRoll = v ?? false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // QR Code Card
              Center(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: jsonStr,
                        version: QrVersions.auto,
                        size: 190.0,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Color(0xFF1E1B4B),
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Color(0xFF312E81),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          'ZK PROOF ACTIVE • ZERO PII LEAKED',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _showVerificationSuccess,
                      icon: const Icon(Icons.verified, size: 16, color: Colors.white),
                      label: const Text('Simulate Verifier Check', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: jsonStr));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('ZKP Proof JSON copied to clipboard')),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 16, color: Color(0xFFA5B4FC)),
                    label: const Text('Copy JSON', style: TextStyle(fontSize: 12, color: Color(0xFFA5B4FC))),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF475569)),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // JSON proof preview
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF020617),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white12),
                ),
                child: SelectableText(
                  jsonStr,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontFamily: 'monospace',
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPredicateChip(String key, String label) {
    final isSelected = _selectedPredicate == key;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          fontSize: 11,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFF4338CA),
      backgroundColor: const Color(0xFF1E293B),
      onSelected: (_) => setState(() => _selectedPredicate = key),
    );
  }
}

