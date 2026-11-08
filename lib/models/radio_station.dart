import 'package:flutter/material.dart';

class RadioStation {
  const RadioStation({
    required this.id,
    required this.name,
    required this.tagline,
    required this.streamUrl,
    required this.embedUrl,
    required this.category,
    required this.frequency,
    required this.color,
    this.fallbackStreamUrl,
  });

  final String id;
  final String name;
  final String tagline;
  final String streamUrl;
  final String? fallbackStreamUrl;
  final String embedUrl;
  final String category;
  final String frequency;
  final Color color;

  static const List<RadioStation> stations = [
    RadioStation(
      id: 'vividh_bharti',
      name: 'AIR Vividh Bharati',
      tagline: 'Desh Ki Swar Lahari - All India Radio',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio001/playlist.m3u8',
      fallbackStreamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio001/playlist.m3u8',
      embedUrl: 'http://e.radioindia.in/embed/vividh-bharti-428238',
      category: 'National / Retro & News',
      frequency: '102.8 FM',
      color: Color(0xFFFF9933), // Saffron / Gold
    ),
    RadioStation(
      id: 'non_stop_hindi',
      name: 'Non-Stop Hindi',
      tagline: 'Superhit Bollywood & Romantic Melodies',
      streamUrl: 'http://s5.voscast.com:8216/stream',
      fallbackStreamUrl: 'http://s5.voscast.com:8216/stream',
      embedUrl: 'http://e.radioindia.in/embed/non-stop-hindi-417062',
      category: 'Bollywood / 24x7 HD Hits',
      frequency: 'HD Stream',
      color: Color(0xFF00D2FF), // Cyber Cyan
    ),
  ];
}
