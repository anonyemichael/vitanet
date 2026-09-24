class VideoKeyStep {
  final String time;
  final String action;

  const VideoKeyStep({
    required this.time,
    required this.action,
  });

  factory VideoKeyStep.fromJson(Map<String, dynamic> json) {
    return VideoKeyStep(
      time: json['time'] as String,
      action: json['action'] as String,
    );
  }
}

class HealthVideo {
  final String videoId;
  final String title;
  final String category;
  final String organization;
  final String duration;
  final String thumbnailUrl;
  final String summary;
  final List<VideoKeyStep> keySteps;
  final String verificationStatus;

  const HealthVideo({
    required this.videoId,
    required this.title,
    required this.category,
    required this.organization,
    required this.duration,
    required this.thumbnailUrl,
    required this.summary,
    required this.keySteps,
    required this.verificationStatus,
  });

  factory HealthVideo.fromJson(Map<String, dynamic> json) {
    return HealthVideo(
      videoId: json['video_id'] as String,
      title: json['title'] as String,
      category: json['category'] as String,
      organization: json['organization'] as String,
      duration: json['duration'] as String,
      thumbnailUrl: json['thumbnail_url'] as String,
      summary: json['summary'] as String,
      keySteps: (json['key_steps'] as List).map((s) => VideoKeyStep.fromJson(s)).toList(),
      verificationStatus: json['verification_status'] as String,
    );
  }
}
