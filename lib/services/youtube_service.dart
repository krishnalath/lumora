import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
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
    // On web, direct YouTube requests fail due to CORS. 
    // We try multiple public CORS proxies to ensure reliability.
    if (kIsWeb) {
      final target = 'https://www.youtube.com/results?search_query=${Uri.encodeComponent(query)}';
      
      final proxies = [
        'https://api.codetabs.com/v1/proxy?quest=',
        'https://api.allorigins.win/raw?url=',
        'https://corsproxy.io/?',
      ];

      for (String proxy in proxies) {
        try {
          final url = Uri.parse('$proxy${Uri.encodeComponent(target)}');
          final response = await http.get(url);
          
          if (response.statusCode == 200) {
            final html = response.body;
            final startStr = 'var ytInitialData = ';
            final startIndex = html.indexOf(startStr);
            if (startIndex != -1) {
              final jsonStart = startIndex + startStr.length;
              final jsonEnd = html.indexOf(';</script>', jsonStart);
              if (jsonEnd != -1) {
                final jsonStr = html.substring(jsonStart, jsonEnd);
                final data = jsonDecode(jsonStr);
                
                final contents = data['contents']['twoColumnSearchResultsRenderer']['primaryContents']['sectionListRenderer']['contents'][0]['itemSectionRenderer']['contents'];
                for (var item in contents) {
                  if (item.containsKey('videoRenderer')) {
                    final video = item['videoRenderer'];
                    final id = video['videoId'];
                    final title = video['title']['runs'][0]['text'];
                    final author = video['ownerText']['runs'][0]['text'];
                    final lengthText = video['lengthText']?['simpleText'] ?? '0:00';
                    final thumb = 'https://i.ytimg.com/vi/$id/hqdefault.jpg';
                    
                    final parts = lengthText.split(':').reversed.toList();
                    int seconds = 0;
                    if (parts.isNotEmpty) seconds += int.parse(parts[0]);
                    if (parts.length > 1) seconds += int.parse(parts[1]) * 60;
                    if (parts.length > 2) seconds += int.parse(parts[2]) * 3600;
                    
                    return YouTubeVideoData(
                      id: id,
                      title: title,
                      thumbnailUrl: thumb,
                      author: author,
                      duration: Duration(seconds: seconds),
                    );
                  }
                }
              }
            }
          }
        } catch (e) {
          print('Error with web cors proxy $proxy: $e');
        }
      }
    }

    // Fallback to youtube_explode_dart for non-web platforms or if all proxies fail
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
