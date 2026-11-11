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
    this.icon = '📻',
    this.imageUrl,
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
  final String icon;
  final String? imageUrl;

  static const List<RadioStation> stations = [
    // ==========================================
    // 1. LEGENDARY ARTISTS (गायक एवं स्वर कोकिला)
    // ==========================================
    RadioStation(
      id: 'lata_mangeshkar',
      name: 'Hits of Lata Mangeshkar',
      tagline: 'Bharat Ratna • Swar Kokila Everlasting Hits',
      streamUrl: 'https://stream.zeno.fm/g95zm67prfhvv',
      fallbackStreamUrl: 'https://stream.zeno.fm/g95zm67prfhvv',
      embedUrl: 'http://e.radioindia.in/embed/lata-mangeshkar',
      category: 'Artists',
      frequency: '24x7 Hits',
      color: Color(0xFF9C27B0), // Royal Purple
      icon: '🌸',
      imageUrl: 'https://static.mytuner.mobi/media/tvos_radios/591/hits-of-lata-mangeshkar.6b81cbb3.png',
    ),
    RadioStation(
      id: 'kishore_kumar',
      name: 'Hits of Kishore Kumar',
      tagline: 'Evergreen Magic • Yoodling Superstar Hits',
      streamUrl: 'https://stream.zeno.fm/0ghtfp8ztm0uv',
      fallbackStreamUrl: 'https://stream.zeno.fm/0ghtfp8ztm0uv',
      embedUrl: 'http://e.radioindia.in/embed/kishore-kumar',
      category: 'Artists',
      frequency: '24x7 Hits',
      color: Color(0xFF00897B), // Teal Emerald
      icon: '🎤',
      imageUrl: 'https://static.mytuner.mobi/media/tvos_radios/590/hits-of-kishor-kumar.70a74602.jpg',
    ),
    RadioStation(
      id: 'mohammed_rafi',
      name: 'Hits of Mohammed Rafi',
      tagline: 'Golden Era Voice • Timeless Ghazals & Songs',
      streamUrl: 'https://stream.zeno.fm/0zkr7x8ztm0uv',
      fallbackStreamUrl: 'https://stream.zeno.fm/0zkr7x8ztm0uv',
      embedUrl: 'http://e.radioindia.in/embed/mohammed-rafi',
      category: 'Artists',
      frequency: '24x7 Hits',
      color: Color(0xFFD81B60), // Ruby Pink
      icon: '🎶',
      imageUrl: 'https://static.mytuner.mobi/media/tvos_radios/878/mohammed-rafi-radio.8797b0fb.png',
    ),
    RadioStation(
      id: 'kumar_sanu',
      name: 'Kumar Sanu Radio',
      tagline: 'King of 90s Romance • Melody King 24x7',
      streamUrl: 'https://stream.zeno.fm/shxt7qxapy8uv',
      fallbackStreamUrl: 'https://stream.zeno.fm/shxt7qxapy8uv',
      embedUrl: 'http://e.radioindia.in/embed/kumar-sanu',
      category: 'Artists',
      frequency: '90s Melodies',
      color: Color(0xFF1E88E5), // Ocean Blue
      icon: '🎙️',
      imageUrl: 'https://static.mytuner.mobi/media/tvos_radios/187/kumar-sanu.fcf44709.jpg',
    ),
    RadioStation(
      id: 'mukesh_radio',
      name: 'Mukesh Radio',
      tagline: 'Dard Bhare Geet & Soulful Classics',
      streamUrl: 'https://stream.zeno.fm/mrcz5sus1p8uv',
      fallbackStreamUrl: 'https://stream.zeno.fm/t39watus1p8uv',
      embedUrl: 'http://e.radioindia.in/embed/mukesh',
      category: 'Artists',
      frequency: 'Classic Retro',
      color: Color(0xFFFB8C00), // Amber Gold
      icon: '📻',
    ),

    // ==========================================
    // 2. NATIONAL & TOP LIVE FM CHANNELS
    // ==========================================
    RadioStation(
      id: 'mirchi983',
      name: 'Radio Mirchi 98.3',
      tagline: 'Bollywood Hits Live',
      streamUrl: 'https://vm65162.streamerr.co/listen/mirchi/radio.mp3',
      fallbackStreamUrl: 'https://drive.uber.radio/uber/bollywoodnow/icecast.audio',
      embedUrl: 'http://e.radioindia.in/embed/radio-city-hindi',
      category: 'Top FM',
      frequency: '98.3 FM',
      color: Color(0xFFFF1744),
      icon: '📻',
      imageUrl: 'https://images.radioindia.in/stations/mirchi.png',
    ),
    RadioStation(
      id: 'vividhbharati',
      name: 'Vividh Bharati',
      tagline: 'All India Radio (AIR)',
      streamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio001/playlist.m3u8',
      fallbackStreamUrl: 'http://air.pc.cdn.bitgravity.com/air/live/pbaudio001/playlist.m3u8',
      embedUrl: 'http://e.radioindia.in/embed/vividh-bharti-428238',
      category: 'Top FM',
      frequency: '102.8 FM',
      color: Color(0xFFFF9933),
      icon: '🎙️',
      imageUrl: 'https://images.radioindia.in/stations/vividh.png',
    ),
    RadioStation(
      id: 'radiocity',
      name: 'Radio City 91.1',
      tagline: 'Hindi Hits Live',
      streamUrl: 'https://planetradiocity-intl-live.akamaized.net/rf_hls/live/planetradiocity/hindi/master.m3u8',
      fallbackStreamUrl: 'https://stream.zeno.fm/fvrx452618uvv',
      embedUrl: 'http://e.radioindia.in/embed/radio-city-hindi',
      category: 'Top FM',
      frequency: '91.1 FM',
      color: Color(0xFF007BFF),
      icon: '🎵',
      imageUrl: 'https://images.radioindia.in/stations/city.png',
    ),
    RadioStation(
      id: 'bigfm927',
      name: 'Big FM 92.7',
      tagline: 'Dhun Badal Ke Toh Dekho',
      streamUrl: 'https://stream.zeno.fm/0r0xa792kwzuv',
      fallbackStreamUrl: 'https://stream.zeno.fm/f9wsm63v02quv',
      embedUrl: 'http://e.radioindia.in/embed/big-fm-delhi',
      category: 'Top FM',
      frequency: '92.7 FM',
      color: Color(0xFF2563EB),
      icon: '🎧',
      imageUrl: 'https://images.radioindia.in/stations/bigfm.png',
    ),
    RadioStation(
      id: 'airgold',
      name: 'AIR FM Gold 106.4',
      tagline: 'Classic Gold & News',
      streamUrl: 'https://airhlspush.pc.cdn.bitgravity.com/httppush/hlspbaudio005/hlspbaudio00564kbps.m3u8',
      fallbackStreamUrl: 'https://air.pc.cdn.bitgravity.com/air/live/pbaudio002/playlist.m3u8',
      embedUrl: 'http://e.radioindia.in/embed/air-fm-gold-delhi',
      category: 'Top FM',
      frequency: '106.4 FM',
      color: Color(0xFFFFB300),
      icon: '📻',
      imageUrl: 'https://images.radioindia.in/stations/airgold.png',
    ),
    RadioStation(
      id: 'airrainbow',
      name: 'AIR FM Rainbow',
      tagline: 'Youth & Entertainment',
      streamUrl: 'https://airhlspush.pc.cdn.bitgravity.com/httppush/hlspbaudio004/hlspbaudio00432kbps.m3u8',
      fallbackStreamUrl: 'https://d3r9rhourdc02u.cloudfront.net/assets/radio/airdelhi02/air002_Auto.m3u8',
      embedUrl: 'http://e.radioindia.in/embed/fm-rainbow',
      category: 'Top FM',
      frequency: '102.6 FM',
      color: Color(0xFF8E24AA),
      icon: '🌈',
      imageUrl: 'https://images.radioindia.in/stations/rainbow.png',
    ),
    RadioStation(
      id: 'red_fm_india',
      name: 'Superhit Red FM 93.5',
      tagline: 'Bajaate Raho! • India No.1 Hit Music',
      streamUrl: 'https://stream.zeno.fm/5y4h3s0z7qzuv',
      fallbackStreamUrl: 'https://stream.zeno.fm/5y4h3s0z7qzuv',
      embedUrl: 'http://e.radioindia.in/embed/red-fm-delhi',
      category: 'Top FM',
      frequency: '93.5 FM',
      color: Color(0xFFE50914),
      icon: '🔥',
    ),
    RadioStation(
      id: 'ishq_fm',
      name: '104.8 Ishq FM',
      tagline: 'Do Dil Ek Dhadkan • Romantic Bollywood',
      streamUrl: 'https://stream.zeno.fm/054rqsmz7qzuv',
      fallbackStreamUrl: 'https://stream.zeno.fm/054rqsmz7qzuv',
      embedUrl: 'http://e.radioindia.in/embed/ishq-fm',
      category: 'Top FM',
      frequency: '104.8 FM',
      color: Color(0xFFEC4899),
      icon: '❤️',
    ),

    // ==========================================
    // 3. RETRO, 90s & BOLLYWOOD CLASSICS
    // ==========================================
    RadioStation(
      id: 'hungamahindi',
      name: 'Hungama 90s Once Again',
      tagline: 'Superhit 90s Songs',
      streamUrl: 'https://stream.zeno.fm/143d7gty24zuv',
      fallbackStreamUrl: 'https://stream.zeno.fm/7k975w810hzuv',
      embedUrl: 'http://e.radioindia.in/embed/non-stop-hindi-417062',
      category: 'Retro & 90s',
      frequency: 'HD Digital',
      color: Color(0xFFE91E63),
      icon: '📼',
      imageUrl: 'https://images.radioindia.in/stations/hungama.png',
    ),
    RadioStation(
      id: 'retro_bollywood_90s',
      name: 'Radio Retro Bollywood',
      tagline: 'Best of 70s, 80s & 90s Bollywood Classics',
      streamUrl: 'https://stream.zeno.fm/fdgs82xkzhhvv',
      fallbackStreamUrl: 'https://stream.zeno.fm/v2zfmxef798uv',
      embedUrl: 'http://e.radioindia.in/embed/retro-bollywood',
      category: 'Retro & 90s',
      frequency: 'HD Retro',
      color: Color(0xFF673AB7),
      icon: '📼',
    ),

    // ==========================================
    // 4. BHAKTI & SPIRITUAL (भक्ति व सत्संग)
    // ==========================================
    RadioStation(
      id: 'bhakti_sagar',
      name: 'Bhakti Sagar Radio',
      tagline: 'Devi Maa & Shrimad Bhagwat Bhajans 24x7',
      streamUrl: 'https://stream.zeno.fm/syu0rdutvxhvv',
      fallbackStreamUrl: 'https://stream.zeno.fm/syu0rdutvxhvv',
      embedUrl: 'http://e.radioindia.in/embed/bhakti-sangeet',
      category: 'Bhakti',
      frequency: '24x7 Bhakti',
      color: Color(0xFFFF5722),
      icon: '🙏',
      imageUrl: 'https://static.mytuner.mobi/media/tvos_radios/147/bhakti-sangeet.b004b72c.jpg',
    ),
    RadioStation(
      id: 'bhakti_world_ram',
      name: 'Bhakti World (Hanuman & Ram)',
      tagline: 'Jai Shri Ram • Hanuman Chalisa 24x7',
      streamUrl: 'https://dard.out.airtime.pro/dard_a',
      fallbackStreamUrl: 'http://2bhanuman.out.airtime.pro:8000/2bhanuman_a',
      embedUrl: 'http://e.radioindia.in/embed/bhakti-world',
      category: 'Bhakti',
      frequency: 'Spiritual FM',
      color: Color(0xFFE64A19),
      icon: '🪔',
    ),

    // ==========================================
    // 5. RAJASTHAN & REGIONAL (राजस्थानी व मारवाड़ी)
    // ==========================================
    RadioStation(
      id: 'marwadiradio',
      name: 'Radio Rajasthani',
      tagline: 'Marwadi Folk, Bhajan & Cultural Songs',
      streamUrl: 'https://radio.wavespb.com/live/23ae73f45ccdd42d/23ae73f45ccdd42d.m3u8',
      fallbackStreamUrl: 'https://stream.zeno.fm/4vrm2803q2zuv',
      embedUrl: 'http://e.radioindia.in/embed/air-jodhpur',
      category: 'Rajasthan',
      frequency: '102.1 FM',
      color: Color(0xFFFF6D00),
      icon: '🏜️',
      imageUrl: 'https://images.radioindia.in/stations/rajasthani.png',
    ),
    RadioStation(
      id: 'air_jaipur',
      name: 'AIR Jaipur (Pink City)',
      tagline: 'Akashvani Jaipur • Folk & Samachar',
      streamUrl: 'https://radio.wavespb.com/live/ad081b4086797344/ad081b4086797344.m3u8',
      fallbackStreamUrl: 'https://radio.wavespb.com/live/72d34573791c739b/72d34573791c739b.m3u8',
      embedUrl: 'http://e.radioindia.in/embed/air-jaipur',
      category: 'Rajasthan',
      frequency: '101.2 FM',
      color: Color(0xFFFF2A85),
      icon: '🏰',
    ),
    RadioStation(
      id: 'air_jodhpur_primary',
      name: 'AIR Jodhpur Primary',
      tagline: 'Marwar Cultural & Folk Kendra',
      streamUrl: 'https://radio.wavespb.com/live/520ec0fb4a9139a7/520ec0fb4a9139a7.m3u8',
      fallbackStreamUrl: 'https://radio.wavespb.com/live/23ae73f45ccdd42d/23ae73f45ccdd42d.m3u8',
      embedUrl: 'http://e.radioindia.in/embed/air-jodhpur',
      category: 'Rajasthan',
      frequency: '531 kHz AM',
      color: Color(0xFFD84315),
      icon: '🐪',
    ),
  ];
}
