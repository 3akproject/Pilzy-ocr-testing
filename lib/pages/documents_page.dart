import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

class DocumentsPage extends StatefulWidget {
  final int? userId;

  const DocumentsPage({super.key, this.userId});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends State<DocumentsPage> {
  List<_DocumentItem> _documents = [];

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  // ================= LOAD / SAVE JSON =================

  Future<File> _getJsonFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final fileName = widget.userId != null 
        ? 'documents_${widget.userId}.json'
        : 'documents.json';
    return File('${dir.path}/$fileName');
  }

  Future<void> _loadDocuments() async {
    final file = await _getJsonFile();
    if (!await file.exists()) return;

    final content = await file.readAsString();
    final List data = jsonDecode(content);

    setState(() {
      _documents = data.map((e) => _DocumentItem.fromMap(e)).toList();
    });
  }

  Future<void> _saveDocuments() async {
    final file = await _getJsonFile();
    final data = _documents.map((e) => e.toMap()).toList();
    await file.writeAsString(jsonEncode(data));
  }

  // ================= PICK & SAVE FILE =================

  Future<void> _pickAndSaveFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'mp3', 'wav'],
    );

    if (result == null) return;

    final originalFile = File(result.files.single.path!);

    final nameController =
        TextEditingController(text: result.files.single.name);
    final descController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Save Document"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "File Name"),
            ),
            TextField(
              controller: descController,
              decoration:
                  const InputDecoration(labelText: "Description (optional)"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Save")),
        ],
      ),
    );

    if (confirmed != true) return;

    final dir = await getApplicationDocumentsDirectory();
    final newPath =
        '${dir.path}/${DateTime.now().millisecondsSinceEpoch}_${nameController.text}';
    final savedFile = await originalFile.copy(newPath);

    final item = _DocumentItem(
      fileName: nameController.text,
      filePath: savedFile.path,
      description: descController.text.trim(),
      savedDate: DateTime.now(),
    );

    setState(() => _documents.add(item));
    await _saveDocuments();
  }

  // ================= EDIT =================

  Future<void> _editDocument(int index) async {
    final doc = _documents[index];
    final nameController = TextEditingController(text: doc.fileName);
    final descController = TextEditingController(text: doc.description);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Document"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "File Name"),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: "Description"),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Save")),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _documents[index] = doc.copyWith(
        fileName: nameController.text,
        description: descController.text.trim(),
      );
    });

    await _saveDocuments();
  }

  // ================= DELETE =================

  Future<void> _deleteDocument(int index) async {
    final doc = _documents[index];
    final file = File(doc.filePath);
    if (await file.exists()) await file.delete();

    setState(() => _documents.removeAt(index));
    await _saveDocuments();
  }

  // ================= UI HELPERS =================

  String _formatDate(DateTime date) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(date);

  IconData _getFileIcon(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return Icons.picture_as_pdf;
    if (lower.endsWith('.mp3') || lower.endsWith('.wav')) {
      return Icons.audiotrack;
    }
    return Icons.image;
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Medical Documents")),
      body: Column(
        children: [
          Expanded(
            child: _documents.isEmpty
                ? const Center(child: Text("No documents saved"))
                : ListView.builder(
                    itemCount: _documents.length,
                    itemBuilder: (context, index) {
                      final doc = _documents[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        child: ListTile(
                          onTap: () => OpenFile.open(doc.filePath),
                          leading: Icon(_getFileIcon(doc.fileName),
                              size: 36, color: Colors.blueGrey),
                          title: Text(doc.fileName),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (doc.description.isNotEmpty)
                                Text(doc.description),
                              const SizedBox(height: 4),
                              Text("Saved: ${_formatDate(doc.savedDate)}",
                                  style: const TextStyle(fontSize: 12)),
                            ],
                          ),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') _editDocument(index);
                              if (value == 'delete') _deleteDocument(index);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                  value: 'edit', child: Text('Edit')),
                              PopupMenuItem(
                                  value: 'delete', child: Text('Delete')),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _pickAndSaveFile,
                  icon: const Icon(Icons.add),
                  label: const Text("Add New File"),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================= MODEL =================

class _DocumentItem {
  final String fileName;
  final String filePath;
  final String description;
  final DateTime savedDate;

  _DocumentItem({
    required this.fileName,
    required this.filePath,
    required this.description,
    required this.savedDate,
  });

  Map<String, dynamic> toMap() => {
        'fileName': fileName,
        'filePath': filePath,
        'description': description,
        'savedDate': savedDate.toIso8601String(),
      };

  factory _DocumentItem.fromMap(Map<String, dynamic> map) => _DocumentItem(
        fileName: map['fileName'],
        filePath: map['filePath'],
        description: map['description'],
        savedDate: DateTime.parse(map['savedDate']),
      );

  _DocumentItem copyWith({
    String? fileName,
    String? description,
  }) =>
      _DocumentItem(
        fileName: fileName ?? this.fileName,
        filePath: filePath,
        description: description ?? this.description,
        savedDate: savedDate,
      );
}