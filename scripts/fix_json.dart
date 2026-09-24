import 'dart:convert';
import 'dart:io';

void main() async {
  print('Starting JSON fix...');
  
  // Fix Videos
  final videosFile = File('assets/health_library_data/videos/videos_catalog_v4.json');
  final videosStr = await videosFile.readAsString();
  final List<dynamic> videos = json.decode(videosStr);
  
  for (var v in videos) {
    if (v['video_id'] == 'Gmh_xMMJ2Pw') {
      v['video_id'] = 'j8Zm-c0oX7Q'; // Replace dead video
    }
    
    if (v['thumbnail_url'].contains('\$ytId') || v['thumbnail_url'].contains('\\\$ytId')) {
      v['thumbnail_url'] = 'https://img.youtube.com/vi/\${v["video_id"]}/hqdefault.jpg';
    }
    
    if (v['title'].contains('\${item')) {
      v['title'] = 'Deep Dive: \${v["category"]}';
    }
    
    if (v['duration'].contains('%')) {
      v['duration'] = '10:45';
    }
  }
  
  await videosFile.writeAsString(json.encode(videos));
  
  // Fix Articles
  final articlesFile = File('assets/health_library_data/articles/articles_catalog_v4.json');
  final articlesStr = await articlesFile.readAsString();
  final List<dynamic> articles = json.decode(articlesStr);
  
  int count = 0;
  for (var a in articles) {
    count++;
    if (a['related_video_id'] == 'Gmh_xMMJ2Pw') {
      a['related_video_id'] = 'j8Zm-c0oX7Q';
    }
    
    if (a['id'].contains('\$')) {
      a['id'] = 'article_\${a["category"].replaceAll(" ", "_").toLowerCase()}_\$count';
    }
    
    if (a['read_time'].contains('%')) {
      a['read_time'] = '5 min read';
    }
    
    for (var sec in a['sections']) {
      if (sec['content'].contains('\${item')) {
        sec['content'] = sec['content'].replaceAll(RegExp(r'\$\{.*?\}'), a['title'].toLowerCase());
      }
    }
  }
  
  await articlesFile.writeAsString(json.encode(articles));
  print('Done fixing JSONs!');
}
