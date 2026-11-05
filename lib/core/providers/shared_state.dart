import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final searchActionProvider = StateProvider<String?>((ref) => null);

/// Controls whether the top headers and bottom navigation bar are visible.
/// Follows YouTube-style behavior: hides when scrolling down, reappears when scrolling up or at top.
final navBarVisibleProvider = StateProvider<bool>((ref) => true);

/// Universal scroll notification listener logic for auto-hide.
/// Returns false so notifications continue bubbling normally.
bool handleScrollNotification(ScrollNotification notification, WidgetRef ref) {
  // Only process vertical scrolling on the primary scroll view
  if (notification.metrics.axis != Axis.vertical || notification.depth != 0) {
    return false;
  }

  // Always reveal navbar when near or at the top of the content
  if (notification.metrics.pixels <= 15.0) {
    if (!ref.read(navBarVisibleProvider)) {
      ref.read(navBarVisibleProvider.notifier).state = true;
    }
    return false;
  }

  if (notification is ScrollUpdateNotification) {
    final delta = notification.scrollDelta;
    if (delta != null) {
      // Meaningful threshold to filter out finger tremors, mousewheel jitter, and micro-movements
      if (delta > 8.0) {
        if (ref.read(navBarVisibleProvider)) {
          ref.read(navBarVisibleProvider.notifier).state = false;
        }
      } else if (delta < -8.0) {
        if (!ref.read(navBarVisibleProvider)) {
          ref.read(navBarVisibleProvider.notifier).state = true;
        }
      }
    }
  }

  // Also reveal navbar when reaching the bottom of the content
  if (notification.metrics.pixels >= notification.metrics.maxScrollExtent - 20.0) {
    if (!ref.read(navBarVisibleProvider)) {
      ref.read(navBarVisibleProvider.notifier).state = true;
    }
  }
  return false;
}
