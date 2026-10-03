import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/database/app_database.dart';
import '../../logic/providers/document_provider.dart';

class AddEditDocumentScreen extends StatefulWidget {
  final Document? documentToEdit;

  const AddEditDocumentScreen({super.key, this.documentToEdit});

  @override
  State<AddEditDocumentScreen> createState() => _AddEditDocumentScreenState();
}

class _AddEditDocumentScreenState extends State<AddEditDocumentScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _titleController;
  late TextEditingController _subjectController;
  late TextEditingController _filePathController;
  late String _selectedCategory;
  late DateTime _selectedDate;
  bool _isSaving = false;

  final List<String> _categoryOptions = [
    'Slide',
    'Bài tập',
    'Sách',
    'Tài liệu khác',
  ];

  @override
  void initState() {
    super.initState();
    final doc = widget.documentToEdit;
    _titleController = TextEditingController(text: doc?.title ?? '');
    _subjectController = TextEditingController(text: doc?.subject ?? '');
    _filePathController = TextEditingController(text: doc?.filePath ?? '');
    _selectedCategory = doc != null && _categoryOptions.contains(doc.category)
        ? doc.category
        : _categoryOptions.first;
    _selectedDate = doc?.createdAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subjectController.dispose();
    _filePathController.dispose();
    super.dispose();
  }

  Future<void> _pickDateTime() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDate),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final provider = context.read<DocumentProvider>();

    try {
      if (widget.documentToEdit == null) {
        // Thêm mới
        await provider.addDocument(
          title: _titleController.text,
          subject: _subjectController.text,
          category: _selectedCategory,
          filePath: _filePathController.text,
          createdAt: _selectedDate,
        );
      } else {
        // Cập nhật
        final updated = widget.documentToEdit!.copyWith(
          title: _titleController.text.trim(),
          subject: _subjectController.text.trim(),
          category: _selectedCategory,
          filePath: _filePathController.text.trim(),
          createdAt: _selectedDate,
        );
        await provider.updateExistingDocument(updated);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.documentToEdit == null
                  ? 'Đã thêm tài liệu thành công!'
                  : 'Đã cập nhật tài liệu thành công!',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.documentToEdit != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Chỉnh sửa tài liệu' : 'Thêm tài liệu mới'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tiêu đề
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'Tiêu đề tài liệu *',
                  hintText: 'VD: Slide Bài giảng Tuần 1, Đề thi mẫu...',
                  prefixIcon: const Icon(Icons.title_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.next,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tiêu đề tài liệu';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Môn học
              TextFormField(
                controller: _subjectController,
                decoration: InputDecoration(
                  labelText: 'Môn học *',
                  hintText: 'VD: Lập trình di động, Cấu trúc dữ liệu...',
                  prefixIcon: const Icon(Icons.school_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.next,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tên môn học';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Loại tài liệu Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Loại tài liệu',
                  prefixIcon: const Icon(Icons.category_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: _categoryOptions.map((cat) {
                  return DropdownMenuItem(
                    value: cat,
                    child: Text(cat),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 16),

              // Đường dẫn / Link file
              TextFormField(
                controller: _filePathController,
                decoration: InputDecoration(
                  labelText: 'Đường dẫn / Link tài liệu *',
                  hintText: 'https://drive.google.com/... hoặc D:/Docs/slide.pdf',
                  prefixIcon: const Icon(Icons.link_rounded),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                textInputAction: TextInputAction.done,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập đường dẫn hoặc link file';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Chọn ngày tạo
              InkWell(
                onTap: _pickDateTime,
                borderRadius: BorderRadius.circular(12),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Thời gian tạo',
                    prefixIcon: const Icon(Icons.calendar_today_rounded),
                    suffixIcon: const Icon(Icons.arrow_drop_down),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    DateFormat('dd/MM/yyyy HH:mm').format(_selectedDate),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Nút lưu
              FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded),
                label: Text(
                  _isSaving
                      ? 'Đang lưu...'
                      : (isEditing ? 'Lưu thay đổi' : 'Thêm tài liệu'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
