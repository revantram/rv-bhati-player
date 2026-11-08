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
    // --- Rajasthan Regional Stations ---
    RadioStation(
      id: 'air_jodhpur_suncity',
      name: 'AIR Jodhpur (Sun City FM)',
      tagline: 'Akashvani Jodhpur • Marwar Ki Meethi Vaani',
      streamUrl: 'https://radio.wavespb.com/live/23ae73f45ccdd42d/23ae73f45ccdd42d.m3u8',
      fallbackStreamUrl: 'https://radio.wavespb.com/live/520ec0fb4a9139a7/520ec0fb4a9139a7.m3u8',
      embedUrl: 'http://e.radioindia.in/embed/air-jodhpur',
      category: 'Rajasthan Regional / Marwari & Hindi',
      frequency: '102.1 FM',
      color: Color(0xFFFF6D00), // Royal Marwar Amber
    ),
    RadioStation(
      id: 'air_jaipur',
      name: 'AIR Jaipur',
      tagline: 'Pink City Akashvani • Rajasthani Geet & Samachar',
      streamUrl: 'https://radio.wavespb.com/live/ad081b4086797344/ad081b4086797344.m3u8',
      fallbackStreamUrl: 'https://radio.wavespb.com/live/72d34573791c739b/72d34573791c739b.m3u8',
      embedUrl: 'http://e.radioindia.in/embed/air-jaipur',
      category: 'Rajasthan Regional / Folk & News',
      frequency: '101.2 FM',
      color: Color(0xFFFF2A85), // Pink City Magenta
    ),
    RadioStation(
      id: 'air_jodhpur_primary',
      name: 'AIR Jodhpur Primary',
      tagline: 'Prasar Bharati Akashvani Jodhpur Kendra',
      streamUrl: 'https://radio.wavespb.com/live/520ec0fb4a9139a7/520ec0fb4a9139a7.m3u8',
      fallbackStreamUrl: 'https://radio.wavespb.com/live/23ae73f45ccdd42d/23ae73f45ccdd42d.m3u8',
      embedUrl: 'http://e.radioindia.in/embed/air-jodhpur',
      category: 'Rajasthan Regional / Cultural & Folk',
      frequency: '531 kHz AM',
      color: Color(0xFFE65100), // Sunset Orange
    ),

    // --- National AIR & Commercial Hits ---
    RadioStation(
      id: 'vividh_bharti',
      name: 'AIR Vividh Bharati',
      tagline: 'Desh Ki Swar Lahari • All India Radio Golden Hits',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio001/playlist.m3u8',
      fallbackStreamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio001/playlist.m3u8',
      embedUrl: 'http://e.radioindia.in/embed/vividh-bharti-428238',
      category: 'National / Retro Classics & Sangeet',
      frequency: '102.8 FM',
      color: Color(0xFFFF9933), // Saffron / Gold
    ),
    RadioStation(
      id: 'mirchi_top_20',
      name: 'Radio Mirchi Top 20',
      tagline: 'Mirchi Pe Sabse Bada Music Countdown & Hits',
      streamUrl: 'https://drive.uber.radio/uber/bollywoodnow/icecast.audio',
      fallbackStreamUrl: 'https://drive.uber.radio/uber/bollywoodnow/icecast.audio',
      embedUrl: 'http://e.radioindia.in/embed/radio-city-hindi',
      category: 'Bollywood / Trending Chartbusters',
      frequency: '98.3 FM',
      color: Color(0xFFFF1744), // Vibrant Red
    ),
    RadioStation(
      id: 'non_stop_hindi',
      name: 'Non-Stop Hindi',
      tagline: 'Superhit Bollywood & Romantic Melodies 24x7',
      streamUrl: 'http://s5.voscast.com:8216/stream',
      fallbackStreamUrl: 'http://s5.voscast.com:8216/stream',
      embedUrl: 'http://e.radioindia.in/embed/non-stop-hindi-417062',
      category: 'Bollywood / 24x7 HD Hits',
      frequency: 'HD Digital',
      color: Color(0xFF00D2FF), // Cyber Cyan
    ),
    RadioStation(
      id: 'fm_rainbow',
      name: 'AIR FM Rainbow',
      tagline: 'All India Radio Youth & Contemporary Music Channel',
      streamUrl: 'https://airhlspush.pc.cdn.bitgravity.com/httppush/hlspbaudio004/hlspbaudio00432kbps.m3u8',
      fallbackStreamUrl: 'https://airhlspush.pc.cdn.bitgravity.com/httppush/hlspbaudio004/hlspbaudio00432kbps.m3u8',
      embedUrl: 'http://e.radioindia.in/embed/fm-rainbow',
      category: 'National / Contemporary Pop & Melodies',
      frequency: '102.6 FM',
      color: Color(0xFF8E24AA), // Electric Purple
    ),
  ];
}
