import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/supabase_service.dart';

const Color primaryBlue = Color.fromARGB(255, 79, 134, 224);

class IzinCutiScreen extends StatefulWidget {
  const IzinCutiScreen({super.key});

  @override
  State<IzinCutiScreen> createState() => _IzinCutiScreenState();
}

class _IzinCutiScreenState extends State<IzinCutiScreen> {
  final _formKey = GlobalKey<FormState>();

  String name = '';
  String npm = '';
  String jenis = 'Izin';
  String alasan = '';

  DateTime? tanggalMulai;
  DateTime? tanggalSelesai;

  final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  Future<void> _selectDate(BuildContext context, bool isMulai) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() {
        if (isMulai) {
          tanggalMulai = picked;
        } else {
          tanggalSelesai = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text(
            'Ajukan Izin / Cuti / Sakit',
            style: TextStyle(color: Colors.white),),
          backgroundColor: Colors.blue.shade700),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _textField(
                label: 'Nama',
                onChanged: (v) => name = v,
              ),
              const SizedBox(height: 16),
              _textField(
                label: 'NPM',
                onChanged: (v) => npm = v,
              ),
              const SizedBox(height: 20),
              const Text(
                'Jenis Pengajuan',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _radioItem('Izin'),
              _radioItem('Sakit'),
              _radioItem('Cuti'),
              const SizedBox(height: 20),
              _dateField(
                label: 'Tanggal Mulai',
                date: tanggalMulai,
                onTap: () => _selectDate(context, true),
              ),
              const SizedBox(height: 16),
              _dateField(
                label: 'Tanggal Selesai',
                date: tanggalSelesai,
                onTap: () => _selectDate(context, false),
              ),
              const SizedBox(height: 20),
              TextFormField(
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Alasan',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: primaryBlue),
                  ),
                ),
                validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
                onChanged: (v) => alasan = v,
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate() &&
                      tanggalMulai != null &&
                      tanggalSelesai != null) {
                    await SupabaseService.insertIzin(
                      name: name,
                      npm: npm,
                      jenis: jenis,
                      alasan: alasan,
                      tanggalMulai: tanggalMulai!,
                      tanggalSelesai: tanggalSelesai!,
                    );

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Pengajuan berhasil')),
                    );
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Lengkapi semua data & tanggal'),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade800,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'KIRIM',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16
                    ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===== UI HELPERS (TAMPILAN SAJA) =====

  Widget _radioItem(String value) {
    return RadioListTile(
      title: Text(value),
      value: value,
      groupValue: jenis,
      activeColor: primaryBlue,
      contentPadding: EdgeInsets.zero,
      onChanged: (v) => setState(() => jenis = v!),
    );
  }

  Widget _textField({
    required String label,
    required Function(String) onChanged,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: primaryBlue),
        ),
      ),
      validator: (v) => v!.isEmpty ? 'Wajib diisi' : null,
      onChanged: onChanged,
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          border: Border.all(color: primaryBlue),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              date == null ? label : '$label: ${_dateFormat.format(date)}',
              style: TextStyle(
                color: date == null ? Colors.grey : Colors.black,
              ),
            ),
            const Icon(Icons.calendar_month, color: primaryBlue),
          ],
        ),
      ),
    );
  }
}
