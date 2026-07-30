import 'package:flutter/material.dart';
import '../services/hospital_api_service.dart';
import '../models/patient.dart';

class AdminPatientDataPage extends StatefulWidget {
  const AdminPatientDataPage({super.key});

  @override
  State<AdminPatientDataPage> createState() => _AdminPatientDataPageState();
}

class _AdminPatientDataPageState extends State<AdminPatientDataPage> {
  final ApiService _apiService = ApiService();
  List<Patient>? _allPatients;
  List<Patient>? _filteredPatients;
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPatients() async {
    try {
      final patients = await _apiService.getPatients();
      setState(() {
        _allPatients = patients;
        _filteredPatients = patients;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _filterPatients(String query) {
    if (_allPatients == null) return;
    setState(() {
      _filteredPatients = _allPatients!
          .where((p) =>
              p.name.toLowerCase().contains(query.toLowerCase()) ||
              p.id.toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  void _addPatient() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Add New Patient Entry', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            const TextField(decoration: InputDecoration(labelText: 'Patient Full Name', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Age', border: OutlineInputBorder())),
            const SizedBox(height: 16),
            const TextField(decoration: InputDecoration(labelText: 'Gender', border: OutlineInputBorder())),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('New patient entry registered.')),
                  );
                },
                child: const Text('Register Patient'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPatientDetails(Patient patient) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(patient.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ID: ${patient.id}'),
            Text('Age: ${patient.age}'),
            Text('Gender: ${patient.gender}'),
            Text('Status: ${patient.status}'),
            const SizedBox(height: 16),
            const Text('Clinical Notes:', style: TextStyle(fontWeight: FontWeight.bold)),
            const Text('Patient is showing steady recovery in stable condition.'),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Update History')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : const Color(0xFFF1F8FE),
      appBar: AppBar(
        title: const Text('Patient Registry'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(80),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: TextField(
              controller: _searchController,
              onChanged: _filterPatients,
              decoration: InputDecoration(
                hintText: 'Search by identifier or name...',
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: _searchController.text.isNotEmpty 
                  ? IconButton(icon: const Icon(Icons.clear), onPressed: () {
                      _searchController.clear();
                      _filterPatients('');
                    }) 
                  : null,
                filled: true,
                fillColor: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
                hintStyle: TextStyle(fontSize: 15, color: colorScheme.onSurfaceVariant.withAlpha(150)),
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadPatients,
              child: LayoutBuilder(
              builder: (context, constraints) {
                double horizontalPadding = constraints.maxWidth > 800 ? (constraints.maxWidth - 800) / 2 : 16;
                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 16),
                  itemCount: _filteredPatients?.length ?? 0,
                  itemBuilder: (context, index) {
                    final patient = _filteredPatients![index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: isDark ? colorScheme.surfaceContainerHighest.withAlpha(50) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: isDark ? [] : [
                            BoxShadow(
                              color: Colors.black.withAlpha(5),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            )
                          ],
                          border: Border.all(
                            color: isDark ? colorScheme.outlineVariant : Colors.transparent,
                            width: 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          leading: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: colorScheme.primary.withAlpha(20),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(Icons.person_outline, color: colorScheme.primary),
                          ),
                          title: Text(
                            patient.name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(
                              'ID: ${patient.id} • ${patient.gender} • ${patient.age} Yrs',
                              style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: patient.status == 'Critical' 
                                  ? Colors.red.withAlpha(20)
                                  : patient.status == 'Monitored' 
                                      ? Colors.orange.withAlpha(20)
                                      : Colors.green.withAlpha(20),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: patient.status == 'Critical' 
                                  ? Colors.red.withAlpha(50)
                                  : patient.status == 'Monitored' 
                                      ? Colors.orange.withAlpha(50)
                                      : Colors.green.withAlpha(50),
                              ),
                            ),
                            child: Text(
                              patient.status,
                              style: TextStyle(
                                color: patient.status == 'Critical' 
                                  ? Colors.red[700]
                                  : patient.status == 'Monitored' 
                                      ? Colors.orange[800]
                                      : Colors.green[700],
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          onTap: () => _showPatientDetails(patient),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPatient,
        backgroundColor: colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_alt_1_outlined),
        label: const Text('Add Entry'),
        elevation: 2,
      ),
    );
  }
}


