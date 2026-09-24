import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';
import 'package:vitanet/core/utils/launch_helpers.dart';

class EmergencyCallCard extends StatelessWidget {
  const EmergencyCallCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, size: 36, color: Color(0xFFDC2626)),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Life-Threatening Emergency?',
            textAlign: TextAlign.center,
            style: context.textTheme.titleMedium?.copyWith(
              color: context.colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => LaunchHelpers.dialOrSnack(context, '911'),
              icon: const Icon(Icons.phone_in_talk_rounded, color: Colors.white),
              label: const Text('Call 911', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LiveLocationCard extends StatefulWidget {
  const LiveLocationCard({super.key});

  @override
  State<LiveLocationCard> createState() => _LiveLocationCardState();
}

class _LiveLocationCardState extends State<LiveLocationCard> {
  Position? _currentPosition;
  String? _currentAddress;
  String _error = '';
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isLoading = true;
  bool _isGeocoding = false;

  @override
  void initState() {
    super.initState();
    _startLocationTracking();
  }

  Future<void> _getAddressFromCoordinates(double lat, double lon) async {
    if (_isGeocoding) return;
    _isGeocoding = true;
    try {
      final url = Uri.parse('https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json');
      final response = await http.get(url, headers: {
        'User-Agent': 'VitaNet/1.0',
      });
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data != null && data['display_name'] != null) {
          if (mounted) {
            setState(() {
              _currentAddress = data['display_name'];
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _currentAddress = 'Address unavailable (using coordinates)';
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _currentAddress = 'Address unavailable (using coordinates)';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _currentAddress = 'Address unavailable (using coordinates)';
        });
      }
    } finally {
      _isGeocoding = false;
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() { _error = 'Location services are disabled.'; _isLoading = false; });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) setState(() { _error = 'Location permission denied.'; _isLoading = false; });
          return;
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        if (mounted) setState(() { _error = 'Location permissions permanently denied.'; _isLoading = false; });
        return;
      }

      // Start listening to the live stream
      final locationSettings = const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      );

      _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings)
          .listen((Position? position) async {
        if (mounted && position != null) {
          setState(() {
            _currentPosition = position;
            _isLoading = false;
            _error = '';
          });
          
          if (_currentAddress == null) {
             _getAddressFromCoordinates(position.latitude, position.longitude);
          }
        }
      }, onError: (e) {
        if (mounted) setState(() { _error = 'Failed to get location.'; _isLoading = false; });
      });

    } catch (e) {
      if (mounted) setState(() { _error = 'Failed to get location.'; _isLoading = false; });
    }
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(color: context.colorScheme.primary.withValues(alpha: 0.2)),
      ),
      elevation: 0,
      color: context.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.my_location_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Text(
                  'Your Live Location',
                  style: context.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: context.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                if (_isLoading)
                  SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: context.colorScheme.primary),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (_error.isNotEmpty)
              Text(_error, style: TextStyle(color: context.colorScheme.error))
            else if (_currentPosition != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.colorScheme.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.colorScheme.primary.withValues(alpha: 0.1)),
                  boxShadow: [
                    if (!context.isDark)
                      BoxShadow(
                        color: context.colorScheme.primary.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_currentAddress != null) ...[
                            Text(
                              _currentAddress!,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, height: 1.3),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_currentAddress == null && !_isLoading) ...[
                            Text(
                              'Finding address...',
                              style: TextStyle(color: context.colorScheme.primary, fontStyle: FontStyle.italic),
                            ),
                            const SizedBox(height: 8),
                          ],
                          Text(
                            'Lat: ${_currentPosition!.latitude.toStringAsFixed(5)} • Lng: ${_currentPosition!.longitude.toStringAsFixed(5)}',
                            style: context.textTheme.bodySmall?.copyWith(
                              color: context.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton(
                      onPressed: () {
                        final textToCopy = _currentAddress != null 
                          ? '$_currentAddress (Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude})'
                          : 'Lat: ${_currentPosition!.latitude}, Lng: ${_currentPosition!.longitude}';
                        Clipboard.setData(ClipboardData(text: textToCopy));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Location copied to clipboard')),
                        );
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: context.colorScheme.primaryContainer,
                      ),
                      icon: Icon(Icons.copy_rounded, color: context.colorScheme.primary, size: 20),
                      tooltip: 'Copy location',
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
