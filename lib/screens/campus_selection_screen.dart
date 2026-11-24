import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/campus_model.dart';
import '../services/campus_service.dart';
import 'home_screen.dart';

class CampusSelectionScreen extends StatefulWidget {
  const CampusSelectionScreen({super.key});

  @override
  State<CampusSelectionScreen> createState() =>
      _CampusSelectionScreenState();
}

class _CampusSelectionScreenState extends State<CampusSelectionScreen> {
  final CampusService _campusService = CampusService();
  final TextEditingController _searchController = TextEditingController();

  // ── State ──────────────────────────────────────────────────────────────────
  List<CampusModel> _allCampuses = [];
  List<CampusModel> _searchResults = [];
  CampusModel? _selectedCampus;

  bool _isLoading = true;
  bool _isSearching = false;
  bool _isConfirming = false;
  String? _errorMessage;

  // ── Debounce timer ─────────────────────────────────────────────────────────
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _loadCampuses();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ── Load initial campus list from Firestore ────────────────────────────────
  Future<void> _loadCampuses() async {
    try {
      final campuses = await _campusService.fetchCampuses();
      setState(() {
        _allCampuses = campuses;
        _searchResults = campuses;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Debounced search using Algolia ────────────────────────────────────────
  void _onSearchChanged() {
    final query = _searchController.text.trim();

    _debounce?.cancel();

    if (query.isEmpty) {
      setState(() {
        _searchResults = _allCampuses;
        _isSearching = false;
        _selectedCampus = null;
      });
      return;
    }

    // Show loading immediately
    setState(() => _isSearching = true);

    // Debounce 400ms — only search after user stops typing
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      try {
        final results =
        await _campusService.searchCampusesAlgolia(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isSearching = false;
          });
        }
      } catch (e) {
        // Algolia failed — fall back to local filter
        if (mounted) {
          setState(() {
            _searchResults =
                _campusService.filterLocally(_allCampuses, query);
            _isSearching = false;
          });
        }
      }
    });
  }

  // ── Confirm campus selection ──────────────────────────────────────────────
  Future<void> _confirmSelection() async {
    if (_selectedCampus == null) return;
    setState(() => _isConfirming = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      await _campusService.updateUserCampus(
        userId: user.uid,
        campus: _selectedCampus!,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  // ── Open request campus sheet ─────────────────────────────────────────────
  void _openRequestSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _RequestCampusSheet(),
    );
  }

  // ── Campus tile ───────────────────────────────────────────────────────────
  Widget _buildCampusTile(CampusModel campus) {
    final isSelected = _selectedCampus?.id == campus.id;

    // ── Filter colleges that match search query ───────────────────────────────
    final query = _searchController.text.toLowerCase().trim();
    final matchingColleges = query.isEmpty
        ? campus.colleges
        : campus.colleges
        .where((c) => c.toLowerCase().contains(query))
        .toList();

    return GestureDetector(
      onTap: () => setState(() => _selectedCampus = campus),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.deepPurple.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? Colors.deepPurple
                : Colors.grey.shade200,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── University name — primary heading ─────────
                      Text(
                        campus.name,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? Colors.deepPurple
                              : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      // ── District, State ───────────────────────────
                      Text(
                        '${campus.district}, ${campus.state}',
                        style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle,
                      color: Colors.deepPurple, size: 22),
              ],
            ),

            // ── Colleges list underneath ──────────────────────────────
            if (campus.colleges.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFEEEEEE)),
              const SizedBox(height: 8),

              // ── Show all colleges or matching ones ────────────────
              ...( matchingColleges.isEmpty
                  ? campus.colleges
                  : matchingColleges)
                  .map(
                    (college) => Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Dot indicator
                      Padding(
                        padding: const EdgeInsets.only(top: 5, right: 8),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.deepPurple.shade300
                                : Colors.grey.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      // College name
                      Expanded(
                        child: _buildHighlightedText(
                          college,
                          query,
                          isSelected,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

// ── Highlight matching text in college name ───────────────────────────────────
  Widget _buildHighlightedText(
      String text, String query, bool isSelected) {
    if (query.isEmpty) {
      return Text(
        text,
        style: TextStyle(
          fontSize: 13,
          color: isSelected
              ? Colors.deepPurple.shade700
              : Colors.grey.shade700,
        ),
      );
    }

    final lowerText = text.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerText.indexOf(lowerQuery);

    // No match — show plain text
    if (matchIndex == -1) {
      return Text(
        text,
        style: TextStyle(
            fontSize: 13, color: Colors.grey.shade700),
      );
    }

    // ── Highlight the matched portion ────────────────────────────────────────
    final before = text.substring(0, matchIndex);
    final match = text.substring(matchIndex, matchIndex + query.length);
    final after = text.substring(matchIndex + query.length);

    return RichText(
      text: TextSpan(
        style: TextStyle(
            fontSize: 13,
            color: isSelected
                ? Colors.deepPurple.shade700
                : Colors.grey.shade700),
        children: [
          TextSpan(text: before),
          TextSpan(
            text: match,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
              backgroundColor:
              Colors.deepPurple.withOpacity(0.1),
            ),
          ),
          TextSpan(text: after),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F8F8),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Select Your Campus',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Search bar ──────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by campus, district or state...',
                hintStyle: TextStyle(
                    color: Colors.grey.shade400, fontSize: 14),
                prefixIcon: Icon(Icons.search,
                    color: Colors.grey.shade400),
                // ── Show Algolia powered badge ──────────────────────
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                )
                    : Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Image.asset(
                    'assets/algolia_logo.png',
                    height: 16,
                    errorBuilder: (_, __, ___) =>
                    const SizedBox.shrink(),
                  ),
                ),
                filled: true,
                fillColor: const Color(0xFFF3F3F3),
                contentPadding:
                const EdgeInsets.symmetric(vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),

          // ── Results count ───────────────────────────────────────────
          if (_searchController.text.isNotEmpty && !_isSearching)
            Padding(
              padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_searchResults.length} result${_searchResults.length == 1 ? '' : 's'} found',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey.shade500),
                ),
              ),
            ),

          // ── Campus list ─────────────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                child: Text(_errorMessage!,
                    style:
                    const TextStyle(color: Colors.red)))
                : _isSearching
                ? const Center(
                child: CircularProgressIndicator(
                    color: Colors.deepPurple))
                : _searchResults.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
              padding: const EdgeInsets.only(
                  top: 8, bottom: 20),
              itemCount: _searchResults.length,
              itemBuilder: (_, index) =>
                  _buildCampusTile(
                      _searchResults[index]),
            ),
          ),

          // ── Bottom buttons ──────────────────────────────────────────
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.school_outlined,
              size: 60, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No campuses found',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Text('Try a different search term',
              style: TextStyle(
                  fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }

  Widget _buildBottomSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed:
              _selectedCampus == null ? null : _confirmSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                disabledBackgroundColor: Colors.grey.shade200,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isConfirming
                  ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : Text(
                _selectedCampus == null
                    ? 'Select a Campus'
                    : 'Confirm — ${_selectedCampus!.name}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _selectedCampus == null
                      ? Colors.grey
                      : Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _openRequestSheet,
            child: const Text(
              'Campus not found? Request to add it',
              style: TextStyle(
                color: Colors.deepPurple,
                fontSize: 13,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Request Campus Bottom Sheet ───────────────────────────────────────────────
class _RequestCampusSheet extends StatefulWidget {
  const _RequestCampusSheet();

  @override
  State<_RequestCampusSheet> createState() =>
      _RequestCampusSheetState();
}

class _RequestCampusSheetState extends State<_RequestCampusSheet> {
  final CampusService _campusService = CampusService();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _districtController =
  TextEditingController();
  final TextEditingController _stateController = TextEditingController();

  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _districtController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      await _campusService.submitCampusRequest(
        name: _nameController.text,
        district: _districtController.text,
        state: _stateController.text,
        userId: user.uid,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                '✅ Request submitted! Your campus will be available after verification.'),
            duration: Duration(seconds: 4),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon:
          Icon(icon, color: Colors.deepPurple, size: 20),
          filled: true,
          fillColor: const Color(0xFFF3F3F3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
                color: Colors.deepPurple, width: 1.5),
          ),
        ),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return '$label is required';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Request a Campus',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87)),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
                'Your request will be reviewed and added after verification.',
                style: TextStyle(
                    fontSize: 13, color: Colors.grey.shade500)),
            const SizedBox(height: 20),
            _buildField(
              controller: _nameController,
              label: 'Campus Name',
              hint: 'e.g. Anna University',
              icon: Icons.school_outlined,
            ),
            _buildField(
              controller: _districtController,
              label: 'District',
              hint: 'e.g. Chennai',
              icon: Icons.location_city_outlined,
            ),
            _buildField(
              controller: _stateController,
              label: 'State',
              hint: 'e.g. Tamil Nadu',
              icon: Icons.map_outlined,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Text('Submit Request',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}