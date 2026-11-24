import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> kIssueTypes = [
  'App Bug / Crash',
  'Inappropriate Ad',
  'Fake Listing',
  'Wrong Campus Data',
  'Account Issue',
  'Other',
];

class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});

  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _descController = TextEditingController();
  String? _selectedIssue;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedIssue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select an issue type')));
      return;
    }
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please describe the problem')));
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await FirebaseFirestore.instance.collection('reports').add({
        'issueType': _selectedIssue,
        'description': _descController.text.trim(),
        'userId': user?.uid ?? '',
        'userEmail': user?.email ?? '',
        'reportedAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('✅ Report submitted. Thank you!'),
            backgroundColor: Colors.green));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Report a Problem'),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('What kind of issue are you facing?',
              style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 12),

          // Issue type dropdown
          DropdownButtonFormField<String>(
            value: _selectedIssue,
            decoration: InputDecoration(
              hintText: 'Select issue type',
              prefixIcon: const Icon(Icons.flag_outlined,
                  color: Colors.deepPurple, size: 20),
              filled: true, fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple)),
            ),
            items: kIssueTypes.map((t) =>
                DropdownMenuItem(value: t, child: Text(t))).toList(),
            onChanged: (v) => setState(() => _selectedIssue = v),
          ),
          const SizedBox(height: 16),

          Text('Describe the problem',
              style: TextStyle(fontSize: 15,
                  fontWeight: FontWeight.w600, color: Colors.black87)),
          const SizedBox(height: 12),

          TextField(
            controller: _descController,
            maxLines: 5,
            decoration: InputDecoration(
              hintText: 'Give as much detail as possible...',
              hintStyle: TextStyle(
                  color: Colors.grey.shade400, fontSize: 13),
              filled: true, fillColor: const Color(0xFFF8F8F8),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Colors.deepPurple)),
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity, height: 52,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSubmitting
                  ? const SizedBox(height: 20, width: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2))
                  : const Text('Submit Report',
                  style: TextStyle(fontSize: 15,
                      fontWeight: FontWeight.w600, color: Colors.white)),
            ),
          ),
        ]),
      ),
    );
  }
}