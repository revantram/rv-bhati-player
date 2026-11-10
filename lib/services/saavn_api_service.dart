import 'dart:convert';
import 'dart:io';

import '../models/online_song.dart';

class SaavnArtist {
  final String name;
  final String category; // 'Legends', '90s Icons', 'Modern Hits'
  final String subtitle;
  final String avatarUrl;

  const SaavnArtist({
    required this.name,
    required this.category,
    required this.subtitle,
    required this.avatarUrl,
  });

  bool get isRajasthani => category.toLowerCase().contains('rajasthan');
  bool get isBollywood => !isRajasthani;
}

class SaavnApiService {
  SaavnApiService._();
  static final SaavnApiService instance = SaavnApiService._();

  static const String _baseUrl = 'https://www.jiosaavn.com/api.php';
  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12);

  // In-memory caches to make UI snappy
  final Map<String, List<OnlineSong>> _cachedQueries = {};
  List<OnlineSong>? _cachedTrending;
  final Map<String, List<OnlineSong>> _cachedPlaylists = {};
  final Map<String, List<OnlineSong>> _cachedArtists = {};

  // Curated Artists Catalog as requested
  static const List<SaavnArtist> curatedArtists = [
    // --- Modern Hits ---
    SaavnArtist(
      name: 'Arijit Singh',
      category: 'Modern Hits',
      subtitle: 'The Soul of Bollywood',
      avatarUrl: 'https://c.saavncdn.com/artists/Arijit_Singh_002_20230323062147_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Atif Aslam',
      category: 'Modern Hits',
      subtitle: 'Romantic Melodies & Hits',
      avatarUrl: 'https://c.saavncdn.com/artists/Atif_Aslam_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Jubin Nautiyal',
      category: 'Modern Hits',
      subtitle: 'Heart-touching Chartbusters',
      avatarUrl: 'https://c.saavncdn.com/artists/Jubin_Nautiyal_003_20231130204020_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Shreya Ghoshal',
      category: 'Modern Hits',
      subtitle: 'Melody Queen of Modern Era',
      avatarUrl: 'https://c.saavncdn.com/artists/Shreya_Ghoshal_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Neha Kakkar',
      category: 'Modern Hits',
      subtitle: 'Party & Dance Anthem Queen',
      avatarUrl: 'https://c.saavncdn.com/artists/Neha_Kakkar_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Darshan Raval',
      category: 'Modern Hits',
      subtitle: 'Monsoon Melodies & Romance',
      avatarUrl: 'https://c.saavncdn.com/artists/Darshan_Raval_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Armaan Malik',
      category: 'Modern Hits',
      subtitle: 'Prince of Romance',
      avatarUrl: 'https://c.saavncdn.com/artists/Armaan_Malik_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Diljit Dosanjh',
      category: 'Modern Hits',
      subtitle: 'Global Punjabi Sensation',
      avatarUrl: 'https://c.saavncdn.com/artists/Diljit_Dosanjh_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Badshah',
      category: 'Modern Hits',
      subtitle: 'Desi Hip-Hop & Party Hits',
      avatarUrl: 'https://c.saavncdn.com/artists/Badshah_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Yo Yo Honey Singh',
      category: 'Modern Hits',
      subtitle: 'Desi Kalakaar & Rap King',
      avatarUrl: 'https://c.saavncdn.com/artists/Yo_Yo_Honey_Singh_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Sunidhi Chauhan',
      category: 'Modern Hits',
      subtitle: 'Powerhouse of Bollywood',
      avatarUrl: 'https://c.saavncdn.com/artists/Sunidhi_Chauhan_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Mohit Chauhan',
      category: 'Modern Hits',
      subtitle: 'Soulful Indie & Rock Melodies',
      avatarUrl: 'https://c.saavncdn.com/artists/Mohit_Chauhan_500x500.jpg',
    ),
    SaavnArtist(
      name: 'KK',
      category: 'Modern Hits',
      subtitle: 'Voice of Pure Emotions & Youth',
      avatarUrl: 'https://c.saavncdn.com/artists/KK_500x500.jpg',
    ),
    SaavnArtist(
      name: 'A.R. Rahman',
      category: 'Modern Hits',
      subtitle: 'The Mozart of Madras',
      avatarUrl: 'https://c.saavncdn.com/artists/AR_Rahman_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Anuv Jain',
      category: 'Modern Hits',
      subtitle: 'Indie Acoustic Sensation',
      avatarUrl: 'https://c.saavncdn.com/436/Husn-Hindi-2023-20231129054140-500x500.jpg',
    ),
    SaavnArtist(
      name: 'B Praak',
      category: 'Modern Hits',
      subtitle: 'Teri Mitti & Heartbreak Anthems',
      avatarUrl: 'https://c.saavncdn.com/artists/B_Praak_001_20191118112005_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Sidhu Moose Wala',
      category: 'Modern Hits',
      subtitle: 'The Legend of Desi Hip-Hop',
      avatarUrl: 'https://c.saavncdn.com/artists/Sidhu_Moose_Wala_004_20250617183705_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Vishal Mishra',
      category: 'Modern Hits',
      subtitle: 'Pehle Bhi Main & Soul Hits',
      avatarUrl: 'https://c.saavncdn.com/artists/Vishal_Mishra_005_20251120085316_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Stebin Ben',
      category: 'Modern Hits',
      subtitle: 'Romantic Chartbusters',
      avatarUrl: 'https://c.saavncdn.com/artists/Stebin_Ben_005_20240124093234_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Shilpa Rao',
      category: 'Modern Hits',
      subtitle: 'Chaleya & Besharam Rang Diva',
      avatarUrl: 'https://c.saavncdn.com/artists/Shilpa_Rao_002_20230321111415_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Jonita Gandhi',
      category: 'Modern Hits',
      subtitle: 'What Jhumka & Arabic Kuthu',
      avatarUrl: 'https://c.saavncdn.com/artists/Jonita_Gandhi_003_20180507091741_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Monali Thakur',
      category: 'Modern Hits',
      subtitle: 'Moh Moh Ke Dhaage & Sawaar Loon',
      avatarUrl: 'https://c.saavncdn.com/artists/Monali_Thakur_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Prateek Kuhad',
      category: 'Modern Hits',
      subtitle: 'Cold/Mess & Indie Acoustic',
      avatarUrl: 'https://c.saavncdn.com/artists/Prateek_Kuhad_006_20260515064251_500x500.jpg',
    ),
    SaavnArtist(
      name: 'King',
      category: 'Modern Hits',
      subtitle: 'Maan Meri Jaan & Tu Aake Dekhle',
      avatarUrl: 'https://c.saavncdn.com/artists/King_004_20240819092014_500x500.jpg',
    ),
    SaavnArtist(
      name: 'DIVINE',
      category: 'Modern Hits',
      subtitle: 'Gully Boy & Desi Rap Pioneer',
      avatarUrl: 'https://c.saavncdn.com/artists/DIVINE_006_20250911071442_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Javed Ali',
      category: 'Modern Hits',
      subtitle: 'Kun Faya Kun & Srivalli',
      avatarUrl: 'https://c.saavncdn.com/artists/Javed_Ali_006_20260821184545_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Pritam',
      category: 'Modern Hits',
      subtitle: 'The Hitmaker of Bollywood',
      avatarUrl: 'https://c.saavncdn.com/artists/Pritam_Chakraborty-20170711073326_500x500.jpg',
    ),

    // --- 90s Icons ---
    SaavnArtist(
      name: 'Kumar Sanu',
      category: '90s Icons',
      subtitle: 'King of 90s Romance',
      avatarUrl: 'https://c.saavncdn.com/artists/Kumar_Sanu_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Alka Yagnik',
      category: '90s Icons',
      subtitle: 'Golden Voice of 90s & 2000s',
      avatarUrl: 'https://c.saavncdn.com/artists/Alka_Yagnik_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Udit Narayan',
      category: '90s Icons',
      subtitle: 'Evergreen Romantic Voice',
      avatarUrl: 'https://c.saavncdn.com/artists/Udit_Narayan_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Sonu Nigam',
      category: '90s Icons',
      subtitle: 'The Lord of Melody',
      avatarUrl: 'https://c.saavncdn.com/artists/Sonu_Nigam_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Shaan',
      category: '90s Icons',
      subtitle: 'Golden Voice & Melodies',
      avatarUrl: 'https://c.saavncdn.com/artists/Shaan_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Anuradha Paudwal',
      category: '90s Icons',
      subtitle: 'Bhakti & 90s Melodies',
      avatarUrl: 'https://c.saavncdn.com/artists/Anuradha_Paudwal_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Kavita Krishnamurthy',
      category: '90s Icons',
      subtitle: 'Classic 90s Bollywood Diva',
      avatarUrl: 'https://c.saavncdn.com/artists/Kavita_Krishnamurthy_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Abhijeet Bhattacharya',
      category: '90s Icons',
      subtitle: 'Voice of Shah Rukh Khan Hits',
      avatarUrl: 'https://c.saavncdn.com/artists/Abhijeet_Bhattacharya_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Himesh Reshammiya',
      category: '90s Icons',
      subtitle: '2000s High-Pitch Sensation',
      avatarUrl: 'https://c.saavncdn.com/artists/Himesh_Reshammiya_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Lucky Ali',
      category: '90s Icons',
      subtitle: 'Soulful Indie Nomad',
      avatarUrl: 'https://c.saavncdn.com/artists/Lucky_Ali_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Sukhwinder Singh',
      category: '90s Icons',
      subtitle: 'Chaiyya Chaiyya & Power Hits',
      avatarUrl: 'https://c.saavncdn.com/artists/Sukhwinder_Singh_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Hariharan',
      category: '90s Icons',
      subtitle: 'Colonial Cousins & Roja Melodies',
      avatarUrl: 'https://c.saavncdn.com/artists/Hariharan_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Suresh Wadkar',
      category: '90s Icons',
      subtitle: 'Lagi Aaj Sawan Ki & Classics',
      avatarUrl: 'https://c.saavncdn.com/artists/Suresh_Wadkar_005_20230825062730_500x500.jpg',
    ),

    // --- Legends ---
    SaavnArtist(
      name: 'Kishore Kumar',
      category: 'Legends',
      subtitle: 'The Incomparable Genius',
      avatarUrl: 'https://c.saavncdn.com/artists/Kishore_Kumar_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Mohammed Rafi',
      category: 'Legends',
      subtitle: 'The Immortal Golden Voice',
      avatarUrl: 'https://c.saavncdn.com/artists/Mohammed_Rafi_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Lata Mangeshkar',
      category: 'Legends',
      subtitle: 'Nightingale of India',
      avatarUrl: 'https://c.saavncdn.com/artists/Lata_Mangeshkar_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Mukesh',
      category: 'Legends',
      subtitle: 'The Soulful Legend',
      avatarUrl: 'https://c.saavncdn.com/artists/Mukesh_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Asha Bhosle',
      category: 'Legends',
      subtitle: 'Versatile Evergreen Queen',
      avatarUrl: 'https://c.saavncdn.com/artists/Asha_Bhosle_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Jagjit Singh',
      category: 'Legends',
      subtitle: 'The Ghazal King of India',
      avatarUrl: 'https://c.saavncdn.com/artists/Jagjit_Singh_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Pankaj Udhas',
      category: 'Legends',
      subtitle: 'Velvet Voice of Ghazals',
      avatarUrl: 'https://c.saavncdn.com/artists/Pankaj_Udhas_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Manna Dey',
      category: 'Legends',
      subtitle: 'Classical Playback Legend',
      avatarUrl: 'https://c.saavncdn.com/artists/Manna_Dey_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Anup Jalota',
      category: 'Legends',
      subtitle: 'Bhajan Samrat of India',
      avatarUrl: 'https://c.saavncdn.com/artists/Anup_Jalota_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Lakhbir Singh Lakkha',
      category: 'Legends',
      subtitle: 'Mata Ke Bhajan & Shiv Bhakti',
      avatarUrl: 'https://c.saavncdn.com/435/Saj-Rahe-Bhole-Baba-Nirale-Dulhe-Mein-Hindi-2019-20190709224546-500x500.jpg',
    ),

    // --- Rajasthani & Folk ---
    SaavnArtist(
      name: 'Prakash Mali',
      category: 'Rajasthani & Folk',
      subtitle: 'Bhajan Samrat of Marwar',
      avatarUrl: 'https://c.saavncdn.com/artists/Prakash_Mali_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Seema Mishra',
      category: 'Rajasthani & Folk',
      subtitle: 'Veena Cassettes Folk Queen',
      avatarUrl: 'https://c.saavncdn.com/artists/Seema_Mishra_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Chhotu Singh Rawna',
      category: 'Rajasthani & Folk',
      subtitle: 'Veer Ras & Rajputana Hits',
      avatarUrl: 'https://c.saavncdn.com/640/Teen-Baan-Ke-Dhari-Hindi-2025-20260602191940-500x500.jpg',
    ),
    SaavnArtist(
      name: 'Mame Khan',
      category: 'Rajasthani & Folk',
      subtitle: 'Coke Studio Chaudhary & Sufi',
      avatarUrl: 'https://c.saavncdn.com/668/Coke-Studio-S2-Hindi-2023-20260606091636-500x500.jpg',
    ),
    SaavnArtist(
      name: 'Gajendra Verma',
      category: 'Rajasthani & Folk',
      subtitle: 'Emptiness & Indie Love Hits',
      avatarUrl: 'https://c.saavncdn.com/artists/Gajendra_Verma_007_20241021075316_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Ila Arun',
      category: 'Rajasthani & Folk',
      subtitle: 'Rajasthani Folk & Pop Icon',
      avatarUrl: 'https://c.saavncdn.com/artists/Ila_Arun_20200205103703_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Shyam Paliwal',
      category: 'Rajasthani & Folk',
      subtitle: 'Desi Marwari & Santvani Hits',
      avatarUrl: 'https://c.saavncdn.com/artists/Shyam_Paliwal_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Sarita Kharwal',
      category: 'Rajasthani & Folk',
      subtitle: 'Rajasthani Lokgeet Queen',
      avatarUrl: 'https://c.saavncdn.com/artists/Sarita_Kharwal_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Shravan Singh Rawat',
      category: 'Rajasthani & Folk',
      subtitle: 'Marwari Folk & Traditional',
      avatarUrl: 'https://c.saavncdn.com/206/Byan-Ka-Chana-Jor-Garam-Rajasthani-2014-500x500.jpg',
    ),
    SaavnArtist(
      name: 'Rani Rangili',
      category: 'Rajasthani & Folk',
      subtitle: 'Marwari DJ Dhamaka Queen',
      avatarUrl: 'https://c.saavncdn.com/artists/Rani_Rangili_20191129073418_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Swaroop Khan',
      category: 'Rajasthani & Folk',
      subtitle: 'Tharki Chokro & Rajasthani Folk',
      avatarUrl: 'https://c.saavncdn.com/artists/Swaroop_Khan_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Salim Shekhawas',
      category: 'Rajasthani & Folk',
      subtitle: 'Marwari DJ & Folk Dhamaka',
      avatarUrl: 'https://c.saavncdn.com/artists/Salim_Shekhawas_20191130124656_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Asha Vaishnav',
      category: 'Rajasthani & Folk',
      subtitle: 'Desi Bhajan & Marwari Melodies',
      avatarUrl: 'https://c.saavncdn.com/artists/Asha_Vaishnav_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Neeta Nayak',
      category: 'Rajasthani & Folk',
      subtitle: 'Rajasthani Lokgeet & Live Melodies',
      avatarUrl: 'https://c.saavncdn.com/artists/Neeta_Nayak_003_20220411174944_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Hemraj Goyal',
      category: 'Rajasthani & Folk',
      subtitle: 'Veena Rajasthani Classics',
      avatarUrl: 'https://c.saavncdn.com/artists/Hemraj_Goyal_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Twinkle Vaishnav',
      category: 'Rajasthani & Folk',
      subtitle: 'Marwari Lokgeet & Dance',
      avatarUrl: 'https://c.saavncdn.com/artists/Twinkle_Vaishnav_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Sarita Kharwal',
      category: 'Rajasthani & Folk',
      subtitle: 'Desi Marwari & Folk Diva',
      avatarUrl: 'https://c.saavncdn.com/artists/Sarita_Kharwal_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Gajendra Ajmera',
      category: 'Rajasthani & Folk',
      subtitle: 'Tejaji Bhajan & Folk Star',
      avatarUrl: 'https://c.saavncdn.com/artists/Gajendra_Ajmera_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Mamta Vajpayee',
      category: 'Rajasthani & Folk',
      subtitle: 'Rajasthani Ghoomar & Geet',
      avatarUrl: 'https://c.saavncdn.com/artists/Mamta_Vajpayee_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Mame Khan',
      category: 'Rajasthani & Folk',
      subtitle: 'Chaudhary & Coke Studio Legend',
      avatarUrl: 'https://c.saavncdn.com/artists/Mame_Khan_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Ila Arun',
      category: 'Rajasthani & Folk',
      subtitle: 'Choli Ke Peeche & Folk Power',
      avatarUrl: 'https://c.saavncdn.com/artists/Ila_Arun_500x500.jpg',
    ),

    // --- Punjabi & Haryanvi ---
    SaavnArtist(
      name: 'Sidhu Moose Wala',
      category: 'Punjabi',
      subtitle: 'The Legend • 295 & So High',
      avatarUrl: 'https://c.saavncdn.com/artists/Sidhu_Moose_Wala_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Karan Aujla',
      category: 'Punjabi',
      subtitle: 'Tauba Tauba & Making Memories',
      avatarUrl: 'https://c.saavncdn.com/artists/Karan_Aujla_004_20240404092241_500x500.jpg',
    ),
    SaavnArtist(
      name: 'AP Dhillon',
      category: 'Punjabi',
      subtitle: 'Brown Munde & With You',
      avatarUrl: 'https://c.saavncdn.com/artists/AP_Dhillon_003_20230818113527_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Shubh',
      category: 'Punjabi',
      subtitle: 'Cheques & Baller Anthems',
      avatarUrl: 'https://c.saavncdn.com/artists/Shubh_003_20230526063428_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Ammy Virk',
      category: 'Punjabi',
      subtitle: 'Qismat & Romantic Hits',
      avatarUrl: 'https://c.saavncdn.com/artists/Ammy_Virk_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Guru Randhawa',
      category: 'Punjabi',
      subtitle: 'High Rated Gabru & Lahore',
      avatarUrl: 'https://c.saavncdn.com/artists/Guru_Randhawa_500x500.jpg',
    ),
    SaavnArtist(
      name: 'B Praak',
      category: 'Punjabi',
      subtitle: 'Filhall & Teri Mitti Sensation',
      avatarUrl: 'https://c.saavncdn.com/artists/B_Praak_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Harrdy Sandhu',
      category: 'Punjabi',
      subtitle: 'Bijlee Bijlee & Kya Baat Ay',
      avatarUrl: 'https://c.saavncdn.com/artists/Harrdy_Sandhu_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Renuka Panwar',
      category: 'Punjabi',
      subtitle: '52 Gaj Ka Daman Queen',
      avatarUrl: 'https://c.saavncdn.com/artists/Renuka_Panwar_004_20240715112921_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Gulzaar Chhaniwala',
      category: 'Punjabi',
      subtitle: 'Desi Haryanvi Bangers',
      avatarUrl: 'https://c.saavncdn.com/artists/Gulzaar_Chhaniwala_500x500.jpg',
    ),

    // --- Devotional / Bhakti ---
    SaavnArtist(
      name: 'Hansraj Raghuwanshi',
      category: 'Legends',
      subtitle: 'Mera Bhola Hai Bhandari Star',
      avatarUrl: 'https://c.saavncdn.com/artists/Hansraj_Raghuwanshi_003_20220412093836_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Narendra Chanchal',
      category: 'Legends',
      subtitle: 'Mata Ke Bhent Bhajan Samrat',
      avatarUrl: 'https://c.saavncdn.com/artists/Narendra_Chanchal_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Kanhaiya Mittal',
      category: 'Legends',
      subtitle: 'Khatu Shyam Ji Ke Bhajan',
      avatarUrl: 'https://c.saavncdn.com/artists/Kanhaiya_Mittal_002_20220818131338_500x500.jpg',
    ),

    // --- More Modern Bollywood & 90s ---
    SaavnArtist(
      name: 'Sachin-Jigar',
      category: 'Modern Hits',
      subtitle: 'Stree 2 & Apna Bana Le Melodies',
      avatarUrl: 'https://c.saavncdn.com/artists/Sachin-Jigar_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Amit Trivedi',
      category: 'Modern Hits',
      subtitle: 'Namo Namo & Soulful Maestro',
      avatarUrl: 'https://c.saavncdn.com/artists/Amit_Trivedi_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Shankar Mahadevan',
      category: 'Modern Hits',
      subtitle: 'Breathless & National Awardee',
      avatarUrl: 'https://c.saavncdn.com/artists/Shankar_Mahadevan_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Mika Singh',
      category: 'Modern Hits',
      subtitle: 'King of Party Anthems',
      avatarUrl: 'https://c.saavncdn.com/artists/Mika_Singh_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Himesh Reshammiya',
      category: 'Modern Hits',
      subtitle: 'Aashiq Banaya Aapne & Tera Suroor',
      avatarUrl: 'https://c.saavncdn.com/artists/Himesh_Reshammiya_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Raftaar',
      category: 'Modern Hits',
      subtitle: 'Desi Hip-Hop Pioneer & Dhaakad',
      avatarUrl: 'https://c.saavncdn.com/artists/Raftaar_500x500.jpg',
    ),
    SaavnArtist(
      name: 'MC Stan',
      category: 'Modern Hits',
      subtitle: 'Basti Ka Hasti & New School Rap',
      avatarUrl: 'https://c.saavncdn.com/artists/MC_Stan_002_20221102071946_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Kavita Krishnamurthy',
      category: '90s Icons',
      subtitle: 'Dola Re Dola & 90s Magic',
      avatarUrl: 'https://c.saavncdn.com/artists/Kavita_Krishnamurthy_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Sadhana Sargam',
      category: '90s Icons',
      subtitle: 'Saat Samundar Paar & Melodies',
      avatarUrl: 'https://c.saavncdn.com/artists/Sadhana_Sargam_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Abhijeet Bhattacharya',
      category: '90s Icons',
      subtitle: 'Shah Rukh Khan 90s Voice',
      avatarUrl: 'https://c.saavncdn.com/artists/Abhijeet_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Lucky Ali',
      category: '90s Icons',
      subtitle: 'O Sanam & Indipop Maestro',
      avatarUrl: 'https://c.saavncdn.com/artists/Lucky_Ali_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Altaf Raja',
      category: '90s Icons',
      subtitle: 'Tum To Thehre Pardesi Legend',
      avatarUrl: 'https://c.saavncdn.com/artists/Altaf_Raja_500x500.jpg',
    ),
    SaavnArtist(
      name: 'A.R. Rahman',
      category: 'Legends',
      subtitle: 'Oscar-Winning Musical Genius',
      avatarUrl: 'https://c.saavncdn.com/artists/A_R_Rahman_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Sid Sriram',
      category: 'Modern Hits',
      subtitle: 'Srivalli & Soulful Pan-India Hits',
      avatarUrl: 'https://c.saavncdn.com/artists/Sid_Sriram_003_20240129080516_500x500.jpg',
    ),
    SaavnArtist(
      name: 'Anirudh Ravichander',
      category: 'Modern Hits',
      subtitle: 'Jawan & Hukum Rockstar',
      avatarUrl: 'https://c.saavncdn.com/artists/Anirudh_Ravichander_005_20230818113524_500x500.jpg',
    ),
  ];

  static SaavnArtist? findCuratedArtist(String name) {
    final clean = name.trim().toLowerCase();
    for (final artist in curatedArtists) {
      final aName = artist.name.toLowerCase();
      if (aName == clean || clean.contains(aName) || aName.contains(clean)) {
        return artist;
      }
    }
    return null;
  }

  Future<String?> _get(String url) async {
    try {
      final req = await _client.getUrl(Uri.parse(url));
      req.headers.set('User-Agent',
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');
      req.headers.set('Accept', 'application/json, text/plain, */*');
      final res = await req.close();
      if (res.statusCode == 200) {
        return await utf8.decodeStream(res);
      }
    } catch (_) {}
    return null;
  }

  static String _normalizeTitleForDedup(String raw) {
    var t = raw.toLowerCase()
        .replaceAll('&quot;', '')
        .replaceAll('&#039;', "'")
        .replaceAll('&amp;', '&');
    final p = t.indexOf('(');
    if (p > 0) {
      final inside = t.substring(p).toLowerCase();
      if (inside.contains('from') ||
          inside.contains('feat') ||
          inside.contains('movie') ||
          inside.contains('soundtrack')) {
        t = t.substring(0, p).trim();
      }
    }
    final b = t.indexOf('[');
    if (b > 0) {
      t = t.substring(0, b).trim();
    }
    return t.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  Future<List<OnlineSong>> searchSongs(String query, {int page = 1, int limit = 30}) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return const [];

    final cacheKey = '${cleanQuery.toLowerCase()}_${page}_$limit';
    if (_cachedQueries.containsKey(cacheKey)) {
      return _cachedQueries[cacheKey]!;
    }

    if (limit > 40) {
      final pagesNeeded = (limit / 50).ceil().clamp(1, 8);
      final futures = <Future<List<OnlineSong>>>[];
      for (int p = 1; p <= pagesNeeded; p++) {
        futures.add(_searchSinglePage(cleanQuery, page: p, limit: 50));
      }
      final results = await Future.wait(futures);
      final combined = <OnlineSong>[];
      final seenIds = <String>{};
      final seenTitles = <String>{};
      for (final list in results) {
        for (final song in list) {
          if (!seenIds.add(song.id)) continue;
          final norm = _normalizeTitleForDedup(song.title);
          if (norm.isNotEmpty && !seenTitles.add(norm)) continue;
          combined.add(song);
        }
      }
      if (combined.isNotEmpty) {
        _cachedQueries[cacheKey] = combined;
      }
      return combined;
    }

    final single = await _searchSinglePage(cleanQuery, page: page, limit: limit);
    if (single.isNotEmpty) {
      _cachedQueries[cacheKey] = single;
    }
    return single;
  }

  Future<List<OnlineSong>> _searchSinglePage(String cleanQuery, {required int page, required int limit}) async {
    try {
      final q = Uri.encodeComponent(cleanQuery);
      final url =
          '$_baseUrl?__call=search.getResults&q=$q&_format=json&_marker=0&api_version=4&n=$limit&p=$page';

      final body = await _get(url);
      if (body == null) return const [];

      final data = json.decode(body);
      if (data is Map && data['results'] is List) {
        final list = <OnlineSong>[];
        for (final item in data['results']) {
          if (item is Map<String, dynamic>) {
            final song = OnlineSong.fromJson(item);
            if (song != null) list.add(song);
          }
        }
        return list;
      }
    } catch (_) {}

    return const [];
  }

  /// 2. Trending / Top Charts:
  /// Most-played weekly chartbusters aur recommendation list fetch karna
  Future<List<OnlineSong>> getTrendingSongs({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedTrending != null && _cachedTrending!.isNotEmpty) {
      return _cachedTrending!;
    }

    try {
      // Fetch 'Trending Today' playlist (listid=110858205) or 'India Superhits Top 50'
      const playlistUrl =
          '$_baseUrl?__call=playlist.getDetails&listid=110858205&_format=json&api_version=4&_marker=0';
      final body = await _get(playlistUrl);

      if (body != null) {
        final data = json.decode(body);
        if (data is Map && data['list'] is List) {
          final list = <OnlineSong>[];
          for (final item in data['list']) {
            if (item is Map<String, dynamic>) {
              final song = OnlineSong.fromJson(item);
              if (song != null) list.add(song);
            }
          }
          if (list.isNotEmpty) {
            _cachedTrending = list;
            return list;
          }
        }
      }
    } catch (_) {}

    // Fallback: search top trending
    final fallback = await searchSongs('Hindi Trending Hits', limit: 25);
    if (fallback.isNotEmpty) {
      _cachedTrending = fallback;
    }
    return fallback;
  }

  /// 3. Categorized Playlists:
  /// - 'New Bollywood Hits' (Latest releases)
  /// - 'Evergreen Classics' (70s, 80s, 90s Golden Hits)
  Future<List<OnlineSong>> getCategorizedPlaylist(String category) async {
    if (_cachedPlaylists.containsKey(category)) {
      return _cachedPlaylists[category]!;
    }

    final isNewHits = category == 'New Bollywood Hits';
    final queries = isNewHits
        ? ['Latest Bollywood', 'New Hindi Songs']
        : ['Bollywood Retro', 'Evergreen Bollywood', 'Old Hindi Songs'];

    final allSongs = <OnlineSong>[];
    final seenIds = <String>{};

    for (final q in queries) {
      final songs = await searchSongs(q, limit: 35);
      for (final s in songs) {
        if (seenIds.add(s.id)) {
          allSongs.add(s);
        }
      }
      if (allSongs.length >= 30) break;
    }

    if (allSongs.isNotEmpty) {
      _cachedPlaylists[category] = allSongs;
    }
    return allSongs;
  }

  /// 4. Artist Catalog Fetcher:
  /// Specific Artist query se us singer ke top 20-30 songs dynamically load karna
  Future<List<OnlineSong>> getArtistSongs(String artistName, {int limit = 300}) async {
    final key = artistName.trim().toLowerCase();
    if (_cachedArtists.containsKey(key)) {
      return _cachedArtists[key]!;
    }

    final songs = await searchSongs(artistName, limit: limit);
    if (songs.isNotEmpty) {
      _cachedArtists[key] = songs;
    }
    return songs;
  }

  /// Search online artists dynamically from JioSaavn
  Future<List<SaavnArtist>> searchArtists(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return const [];
    try {
      final url =
          '$_baseUrl?__call=search.getArtistResults&q=${Uri.encodeComponent(clean)}&_format=json&api_version=4&n=20';
      final body = await _get(url);
      if (body != null) {
        final data = json.decode(body);
        if (data is Map && data['results'] is List) {
          final list = <SaavnArtist>[];
          for (final item in data['results']) {
            if (item is Map) {
              final name = item['name']?.toString() ?? '';
              if (name.isEmpty) continue;
              var img = item['image']?.toString() ?? '';
              if (img.contains('50x50')) {
                img = img.replaceAll('50x50', '500x500');
              } else if (img.contains('150x150')) {
                img = img.replaceAll('150x150', '500x500');
              }
              final role = item['role']?.toString() ?? 'Artist';
              list.add(SaavnArtist(
                name: OnlineSong.unescapeHtml(name),
                category: 'All',
                subtitle: role,
                avatarUrl: img,
              ));
            }
          }
          return list;
        }
      }
    } catch (_) {}
    return const [];
  }

  /// 5. Dynamic Mood & Regional Playlists:
  /// - Rajasthani & Marwari Hits (Veena classics, chang/dhamal, lokgeet)
  /// - Bhakti & Bhajan (Krishna, Ram dhun, Aarti)
  /// - Deshbhakti & Motivation (Patriotic Hindi anthems)
  /// - 90s Romantic & Melodies (Evergreen love classics)
  static const List<Map<String, String>> moodCategories = [
    {
      'id': 'rajasthani',
      'title': 'Rajasthani & Marwari',
      'subtitle': 'Veena Classics, Lokgeet & Dhamal',
      'icon': '🪕',
      'query': 'Rajasthani',
      'color1': '0xFFFF8C00', // Saffron / Marwari Orange
      'color2': '0xFFFF3D00',
    },
    {
      'id': 'bhakti',
      'title': 'Bhakti & Bhajan',
      'subtitle': 'Krishna, Ram Dhun & Daily Aarti',
      'icon': '🪔',
      'query': 'Bhakti',
      'color1': '0xFFFFD700', // Gold / Divine Amber
      'color2': '0xFFFF6D00',
    },
    {
      'id': 'deshbhakti',
      'title': 'Deshbhakti & Motivation',
      'subtitle': 'Patriotic Anthems & Energy',
      'icon': '🇮🇳',
      'query': 'Deshbhakti',
      'color1': '0xFF00C853', // Indian Flag Green
      'color2': '0xFF1E88E5',
    },
    {
      'id': '90s_romantic',
      'title': '90s Romantic & Melodies',
      'subtitle': 'Golden Era Love Songs & Melodies',
      'icon': '💖',
      'query': '90s Romantic',
      'color1': '0xFFFF4081', // Romantic Pink / Purple
      'color2': '0xFF7C4DFF',
    },
  ];

  Future<List<OnlineSong>> getMoodPlaylist(String moodId, {int limit = 35}) async {
    final cat = moodCategories.firstWhere(
      (c) => c['id'] == moodId,
      orElse: () => moodCategories.first,
    );
    final primaryQuery = cat['query'] ?? 'Hindi Hits';

    final Map<String, List<String>> fallbacks = {
      'rajasthani': ['Rajasthani', 'Marwadi', 'Veena Rajasthani'],
      'bhakti': ['Bhakti', 'Bhajan', 'Krishna Bhajan', 'Aarti'],
      'deshbhakti': ['Deshbhakti', 'Patriotic Hindi', 'Desh Bhakti'],
      '90s_romantic': ['90s Romantic', '90s Bollywood', '90s Hindi Love'],
    };

    final queriesToTry = fallbacks[moodId] ?? [primaryQuery];
    final allSongs = <OnlineSong>[];
    final seenIds = <String>{};

    for (final q in queriesToTry) {
      final songs = await searchSongs(q, limit: limit);
      for (final s in songs) {
        if (seenIds.add(s.id)) {
          allSongs.add(s);
        }
      }
      if (allSongs.length >= limit) break;
    }

    return allSongs;
  }

  // In-memory cache for song lyrics
  final Map<String, String> _cachedLyrics = {};

  /// 6. Synced / Live Lyrics:
  /// Fetch lyrics from JioSaavn API using song ID or lyrics ID
  Future<String?> getLyrics(String songId) async {
    if (songId.isEmpty) return null;
    if (_cachedLyrics.containsKey(songId)) {
      return _cachedLyrics[songId];
    }

    try {
      final url = '$_baseUrl?__call=lyrics.getLyrics&lyrics_id=$songId&_format=json&api_version=4&_marker=0';
      final body = await _get(url);
      if (body != null) {
        final data = json.decode(body);
        if (data is Map && data['lyrics'] != null) {
          String lyrics = data['lyrics'].toString();
          // Clean HTML tags and entities
          lyrics = lyrics
              .replaceAll('<br />', '\n')
              .replaceAll('<br/>', '\n')
              .replaceAll('<br>', '\n')
              .replaceAll('&quot;', '"')
              .replaceAll('&#039;', "'")
              .replaceAll('&amp;', '&');
          lyrics = lyrics.trim();
          if (lyrics.isNotEmpty) {
            _cachedLyrics[songId] = lyrics;
            return lyrics;
          }
        }
      }
    } catch (_) {}

    return null;
  }

  /// 7. JioSaavn Playlist Fetcher & Syncer:
  /// Supports JioSaavn playlist URLs, tokens, list IDs, or search queries
  Future<JioPlaylistResult> fetchPlaylist(String input) async {
    final clean = input.trim();
    if (clean.isEmpty) return const JioPlaylistResult(title: 'Playlist', songs: []);

    String playlistTitle = 'JioSaavn Playlist';
    try {
      String? token;
      String? listId;

      if (clean.contains('jiosaavn.com')) {
        final uri = Uri.tryParse(clean);
        if (uri != null) {
          final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
          if (segments.isNotEmpty) {
            token = segments.last;
          }
        }
      } else if (RegExp(r'^[0-9]+$').hasMatch(clean)) {
        listId = clean;
      } else if (clean.length > 15 && !clean.contains(' ')) {
        token = clean;
      }

      // 1. If we have a token, resolve playlist details via webapi.get
      if (token != null && token.isNotEmpty) {
        final tokenUrl =
            '$_baseUrl?__call=webapi.get&token=${Uri.encodeComponent(token)}&type=playlist&_format=json&api_version=4';
        final body = await _get(tokenUrl);
        if (body != null) {
          final data = json.decode(body);
          if (data is Map) {
            final t = data['title']?.toString();
            if (t != null && t.isNotEmpty) playlistTitle = OnlineSong.unescapeHtml(t);
            final foundId = data['id']?.toString() ?? data['listid']?.toString();
            if (foundId != null && foundId.isNotEmpty) {
              listId = foundId;
            } else if (data['list'] is List) {
              final list = <OnlineSong>[];
              for (final item in data['list']) {
                if (item is Map<String, dynamic>) {
                  final s = OnlineSong.fromJson(item);
                  if (s != null) list.add(s);
                }
              }
              if (list.isNotEmpty) {
                return JioPlaylistResult(title: playlistTitle, songs: list);
              }
            }
          }
        }
      }

      // 2. If listId resolved, fetch full songs list
      if (listId != null && listId.isNotEmpty) {
        final listUrl =
            '$_baseUrl?__call=playlist.getDetails&listid=${Uri.encodeComponent(listId)}&_format=json&api_version=4&n=500';
        final body = await _get(listUrl);
        if (body != null) {
          final data = json.decode(body);
          if (data is Map) {
            final t = data['title']?.toString() ?? data['listname']?.toString();
            if (t != null && t.isNotEmpty) playlistTitle = OnlineSong.unescapeHtml(t);
            final rawList = data['list'] ?? data['songs'];
            if (rawList is List) {
              final list = <OnlineSong>[];
              for (final item in rawList) {
                if (item is Map<String, dynamic>) {
                  final s = OnlineSong.fromJson(item);
                  if (s != null) list.add(s);
                }
              }
              if (list.isNotEmpty) {
                return JioPlaylistResult(title: playlistTitle, songs: list);
              }
            }
          }
        }
      }

      // 3. Search playlist by query
      final searchUrl =
          '$_baseUrl?__call=search.getPlaylistResults&q=${Uri.encodeComponent(clean)}&_format=json&api_version=4&n=5';
      final searchBody = await _get(searchUrl);
      if (searchBody != null) {
        final searchData = json.decode(searchBody);
        if (searchData is Map &&
            searchData['results'] is List &&
            (searchData['results'] as List).isNotEmpty) {
          final first = searchData['results'][0];
          final t = first['title']?.toString();
          if (t != null && t.isNotEmpty) playlistTitle = OnlineSong.unescapeHtml(t);
          final pid = first['id']?.toString() ?? first['listid']?.toString();
          if (pid != null && pid.isNotEmpty) {
            final plBody = await _get(
                '$_baseUrl?__call=playlist.getDetails&listid=$pid&_format=json&api_version=4&n=500');
            if (plBody != null) {
              final plData = json.decode(plBody);
              final rawList = plData['list'] ?? plData['songs'];
              if (rawList is List) {
                final list = <OnlineSong>[];
                for (final item in rawList) {
                  if (item is Map<String, dynamic>) {
                    final s = OnlineSong.fromJson(item);
                    if (s != null) list.add(s);
                  }
                }
                if (list.isNotEmpty) {
                  return JioPlaylistResult(title: playlistTitle, songs: list);
                }
              }
            }
          }
        }
      }

      // 4. Fallback: Search songs
      final songs = await searchSongs(clean, limit: 120);
      return JioPlaylistResult(
        title: clean,
        songs: songs,
      );
    } catch (_) {}

    return JioPlaylistResult(title: playlistTitle, songs: const []);
  }
}

class JioPlaylistResult {
  final String title;
  final List<OnlineSong> songs;
  const JioPlaylistResult({required this.title, required this.songs});
}

