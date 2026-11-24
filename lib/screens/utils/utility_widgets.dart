import 'package:flutter/material.dart';

Widget _placeholderCard({required IconData icon, required String text}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: const Color(0xFFF8F5FF),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
          color: Colors.deepPurple.withOpacity(0.2), width: 0.8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.deepPurple, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
                height: 1.5),
          ),
        ),
      ],
    ),
  );
}

Widget _infoPoint(IconData icon, String text) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.deepPurple, size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text,
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4)),
        ),
      ],
    ),
  );
}