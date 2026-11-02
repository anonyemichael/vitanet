import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// Minimal, enterprise-grade top utility header for AI Chat.
/// 
/// Contains:
/// - Left: Interactive "Recent Chats" trigger button.
/// - Center: "VitaNet AI" with 6px emerald/teal live status dot.
/// - Right: Matched "+ New Chat" action button (38px, BorderRadius.circular(10), 1px border).
/// - YouTube-style scroll auto-hide: smoothly slides up and disappears on scroll down.
class ChatHeader extends ConsumerWidget implements PreferredSizeWidget {
  final VoidCallback onMenuPressed;
  final VoidCallback onNewChatPressed;
  final VoidCallback? onProfilePressed;
  final bool isHistoryOpen;
  final bool isNewChatEnabled;

  const ChatHeader({
    super.key,
    required this.onMenuPressed,
    required this.onNewChatPressed,
    this.onProfilePressed,
    this.isHistoryOpen = false,
    this.isNewChatEnabled = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 800;
    return SafeArea(
      bottom: false,
      child: Container(
            height: 60,
            padding: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
            // Left: Explicit Interactive Recent Chats Button
            _HeaderActionButton(
              icon: Icons.history_rounded,
              label: isDesktop ? 'Recent Chats' : null,
              isActive: isHistoryOpen,
              onTap: onMenuPressed,
              isDark: isDark,
            ),

            // Center: "VitaNet AI" with small 6px emerald status dot
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981), // Emerald / Teal active status dot
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'VitaNet AI',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A),
                    letterSpacing: -0.2,
                  ),
                ),
              ],
            ),

            // Right: Dynamic "+ New Chat" Action
            _NewChatButton(
              onTap: onNewChatPressed,
              isDark: isDark,
              isEnabled: isNewChatEnabled,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderActionButton extends StatefulWidget {
  final IconData icon;
  final String? label;
  final bool isActive;
  final VoidCallback onTap;
  final bool isDark;

  const _HeaderActionButton({
    required this.icon,
    this.label,
    required this.isActive,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_HeaderActionButton> createState() => _HeaderActionButtonState();
}

class _HeaderActionButtonState extends State<_HeaderActionButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final textPrimary = widget.isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = widget.isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    final effectiveColor = widget.isActive
        ? const Color(0xFF0D9488)
        : (_isHovered ? textPrimary : textSecondary);

    final bgColor = widget.isActive
        ? const Color(0xFF0D9488).withValues(alpha: 0.12)
        : (_isHovered
            ? (widget.isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9))
            : (widget.isDark ? const Color(0xFF1E293B) : Colors.white));

    final borderColor = widget.isActive
        ? const Color(0xFF0D9488).withValues(alpha: 0.40)
        : (_isHovered
            ? (widget.isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1))
            : (widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0)));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isDark ? 0.20 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 17,
                color: effectiveColor,
              ),
              if (widget.label != null) ...[
                const SizedBox(width: 8),
                Text(
                  widget.label!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: widget.isActive ? FontWeight.w600 : FontWeight.w500,
                    color: effectiveColor,
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: effectiveColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NewChatButton extends StatefulWidget {
  final VoidCallback onTap;
  final bool isDark;
  final bool isEnabled;

  const _NewChatButton({
    required this.onTap,
    required this.isDark,
    this.isEnabled = true,
  });

  @override
  State<_NewChatButton> createState() => _NewChatButtonState();
}

class _NewChatButtonState extends State<_NewChatButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) {
      final mutedColor = widget.isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
      return Container(
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: widget.isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.5)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: widget.isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_rounded,
              size: 16,
              color: mutedColor,
            ),
            const SizedBox(width: 6),
            Text(
              'New Chat',
              style: GoogleFonts.plusJakartaSans(
                color: mutedColor,
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      );
    }

    final bgColor = widget.isDark
        ? (_isHovered ? const Color(0xFF334155) : const Color(0xFF1E293B))
        : (_isHovered ? const Color(0xFFF1F5F9) : Colors.white);

    final borderColor = widget.isDark
        ? (_isHovered ? const Color(0xFF0D9488) : const Color(0xFF334155))
        : (_isHovered ? const Color(0xFF0D9488) : const Color(0xFFE2E8F0));

    final textColor = widget.isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final iconColor = const Color(0xFF0D9488);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor, width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: widget.isDark ? 0.20 : 0.04),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.add_rounded,
                size: 16,
                color: iconColor,
              ),
              const SizedBox(width: 6),
              Text(
                'New Chat',
                style: GoogleFonts.plusJakartaSans(
                  color: textColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
