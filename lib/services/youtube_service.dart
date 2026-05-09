import 'package:youtube_explode_dart/youtube_explode_dart.dart';

class YouTubeVideoData {
  final String id;
  final String title;
  final String thumbnailUrl;
  final String author;
  final Duration duration;

  YouTubeVideoData({
    required this.id,
    required this.title,
    required this.thumbnailUrl,
    required this.author,
    required this.duration,
  });
}

class YouTubeService {
  /// Searches YouTube for a specific query and returns the best matching video.
  static Future<YouTubeVideoData?> searchBestVideo(String query) async {
    final yt = YoutubeExplode();
    try {
      final searchResults = await yt.search.search(query);
      if (searchResults.isNotEmpty) {
        final video = searchResults.first;
        return YouTubeVideoData(
          id: video.id.value,
          title: video.title,
          thumbnailUrl: video.thumbnails.highResUrl,
          author: video.author,
          duration: video.duration ?? const Duration(),
        );
      }
    } catch (e) {
      print('Error searching YouTube: $e');
    } finally {
      yt.close();
    }
    return null;
  }
}
