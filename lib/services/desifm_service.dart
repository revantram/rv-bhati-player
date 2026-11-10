import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/online_song.dart';

class DesiFmSeries {
  final String id;
  final String title;
  final String description;
  final String coverUrl;
  final String genre;
  final int totalEpisodes;
  final int totalDurationSeconds;
  final String slug;

  const DesiFmSeries({
    required this.id,
    required this.title,
    required this.description,
    required this.coverUrl,
    required this.genre,
    required this.totalEpisodes,
    required this.totalDurationSeconds,
    required this.slug,
  });

  factory DesiFmSeries.fromJson(Map<String, dynamic> json) {
    return DesiFmSeries(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Desi FM Series',
      description: json['series_description']?.toString() ?? '',
      coverUrl: json['cover_art_url']?.toString() ?? '',
      genre: json['genre_slug']?.toString() ?? 'Drama',
      totalEpisodes: (json['total_episodes'] as num?)?.toInt() ?? 0,
      totalDurationSeconds: (json['total_duration_seconds'] as num?)?.toInt() ?? 0,
      slug: json['slug']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'series_description': description,
        'cover_art_url': coverUrl,
        'genre_slug': genre,
        'total_episodes': totalEpisodes,
        'total_duration_seconds': totalDurationSeconds,
        'slug': slug,
      };
}

class DesiFmEpisode {
  final String id;
  final String seriesId;
  final String title;
  final String description;
  final String audioUrl;
  final String coverUrl;
  final int durationSeconds;
  final int episodeNumber;

  const DesiFmEpisode({
    required this.id,
    required this.seriesId,
    required this.title,
    required this.description,
    required this.audioUrl,
    required this.coverUrl,
    required this.durationSeconds,
    required this.episodeNumber,
  });

  factory DesiFmEpisode.fromJson(Map<String, dynamic> json, String defaultCover) {
    final rawCover = json['cover_art_url']?.toString() ?? '';
    final fullCover = rawCover.isNotEmpty ? rawCover : defaultCover;

    return DesiFmEpisode(
      id: json['id']?.toString() ?? '',
      seriesId: json['series_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Episode',
      description: json['episode_description']?.toString() ?? '',
      audioUrl: json['audio_url']?.toString() ?? '',
      coverUrl: fullCover,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      episodeNumber: (json['episode_number'] as num?)?.toInt() ?? 1,
    );
  }

  OnlineSong toOnlineSong(DesiFmSeries series) {
    return OnlineSong(
      id: 'desifm_$id',
      title: '$title: ${series.title}',
      artist: 'Desi FM (${series.genre.toUpperCase()})',
      album: series.title,
      duration: Duration(seconds: durationSeconds),
      imageUrl: coverUrl.isNotEmpty ? coverUrl : series.coverUrl,
      streamUrl: audioUrl,
    );
  }
}

class DesiFmService {
  DesiFmService._() {
    _initBuiltin();
  }
  static final DesiFmService instance = DesiFmService._();

  static const String _seriesApi = 'https://api.desifm.app/series';

  static final List<Map<String, dynamic>> _builtinData = [{"id": "mj9toPgWBHcJWQWY7GToAPASvcgcArip", "title": "Hafte Ka Bantwara", "series_description": "Ek maa ne apne bete ko kho diya. Uske baad usne ek jhooth bola — ki us shaam woh ghar par nahi thi. Do saal baad wahi jhooth uski beti ki custody ka sabse mazboot saboot ban gaya. Ab use har hafte apni beti us ghar bhejni padti hai jahan uska beta gira tha. Sach bolegi to beti jaayegi. Chup rahegi to khud ko kabhi maaf nahi kar paayegi.", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/hafte_ka_bantwara.webp", "genre_slug": "drama", "total_episodes": 10, "total_duration_seconds": 5809, "slug": "hafte-ka-bantwara"}, {"id": "CIBqJjnp52oq1mWDNmFm9AQptzDHn0Hg", "title": "Ward Band Hai", "series_description": "Jhansi ke purane district hospital mein nayi night nurse Shreya ko upar wale band ward ki duty milti hai. Ward number nau, jo untees saal se band hai. Har subah wahan ek bed ki chadar gili milti hai. Purane register mein paani se naam likhe jaate hain. Jiska naam likha jaata hai, woh ward ka mareez ban jaata hai. Aur is baar register mein Shreya ka naam likha gaya hai.", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/ward_band_hai.webp", "genre_slug": "horror", "total_episodes": 10, "total_duration_seconds": 7670, "slug": "ward-band-hai"}, {"id": "kYFz52zOuD42n7CYloWXv0sJ28l8Geca", "title": "Peetal Ki Dibiya", "series_description": "Varanasi ke kabadi bazaar mein Ramesh ko ek purani peetal ki dibiya milti hai — bina seam, bina kabze. Us raat dibiya uski mari hui biwi ki awaaz mein bolti hai. Beti Chanda ko lagta hai maa wapas aa gayi hai. Par dibiya jo bhi naam sunti hai, woh kisi ki yaad se mitne lagta hai. Aur agli baar Chanda ka naam hai.", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/peetal_ki_dibiya.webp", "genre_slug": "horror", "total_episodes": 10, "total_duration_seconds": 7119, "slug": "peetal-ki-dibiya"}, {"id": "MVgAFDDLWOO5nLlpmnd75jV4bnaKjwSJ", "title": "Gehra Samundar", "series_description": "Konkan ke ek machhuare ko gyarah saal baad apna dooba hua beta jaal mein zinda milta hai — bilkul waisa hi, usi laal kameez mein. Gaon ise chamatkar kehta hai. Par uske aane ke baad har raat ek naya naam doobta hai. Beta wapas aaya hai... ya hisaab lene?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/gehra_samundar.webp", "genre_slug": "horror", "total_episodes": 10, "total_duration_seconds": 8475, "slug": "gehra-samundar"}, {"id": "LWQ6i5riQmjwecdEnBTYE0OpzssYHLDn", "title": "Barfi Ka Hisaab", "series_description": "Kanpur ke chaurahe par Tanvi apne pitaji ki mithai ki dukaan chalati hai. Ek din wahan bikri ka notice aa jata hai, aur kaghaz par uski maa ke dastkhat hain. Jis aadmi se woh roz ladti hai, wahi us dukaan par mall banana chahta hai. Dono ke pitaji ka naam ek hi kaghaz par likha hai — aur hisaab abhi baaki hai.", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/barfi_ka_hisaab.webp", "genre_slug": "romance", "total_episodes": 10, "total_duration_seconds": 7350, "slug": "barfi-ka-hisaab"}, {"id": "suFJBe6ittO7tUktNc5n7B0fpQ5njFe4", "title": "Peeli File", "series_description": "Indore Nagar Nigam ke record room mein retirement se ek mahina pehle Devendra ke haath ek peeli file aati hai — jis par uski khud ki likhawat hai. Bees saal purani ek zameen, ek murda kisan, aur ek muhar jo sab kuch badal degi.", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/peeli_file.webp", "genre_slug": "crime-thriller", "total_episodes": 10, "total_duration_seconds": 7117, "slug": "peeli-file"}, {"id": "dERlG2dKRPAFc385GMSw0UrRuZ7hcEFD", "title": "Doosri Subah", "series_description": "Jaipur ki purani Chandpol gali mein Amrita apni chhoti beti aur sasural ke saath rehti hai. Uska pura sansar uski silai ki dukaan hai — jab tak neeche ka naya kiraedar uski zindagi mein nahi aata. Ek aisi kahani jo poochti hai: kisi ki yaad chhodna gunah hai ya zaroorat?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/doosri_subah.webp", "genre_slug": "romance", "total_episodes": 20, "total_duration_seconds": 14053, "slug": "doosri-subah"}, {"id": "kDr1WTIXDoM5wafvf9zrm3KVm2HBEI3t", "title": "Khali Truck", "series_description": "Har mangalvar raat Hardev ek khaali truck lekar Saryu paar jaata hai. Paanch hazaar cash, koi parchi nahi, koi sawaal nahi. Nau saal se yahi routine hai. Lekin aaj raat truck ke andar se awaaz aayi — aur woh awaaz uski behen ki thi, jo nau saal pehle isi highway par gum ho gayi thi.", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/khali_truck.webp", "genre_slug": "crime-thriller", "total_episodes": 10, "total_duration_seconds": 7815, "slug": "khali-truck"}, {"id": "Ig3c3ufrIxpZpRWMcF1evhqPmS8pJocy", "title": "Maa Ki Chuppi", "series_description": "Woh maa jisne kabhi gale nahi lagaya. Kabhi nahi kaha ki \"meri beti.\" Ab uski saans ruk rahi hai. Paanch betiyan khadi hain... ro nahi pa rahi. Kyunki maa ne aakhri baar kaha, \"Meri chuppi tumhari mazbooti hai... chahe woh tumhe tod de.\" Kaun si beti bachegi is aag se?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/maa_ki_chuppi.webp", "genre_slug": "drama", "total_episodes": 10, "total_duration_seconds": 7957, "slug": "maa-ki-chuppi"}, {"id": "qKkPUwp8ZptWPWSX7FwK2SdkXZZeIzhz", "title": "Vansh Ki Aag", "series_description": "Ramveer Singh ki maut ke baad bada beta Surya – jisne parivaar ke liye sab kuch luta diya – use sirf ek gandi jhonpdi milti hai. Us jhonpdi ki chaabi kholti hai wo kismat jo uske janam se pehle hi likhi ja chuki thi. Kya Surya sirf ek kabaad ka malik hai... ya fir uske khoon mein chhipa hai poora sheher hila dene wala raaz?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/vansh_ki_aag.webp", "genre_slug": "drama", "total_episodes": 10, "total_duration_seconds": 5729, "slug": "vansh-ki-aag"}, {"id": "bdtwysnow5b5Y3DcNEaUFJzwEvewEo1i", "title": "Kaagzi Dil", "series_description": "Kajal ki purani diary se mila ek panna uski maa aur Rehan ke mare hue bhai Kabir ka aisa raaz kholta hai jo sab tabah kar sakta hai. Magar twist tab aata hai jab Kabir ka asli qatil koi gair nahi, balki uska apna hi parivar nikalta hai! Uski maa ne kyu di apni jaan? Kya khulega Kabir ki maut ka ye khaufnak raaz?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/kaagzi_dil.webp", "genre_slug": "romance", "total_episodes": 20, "total_duration_seconds": 8431, "slug": "kaagzi-dil"}, {"id": "JkBcu0gDjn1g8Rpn9407ZlVgNlXIpTG4", "title": "Kanch Ke Dil", "series_description": "Ek shaadi mein akele baithi tara ki nzarein us aadmi se milti hai jo uski tarah toota hai. \nAgle din pata chalta hai—woh uske ex ka bhai hai, aur uski poori zindagi uske bunaaye jaal mein phansi hai.\nAb sawaal yeh hai... Kaun hai asli villain? Aur kya yeh kaanch ke dil dubara jud payenge?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/kanch_ke_dil.webp", "genre_slug": "romance", "total_episodes": 10, "total_duration_seconds": 5107, "slug": "kanch-ke-dil"}, {"id": "snHwawfl0XxUkfmkLSXAbovFhl3bxuQC", "title": "Bewajah Tum", "series_description": "College mein teen saal se ek doosre se door baithe, par har roz aankhein milane waale Arav aur Meera. Ek raat library mein dekha—Meera ro rahi thi. Agle din woh gaayab. Kya Arav usse dhundh paayega? Ya ye pyaar bhi unki zindagi ki sabse badi saza ban jayega?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/bewajah_tum.webp", "genre_slug": "romance", "total_episodes": 10, "total_duration_seconds": 6403, "slug": "bewajah-tum"}, {"id": "Ctzoc7cKE199SqkLuvxZEH8xVGPprjo2", "title": "Samay Ki Barat", "series_description": "Shaadi ke mandap mein ek second ki light gayi, aur dulhan ke maathe pe jaadui ghunghat aa gaya. Ek rakshas Zarx uske andar hai, jo har janam mein unka pyaar mita deta hai. Saat janmo ki kahani, ek hi soul. Kya yeh couple apni maut ko harayega? Ya Zarx ki game abhi khatam nahi hui?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/samay_ki_barat.webp", "genre_slug": "sci-fi-fantasy", "total_episodes": 10, "total_duration_seconds": 5026, "slug": "samay-ki-barat"}, {"id": "GYB3Xe8PzgHdK9GYz2bOLpT4DSPIpx0q", "title": "Dusra Swarg", "series_description": "Mrti behen ne bulaya, aur main us neeli roshni mein chali gayi. Wahan swarg nahi, ek dangerous simulation tha. Ab main khud ek jail ban gayi hoon. Kya main maa ko bacha paungi? Ya yeh doosra swarg mujhe kabhi wapas nahi aane degi?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/dusra_swarg.webp", "genre_slug": "sci-fi-fantasy", "total_episodes": 10, "total_duration_seconds": 4316, "slug": "dusra-swarg"}, {"id": "ZdKtc3ankQjW2T3mSK3LDFdAy8yPmM5B", "title": "Tere Bina Adhura", "series_description": "Library ke uss koone mein ek chhatri ne do dilon ko chhu liya. Rehan har raat Aradhya ki khidki ke neeche aata, chaabiyan deta, waade karta... lekin apni maa ki diary kholte hi saamne aaya woh sach - uski maa aur Aradhya ki maa sagi behen thi. Ab yeh pyaar namumkin hai? Kya khoon ka rishta inki mohabbat ko maar daalega?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/tere_bina_adhura.webp", "genre_slug": "romance", "total_episodes": 10, "total_duration_seconds": 3872, "slug": "tere-bina-adhura"}, {"id": "EJPKKvkcReOvBXt1KbCMWmAZKHGaIxfl", "title": "Chhupa Dard", "series_description": "Ek ladka apna dard chupaata hai, ek ladki uski deewar ke uss paar roj toot-ti hai. Beech mein sirf patli deewar aur maa ka wo khat hai jisme likha hai – “usne mujhe nahi mara”. Lekin jab pata chalta hai ki khat aadha jala hai, toh sawaal badal jaata hai. Kaun hai woh? Aur kiske liye likha tha – “usne mujhe nahi mara”?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/chhupa_dard.webp", "genre_slug": "romance", "total_episodes": 10, "total_duration_seconds": 2120, "slug": "chhupa-dard"}, {"id": "muA9nqEccCVpRMoTb1B7ynl2bJVSGWZB", "title": "Akhiri Khat", "series_description": "Dus saal pehle jis ladki ko kabir ne khudkushi ki tarah mara dekha, usi ka aadha jala khat milta hai – ‘usne mujhe nahi mara’. ek raat uske darwaaze par wohi ladki khadi hoti hai… doosre chehre mein. kaun hai woh? aur kiske liye likha tha – ‘usne mujhe nahi mara’?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/akhiri_khat.webp", "genre_slug": "crime-thriller", "total_episodes": 15, "total_duration_seconds": 5460, "slug": "akhiri-khat"}, {"id": "3CQ0oQpo0EWQAHeRvXsOcDaz1oylsOvi", "title": "Nai Ki Dukaan", "series_description": "Ek SHO apne pitaji ke 30 saal purane mysterious case ki fir se jaanch karta hai. Unka sir takiye par mila tha, lekin shareer gayab. Har mahine 13 tarikh ko woh nayi dukaan ke bahar khada hota hai, jahan andar se kaichi ki awaazein aati hain. Kaun hai yeh kaichi? Aur kya hai iska raaz?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/nai_ki_dukaan.webp", "genre_slug": "horror", "total_episodes": 10, "total_duration_seconds": 2888, "slug": "nai-ki-dukaan"}, {"id": "aT5Zu3AHC6ZCguMPJykJeb5aoptRoNl2", "title": "Parchai", "series_description": "Riya apne naye ghar mein ek purani aaine ke saamne apni parchhaayi dekhti hai — jo uski nahi, kisi aur ki hai. Woh usse aankhen milati hai, aur ek raat woh aaine ke andar se nikal kar uske andar aa jaati hai. Kaun hai yeh aurat? Aur kya hai uska raaz?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/parchai.webp", "genre_slug": "horror", "total_episodes": 10, "total_duration_seconds": 3870, "slug": "parchai"}, {"id": "PDJDCE9mQKDreGPZUvu2I5zVuykejJLx", "title": "Andha Gawah", "series_description": "Ek andha insaan har raat apni padosan ki dard bhari cheekh sunta hai. Police ko bulata hai, lekin subah sab normal hota hai — koi khoon nahi, koi lash nahi. Phir ek raat woh khud uske ghar jaata hai aur khoon se latpat lash chhoota hai. Kaun hai yeh aurat? Kya hai is raat ka raaz?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/andha_gawah.webp", "genre_slug": "crime-thriller", "total_episodes": 10, "total_duration_seconds": 3802, "slug": "andha-gawah"}, {"id": "HUh37Twn8iMKwz0LuYnxtJu7xNtL8bTz", "title": "Pati Ki Diary", "series_description": "Pati ki maut ke baad Meera ko milti hai ek purani diary. Ussme likhe hain 10 aurton ke naam — har saal 15 September ko ek naam. Pati kaun tha? Aur yeh naam kyun likhe the? Kya Meera sach chhupa payegi?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/pati_ki_diary.webp", "genre_slug": "crime-thriller", "total_episodes": 10, "total_duration_seconds": 4532, "slug": "pati-ki-diary"}, {"id": "ipdtHzCIOgUQ9q0SQ3oIRnCQpfpvZf9h", "title": "Band Ankhe", "series_description": "Ek insaan subah uthta hai aur apne haatho par khoon dekhta hai. Use raat ko kuch yaad nahi. Uske andar koi aur rehta hai — jo raat ko jaagta hai, khoon karta hai, aur subah gayab ho jata hai. Kaun hai woh? Aur kyun kar raha hai yeh sab?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/band_ankhe.webp", "genre_slug": "crime-thriller", "total_episodes": 10, "total_duration_seconds": 3465, "slug": "band-ankhe"}, {"id": "hGipI4Rc6cRwWJ2eMjE9qWVlPvZ9I2uL", "title": "Dark Web", "series_description": "Ek college student Maahi online game khelti hai - \"Predator\". Pehle tasks simple hote hain, phir woh real murders mein badal jaate hain. Ab usse kisi ko naam batana hai, ya uski family hogi target. Kaun hai game ka asli creator? Aur kya hai uska dark web ka raaz?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/dark_web.webp", "genre_slug": "crime-thriller", "total_episodes": 10, "total_duration_seconds": 3147, "slug": "dark-web"}, {"id": "NWmZt2wDX3ZLtN1SanMG1uYT3CcclQ45", "title": "Akhiri Barish", "series_description": "Chaar dost, ek purani resort, aur barsaat mein band sadke. Ek raat Tara ko ek bhandi room mein milti hai ek diary. Usme likha hai — unn sabke naam jo is resort mein mar chuke hain. Aur ab unnmein se ek naam hai… uska apna.", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/akhiri_barish.webp", "genre_slug": "crime-thriller", "total_episodes": 10, "total_duration_seconds": 3415, "slug": "akhiri-barish"}, {"id": "HsCTJ2zjsorIhNjhvKMmJiARrAXFFRwF", "title": "20 Crore", "series_description": "Ek retired SSP ke bete ne 7 saal baad 20 crore loot ke paise wapas kar diye. Saath mein likha — \"Papa, main jaanta hoon uss raat aapne kya kiya tha.\" Kaun hai yeh beta? Aur usne yeh sab kyun kiya?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/20_crore.webp", "genre_slug": "crime-thriller", "total_episodes": 10, "total_duration_seconds": 3274, "slug": "20-crore"}, {"id": "5DFBnboMHV5ALDbAQzzb1Qv7RV9dicvw", "title": "Raat Ka Show", "series_description": "Ek famous night show anchor ki likhi har crime story next day real life mein ho jaati hai. Pehle usse coincidence lagta hai, phir usse pata chalta hai — koi uska loyal fan hai jo uski stories ko haqeeqat mein badal raha hai. Kaun hai woh? Aur kyun?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/raat_ka_show.webp", "genre_slug": "crime-thriller", "total_episodes": 10, "total_duration_seconds": 3326, "slug": "raat-ka-show"}, {"id": "4GmcdlACoCKqGnBIVvi9f6hRebpxOtrk", "title": "Tera Ghar Mera Kamra", "series_description": "Tumhare ghar ka har kamra. Tumhara sofa. Tumhara bed. Tumhari raat ki chai. Koi dekh raha hai. Har roz. Kaun? Tumhara padosi? Tumhara guard? Ya tumhara apna koi? Ab tum bhi check karo – jo camera tumne safety ke liye lagaya tha, woh kiski aankh ban chuka hai. Kyunki ab woh tumhe dekh raha hai. Tumhare ghar mein. Tumhare kamre mein. Tumhare saath.", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/tera_ghar_mera_kamra.webp", "genre_slug": "crime-thriller", "total_episodes": 10, "total_duration_seconds": 4147, "slug": "tera-ghar-mera-kamra"}, {"id": "SePtfpo57UKYADo50BGD0upDw49YBClM", "title": "Khooni Calendar", "series_description": "Ek maa ki hatya. Ek beta jo 29 saal baad insaaf leta hai. Har maheene ek maut. Har seene par agle maheene ki taareekh. Lekin asli katali ab bhi police ki vardi mein hai. Ab dekhte hain – kaun bachta hai, kaun marta hai, aur kaun calendar ka agla panna palat ta hai.", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/khooni_calendar.webp", "genre_slug": "crime-thriller", "total_episodes": 10, "total_duration_seconds": 3990, "slug": "khooni-calendar"}, {"id": "QgZc8gECtEfT7lpEO4TptRbjG2VE50Yi", "title": "Sukha Kua", "series_description": "Jab raat ke barah baje kue se awaaz aati hai, gaon ke log dar se kapkapte hain. Koi nahi jaanta uss kue mein kya hai. Ek ladki jiska munh sila hai. Woh bulati hai. Jo uski awaaz sun leta hai, woh kabhi wapas nahi aata. Kya usey koi rok sakta hai? Suno poori kahani.\n", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/sukha_kua.webp", "genre_slug": "horror", "total_episodes": 10, "total_duration_seconds": 4118, "slug": "sukha-kua"}, {"id": "cgOD3PaNjxAmzx6GJzjBZ48EzH48QtOm", "title": "Call Call", "series_description": "Raat 3:03. Screen pe apna number. Koi mare hue logo ki awaaz mein kehta hai — kal subah mat uthna. Pehle laga prank. Phir laga ki yeh kuch aur hai. Tab tak bahut der ho chuki thi. Ye series hai uss ek call ki — jo zindagi badalti hai. Ya khatam. Hamesha ke liye.", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/call_call.webp", "genre_slug": "horror", "total_episodes": 10, "total_duration_seconds": 3109, "slug": "call-call"}, {"id": "uOrfxqY3RERqyYUB4HjUmx0xqUHkllwV", "title": "Zero Se Billionaire", "series_description": "Ek ladka jiske paas kuch nahi tha — na padhai, na paise, na baap. Par usne kabhi haar nahi maani. Chori se shuru kiya, phir cycle se, phir apna business khada kiya. Kaise ek gareeb bachcha 3,000 crore ka maalik ban gaya? Ye kahani hai uske safar ki.", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/zero_se_billionaire.webp", "genre_slug": "drama", "total_episodes": 5, "total_duration_seconds": 2483, "slug": "zero-se-billionaire"}, {"id": "64fqdA6o3lSCLllcNw6xYKHFjAXxNgRX", "title": "Woh Akhiri Call", "series_description": "Ek call center agent, Arjun, ki night shift mein aati hai ek ladki ki khatarnaak call. Woh kidnap hai, par police corrupt hai. Ab Arjun ke paas sirf ek hint hai — train, factory, aur ek naam 'Vikram'. Kya woh use dhundh paayega?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/woh_akhiri_call.webp", "genre_slug": "crime-thriller", "total_episodes": 5, "total_duration_seconds": 2356, "slug": "woh-akhiri-call"}, {"id": "iJsNUTMCHLboyh87Frc1yOHaSrEdIIzM", "title": "Sunta Hain Andhera", "series_description": "Ek andha dukandaar raat ko sirf awaazon se ek khun hone ka pura naksha sun leta hai. Police ko uska gavah manzoor nahi, lekin woh apne kaano se woh sab dekh leta hai jo aankhon se nahi dikhta. Raaz kya hai?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/sunta_hain_andhera.webp", "genre_slug": "crime-thriller", "total_episodes": 5, "total_duration_seconds": 1617, "slug": "sunta-hain-andhera"}, {"id": "RO2zDZHYX2OPhGTMGT01qAJqKrVyQBUC", "title": "Number 13 Ki Kirayedar", "series_description": "Ek naya flat, ek purani khushbu, aur aaine par likha ek shabd - \"Jao.\" Nahaana band hota hua nalka, apne aap hatti hui kursi, aur raat ke 2 baje kaunsi parchaai? Kahaani hai Khaavya ki jo lapata ho gayi. Par kya wo sach mein gayi? Ya ab bhi hai? Flat number 13 ka raaz kya hai?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/number_13_ki_kirayedar.webp", "genre_slug": "horror", "total_episodes": 5, "total_duration_seconds": 1532, "slug": "number-13-ki-kirayedar"}, {"id": "roIqAHWLUuVG159YyDJUJAHjbhYHeChO", "title": "Sab Sunne Wala Ghar", "series_description": "Kuch ghar sirf dekhate nahi, sunte bhi hain. Ek journalist, ek purani kothi, aur raat ke 2:30 bajay aaine mein dikhi parchaai. Lekin sabse strange baat? Uska apna recorder, jis mein kisi aur ki awaaz aayi. Aur wo awaaz jaanti thi uska naam. Kaun hai \"Woh\"? Aur kyun yeh ghar sirf uska intezaar kar raha tha?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/sab_sunne_wala_ghar.webp", "genre_slug": "horror", "total_episodes": 5, "total_duration_seconds": 881, "slug": "sab-sunne-wala-ghar"}, {"id": "QRMHhBOlfvU3qvvD0FT5vmvD82MQmRDf", "title": "Ek Crore Ki Gend", "series_description": "Ek kisaan, ek rubber ball, aur ek sapna jisko duniya ne roka. IPL auction mein ek naam chamka — 2 crore ka. Par uss number ke peeche chhupa hai ek baap ka woh faisla, jiske baare mein koi nahi jaanta. Kya tha woh raaz?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/ek_crore_ki_gend.webp", "genre_slug": "drama", "total_episodes": 5, "total_duration_seconds": 3781, "slug": "ek-crore-ki-gend"}, {"id": "d3ylFtV1YjCMPBiYotnV8DSK2pvVTBUj", "title": "Teen Tale", "series_description": "Ek marne wale pitaji ki diary milti hai beti Aarti ko. Teen naam likhe hain — aur teenon ki maut 'heart attack' se. Lekin ek common baat? Teeno ki diaries gayab. Ab Aarti ke paas ek sawaal hai: Kaun hai woh jo har diary chura raha hai? Aur kyun?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/teen_tale.webp", "genre_slug": "crime-thriller", "total_episodes": 5, "total_duration_seconds": 4282, "slug": "teen-tale"}, {"id": "Yn5U6I5GsEBHTHZFTsz2AO8THkhEQ68k", "title": "Khoon Se Likhi Vashihat", "series_description": "Ek purani diary, teen shabd, aur ek vasiyat — jo kisi lawyer ne nahi, kisi marne wale insaan ne apne khoon se likhi. Ek bhai doosre bhai ke khilaf. Ek maa ki chaupaal, aur ek sach jo 12 saal tak dafan raha. Kya tha uss diary mein? Aur kaun tha asli kathil?", "cover_art_url": "https://cdnpublic.zippybits.in/r2_desifm/cover/khoon_se_likhi_vashihat.webp", "genre_slug": "crime-thriller", "total_episodes": 5, "total_duration_seconds": 4796, "slug": "khoon-se-likhi-vashihat"}];

  List<DesiFmSeries> _cachedSeries = [];
  final Map<String, List<DesiFmEpisode>> _cachedEpisodes = {};

  List<DesiFmSeries> get series => List.unmodifiable(_cachedSeries);

  void _initBuiltin() {
    _cachedSeries = _builtinData.map((e) => DesiFmSeries.fromJson(e)).toList();
  }

  File _getCacheFile() {
    return File('/data/user/0/com.rvbhati.player/files/desifm_series_v1.json');
  }

  Future<List<DesiFmSeries>> fetchSeriesList({bool forceRefresh = false}) async {
    if (_cachedSeries.isNotEmpty && !forceRefresh) {
      _fetchRemoteSeries();
      return _cachedSeries;
    }

    if (!forceRefresh) {
      try {
        final cache = _getCacheFile();
        if (cache.existsSync()) {
          final content = await cache.readAsString();
          final list = jsonDecode(content) as List?;
          if (list != null && list.isNotEmpty) {
            _cachedSeries = list
                .map((e) => DesiFmSeries.fromJson(e as Map<String, dynamic>))
                .toList();
            _fetchRemoteSeries();
            return _cachedSeries;
          }
        }
      } catch (e) {
        debugPrint('[DesiFmService] Cache load error: $e');
      }
    }

    final remote = await _fetchRemoteSeries();
    if (remote.isNotEmpty) {
      return remote;
    }
    return _cachedSeries;
  }

  Future<List<DesiFmSeries>> _fetchRemoteSeries() async {
    try {
      final resp = await http.get(
        Uri.parse(_seriesApi),
        headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final list = jsonDecode(resp.body) as List? ?? [];
        final parsed = list
            .map((e) => DesiFmSeries.fromJson(e as Map<String, dynamic>))
            .where((s) => s.id.isNotEmpty && s.title.isNotEmpty)
            .toList();

        if (parsed.isNotEmpty) {
          _cachedSeries = parsed;
          try {
            final cache = _getCacheFile();
            if (!cache.parent.existsSync()) {
              cache.parent.createSync(recursive: true);
            }
            await cache.writeAsString(jsonEncode(parsed.map((s) => s.toJson()).toList()));
          } catch (_) {}
          return _cachedSeries;
        }
      }
    } catch (e) {
      debugPrint('[DesiFmService] Fetch series error: $e');
    }
    return _cachedSeries;
  }

  Future<List<DesiFmEpisode>> fetchSeriesEpisodes(DesiFmSeries series) async {
    if (_cachedEpisodes.containsKey(series.slug) && _cachedEpisodes[series.slug]!.isNotEmpty) {
      return _cachedEpisodes[series.slug]!;
    }

    try {
      final targetKey = series.slug.isNotEmpty ? series.slug : series.id;
      final url = '$_seriesApi/$targetKey';
      final resp = await http.get(
        Uri.parse(url),
        headers: {'User-Agent': 'Mozilla/5.0 (Android; Mobile)'},
      ).timeout(const Duration(seconds: 10));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as Map<String, dynamic>;
        final rawEpisodes = data['episodes'] as List? ?? [];
        final episodes = rawEpisodes
            .map((e) => DesiFmEpisode.fromJson(e as Map<String, dynamic>, series.coverUrl))
            .where((ep) => ep.audioUrl.isNotEmpty)
            .toList();

        episodes.sort((a, b) => a.episodeNumber.compareTo(b.episodeNumber));

        if (episodes.isNotEmpty) {
          _cachedEpisodes[series.slug] = episodes;
          return episodes;
        }
      }
    } catch (e) {
      debugPrint('[DesiFmService] Fetch episodes error: $e');
    }
    return _cachedEpisodes[series.slug] ?? const [];
  }

  List<DesiFmSeries> searchSeries(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return _cachedSeries;
    return _cachedSeries.where((s) {
      return s.title.toLowerCase().contains(q) ||
          s.genre.toLowerCase().contains(q) ||
          s.description.toLowerCase().contains(q);
    }).toList();
  }
}
