import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/board_constants.dart';
import '../models/board_post_model.dart';
import '../services/board_service.dart';
import '../services/groq_service.dart';

class CreateBoardPostScreen extends StatefulWidget {
  final String campusId;
  final BoardPostModel? existingPost; // non-null = edit mode

  const CreateBoardPostScreen({
    super.key,
    required this.campusId,
    this.existingPost,
  });

  @override
  State<CreateBoardPostScreen> createState() =>
      _CreateBoardPostScreenState();
}

enum _PostMode { ai, manual }

class _CreateBoardPostScreenState extends State<CreateBoardPostScreen> {
  final _boardService = BoardService();
  _PostMode _mode = _PostMode.ai;
  bool _isPosting = false;
  String _statusMessage = '';

  // AI mode
  final _aiTextController = TextEditingController();
  GroqResult? _aiResult;

  // Manual mode fields
  final _manTitleCtrl = TextEditingController();
  final _manSummaryCtrl = TextEditingController();
  final _manDetailsCtrl = TextEditingController();
  final _manVenueCtrl = TextEditingController();
  final _manContactNameCtrl = TextEditingController();
  final _manPhoneCtrl = TextEditingController();
  final _manEmailCtrl = TextEditingController();
  String? _manCategory;
  String _manUrgency = 'low';
  DateTime? _manEventDate;
  DateTime? _manDeadline;
  final List<_LinkEntry> _manLinks = [];

  // AI preview editable fields
  final _prevTitleCtrl = TextEditingController();
  final _prevSummaryCtrl = TextEditingController();
  final _prevDetailsCtrl = TextEditingController();
  final _prevVenueCtrl = TextEditingController();
  final _prevContactNameCtrl = TextEditingController();
  final _prevPhoneCtrl = TextEditingController();
  final _prevEmailCtrl = TextEditingController();
  String _prevUrgency = 'low';
  DateTime? _prevEventDate;
  DateTime? _prevDeadline;
  final List<_LinkEntry> _prevLinks = [];

  // Shared attachments
  List<PlatformFile> _files = [];
  bool get _isEditMode => widget.existingPost != null;

  @override
  void initState() {
    super.initState();
    if (_isEditMode) {
      final p = widget.existingPost!;
      _mode = _PostMode.manual;
      _manTitleCtrl.text = p.title;
      _manSummaryCtrl.text = p.summary;
      _manDetailsCtrl.text = p.details;
      _manVenueCtrl.text = p.venue ?? '';
      _manContactNameCtrl.text = p.contactName ?? '';
      _manPhoneCtrl.text = p.contactPhone ?? '';
      _manEmailCtrl.text = p.contactEmail ?? '';
      _manCategory = p.category;
      _manUrgency = p.urgencyLevel;
      _manEventDate = p.eventDate;
      _manDeadline = p.deadlineAt;
      _aiTextController.text = p.rawContent;
      for (final l in p.links) {
        _manLinks.add(_LinkEntry(url: l.url, label: l.label ?? ''));
      }
    }
  }

  @override
  void dispose() {
    _aiTextController.dispose();
    _manTitleCtrl.dispose();
    _manSummaryCtrl.dispose();
    _manDetailsCtrl.dispose();
    _manVenueCtrl.dispose();
    _manContactNameCtrl.dispose();
    _manPhoneCtrl.dispose();
    _manEmailCtrl.dispose();
    _prevTitleCtrl.dispose();
    _prevSummaryCtrl.dispose();
    _prevDetailsCtrl.dispose();
    _prevVenueCtrl.dispose();
    _prevContactNameCtrl.dispose();
    _prevPhoneCtrl.dispose();
    _prevEmailCtrl.dispose();
    for (final l in _manLinks) {
      l.dispose();
    }
    for (final l in _prevLinks) {
      l.dispose();
    }
    super.dispose();
  }

  // ── File picking ───────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final remaining = kMaxFileCount - _files.length;
    if (remaining <= 0) {
      _showError('Maximum $kMaxFileCount files allowed.');
      return;
    }
    // Use image_picker so Android 13+ uses the system Photo Picker without READ_MEDIA_* permissions
    final picker = ImagePicker();
    final List<XFile> picked;
    if (remaining == 1) {
      final one = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      picked = one != null ? [one] : [];
    } else {
      picked = await picker.pickMultiImage(
        imageQuality: 85,
        limit: remaining,
      );
    }
    if (picked.isEmpty) return;
    final platformFiles = await Future.wait(
      picked.map((xFile) async {
        final size = await File(xFile.path).length();
        return PlatformFile(
          name: xFile.name,
          path: xFile.path,
          size: size,
        );
      }),
    );
    _addFiles(platformFiles);
  }

  Future<void> _pickDocument() async {
    if (_files.length >= kMaxFileCount) {
      _showError('Maximum $kMaxFileCount files allowed.');
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
      allowMultiple: true,
      withData: false,
    );
    if (result == null) return;
    _addFiles(result.files);
  }

  void _addFiles(List<PlatformFile> picked) {
    final combined = [..._files, ...picked];
    final error = BoardService.validateFiles(combined);
    if (error != null) {
      _showError(error);
      return;
    }
    setState(() => _files = combined.take(kMaxFileCount).toList());
  }

  void _removeFile(int index) => setState(() => _files.removeAt(index));

  // ── AI analysis ───────────────────────────────────────────────────────────

  Future<void> _runAI() async {
    final text = _aiTextController.text.trim();
    if (text.isEmpty) {
      _showError('Please write your post content first.');
      return;
    }
    setState(() {
      _isPosting = true;
      _statusMessage = 'Analysing with AI…';
      _aiResult = null;
    });

    final result = await GroqService().analysePost(
      rawText: text,
    );

    _prevTitleCtrl.text = result.title;
    _prevSummaryCtrl.text = result.summary;
    _prevDetailsCtrl.text = result.details;
    _prevVenueCtrl.text = result.venue ?? '';
    _prevContactNameCtrl.text = result.contactName ?? '';
    _prevPhoneCtrl.text = result.contactPhone ?? '';
    _prevEmailCtrl.text = result.contactEmail ?? '';
    _prevUrgency = result.urgencyLevel;
    _prevEventDate = result.eventDate;
    _prevDeadline = result.deadlineAt;

    for (final l in _prevLinks) {
      l.dispose();
    }
    _prevLinks.clear();
    for (final l in result.links) {
      _prevLinks.add(_LinkEntry(url: l.url, label: l.label ?? ''));
    }

    if (!mounted) return;
    setState(() {
      _isPosting = false;
      _statusMessage = '';
      _aiResult = result;
    });
  }

  // ── Submit ────────────────────────────────────────────────────────────────

  Future<void> _submit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _showError('You must be logged in to post.');
      return;
    }

    if ((_mode == _PostMode.manual || _isEditMode) &&
        _manTitleCtrl.text.trim().isEmpty) {
      _showError('Please enter a title.');
      return;
    }

    String userName = user.displayName ?? 'User';
    String? program, department, year;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists) {
        final d = doc.data()!;
        userName = (d['name'] as String?)?.isNotEmpty == true
            ? d['name'] as String
            : userName;
        program = d['program'] as String?;
        department = d['department'] as String?;
        year = d['year'] as String?;
      }
    } catch (_) {}

    setState(() {
      _isPosting = true;
      _statusMessage =
          _files.isNotEmpty ? 'Uploading files…' : 'Saving post…';
    });

    try {
      GroqResult? postData;

      if (_mode == _PostMode.manual || _isEditMode) {
        postData = GroqResult(
          title: _manTitleCtrl.text.trim(),
          summary: _manSummaryCtrl.text.trim(),
          details: _manDetailsCtrl.text.trim(),
          category: _manCategory ?? 'general',
          urgencyLevel: _manUrgency,
          isImportant: _manUrgency == 'high' || _manUrgency == 'critical',
          eventDate: _manEventDate,
          deadlineAt: _manDeadline,
          venue: _manVenueCtrl.text.trim().isNotEmpty
              ? _manVenueCtrl.text.trim()
              : null,
          contactName: _manContactNameCtrl.text.trim().isNotEmpty
              ? _manContactNameCtrl.text.trim()
              : null,
          contactPhone: _manPhoneCtrl.text.trim().isNotEmpty
              ? _manPhoneCtrl.text.trim()
              : null,
          contactEmail: _manEmailCtrl.text.trim().isNotEmpty
              ? _manEmailCtrl.text.trim()
              : null,
          links: _manLinks
              .where((l) => l.urlCtrl.text.trim().isNotEmpty)
              .map((l) => BoardLink(
                    url: l.urlCtrl.text.trim(),
                    label: l.labelCtrl.text.trim().isNotEmpty
                        ? l.labelCtrl.text.trim()
                        : null,
                  ))
              .toList(),
        );
      } else if (_aiResult != null) {
        postData = GroqResult(
          title: _prevTitleCtrl.text.trim().isNotEmpty
              ? _prevTitleCtrl.text.trim()
              : _aiResult!.title,
          summary: _prevSummaryCtrl.text.trim(),
          details: _prevDetailsCtrl.text.trim(),
          category: _aiResult!.category,
          urgencyLevel: _prevUrgency,
          isImportant: _prevUrgency == 'high' || _prevUrgency == 'critical',
          eventDate: _prevEventDate,
          deadlineAt: _prevDeadline,
          venue: _prevVenueCtrl.text.trim().isNotEmpty
              ? _prevVenueCtrl.text.trim()
              : null,
          contactName: _prevContactNameCtrl.text.trim().isNotEmpty
              ? _prevContactNameCtrl.text.trim()
              : null,
          contactPhone: _prevPhoneCtrl.text.trim().isNotEmpty
              ? _prevPhoneCtrl.text.trim()
              : null,
          contactEmail: _prevEmailCtrl.text.trim().isNotEmpty
              ? _prevEmailCtrl.text.trim()
              : null,
          links: _prevLinks
              .where((l) => l.urlCtrl.text.trim().isNotEmpty)
              .map((l) => BoardLink(
                    url: l.urlCtrl.text.trim(),
                    label: l.labelCtrl.text.trim().isNotEmpty
                        ? l.labelCtrl.text.trim()
                        : null,
                  ))
              .toList(),
        );
      }

      await _boardService.submitPost(
        rawContent: _aiTextController.text.trim().isNotEmpty
            ? _aiTextController.text.trim()
            : _manTitleCtrl.text.trim(),
        campusId: widget.campusId,
        postedBy: user.uid,
        postedByName: userName,
        postedByProgram: program,
        postedByDepartment: department,
        postedByYear: year,
        userSelectedCategory: null,
        files: _files,
        existingPost: widget.existingPost,
        manualData: postData,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _isEditMode ? 'Post updated!' : 'Posted to Campus Board!'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context, true);
    } catch (e) {
      _showError('Failed: $e');
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        title: Text(
          _isEditMode ? 'Edit Board Post' : 'New Board Post',
          style: const TextStyle(
              fontWeight: FontWeight.bold, color: Colors.black87),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!_isEditMode) _buildModeToggle(),
                const SizedBox(height: 14),

                if (_mode == _PostMode.ai && !_isEditMode)
                  ..._buildAIMode()
                else
                  ..._buildManualMode(),

                const SizedBox(height: 14),
                _buildAttachmentSection(),
                const SizedBox(height: 14),

                if (_mode == _PostMode.manual ||
                    _isEditMode ||
                    _aiResult != null)
                  _buildPostButton(),

                const SizedBox(height: 40),
              ],
            ),
          ),
          if (_isPosting)
            Container(
              color: Colors.black38,
              child: Center(
                child: Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 14),
                      Text(_statusMessage,
                          style: const TextStyle(fontWeight: FontWeight.w500)),
                    ]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Mode toggle ───────────────────────────────────────────────────────────

  Widget _buildModeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
              child:
                  _modeBtn(_PostMode.ai, 'Post with AI', Icons.auto_awesome)),
          Expanded(
              child: _modeBtn(_PostMode.manual, 'Manual', Icons.edit_note)),
        ],
      ),
    );
  }

  Widget _modeBtn(_PostMode m, String label, IconData icon) {
    final selected = _mode == m;
    return GestureDetector(
      onTap: () => setState(() {
        _mode = m;
        _aiResult = null;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? Colors.deepPurple : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey,
            ),
          ),
        ]),
      ),
    );
  }

  // ── AI mode ───────────────────────────────────────────────────────────────

  List<Widget> _buildAIMode() {
    return [
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: TextField(
          controller: _aiTextController,
          minLines: 6,
          maxLines: 16,
          style: const TextStyle(fontSize: 15, height: 1.5),
          decoration: InputDecoration(
            hintText:
                'Paste or type your announcement here…\n\nAI will extract title, venue, dates, contacts, and links for you to review.',
            hintStyle:
                TextStyle(color: Colors.grey.shade400, fontSize: 14, height: 1.5),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          onPressed: _isPosting ? null : _runAI,
          icon: const Icon(Icons.auto_awesome, size: 18),
          label: Text(
            _aiResult == null ? 'Analyse with AI' : 'Re-analyse with AI',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
      ),
      if (_aiResult != null) ...[
        const SizedBox(height: 12),
        ..._buildAIPreview(),
      ],
    ];
  }

  List<Widget> _buildAIPreview() {
    return [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.deepPurple.withOpacity(0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.deepPurple.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.auto_awesome, color: Colors.deepPurple, size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                _aiResult!.usedFallback
                    ? 'AI unavailable (${_aiResult!.fallbackReason ?? "unknown"}) — review & edit fields below'
                    : 'AI Generated — Edit any field before posting',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _aiResult!.usedFallback
                      ? Colors.orange.shade800
                      : Colors.deepPurple,
                  fontSize: 13,
                ),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _previewField('Title', _prevTitleCtrl),
          const SizedBox(height: 8),
          _previewField('Summary', _prevSummaryCtrl, maxLines: 3),
          const SizedBox(height: 8),
          _previewField('Details', _prevDetailsCtrl, maxLines: 4),
          const SizedBox(height: 8),
          _previewField('Venue', _prevVenueCtrl),
          const SizedBox(height: 8),
          _previewField('Contact Name', _prevContactNameCtrl),
          const SizedBox(height: 8),
          _previewField('Phone', _prevPhoneCtrl,
              inputType: TextInputType.phone),
          const SizedBox(height: 8),
          _previewField('Email', _prevEmailCtrl,
              inputType: TextInputType.emailAddress),
          const SizedBox(height: 10),
          _buildReadOnlyCategoryBadge(_aiResult!.category),
          const SizedBox(height: 10),
          _buildUrgencyRow(
            value: _prevUrgency,
            onChanged: (u) => setState(() => _prevUrgency = u),
          ),
          const SizedBox(height: 10),
          _buildDateRow(
            eventDate: _prevEventDate,
            deadline: _prevDeadline,
            onEventDate: (d) => setState(() => _prevEventDate = d),
            onDeadline: (d) => setState(() => _prevDeadline = d),
          ),
          const SizedBox(height: 10),
          _buildLinksEditor(_prevLinks),
        ]),
      ),
    ];
  }

  Widget _previewField(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: inputType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  // ── Manual mode ───────────────────────────────────────────────────────────

  List<Widget> _buildManualMode() {
    return [
      if (_isEditMode)
        _buildReadOnlyCategoryBadge(_manCategory ?? 'general')
      else
        _buildCategoryRow(
          selected: _manCategory,
          onChanged: (c) => setState(() => _manCategory = c),
        ),
      const SizedBox(height: 10),
      _manField('Title *', _manTitleCtrl),
      const SizedBox(height: 8),
      _manField('Summary', _manSummaryCtrl, maxLines: 3),
      const SizedBox(height: 8),
      _manField('Details', _manDetailsCtrl, maxLines: 5),
      const SizedBox(height: 8),
      _manField('Venue / Location', _manVenueCtrl),
      const SizedBox(height: 8),
      _manField('Contact Name', _manContactNameCtrl),
      const SizedBox(height: 8),
      _manField('Phone Number', _manPhoneCtrl,
          inputType: TextInputType.phone),
      const SizedBox(height: 8),
      _manField('Email', _manEmailCtrl,
          inputType: TextInputType.emailAddress),
      const SizedBox(height: 10),
      _buildUrgencyRow(
        value: _manUrgency,
        onChanged: (u) => setState(() => _manUrgency = u),
      ),
      const SizedBox(height: 10),
      _buildDateRow(
        eventDate: _manEventDate,
        deadline: _manDeadline,
        onEventDate: (d) => setState(() => _manEventDate = d),
        onDeadline: (d) => setState(() => _manDeadline = d),
      ),
      const SizedBox(height: 10),
      _buildLinksEditor(_manLinks),
    ];
  }

  Widget _manField(
    String label,
    TextEditingController ctrl, {
    int maxLines = 1,
    TextInputType inputType = TextInputType.text,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: inputType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
      ),
    );
  }

  // ── Read-only category badge (AI-assigned) ────────────────────────────────

  Widget _buildReadOnlyCategoryBadge(String category) {
    final (_, lbl) = kBoardCategories[category] ?? ('📋', 'General');
    final icon = kBoardCategoryIcons[category] ?? Icons.label_outline;
    final color = kBoardCategoryColors[category] ?? const Color(0xFF3949AB);
    return Row(
      children: [
        const Text('Category: ',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                lbl,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Category row (green icons, manual new post only) ──────────────────────

  Widget _buildCategoryRow({
    required String? selected,
    required ValueChanged<String?> onChanged,
    String label = 'Category',
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54)),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: kBoardCategories.entries.map((e) {
            final key = e.key;
            final (_, lbl) = e.value;
            final icon = kBoardCategoryIcons[key] ?? Icons.label_outline;
            final isSelected = selected == key;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onChanged(isSelected ? null : key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.deepPurple : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color:
                          isSelected ? Colors.deepPurple : Colors.grey.shade300,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        size: 15,
                        color: isSelected ? Colors.white : kCategoryIconColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        lbl,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    ]);
  }

  // ── Urgency row ───────────────────────────────────────────────────────────

  Widget _buildUrgencyRow({
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Urgency',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54)),
      const SizedBox(height: 6),
      Row(
        children: kUrgencyLevels.entries.map((e) {
          final key = e.key;
          final (color, lbl) = e.value;
          final selected = value == key;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => onChanged(key),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? color : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: selected ? color : color.withOpacity(0.3)),
                ),
                child: Text(
                  lbl,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : color,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ]);
  }

  // ── Date row ──────────────────────────────────────────────────────────────

  Widget _buildDateRow({
    required DateTime? eventDate,
    required DateTime? deadline,
    required ValueChanged<DateTime?> onEventDate,
    required ValueChanged<DateTime?> onDeadline,
  }) {
    return Row(children: [
      Expanded(
        child: _DatePickerBtn(
          label: 'Event Date',
          date: eventDate,
          color: kEventColor,
          onPicked: onEventDate,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: _DatePickerBtn(
          label: 'Deadline',
          date: deadline,
          color: kDeadlineColor,
          onPicked: onDeadline,
        ),
      ),
    ]);
  }

  // ── Links editor (shared between manual mode & AI preview) ────────────────

  Widget _buildLinksEditor(List<_LinkEntry> links) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Links',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54)),
        TextButton.icon(
          onPressed: () => setState(() => links.add(_LinkEntry())),
          icon: const Icon(Icons.add, size: 16),
          label: const Text('Add Link', style: TextStyle(fontSize: 12)),
          style: TextButton.styleFrom(
              foregroundColor: kLinkColor, padding: EdgeInsets.zero),
        ),
      ]),
      ...links.asMap().entries.map((en) {
        final i = en.key;
        final l = en.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(children: [
            Expanded(
              flex: 3,
              child: TextField(
                controller: l.urlCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'URL',
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: TextField(
                controller: l.labelCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Label',
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey.shade200)),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18, color: Colors.red),
              onPressed: () {
                setState(() {
                  links[i].dispose();
                  links.removeAt(i);
                });
              },
            ),
          ]),
        );
      }),
    ]);
  }

  // ── Attachments ───────────────────────────────────────────────────────────

  Widget _buildAttachmentSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Attachments',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black54)),
      const SizedBox(height: 6),
      Row(children: [
        _attachBtn(
          icon: Icons.image_outlined,
          label: 'Image',
          color: Colors.deepPurple,
          onTap: _pickImage,
        ),
        const SizedBox(width: 10),
        _attachBtn(
          icon: Icons.attach_file,
          label: 'PDF / Doc',
          color: Colors.indigo,
          onTap: _pickDocument,
        ),
      ]),
      if (_files.isNotEmpty) ...[
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(_files.length, (i) {
            final f = _files[i];
            final ext = f.extension?.toLowerCase() ?? '';
            final isImage = ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
            final isPdf = ext == 'pdf';
            final icon = isImage
                ? Icons.image
                : isPdf
                    ? Icons.picture_as_pdf
                    : Icons.description;
            final color = isImage
                ? Colors.deepPurple
                : isPdf
                    ? Colors.red.shade700
                    : Colors.blue.shade700;
            return Chip(
              avatar: Icon(icon, size: 16, color: color),
              label: Text(
                '${f.name}  •  ${(f.size / 1024).round()}KB',
                style: const TextStyle(fontSize: 11),
              ),
              deleteIcon:
                  const Icon(Icons.close, size: 15, color: Colors.black45),
              onDeleted: () => _removeFile(i),
              backgroundColor: color.withOpacity(0.07),
              side: BorderSide(color: color.withOpacity(0.2)),
            );
          }),
        ),
      ],
    ]);
  }

  Widget _attachBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final disabled = _files.length >= kMaxFileCount;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: disabled ? Colors.grey.shade100 : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: disabled ? Colors.grey.shade200 : color.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: disabled ? Colors.grey : color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: disabled ? Colors.grey : color)),
        ]),
      ),
    );
  }

  // ── Post button ───────────────────────────────────────────────────────────

  Widget _buildPostButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton.icon(
        onPressed: _isPosting ? null : _submit,
        icon: const Icon(Icons.send_rounded, size: 18),
        label: Text(
          _isEditMode ? 'Update Post' : 'Post',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.deepPurple,
          foregroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 2,
        ),
      ),
    );
  }
}

// ── Date picker button ────────────────────────────────────────────────────────

class _DatePickerBtn extends StatelessWidget {
  final String label;
  final DateTime? date;
  final Color color;
  final ValueChanged<DateTime?> onPicked;

  const _DatePickerBtn({
    required this.label,
    required this.date,
    required this.color,
    required this.onPicked,
  });

  String _fmt(DateTime d) {
    const m = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${d.day} ${m[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (picked != null) onPicked(picked);
      },
      onLongPress: () => onPicked(null),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: date != null ? color.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color:
                  date != null ? color.withOpacity(0.4) : Colors.grey.shade300),
        ),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined,
              size: 14, color: date != null ? color : Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              date != null ? _fmt(date!) : label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: date != null ? color : Colors.grey,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (date != null)
            GestureDetector(
              onTap: () => onPicked(null),
              child: Icon(Icons.close, size: 14, color: color),
            ),
        ]),
      ),
    );
  }
}

// ── Link entry with controllers ───────────────────────────────────────────────

class _LinkEntry {
  final TextEditingController urlCtrl;
  final TextEditingController labelCtrl;

  _LinkEntry({String url = '', String label = ''})
      : urlCtrl = TextEditingController(text: url),
        labelCtrl = TextEditingController(text: label);

  void dispose() {
    urlCtrl.dispose();
    labelCtrl.dispose();
  }
}
