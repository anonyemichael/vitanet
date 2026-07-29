import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vitanet/core/constants/app_spacing.dart';
import 'package:vitanet/core/extensions/context_ext.dart';

class DeviceConnectionScreen extends StatefulWidget {
  final String metricId;

  const DeviceConnectionScreen({
    super.key,
    required this.metricId,
  });

  @override
  State<DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<DeviceConnectionScreen> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _isConnecting = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _simulateConnection() async {
    setState(() => _isConnecting = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        _isConnecting = false;
        _isConnected = true;
      });
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) context.pop();
      });
    }
  }

  String _getDeviceName() {
    switch (widget.metricId) {
      case 'heart_rate':
        return 'Heart Rate Monitor';
      case 'blood_oxygen':
        return 'Pulse Oximeter';
      case 'temperature':
        return 'Smart Thermometer';
      case 'respiratory_rate':
        return 'Respiratory Sensor';
      default:
        return 'Health Device';
    }
  }

  IconData _getDeviceIcon() {
    switch (widget.metricId) {
      case 'heart_rate':
        return Icons.favorite_rounded;
      case 'blood_oxygen':
        return Icons.air_rounded;
      case 'temperature':
        return Icons.thermostat_rounded;
      case 'respiratory_rate':
        return Icons.water_drop_rounded;
      default:
        return Icons.devices_rounded;
    }
  }

  Color _getDeviceColor() {
    switch (widget.metricId) {
      case 'heart_rate':
        return const Color(0xFFEC4899);
      case 'blood_oxygen':
        return const Color(0xFF8B5CF6);
      case 'temperature':
        return const Color(0xFF3B82F6);
      case 'respiratory_rate':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF6366F1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.isDark ? Colors.white : Colors.black87,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Connect Device',
          style: TextStyle(
            color: context.isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 800) {
            return _buildMobileLayout(context);
          } else {
            return _buildDesktopLayout(context);
          }
        },
      ),
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Expanded(
            child: _buildRadarAnimation(),
          ),
          if (!_isConnected)
            _buildDeviceListSheet(),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: _buildRadarAnimation(),
        ),
        if (!_isConnected)
          Container(
            width: 400,
            margin: const EdgeInsets.all(AppSpacing.xxl),
            decoration: BoxDecoration(
              color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
              ),
              boxShadow: [
                if (!context.isDark)
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: _buildDeviceListSheet(isDesktop: true),
            ),
          ),
      ],
    );
  }

  Widget _buildRadarAnimation() {
    final deviceColor = _getDeviceColor();
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 160 + (_pulseController.value * 40),
                height: 160 + (_pulseController.value * 40),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: deviceColor.withValues(alpha: 0.1 - (_pulseController.value * 0.05)),
                ),
                child: Center(
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: deviceColor.withValues(alpha: 0.2),
                    ),
                    child: Center(
                      child: Icon(
                        _isConnected ? Icons.check_circle_rounded : _getDeviceIcon(),
                        size: 64,
                        color: deviceColor,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: AppSpacing.xxl),
          Text(
            _isConnected ? 'Connected!' : 'Searching for nearby devices...',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _isConnected
                ? 'Your ${_getDeviceName()} is now paired.'
                : 'Make sure your ${_getDeviceName()} is turned on and in pairing mode.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: context.isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceListSheet({bool isDesktop = false}) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDesktop ? Colors.transparent : (context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
        borderRadius: isDesktop ? BorderRadius.zero : const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: isDesktop ? [] : [
          if (!context.isDark)
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -10),
            ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: isDesktop ? MainAxisSize.max : MainAxisSize.min,
        children: [
          Text(
            'Available Devices',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: context.isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildDeviceTile(
            name: 'VitaBand Pro',
            subtitle: 'Signal: Strong',
            icon: Icons.watch_rounded,
            onTap: _isConnecting ? null : _simulateConnection,
          ),
          const SizedBox(height: AppSpacing.md),
          _buildDeviceTile(
            name: 'Unknown Device',
            subtitle: 'Signal: Weak',
            icon: Icons.bluetooth_rounded,
            onTap: null,
          ),
          if (isDesktop) const Spacer(),
          if (!isDesktop) const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }

  Widget _buildDeviceTile({
    required String name,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: context.isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.isDark ? Colors.white12 : Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: context.isDark ? Colors.white70 : Colors.black87),
        ),
        title: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: context.isDark ? Colors.white : Colors.black87,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(
            color: context.isDark ? Colors.white54 : Colors.black54,
            fontSize: 13,
          ),
        ),
        trailing: onTap != null
            ? _isConnecting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: onTap,
                    style: TextButton.styleFrom(
                      backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.1),
                      foregroundColor: const Color(0xFF6366F1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Connect'),
                  )
            : Text(
                'Unsupported',
                style: TextStyle(
                  color: context.isDark ? Colors.white38 : Colors.black38,
                  fontSize: 12,
                ),
              ),
      ),
    );
  }
}
