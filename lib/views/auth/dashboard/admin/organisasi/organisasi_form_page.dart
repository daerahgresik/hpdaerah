import 'package:flutter/material.dart';
import 'package:hpdaerah/models/organization_model.dart';
import 'package:hpdaerah/services/organization_service.dart';

class OrganisasiFormDialog extends StatefulWidget {
  final String? parentId;
  final int parentLevel;
  final Organization? organization;

  const OrganisasiFormDialog({
    super.key,
    this.parentId,
    required this.parentLevel,
    this.organization,
  });

  @override
  State<OrganisasiFormDialog> createState() => _OrganisasiFormDialogState();
}

class _OrganisasiFormDialogState extends State<OrganisasiFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final OrganizationService _service = OrganizationService();

  // Multi-select state untuk Kategori
  final List<String> _selectedCategories = [];
  bool _isLoading = false;

  // Standar Penamaan SESUAI ATURAN BARU
  final List<String> _ageCategories = [
    'Kelompok', // Pengganti Dewasa/Orang Tua
    'Muda-mudi',
    'Praremaja',
    'Caberawit',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.organization != null) {
      _nameController.text = widget.organization!.name;
      // Logic untuk edit mode jika diperlukan
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  int get _targetLevel =>
      widget.organization?.level ??
      (widget.parentId == null ? 0 : widget.parentLevel + 1);

  String get _targetType {
    switch (_targetLevel) {
      case 0:
        return 'daerah';
      case 1:
        return 'desa';
      case 2:
        return 'kelompok';
      case 3:
        return 'kategori_usia';
      default:
        return 'unknown';
    }
  }

  String _getLevelLabel() {
    switch (_targetLevel) {
      case 0:
        return 'Nama Daerah';
      case 1:
        return 'Nama Desa';
      case 2:
        return 'Nama Kelompok';
      case 3:
        return 'Kategori';
      default:
        return 'Nama Organisasi';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final isEditing = widget.organization != null;
    final isKategoriLevel = _targetLevel == 3;

    try {
      if (isEditing) {
        // --- EDIT MODE (Single Item) ---
        String finalName = _nameController.text.trim();

        final updatedOrg = Organization(
          id: widget.organization!.id,
          name: finalName,
          type: widget.organization!.type,
          parentId: widget.organization!.parentId,
          level: widget.organization!.level,
          ageCategory: isKategoriLevel ? finalName.toLowerCase() : null,
        );
        await _service.updateOrganization(updatedOrg);
      } else {
        // --- CREATE MODE ---

        if (isKategoriLevel) {
          // ** BULK CREATE KATEGORI **
          if (_selectedCategories.isEmpty) {
            throw 'Pilih minimal satu kategori!';
          }

          // Loop insert setiap kategori yang dipilih
          for (String categoryName in _selectedCategories) {
            final newOrg = Organization(
              id: '',
              name: categoryName,
              type: _targetType,
              parentId: widget.parentId,
              level: _targetLevel,
              ageCategory: categoryName.toLowerCase(),
            );
            await _service.createOrganization(newOrg);
            // Jeda sebentar untuk memastikan timestamp unik (jika random generator bermasalah)
            await Future.delayed(const Duration(milliseconds: 100));
          }
        } else {
          // ** SINGLE CREATE (Daerah/Desa/Kelompok) **
          final newOrg = Organization(
            id: '',
            name: _nameController.text.trim(),
            type: _targetType,
            parentId: widget.parentId,
            level: _targetLevel,
            ageCategory: null,
          );
          await _service.createOrganization(newOrg);
        }
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isKategoriLevel && !isEditing
                  ? 'Berhasil menyimpan ${_selectedCategories.length} kategori'
                  : 'Berhasil disimpan',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Gagal: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.organization != null;
    final isKategoriCreate = _targetLevel == 3 && !isEditing;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        isEditing ? 'Edit ${_getLevelLabel()}' : 'Tambah ${_getLevelLabel()}',
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // JIKA CREATE KATEGORI (Use Multi-Select Chips)
              if (isKategoriCreate) ...[
                const Text(
                  "Pilih Kategori (Bisa lebih dari satu):",
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _ageCategories.map((cat) {
                    final isSelected = _selectedCategories.contains(cat);
                    return FilterChip(
                      label: Text(cat),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedCategories.add(cat);
                          } else {
                            _selectedCategories.remove(cat);
                          }
                        });
                      },
                      selectedColor: const Color(0xFF1A5F2D),
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black87,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                      backgroundColor: Colors.grey[200],
                    );
                  }).toList(),
                ),
                if (_selectedCategories.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 8.0),
                    child: Text(
                      "* Wajib pilih minimal satu",
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
              ]
              // JIKA EDIT ATAU BUKAN KATEGORI (Use Text Input)
              else ...[
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: _getLevelLabel(),
                    hintText:
                        'Contoh: ${_targetLevel == 0 ? "Daerah Pusat" : "Kelompok 1"}',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey[50],
                  ),
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Wajib diisi' : null,
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.all(20),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1A5F2D),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('Simpan'),
        ),
      ],
    );
  }
}
