import '../models/patient.dart';
import '../models/alert.dart';
import '../models/hospital_data.dart';

class ApiService {
  // Simulate network delay
  Future<void> _delay() => Future.delayed(const Duration(milliseconds: 800));

  Future<HospitalStats> getDashboardStats() async {
    await _delay();
    // This will eventually call: http.get(Uri.parse('$baseUrl/stats'));
    return HospitalStats(
      activePatients: 1240,
      availableWards: 12,
      systemHealth: '98%',
      staffOnDuty: 24,
    );
  }

  Future<List<Patient>> getPatients() async {
    await _delay();
    return List.generate(10, (index) => Patient(
      id: 'PT-${4590 + index}',
      name: 'Patient Case #${1000 + index}',
      age: 30 + index,
      gender: index % 2 == 0 ? 'Male' : 'Female',
      status: 'Monitored',
      lastUpdated: DateTime.now().subtract(Duration(minutes: index * 10)),
    ));
  }

  Future<List<ClinicalAlert>> getAlerts() async {
    await _delay();
    return [
      ClinicalAlert(
        id: '1',
        title: 'High Priority',
        description: 'Urgent attention required in Room 402. Patient vitals fluctuating.',
        isCritical: true,
        timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      ClinicalAlert(
        id: '2',
        title: 'General Update',
        description: 'Daily ward rotation schedule for next week is now available.',
        isCritical: false,
        timestamp: DateTime.now().subtract(const Duration(minutes: 17)),
      ),
    ];
  }

  Future<List<WardInfo>> getWards() async {
    await _delay();
    return [
      WardInfo(name: 'Intensive Care Unit (ICU)', occupied: 4, total: 5, type: 'Critical'),
      WardInfo(name: 'Post-Operative Recovery', occupied: 12, total: 15, type: 'Standard'),
      WardInfo(name: 'Maternity Ward', occupied: 2, total: 10, type: 'Standard'),
    ];
  }

  Future<List<StaffInfo>> getStaff() async {
    await _delay();
    return [
      StaffInfo(name: 'Lead Medical Officer', role: 'Clinical Oversight', status: 'On Duty'),
      StaffInfo(name: 'Nursing Supervisor', role: 'Shift Management', status: 'Active'),
      StaffInfo(name: 'Diagnostics Specialist', role: 'Lab Operations', status: 'Available'),
    ];
  }
}
