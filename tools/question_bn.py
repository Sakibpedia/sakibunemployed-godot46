"""Bengali translation tables for tools/generate_questions.py (the game is in Bengali).

Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

Names follow common Bengali usage in BCS guidebooks and newspapers. Anything missing from a table
falls back to English in the generator, so a gap never breaks an item.
"""
import re


DISTRICT_BN = {
    "Dhaka": "ঢাকা", "Gazipur": "গাজীপুর", "Narayanganj": "নারায়ণগঞ্জ", "Narsingdi": "নরসিংদী", "Manikganj": "মানিকগঞ্জ",
    "Munshiganj": "মুন্সিগঞ্জ", "Tangail": "টাঙ্গাইল", "Kishoreganj": "কিশোরগঞ্জ", "Faridpur": "ফরিদপুর", "Gopalganj": "গোপালগঞ্জ",
    "Madaripur": "মাদারীপুর", "Rajbari": "রাজবাড়ী", "Shariatpur": "শরীয়তপুর", "Chattogram": "চট্টগ্রাম", "Cox's Bazar": "কক্সবাজার",
    "Bandarban": "বান্দরবান", "Rangamati": "রাঙামাটি", "Khagrachhari": "খাগড়াছড়ি", "Cumilla": "কুমিল্লা", "Brahmanbaria": "ব্রাহ্মণবাড়িয়া",
    "Chandpur": "চাঁদপুর", "Feni": "ফেনী", "Lakshmipur": "লক্ষ্মীপুর", "Noakhali": "নোয়াখালী", "Rajshahi": "রাজশাহী", "Bogura": "বগুড়া",
    "Joypurhat": "জয়পুরহাট", "Naogaon": "নওগাঁ", "Natore": "নাটোর", "Chapai Nawabganj": "চাঁপাইনবাবগঞ্জ", "Pabna": "পাবনা",
    "Sirajganj": "সিরাজগঞ্জ", "Khulna": "খুলনা", "Bagerhat": "বাগেরহাট", "Chuadanga": "চুয়াডাঙ্গা", "Jashore": "যশোর",
    "Jhenaidah": "ঝিনাইদহ", "Kushtia": "কুষ্টিয়া", "Magura": "মাগুরা", "Meherpur": "মেহেরপুর", "Narail": "নড়াইল", "Satkhira": "সাতক্ষীরা",
    "Barishal": "বরিশাল", "Barguna": "বরগুনা", "Bhola": "ভোলা", "Jhalokati": "ঝালকাঠি", "Patuakhali": "পটুয়াখালী", "Pirojpur": "পিরোজপুর",
    "Sylhet": "সিলেট", "Habiganj": "হবিগঞ্জ", "Moulvibazar": "মৌলভীবাজার", "Sunamganj": "সুনামগঞ্জ", "Rangpur": "রংপুর",
    "Dinajpur": "দিনাজপুর", "Gaibandha": "গাইবান্ধা", "Kurigram": "কুড়িগ্রাম", "Lalmonirhat": "লালমনিরহাট", "Nilphamari": "নীলফামারী",
    "Panchagarh": "পঞ্চগড়", "Thakurgaon": "ঠাকুরগাঁও", "Mymensingh": "ময়মনসিংহ", "Jamalpur": "জামালপুর", "Netrokona": "নেত্রকোনা",
    "Sherpur": "শেরপুর",
}

# country -> (country in Bengali, capital in Bengali)
COUNTRY_BN = {
    "Afghanistan": ("আফগানিস্তান", "কাবুল"), "Algeria": ("আলজেরিয়া", "আলজিয়ার্স"), "Angola": ("অ্যাঙ্গোলা", "লুয়ান্ডা"),
    "Argentina": ("আর্জেন্টিনা", "বুয়েনস আইরেস"), "Armenia": ("আর্মেনিয়া", "ইয়েরেভান"), "Australia": ("অস্ট্রেলিয়া", "ক্যানবেরা"),
    "Austria": ("অস্ট্রিয়া", "ভিয়েনা"), "Azerbaijan": ("আজারবাইজান", "বাকু"), "Bahrain": ("বাহরাইন", "মানামা"), "Belarus": ("বেলারুশ", "মিনস্ক"),
    "Belgium": ("বেলজিয়াম", "ব্রাসেলস"), "Bhutan": ("ভুটান", "থিম্পু"), "Botswana": ("বতসোয়ানা", "গ্যাবোরোন"), "Brazil": ("ব্রাজিল", "ব্রাসিলিয়া"),
    "Brunei": ("ব্রুনাই", "বন্দর সেরি বেগাওয়ান"), "Cambodia": ("কম্বোডিয়া", "নমপেন"), "Cameroon": ("ক্যামেরুন", "ইয়াউন্ডে"),
    "Canada": ("কানাডা", "অটোয়া"), "Chad": ("চাদ", "এনজামেনা"), "Chile": ("চিলি", "সান্তিয়াগো"), "China": ("চীন", "বেইজিং"),
    "Colombia": ("কলম্বিয়া", "বোগোতা"), "Croatia": ("ক্রোয়েশিয়া", "জাগরেব"), "Cuba": ("কিউবা", "হাভানা"), "Cyprus": ("সাইপ্রাস", "নিকোসিয়া"),
    "Czechia": ("চেক প্রজাতন্ত্র", "প্রাগ"), "Denmark": ("ডেনমার্ক", "কোপেনহেগেন"), "Ecuador": ("ইকুয়েডর", "কিটো"), "Egypt": ("মিসর", "কায়রো"),
    "Estonia": ("এস্তোনিয়া", "তালিন"), "Ethiopia": ("ইথিওপিয়া", "আদ্দিস আবাবা"), "Fiji": ("ফিজি", "সুভা"), "Finland": ("ফিনল্যান্ড", "হেলসিংকি"),
    "France": ("ফ্রান্স", "প্যারিস"), "Georgia": ("জর্জিয়া", "তিবিলিসি"), "Germany": ("জার্মানি", "বার্লিন"), "Ghana": ("ঘানা", "আক্রা"),
    "Greece": ("গ্রিস", "এথেন্স"), "Hungary": ("হাঙ্গেরি", "বুদাপেস্ট"), "Iceland": ("আইসল্যান্ড", "রেইকিয়াভিক"), "India": ("ভারত", "নয়াদিল্লি"),
    "Iran": ("ইরান", "তেহরান"), "Iraq": ("ইরাক", "বাগদাদ"), "Ireland": ("আয়ারল্যান্ড", "ডাবলিন"), "Italy": ("ইতালি", "রোম"),
    "Jamaica": ("জ্যামাইকা", "কিংস্টন"), "Japan": ("জাপান", "টোকিও"), "Jordan": ("জর্ডান", "আম্মান"), "Kenya": ("কেনিয়া", "নাইরোবি"),
    "Kuwait": ("কুয়েত", "কুয়েত সিটি"), "Kyrgyzstan": ("কিরগিজস্তান", "বিশকেক"), "Laos": ("লাওস", "ভিয়েনতিয়েন"), "Latvia": ("লাটভিয়া", "রিগা"),
    "Lebanon": ("লেবানন", "বৈরুত"), "Libya": ("লিবিয়া", "ত্রিপোলি"), "Lithuania": ("লিথুয়ানিয়া", "ভিলনিয়াস"),
    "Madagascar": ("মাদাগাস্কার", "আন্তানানারিভো"), "Malaysia": ("মালয়েশিয়া", "কুয়ালালামপুর"), "Maldives": ("মালদ্বীপ", "মালে"),
    "Mali": ("মালি", "বামাকো"), "Malta": ("মাল্টা", "ভ্যালেটা"), "Mexico": ("মেক্সিকো", "মেক্সিকো সিটি"), "Mongolia": ("মঙ্গোলিয়া", "উলানবাটোর"),
    "Morocco": ("মরক্কো", "রাবাত"), "Mozambique": ("মোজাম্বিক", "মাপুতো"), "Myanmar": ("মিয়ানমার", "নেপিদো"), "Namibia": ("নামিবিয়া", "উইন্ডহোক"),
    "Nepal": ("নেপাল", "কাঠমান্ডু"), "New Zealand": ("নিউজিল্যান্ড", "ওয়েলিংটন"), "Niger": ("নাইজার", "নিয়ামে"), "Nigeria": ("নাইজেরিয়া", "আবুজা"),
    "North Korea": ("উত্তর কোরিয়া", "পিয়ংইয়ং"), "Norway": ("নরওয়ে", "অসলো"), "Oman": ("ওমান", "মাসকট"), "Pakistan": ("পাকিস্তান", "ইসলামাবাদ"),
    "Papua New Guinea": ("পাপুয়া নিউগিনি", "পোর্ট মোরসবি"), "Paraguay": ("প্যারাগুয়ে", "আসুনসিওন"), "Peru": ("পেরু", "লিমা"),
    "Philippines": ("ফিলিপাইন", "ম্যানিলা"), "Poland": ("পোল্যান্ড", "ওয়ারশ"), "Portugal": ("পর্তুগাল", "লিসবন"), "Qatar": ("কাতার", "দোহা"),
    "Romania": ("রোমানিয়া", "বুখারেস্ট"), "Russia": ("রাশিয়া", "মস্কো"), "Rwanda": ("রুয়ান্ডা", "কিগালি"), "Saudi Arabia": ("সৌদি আরব", "রিয়াদ"),
    "Senegal": ("সেনেগাল", "ডাকার"), "Serbia": ("সার্বিয়া", "বেলগ্রেড"), "Singapore": ("সিঙ্গাপুর", "সিঙ্গাপুর"), "Slovakia": ("স্লোভাকিয়া", "ব্রাতিস্লাভা"),
    "Slovenia": ("স্লোভেনিয়া", "লুবলিয়ানা"), "Somalia": ("সোমালিয়া", "মোগাদিশু"), "South Korea": ("দক্ষিণ কোরিয়া", "সিউল"), "Spain": ("স্পেন", "মাদ্রিদ"),
    "Sweden": ("সুইডেন", "স্টকহোম"), "Switzerland": ("সুইজারল্যান্ড", "বার্ন"), "Syria": ("সিরিয়া", "দামেস্ক"), "Tajikistan": ("তাজিকিস্তান", "দুশানবে"),
    "Thailand": ("থাইল্যান্ড", "ব্যাংকক"), "Timor-Leste": ("পূর্ব তিমুর", "দিলি"), "Tunisia": ("তিউনিসিয়া", "তিউনিস"), "Turkey": ("তুরস্ক", "আঙ্কারা"),
    "Turkmenistan": ("তুর্কমেনিস্তান", "আশগাবাত"), "Uganda": ("উগান্ডা", "কাম্পালা"), "Ukraine": ("ইউক্রেন", "কিয়েভ"),
    "United Arab Emirates": ("সংযুক্ত আরব আমিরাত", "আবুধাবি"), "United Kingdom": ("যুক্তরাজ্য", "লন্ডন"), "United States": ("যুক্তরাষ্ট্র", "ওয়াশিংটন ডি.সি."),
    "Uruguay": ("উরুগুয়ে", "মন্টেভিডিও"), "Uzbekistan": ("উজবেকিস্তান", "তাসখন্দ"), "Venezuela": ("ভেনেজুয়েলা", "কারাকাস"), "Vietnam": ("ভিয়েতনাম", "হ্যানয়"),
    "Zambia": ("জাম্বিয়া", "লুসাকা"), "Zimbabwe": ("জিম্বাবুয়ে", "হারারে"),
    "Bangladesh": ("বাংলাদেশ", "ঢাকা"), "Sri Lanka": ("শ্রীলঙ্কা", ""), "Indonesia": ("ইন্দোনেশিয়া", ""), "South Africa": ("দক্ষিণ আফ্রিকা", ""),
    "Netherlands": ("নেদারল্যান্ডস", ""),
}
CITY_BN = {  # famous wrong answers and organisation cities
    "Sydney": "সিডনি", "Melbourne": "মেলবোর্ন", "Toronto": "টরন্টো", "Montreal": "মন্ট্রিয়ল", "Istanbul": "ইস্তাম্বুল",
    "Rio de Janeiro": "রিও ডি জেনিরো", "São Paulo": "সাও পাওলো", "Zurich": "জুরিখ", "Geneva": "জেনেভা", "Auckland": "অকল্যান্ড",
    "Karachi": "করাচি", "Lahore": "লাহোর", "Yangon": "ইয়াঙ্গুন", "Lagos": "লাগোস", "Casablanca": "কাসাব্লাঙ্কা", "Dubai": "দুবাই",
    "New York": "নিউইয়র্ক", "Mumbai": "মুম্বাই", "Kolkata": "কলকাতা", "Ho Chi Minh City": "হো চি মিন সিটি", "Shanghai": "সাংহাই",
    "Jeddah": "জেদ্দা", "Rome": "রোম", "Vienna": "ভিয়েনা", "Jakarta": "জাকার্তা", "Kathmandu": "কাঠমান্ডু", "Brussels": "ব্রাসেলস",
    "Addis Ababa": "আদ্দিস আবাবা", "Lyon": "লিয়ঁ", "The Hague": "দ্য হেগ", "London": "লন্ডন", "Manila": "ম্যানিলা", "Dhaka": "ঢাকা",
    "Bern": "বার্ন", "Nairobi": "নাইরোবি", "Paris": "প্যারিস", "Washington, D.C.": "ওয়াশিংটন ডি.সি.",
}
CURRENCY_BN = {
    "Taka": "টাকা", "Rupee": "রুপি", "Ngultrum": "গুলট্রাম", "Rufiyaa": "রুফিয়া", "Kyat": "কিয়াত", "Baht": "বাত", "Ringgit": "রিংগিত",
    "Rupiah": "রুপিয়াহ", "Peso": "পেসো", "Dong": "ডং", "Riel": "রিয়েল (Riel)", "Kip": "কিপ", "Yuan (Renminbi)": "ইউয়ান (রেনমিনবি)", "Yen": "ইয়েন",
    "Won": "ওন", "Tugrik": "তুগরিক", "Afghani": "আফগানি", "Rial": "রিয়াল (Rial)", "Dinar": "দিনার", "Riyal": "রিয়াল (Riyal)", "Dirham": "দিরহাম",
    "Lira": "লিরা", "Pound": "পাউন্ড", "Shilling": "শিলিং", "Naira": "নাইরা", "Cedi": "সেডি", "Rand": "র‍্যান্ড", "Birr": "বির", "Pula": "পুলা",
    "Kwanza": "কোয়ানজা", "Ruble": "রুবল", "Hryvnia": "রিভনিয়া", "Zloty": "জ্লোটি", "Koruna": "কোরুনা", "Forint": "ফোরিন্ট", "Leu": "লিউ",
    "Pound sterling": "পাউন্ড স্টার্লিং", "Swiss franc": "সুইস ফ্রাঁ", "Krona": "ক্রোনা", "Krone": "ক্রোন", "Dollar": "ডলার", "Real": "রিয়েল (Real)",
    "Sol": "সোল", "Euro": "ইউরো",
}
ORG_BN = {
    "United Nations": "জাতিসংঘ", "UNESCO": "ইউনেস্কো", "World Health Organization (WHO)": "বিশ্ব স্বাস্থ্য সংস্থা (WHO)",
    "International Monetary Fund (IMF)": "আন্তর্জাতিক মুদ্রা তহবিল (IMF)", "World Bank": "বিশ্বব্যাংক", "World Trade Organization (WTO)": "বিশ্ব বাণিজ্য সংস্থা (WTO)",
    "International Labour Organization (ILO)": "আন্তর্জাতিক শ্রম সংস্থা (ILO)", "Food and Agriculture Organization (FAO)": "খাদ্য ও কৃষি সংস্থা (FAO)",
    "UNICEF": "ইউনিসেফ", "UNHCR": "জাতিসংঘ শরণার্থী সংস্থা (UNHCR)", "International Atomic Energy Agency (IAEA)": "আন্তর্জাতিক পরমাণু শক্তি সংস্থা (IAEA)",
    "OPEC": "ওপেক", "ASEAN Secretariat": "আসিয়ান সচিবালয়", "SAARC Secretariat": "সার্ক সচিবালয়", "NATO": "ন্যাটো",
    "European Union (Commission)": "ইউরোপীয় ইউনিয়ন (কমিশন)", "African Union": "আফ্রিকান ইউনিয়ন", "Organisation of Islamic Cooperation (OIC)": "ইসলামি সহযোগিতা সংস্থা (OIC)",
    "Interpol": "ইন্টারপোল", "International Court of Justice": "আন্তর্জাতিক বিচার আদালত", "International Criminal Court": "আন্তর্জাতিক অপরাধ আদালত",
    "International Committee of the Red Cross": "আন্তর্জাতিক রেড ক্রস কমিটি", "Amnesty International": "অ্যামনেস্টি ইন্টারন্যাশনাল",
    "Asian Development Bank": "এশীয় উন্নয়ন ব্যাংক", "Islamic Development Bank": "ইসলামি উন্নয়ন ব্যাংক", "BIMSTEC Secretariat": "বিমসটেক সচিবালয়",
    "World Intellectual Property Organization (WIPO)": "বিশ্ব মেধাসম্পদ সংস্থা (WIPO)", "World Meteorological Organization (WMO)": "বিশ্ব আবহাওয়া সংস্থা (WMO)",
    "International Telecommunication Union (ITU)": "আন্তর্জাতিক টেলিযোগাযোগ ইউনিয়ন (ITU)", "Universal Postal Union": "বিশ্ব ডাক ইউনিয়ন",
    "International Maritime Organization": "আন্তর্জাতিক সমুদ্র সংস্থা", "International Civil Aviation Organization (ICAO)": "আন্তর্জাতিক বেসামরিক বিমান চলাচল সংস্থা (ICAO)",
    "UN Environment Programme (UNEP)": "জাতিসংঘ পরিবেশ কর্মসূচি (UNEP)", "UN-Habitat": "ইউএন-হ্যাবিট্যাট", "UNIDO": "ইউনিডো", "IFAD": "ইফাদ",
    "World Food Programme": "বিশ্ব খাদ্য কর্মসূচি", "UNDP": "ইউএনডিপি", "Commonwealth Secretariat": "কমনওয়েলথ সচিবালয়",
}
ELEMENT_BN = {
    "Hydrogen": "হাইড্রোজেন", "Helium": "হিলিয়াম", "Lithium": "লিথিয়াম", "Beryllium": "বেরিলিয়াম", "Boron": "বোরন", "Carbon": "কার্বন",
    "Nitrogen": "নাইট্রোজেন", "Oxygen": "অক্সিজেন", "Fluorine": "ফ্লোরিন", "Neon": "নিয়ন", "Sodium": "সোডিয়াম", "Magnesium": "ম্যাগনেসিয়াম",
    "Aluminium": "অ্যালুমিনিয়াম", "Silicon": "সিলিকন", "Phosphorus": "ফসফরাস", "Sulfur": "সালফার", "Chlorine": "ক্লোরিন", "Argon": "আর্গন",
    "Potassium": "পটাশিয়াম", "Calcium": "ক্যালসিয়াম", "Titanium": "টাইটানিয়াম", "Chromium": "ক্রোমিয়াম", "Manganese": "ম্যাঙ্গানিজ",
    "Iron": "লোহা", "Cobalt": "কোবাল্ট", "Nickel": "নিকেল", "Copper": "তামা", "Zinc": "দস্তা", "Arsenic": "আর্সেনিক", "Selenium": "সেলেনিয়াম",
    "Bromine": "ব্রোমিন", "Krypton": "ক্রিপ্টন", "Strontium": "স্ট্রনশিয়াম", "Silver": "রুপা", "Tin": "টিন", "Antimony": "অ্যান্টিমনি",
    "Iodine": "আয়োডিন", "Xenon": "জেনন", "Caesium": "সিজিয়াম", "Barium": "বেরিয়াম", "Tungsten": "টাংস্টেন", "Platinum": "প্লাটিনাম",
    "Gold": "সোনা", "Mercury": "পারদ", "Lead": "সিসা", "Bismuth": "বিসমাথ", "Radon": "রেডন", "Radium": "রেডিয়াম", "Uranium": "ইউরেনিয়াম",
    "Plutonium": "প্লুটোনিয়াম",
}
SI_BN = {
    "Force": ("বল", "নিউটন"), "Energy (work)": ("শক্তি (কাজ)", "জুল"), "Power": ("ক্ষমতা", "ওয়াট"), "Pressure": ("চাপ", "প্যাসকেল"),
    "Frequency": ("কম্পাঙ্ক", "হার্টজ"), "Electric current": ("তড়িৎ প্রবাহ", "অ্যাম্পিয়ার"), "Electric charge": ("তড়িৎ আধান", "কুলম্ব"),
    "Electric potential difference": ("বিভব পার্থক্য", "ভোল্ট"), "Electrical resistance": ("রোধ", "ওহম"), "Capacitance": ("ধারকত্ব", "ফ্যারাড"),
    "Inductance": ("আবেশাঙ্ক", "হেনরি"), "Magnetic flux": ("চৌম্বক ফ্লাক্স", "ওয়েবার"), "Magnetic flux density": ("চৌম্বক ফ্লাক্স ঘনত্ব", "টেসলা"),
    "Thermodynamic temperature": ("তাপমাত্রা", "কেলভিন"), "Amount of substance": ("পদার্থের পরিমাণ", "মোল"),
    "Luminous intensity": ("দীপন তীব্রতা", "ক্যান্ডেলা"), "Mass": ("ভর", "কিলোগ্রাম"), "Time": ("সময়", "সেকেন্ড"),
    "Illuminance": ("আলোকমাত্রা", "লাক্স"), "Radioactivity (activity)": ("তেজস্ক্রিয়তা", "বেকেরেল"),
}
CONSTITUTION_BN = {
    "The Republic": "প্রজাতন্ত্র", "The territory of the Republic": "প্রজাতন্ত্রের রাষ্ট্রীয় সীমানা", "The state language": "রাষ্ট্রভাষা",
    "National anthem, flag and emblem": "জাতীয় সংগীত, পতাকা ও প্রতীক", "The capital": "রাজধানী", "Citizenship": "নাগরিকত্ব",
    "Supremacy of the Constitution": "সংবিধানের প্রাধান্য", "Fundamental principles of state policy": "রাষ্ট্র পরিচালনার মূলনীতি",
    "Democracy and human rights": "গণতন্ত্র ও মানবাধিকার", "Provision of basic necessities": "মৌলিক প্রয়োজনের ব্যবস্থা",
    "Free and compulsory education": "অবৈতনিক ও বাধ্যতামূলক শিক্ষা", "Public health and morality": "জনস্বাস্থ্য ও নৈতিকতা",
    "Equality of opportunity": "সুযোগের সমতা", "Work as a right and duty": "অধিকার ও কর্তব্যরূপে কর্ম",
    "Duties of citizens and of public servants": "নাগরিক ও সরকারি কর্মচারীদের কর্তব্য",
    "Separation of the judiciary from the executive": "নির্বাহী বিভাগ হইতে বিচার বিভাগের পৃথকীকরণ", "National culture": "জাতীয় সংস্কৃতি",
    "National monuments": "জাতীয় স্মৃতিনিদর্শন", "Promotion of international peace, security and solidarity": "আন্তর্জাতিক শান্তি, নিরাপত্তা ও সংহতির উন্নয়ন",
    "Laws inconsistent with fundamental rights to be void": "মৌলিক অধিকারের সহিত অসামঞ্জস্য আইন বাতিল",
    "Equality before law": "আইনের দৃষ্টিতে সমতা", "Discrimination on grounds of religion, race, caste, sex or place of birth": "ধর্ম, বর্ণ, জাতি, নারী-পুরুষভেদ বা জন্মস্থানের কারণে বৈষম্য",
    "Equality of opportunity in public employment": "সরকারি নিয়োগলাভে সুযোগের সমতা", "Prohibition of foreign titles": "বিদেশি খেতাব প্রভৃতি গ্রহণ নিষিদ্ধকরণ",
    "Right to protection of law": "আইনের আশ্রয়লাভের অধিকার", "Protection of right to life and personal liberty": "জীবন ও ব্যক্তিস্বাধীনতার অধিকাররক্ষণ",
    "Safeguards as to arrest and detention": "গ্রেপ্তার ও আটক সম্পর্কে রক্ষাকবচ", "Prohibition of forced labour": "জবরদস্তি-শ্রম নিষিদ্ধকরণ",
    "Protection in respect of trial and punishment": "বিচার ও দণ্ড সম্পর্কে রক্ষণ", "Freedom of movement": "চলাফেরার স্বাধীনতা",
    "Freedom of assembly": "সমাবেশের স্বাধীনতা", "Freedom of association": "সংগঠনের স্বাধীনতা",
    "Freedom of thought and conscience, and of speech": "চিন্তা ও বিবেকের স্বাধীনতা এবং বাক্-স্বাধীনতা",
    "Freedom of profession or occupation": "পেশা বা বৃত্তির স্বাধীনতা", "Freedom of religion": "ধর্মীয় স্বাধীনতা", "Rights to property": "সম্পত্তির অধিকার",
    "Protection of home and correspondence": "গৃহ ও যোগাযোগের রক্ষণ", "Enforcement of fundamental rights": "মৌলিক অধিকার বলবৎকরণ",
    "The President": "রাষ্ট্রপতি", "The Cabinet": "মন্ত্রিসভা", "Establishment of Parliament": "সংসদ প্রতিষ্ঠা",
    "Qualifications and disqualifications for election to Parliament": "সংসদে নির্বাচিত হইবার যোগ্যতা ও অযোগ্যতা", "The Ombudsman": "ন্যায়পাল",
    "Ordinance-making power": "অধ্যাদেশ প্রণয়ন-ক্ষমতা", "Establishment of the Supreme Court": "সুপ্রীম কোর্ট প্রতিষ্ঠা", "Appointment of judges": "বিচারক-নিয়োগ",
    "Powers of the High Court Division to issue certain orders and directions (writs)": "কতিপয় আদেশ ও নির্দেশ প্রভৃতি দানের ক্ষেত্রে হাইকোর্ট বিভাগের ক্ষমতা (রিট)",
    "Jurisdiction of the Appellate Division": "আপিল বিভাগের এখতিয়ার", "Review of judgments or orders by the Appellate Division": "আপিল বিভাগ কর্তৃক রায় বা আদেশ পুনর্বিবেচনা",
    "Advisory jurisdiction of the Supreme Court": "সুপ্রীম কোর্টের উপদেষ্টামূলক এখতিয়ার", "Binding effect of Supreme Court judgments": "সুপ্রীম কোর্টের রায়ের বাধ্যতামূলক কার্যকারিতা",
    "Administrative tribunals": "প্রশাসনিক ট্রাইব্যুনাল", "Establishment of the Election Commission": "নির্বাচন কমিশন প্রতিষ্ঠা",
    "Establishment of the office of Auditor-General": "মহা হিসাব-নিরীক্ষক পদের প্রতিষ্ঠা", "Establishment of public service commissions": "সরকারি কর্ম কমিশন প্রতিষ্ঠা",
    "Functions of public service commissions": "কমিশনের দায়িত্ব", "Proclamation of emergency": "জরুরি-অবস্থা ঘোষণা",
    "Power to amend any provision of the Constitution": "সংবিধানের বিধান সংশোধনের ক্ষমতা", "Interpretation": "ব্যাখ্যা",
    "Commencement, citation and authentication": "প্রবর্তন, উল্লেখ ও নির্ভরযোগ্য পাঠ",
}

ACT_BN = {
    "the Penal Code, 1860": "দণ্ডবিধি, ১৮৬০", "the Code of Criminal Procedure, 1898": "ফৌজদারি কার্যবিধি, ১৮৯৮",
    "the Code of Civil Procedure, 1908": "দেওয়ানি কার্যবিধি, ১৯০৮", "the Evidence Act, 1872": "সাক্ষ্য আইন, ১৮৭২", "the Limitation Act, 1908": "তামাদি আইন, ১৯০৮",
    "the Specific Relief Act, 1877": "সুনির্দিষ্ট প্রতিকার আইন, ১৮৭৭", "the Contract Act, 1872": "চুক্তি আইন, ১৮৭২",
    "the Transfer of Property Act, 1882": "সম্পত্তি হস্তান্তর আইন, ১৮৮২",
    "The Penal Code": "দণ্ডবিধি", "The Code of Criminal Procedure": "ফৌজদারি কার্যবিধি", "The Code of Civil Procedure": "দেওয়ানি কার্যবিধি",
    "The Evidence Act": "সাক্ষ্য আইন", "The Limitation Act": "তামাদি আইন", "The Specific Relief Act": "সুনির্দিষ্ট প্রতিকার আইন",
    "The Contract Act": "চুক্তি আইন", "The Transfer of Property Act": "সম্পত্তি হস্তান্তর আইন", "The Registration Act": "রেজিস্ট্রেশন আইন",
    "The Muslim Family Laws Ordinance": "মুসলিম পারিবারিক আইন অধ্যাদেশ", "The Family Courts Ordinance": "পারিবারিক আদালত অধ্যাদেশ",
    "The Arbitration Act": "সালিশ আইন", "The Right to Information Act": "তথ্য অধিকার আইন", "The Consumer Rights Protection Act": "ভোক্তা-অধিকার সংরক্ষণ আইন",
    "The Money Laundering Prevention Act": "মানিলন্ডারিং প্রতিরোধ আইন",
}
SECTION_BN = {
    # Penal Code
    "Definition of 'public servant'": "'সরকারি কর্মচারী'-র সংজ্ঞা", "Acts done by several persons in furtherance of common intention": "সাধারণ অভিপ্রায় সাধনে কয়েকজন কর্তৃক কৃত কার্য",
    "Kinds of punishment": "দণ্ডের প্রকারভেদ", "Act of a child under nine years of age": "নয় বছরের কম বয়স্ক শিশুর কার্য",
    "Act of a child above nine and under twelve of immature understanding": "অপরিপক্ব বোধসম্পন্ন নয় থেকে বারো বছরের শিশুর কার্য",
    "Act of a person of unsound mind": "অপ্রকৃতিস্থ ব্যক্তির কার্য", "Things done in private defence": "ব্যক্তিগত আত্মরক্ষায় কৃত কার্য",
    "When the right of private defence of the body extends to causing death": "দেহের আত্মরক্ষার অধিকার কখন মৃত্যু ঘটানো পর্যন্ত বিস্তৃত",
    "Abetment of a thing": "কোনো কাজে সহায়তা (অপসহায়তা)", "Definition of criminal conspiracy": "অপরাধমূলক ষড়যন্ত্রের সংজ্ঞা",
    "Waging war against Bangladesh": "বাংলাদেশের বিরুদ্ধে যুদ্ধ ঘোষণা", "Unlawful assembly": "বেআইনি সমাবেশ", "Rioting": "দাঙ্গা",
    "Every member of an unlawful assembly guilty of an offence committed in prosecution of the common object": "সাধারণ উদ্দেশ্য সাধনে কৃত অপরাধে বেআইনি সমাবেশের প্রত্যেক সদস্য দোষী",
    "Affray": "মারামারি (অ্যাফ্রে)", "Giving false evidence": "মিথ্যা সাক্ষ্য দেওয়া", "Culpable homicide": "অপরাধজনক নরহত্যা", "Murder": "খুন",
    "Punishment for murder": "খুনের শাস্তি", "Punishment for culpable homicide not amounting to murder": "খুন নয় এমন অপরাধজনক নরহত্যার শাস্তি",
    "Causing death by negligence": "অবহেলাজনিত মৃত্যু ঘটানো", "Attempt to murder": "খুনের চেষ্টা", "Hurt": "আঘাত", "Grievous hurt": "গুরুতর আঘাত",
    "Punishment for voluntarily causing hurt": "ইচ্ছাকৃতভাবে আঘাত করার শাস্তি", "Wrongful restraint": "অবৈধ বাধাদান", "Wrongful confinement": "অবৈধ আটক",
    "Force": "বলপ্রয়োগ", "Criminal force": "অপরাধমূলক বলপ্রয়োগ", "Assault": "আক্রমণ", "Kidnapping": "অপহরণ (কিডন্যাপিং)", "Abduction": "অপহরণ (অ্যাবডাকশন)",
    "Theft": "চুরি", "Punishment for theft": "চুরির শাস্তি", "Extortion": "বলপূর্বক আদায় (চাঁদাবাজি)", "Robbery": "দস্যুতা", "Dacoity": "ডাকাতি",
    "Dishonest misappropriation of property": "অসাধুভাবে সম্পত্তি আত্মসাৎ", "Criminal breach of trust": "অপরাধমূলক বিশ্বাসভঙ্গ", "Cheating": "প্রতারণা",
    "Cheating and dishonestly inducing delivery of property": "প্রতারণা ও অসাধুভাবে সম্পত্তি হস্তান্তরে প্ররোচনা", "Mischief": "অনিষ্ট (ক্ষতিসাধন)",
    "Criminal trespass": "অপরাধমূলক অনধিকার প্রবেশ", "House-trespass": "গৃহে অনধিকার প্রবেশ", "Forgery": "জালিয়াতি", "Defamation": "মানহানি",
    "Punishment for defamation": "মানহানির শাস্তি", "Criminal intimidation": "অপরাধমূলক ভীতি প্রদর্শন",
    # CrPC
    "Definitions": "সংজ্ঞা", "When police may arrest without warrant": "পুলিশ কখন পরোয়ানা ছাড়া গ্রেপ্তার করতে পারে",
    "Person arrested not to be detained more than twenty-four hours": "গ্রেপ্তারকৃত ব্যক্তিকে চব্বিশ ঘণ্টার বেশি আটক রাখা যাবে না",
    "Search to be made in presence of witnesses": "সাক্ষীর উপস্থিতিতে তল্লাশি", "Power to issue order in urgent cases of nuisance or apprehended danger": "উপদ্রব বা আশঙ্কিত বিপদের জরুরি ক্ষেত্রে আদেশ জারির ক্ষমতা",
    "Information in cognizable cases (first information report)": "আমলযোগ্য মামলায় সংবাদ (এজাহার)", "Information in non-cognizable cases": "আমল-অযোগ্য মামলায় সংবাদ",
    "Examination of witnesses by police": "পুলিশ কর্তৃক সাক্ষীর জবানবন্দি গ্রহণ", "Recording of confessions and statements by a Magistrate": "ম্যাজিস্ট্রেট কর্তৃক স্বীকারোক্তি ও জবানবন্দি লিপিবদ্ধকরণ",
    "Procedure when investigation cannot be completed in twenty-four hours (remand)": "চব্বিশ ঘণ্টায় তদন্ত শেষ না হলে পদ্ধতি (রিমান্ড)",
    "Report of police officer on completion of investigation": "তদন্ত শেষে পুলিশ কর্মকর্তার প্রতিবেদন", "Cognizance of offences by Magistrates": "ম্যাজিস্ট্রেট কর্তৃক অপরাধ আমলে গ্রহণ",
    "Examination of complainant": "অভিযোগকারীর জবানবন্দি গ্রহণ", "Issue of process": "প্রসেস জারি", "Power to examine the accused": "অভিযুক্তকে পরীক্ষা করার ক্ষমতা",
    "Person once convicted or acquitted not to be tried for the same offence": "একবার দণ্ডিত বা খালাসপ্রাপ্ত ব্যক্তির একই অপরাধে পুনর্বিচার নিষেধ",
    "Power to call for records of inferior courts": "অধস্তন আদালতের নথি তলবের ক্ষমতা", "High Court Division's powers of revision": "হাইকোর্ট বিভাগের রিভিশনের ক্ষমতা",
    "Power to issue directions of the nature of habeas corpus": "হেবিয়াস কর্পাস প্রকৃতির নির্দেশ দানের ক্ষমতা", "Bail in bailable offences": "জামিনযোগ্য অপরাধে জামিন",
    "Bail in non-bailable offences": "জামিন-অযোগ্য অপরাধে জামিন", "Power to direct admission to bail or reduction of bail": "জামিনে মুক্তি বা জামিনের অঙ্ক কমানোর নির্দেশ দানের ক্ষমতা",
    "Saving of inherent powers of the High Court Division": "হাইকোর্ট বিভাগের সহজাত ক্ষমতার সংরক্ষণ",
    # CPC
    "Courts to try all civil suits unless barred": "বারিত না হলে আদালত সব দেওয়ানি মামলার বিচার করবে", "Stay of suit (res sub judice)": "মামলা স্থগিত (রেস সাব জুডিস)",
    "Res judicata": "রেস জুডিকাটা (পূর্ব-বিচার)", "Court in which suits to be instituted": "যে আদালতে মামলা দায়ের করতে হবে",
    "Suits to be instituted where subject-matter is situate": "বিষয়বস্তু যেখানে অবস্থিত সেখানে মামলা দায়ের",
    "Other suits to be instituted where defendants reside or cause of action arises": "বিবাদী যেখানে বাস করে বা নালিশের কারণ যেখানে উদ্ভূত সেখানে অন্যান্য মামলা",
    "General power of transfer and withdrawal": "স্থানান্তর ও প্রত্যাহারের সাধারণ ক্ষমতা", "Institution of suits": "মামলা দায়ের", "Costs": "খরচা",
    "Compensatory costs in respect of false or vexatious claims": "মিথ্যা বা হয়রানিমূলক দাবির জন্য ক্ষতিপূরণমূলক খরচা",
    "Powers of court to enforce execution": "ডিক্রি জারি কার্যকরে আদালতের ক্ষমতা", "Property liable to attachment and sale in execution": "ডিক্রি জারিতে ক্রোক ও বিক্রয়যোগ্য সম্পত্তি",
    "Notice before suing the Government or a public officer": "সরকার বা সরকারি কর্মকর্তার বিরুদ্ধে মামলার আগে নোটিশ", "Mediation": "মধ্যস্থতা",
    "Appeal from original decree": "মূল ডিক্রির বিরুদ্ধে আপিল", "Second appeal": "দ্বিতীয় আপিল", "Orders from which appeal lies": "যেসব আদেশের বিরুদ্ধে আপিল চলে",
    "Review": "রিভিউ (পুনর্বিবেচনা)", "Revision": "রিভিশন", "Application for restitution": "প্রত্যর্পণের দরখাস্ত", "Enlargement of time": "সময় বৃদ্ধি",
    "Saving of inherent powers of court": "আদালতের সহজাত ক্ষমতার সংরক্ষণ",
    "Rejection of plaint": "আরজি খারিজ", "Temporary injunction": "অস্থায়ী নিষেধাজ্ঞা", "Setting aside a decree passed ex parte against the defendant": "বিবাদীর বিরুদ্ধে একতরফা ডিক্রি রদ",
    "Execution of decrees and orders": "ডিক্রি ও আদেশ জারি", "Appeals from original decrees": "মূল ডিক্রির বিরুদ্ধে আপিল", "Suits by paupers": "নিঃস্ব ব্যক্তির মামলা",
    # Evidence
    "Interpretation clause": "ব্যাখ্যা ধারা", "Evidence may be given of facts in issue and relevant facts": "বিচার্য ও প্রাসঙ্গিক ঘটনার সাক্ষ্য দেওয়া যায়",
    "Motive, preparation and previous or subsequent conduct": "উদ্দেশ্য, প্রস্তুতি এবং পূর্ব বা পরবর্তী আচরণ", "Admission defined": "স্বীকৃতির সংজ্ঞা",
    "Confession caused by inducement, threat or promise, when irrelevant": "প্রলোভন, হুমকি বা প্রতিশ্রুতিতে স্বীকারোক্তি কখন অপ্রাসঙ্গিক",
    "Confession to a police officer not to be proved": "পুলিশ কর্মকর্তার কাছে স্বীকারোক্তি প্রমাণ করা যাবে না",
    "Confession by accused while in custody of police not to be proved against him": "পুলিশ হেফাজতে অভিযুক্তের স্বীকারোক্তি তার বিরুদ্ধে প্রমাণ করা যাবে না",
    "How much of information received from the accused may be proved": "অভিযুক্তের কাছ থেকে প্রাপ্ত তথ্যের কতটুকু প্রমাণ করা যায়",
    "Consideration of proved confession affecting a co-accused": "সহ-অভিযুক্তকে প্রভাবিতকারী প্রমাণিত স্বীকারোক্তি বিবেচনা",
    "Statements by a person who is dead or cannot be found (dying declaration)": "মৃত বা নিখোঁজ ব্যক্তির বিবৃতি (মৃত্যুকালীন জবানবন্দি)",
    "Opinions of experts": "বিশেষজ্ঞের মতামত", "Oral evidence must be direct": "মৌখিক সাক্ষ্য প্রত্যক্ষ হতে হবে", "Primary evidence": "প্রাথমিক সাক্ষ্য",
    "Secondary evidence": "মাধ্যমিক সাক্ষ্য", "Public documents": "সরকারি দলিল", "Burden of proof": "প্রমাণের দায়িত্ব",
    "Burden of proving a fact especially within knowledge": "বিশেষভাবে জ্ঞাত ঘটনা প্রমাণের দায়িত্ব",
    "Birth during marriage, conclusive proof of legitimacy": "বিবাহকালে জন্ম বৈধতার চূড়ান্ত প্রমাণ", "Court may presume existence of certain facts": "আদালত কিছু ঘটনার অস্তিত্ব অনুমান করতে পারে",
    "Estoppel": "এস্টোপেল (প্রতিবন্ধ)", "Who may testify": "কে সাক্ষ্য দিতে পারে", "Accomplice": "দুষ্কর্মের সহযোগী", "Number of witnesses": "সাক্ষীর সংখ্যা",
    "Examination-in-chief, cross-examination and re-examination": "জবানবন্দি, জেরা ও পুনঃজবানবন্দি", "Leading questions": "ইঙ্গিতবাহী প্রশ্ন",
    "Impeaching the credit of a witness": "সাক্ষীর বিশ্বাসযোগ্যতা খণ্ডন", "Judge's power to put questions or order production": "বিচারকের প্রশ্ন করার বা উপস্থাপনের আদেশ দেওয়ার ক্ষমতা",
    "No new trial for improper admission or rejection of evidence": "সাক্ষ্য ভুলভাবে গ্রহণ বা বর্জনের জন্য নতুন বিচার নয়",
    # Limitation
    "Dismissal of suits, appeals and applications made after the period of limitation": "তামাদির মেয়াদের পরে দায়ের করা মামলা, আপিল ও দরখাস্ত খারিজ",
    "Extension of the period in certain cases": "কিছু ক্ষেত্রে মেয়াদ বৃদ্ধি", "Exclusion of time in legal proceedings": "আইনগত কার্যধারায় সময় বাদ দেওয়া",
    "Exclusion of time of proceeding bona fide in a court without jurisdiction": "এখতিয়ারবিহীন আদালতে সরল বিশ্বাসে কার্যধারার সময় বাদ",
    "Effect of acknowledgment in writing": "লিখিত স্বীকৃতির ফল", "Extinguishment of right to property": "সম্পত্তির অধিকার বিলোপ",
    # Specific Relief
    "Recovery of specific immovable property": "সুনির্দিষ্ট স্থাবর সম্পত্তি পুনরুদ্ধার", "Suit by person dispossessed of immovable property": "স্থাবর সম্পত্তি থেকে বেদখল ব্যক্তির মামলা",
    "Recovery of specific movable property": "সুনির্দিষ্ট অস্থাবর সম্পত্তি পুনরুদ্ধার", "Cases in which specific performance is enforceable": "যেসব ক্ষেত্রে চুক্তির সুনির্দিষ্ট কার্যসম্পাদন বলবৎযোগ্য",
    "Contracts not specifically enforceable": "যেসব চুক্তি সুনির্দিষ্টভাবে বলবৎযোগ্য নয়", "Rectification of instruments": "দলিল সংশোধন",
    "Rescission of contracts": "চুক্তি রদ", "Cancellation of instruments": "দলিল বাতিল", "Declaratory decrees (declaration of status or right)": "ঘোষণামূলক ডিক্রি (মর্যাদা বা অধিকারের ঘোষণা)",
    "Temporary and perpetual injunctions": "অস্থায়ী ও চিরস্থায়ী নিষেধাজ্ঞা", "Perpetual injunctions when granted": "চিরস্থায়ী নিষেধাজ্ঞা কখন মঞ্জুর হয়",
    "Mandatory injunctions": "বাধ্যতামূলক নিষেধাজ্ঞা", "Injunction when refused": "নিষেধাজ্ঞা কখন নামঞ্জুর হয়",
    # Contract
    "Definition of 'contract' (an agreement enforceable by law)": "'চুক্তি'-র সংজ্ঞা (আইনত বলবৎযোগ্য সম্মতি)", "What agreements are contracts": "কোন সম্মতি চুক্তি",
    "Who are competent to contract": "কারা চুক্তি করতে সক্ষম", "What considerations and objects are lawful": "কোন প্রতিদান ও উদ্দেশ্য বৈধ",
    "Agreement without consideration void, except in certain cases": "প্রতিদানহীন সম্মতি বাতিল, কিছু ব্যতিক্রম ছাড়া",
    "Agreement to do an impossible act (frustration)": "অসম্ভব কাজ করার সম্মতি (চুক্তির ব্যর্থতা)", "Compensation for loss caused by breach of contract": "চুক্তিভঙ্গজনিত ক্ষতির ক্ষতিপূরণ",
    "Contract of indemnity": "ক্ষতিপূরণের চুক্তি", "Contract of guarantee": "জামিননামার চুক্তি", "Bailment": "জিম্মা (বেইলমেন্ট)", "Pledge": "বন্ধক (প্লেজ)",
    "Agent and principal": "প্রতিনিধি ও মালিক",
    # TPA
    "Sale": "বিক্রয়", "Mortgage": "রেহেন (মর্টগেজ)", "Lease": "ইজারা", "Exchange": "বিনিময়", "Gift": "দান",
}
MAXIM_BN = {
    "Hear the other side": "অপর পক্ষের কথাও শোনো", "Ignorance of the law is no excuse": "আইন না জানা কোনো অজুহাত নয়",
    "The thing speaks for itself": "ঘটনা নিজেই কথা বলে", "Where there is a right, there is a remedy": "যেখানে অধিকার, সেখানে প্রতিকার",
    "No one should be a judge in his own cause": "কেউ নিজের মামলার বিচারক হতে পারে না", "No injury is done to one who consents": "সম্মতিদাতার প্রতি কোনো ক্ষতি হয় না",
    "The law does not concern itself with trifles": "আইন তুচ্ছ বিষয় নিয়ে মাথা ঘামায় না", "Let the buyer beware": "ক্রেতা সাবধান",
    "You may have the body": "দেহ হাজির করো", "We command": "আমরা আদেশ দিচ্ছি", "By what authority": "কোন কর্তৃত্বে",
    "To stand by decided cases": "নিষ্পন্ন নজির অনুসরণ", "A remark said by the way": "প্রসঙ্গক্রমে বলা মন্তব্য", "The reason for the decision": "সিদ্ধান্তের কারণ",
    "Agreements must be kept": "চুক্তি অবশ্যই রক্ষা করতে হবে", "Under judicial consideration": "বিচারাধীন", "Beyond the powers": "ক্ষমতাবহির্ভূত",
    "At first sight": "প্রথম দর্শনে", "In good faith": "সরল বিশ্বাসে", "In bad faith": "অসৎ উদ্দেশ্যে", "On behalf of one side only": "একতরফা",
    "The right to be heard in court (standing)": "আদালতে শুনানির অধিকার (লোকাস স্ট্যান্ডি)", "A matter already judged": "ইতিমধ্যে বিচার-নিষ্পন্ন বিষয়",
    "Friend of the court": "আদালতের বন্ধু", "Guilty mind": "দোষী মন", "Guilty act": "দোষী কাজ",
    "The body of the offence (the facts that a crime occurred)": "অপরাধের মূল উপাদান (অপরাধ সংঘটনের তথ্য)",
    "No one gives what he does not have": "যা নিজের নেই তা কেউ দিতে পারে না", "Damage without legal injury": "আইনগত ক্ষতি ছাড়া ক্ষতি",
    "Legal injury without damage": "ক্ষতি ছাড়া আইনগত ক্ষতি", "Elsewhere": "অন্যত্র", "Among other things": "অন্যান্য বিষয়ের মধ্যে",
    "For the public good (free of charge)": "জনকল্যাণে (বিনা পারিশ্রমিকে)",
}

# ---------------------------------------------------------------------------------------------
# Fact-list items: exact English stem -> Bengali stem, and option text -> Bengali option.
# ---------------------------------------------------------------------------------------------
STEM_BN = {
    # international
    "Which is the largest ocean?": "পৃথিবীর বৃহত্তম মহাসাগর কোনটি?",
    "Which is the longest river in the world (by most standard measures)?": "পৃথিবীর দীর্ঘতম নদী কোনটি (প্রচলিত হিসাবে)?",
    "The highest mountain peak above sea level is:": "সমুদ্রপৃষ্ঠ থেকে সর্বোচ্চ পর্বতশৃঙ্গ কোনটি?",
    "Which is the largest country by area?": "আয়তনে বৃহত্তম দেশ কোনটি?",
    "Which is the smallest country in the world?": "পৃথিবীর ক্ষুদ্রতম দেশ কোনটি?",
    "The Suez Canal links the Mediterranean Sea with:": "সুয়েজ খাল ভূমধ্যসাগরকে কোন সাগরের সঙ্গে যুক্ত করেছে?",
    "The Panama Canal links the Atlantic Ocean with:": "পানামা খাল আটলান্টিক মহাসাগরকে কোনটির সঙ্গে যুক্ত করেছে?",
    "How many permanent members does the UN Security Council have?": "জাতিসংঘ নিরাপত্তা পরিষদের স্থায়ী সদস্য কয়টি?",
    "The UN Charter was signed in 1945 in which city?": "১৯৪৫ সালে জাতিসংঘ সনদ কোন শহরে স্বাক্ষরিত হয়?",
    "SAARC was founded in 1985 in which city?": "১৯৮৫ সালে সার্ক কোন শহরে প্রতিষ্ঠিত হয়?",
    "The 'Land of the Rising Sun' is:": "'উদীয়মান সূর্যের দেশ' কোনটি?",
    "The 'Land of Thunder Dragon' is:": "'বজ্র ড্রাগনের দেশ' কোনটি?",
    "Which line separates India and Pakistan in Punjab (drawn in 1947)?": "পাঞ্জাবে ভারত ও পাকিস্তানকে কোন রেখা বিভক্ত করেছে (১৯৪৭)?",
    "The Durand Line is the border between Pakistan and:": "ডুরান্ড লাইন পাকিস্তান ও কোন দেশের সীমানা?",
    "The McMahon Line is a boundary between India and:": "ম্যাকমোহন লাইন ভারত ও কোন দেশের সীমানা?",
    "Which country gifted the Statue of Liberty to the United States?": "স্ট্যাচু অব লিবার্টি কোন দেশ যুক্তরাষ্ট্রকে উপহার দেয়?",
    "The Great Barrier Reef lies off the coast of:": "গ্রেট বেরিয়ার রিফ কোন দেশের উপকূলে?",
    "The Sahara desert is in:": "সাহারা মরুভূমি কোন মহাদেশে?",
    "The Kyoto Protocol is about:": "কিয়োটো প্রটোকল কোন বিষয়ে?",
    "The Montreal Protocol protects:": "মন্ট্রিয়ল প্রটোকল কী রক্ষা করে?",
    "The Ramsar Convention concerns:": "রামসার কনভেনশন কোন বিষয়ে?",
    "The Nobel Prizes are awarded mainly from which country (Peace Prize from Norway)?": "নোবেল পুরস্কার প্রধানত কোন দেশ থেকে দেওয়া হয় (শান্তি পুরস্কার নরওয়ে থেকে)?",
    # science
    "Deficiency of vitamin C causes:": "ভিটামিন সি-এর অভাবে কোন রোগ হয়?",
    "Deficiency of vitamin D in children causes:": "শিশুদের ভিটামিন ডি-এর অভাবে কোন রোগ হয়?",
    "Deficiency of vitamin A causes:": "ভিটামিন এ-এর অভাবে কোন রোগ হয়?",
    "Deficiency of vitamin B1 (thiamine) causes:": "ভিটামিন বি১ (থায়ামিন)-এর অভাবে কোন রোগ হয়?",
    "Which vitamin is essential for blood clotting?": "রক্ত জমাট বাঁধতে কোন ভিটামিন অপরিহার্য?",
    "Iodine deficiency mainly causes:": "আয়োডিনের অভাবে প্রধানত কোন রোগ হয়?",
    "Insulin is produced by the:": "ইনসুলিন কোথায় তৈরি হয়?",
    "The largest organ of the human body is the:": "মানবদেহের বৃহত্তম অঙ্গ কোনটি?",
    "The largest gland of the human body is the:": "মানবদেহের বৃহত্তম গ্রন্থি কোনটি?",
    "How many bones does an adult human have?": "প্রাপ্তবয়স্ক মানুষের হাড় কয়টি?",
    "How many chromosomes are there in a normal human body cell?": "মানুষের স্বাভাবিক দেহকোষে ক্রোমোজোম কয়টি?",
    "Who discovered the ABO blood groups?": "এবিও রক্তের গ্রুপ কে আবিষ্কার করেন?",
    "Who discovered penicillin?": "পেনিসিলিন কে আবিষ্কার করেন?",
    "Who developed the first smallpox vaccine?": "গুটিবসন্তের প্রথম টিকা কে তৈরি করেন?",
    "Normal human body temperature is about:": "মানুষের দেহের স্বাভাবিক তাপমাত্রা প্রায় কত?",
    "Sound travels fastest through:": "শব্দ কোন মাধ্যমে সবচেয়ে দ্রুত চলে?",
    "Light from the Sun reaches the Earth in about:": "সূর্যের আলো পৃথিবীতে পৌঁছাতে প্রায় কত সময় লাগে?",
    "Laughing gas is:": "লাফিং গ্যাস কোনটি?",
    "Dry ice is solid:": "শুষ্ক বরফ কোন পদার্থের কঠিন রূপ?",
    "Brass is an alloy of copper and:": "পিতল তামা ও কোন ধাতুর সংকর?",
    "Bronze is an alloy of copper and:": "ব্রোঞ্জ (কাঁসা) তামা ও কোন ধাতুর সংকর?",
    "The chemical formula of common salt is:": "খাদ্য লবণের রাসায়নিক সংকেত কোনটি?",
    "The chemical formula of baking soda is:": "বেকিং সোডার রাসায়নিক সংকেত কোনটি?",
    "Marsh gas is:": "মার্শ গ্যাস কোনটি?",
    "The pH of pure water at 25 °C is:": "২৫° সে তাপমাত্রায় বিশুদ্ধ পানির pH কত?",
    "The hardest natural substance is:": "সবচেয়ে কঠিন প্রাকৃতিক পদার্থ কোনটি?",
    "The largest planet of the solar system is:": "সৌরজগতের বৃহত্তম গ্রহ কোনটি?",
    "The planet closest to the Sun is:": "সূর্যের সবচেয়ে কাছের গ্রহ কোনটি?",
    "Which planet is called the Red Planet?": "কোন গ্রহকে লাল গ্রহ বলা হয়?",
    "The hottest planet of the solar system is:": "সৌরজগতের উষ্ণতম গ্রহ কোনটি?",
    "Which gas do plants take in for photosynthesis?": "সালোকসংশ্লেষণে উদ্ভিদ কোন গ্যাস গ্রহণ করে?",
    "The study of earthquakes is called:": "ভূমিকম্প বিষয়ক বিজ্ঞানকে কী বলে?",
    "Which instrument measures atmospheric pressure?": "বায়ুর চাপ মাপার যন্ত্র কোনটি?",
    "Which instrument measures relative humidity?": "আপেক্ষিক আর্দ্রতা মাপার যন্ত্র কোনটি?",
    "Which instrument measures wind speed?": "বাতাসের গতি মাপার যন্ত্র কোনটি?",
    "Red blood cells carry oxygen with the help of:": "লোহিত রক্তকণিকা কিসের সাহায্যে অক্সিজেন বহন করে?",
    "Which blood group is called the universal donor (ABO system)?": "কোন রক্তের গ্রুপকে সর্বজনীন দাতা বলা হয় (এবিও পদ্ধতি)?",
    # ICT
    "Which part of a computer is called its brain?": "কম্পিউটারের মস্তিষ্ক বলা হয় কোন অংশকে?",
    "Which memory is volatile (lost when power goes off)?": "কোন মেমোরি অস্থায়ী (বিদ্যুৎ গেলে মুছে যায়)?",
    "Which of these is an input device?": "নিচের কোনটি ইনপুট ডিভাইস?",
    "Which of these is an output device?": "নিচের কোনটি আউটপুট ডিভাইস?",
    "Which number system does a computer use internally?": "কম্পিউটার অভ্যন্তরীণভাবে কোন সংখ্যাপদ্ধতি ব্যবহার করে?",
    "Which of these is an operating system?": "নিচের কোনটি অপারেটিং সিস্টেম?",
    "Which of these is a web browser?": "নিচের কোনটি ওয়েব ব্রাউজার?",
    "Which key combination copies selected text in Windows?": "উইন্ডোজে নির্বাচিত লেখা কপি করার কি-কম্বিনেশন কোনটি?",
    "Which key combination pastes in Windows?": "উইন্ডোজে পেস্ট করার কি-কম্বিনেশন কোনটি?",
    "Which key combination undoes the last action in Windows?": "উইন্ডোজে শেষ কাজ বাতিল (আনডু) করার কি-কম্বিনেশন কোনটি?",
    "A program that harms or spies on a computer is called:": "যে প্রোগ্রাম কম্পিউটারের ক্ষতি করে বা গোপনে তথ্য নেয় তাকে কী বলে?",
    "Who is called the father of the computer?": "কম্পিউটারের জনক বলা হয় কাকে?",
    "Who invented the World Wide Web?": "ওয়ার্ল্ড ওয়াইড ওয়েব কে উদ্ভাবন করেন?",
    "The smallest unit of data in a computer is:": "কম্পিউটারে ডেটার ক্ষুদ্রতম একক কোনটি?",
    "Which device connects different networks and forwards packets between them?": "কোন যন্ত্র ভিন্ন ভিন্ন নেটওয়ার্ক যুক্ত করে প্যাকেট আদান-প্রদান করে?",
    "Which of these is a spreadsheet program?": "নিচের কোনটি স্প্রেডশিট প্রোগ্রাম?",
    # banking
    "The central bank of Bangladesh is:": "বাংলাদেশের কেন্দ্রীয় ব্যাংক কোনটি?",
    "The head office of Bangladesh Bank is in:": "বাংলাদেশ ব্যাংকের প্রধান কার্যালয় কোথায়?",
    "Who issues currency notes in Bangladesh (except the one and two taka government notes)?": "বাংলাদেশে কাগুজে নোট কে ইস্যু করে (এক ও দুই টাকার সরকারি নোট ছাড়া)?",
    "Who collects VAT and income tax in Bangladesh?": "বাংলাদেশে ভ্যাট ও আয়কর আদায় করে কে?",
    "Inflation means a general:": "মুদ্রাস্ফীতি বলতে সাধারণভাবে কী বোঝায়?",
    "A bank cheque payable only through a bank account is:": "যে চেকের টাকা কেবল ব্যাংক হিসাবের মাধ্যমে পাওয়া যায় তা হলো:",
    "A cheque presented after its validity period is called:": "মেয়াদ পেরিয়ে যাওয়ার পর উপস্থাপিত চেককে কী বলে?",
    "A cheque bearing a future date is called:": "ভবিষ্যতের তারিখযুক্ত চেককে কী বলে?",
    "Money kept with a bank for a fixed period at a fixed rate is a:": "নির্দিষ্ট মেয়াদ ও নির্দিষ্ট হারে ব্যাংকে রাখা টাকাকে কী বলে?",
    "Allowing a customer to withdraw more than the balance in a current account is called:": "চলতি হিসাবের স্থিতির চেয়ে বেশি টাকা তুলতে দেওয়াকে কী বলে?",
    # Bar
    "The Bangladesh Bar Council was established under:": "বাংলাদেশ বার কাউন্সিল কোন আইনের অধীনে প্রতিষ্ঠিত?",
    "Who is the ex officio Chairman of the Bangladesh Bar Council?": "বাংলাদেশ বার কাউন্সিলের পদাধিকারবলে চেয়ারম্যান কে?",
    "Professional conduct of advocates in Bangladesh is guided by the Bar Council's:": "বাংলাদেশে আইনজীবীদের পেশাগত আচরণ বার কাউন্সিলের কোন নিয়মে পরিচালিত হয়?",
    "A writ to produce a detained person before the court is:": "আটক ব্যক্তিকে আদালতে হাজির করার রিট কোনটি?",
    "A writ asking a public official 'by what authority' he holds office is:": "কোনো সরকারি পদধারীকে 'কোন কর্তৃত্বে' পদে আছেন জানতে চাওয়ার রিট কোনটি?",
    "A writ commanding a public authority to perform a public duty is:": "সরকারি কর্তৃপক্ষকে জনদায়িত্ব পালনের আদেশ দেওয়ার রিট কোনটি?",
    "An offence for which police may arrest without a warrant is called:": "যে অপরাধে পুলিশ পরোয়ানা ছাড়া গ্রেপ্তার করতে পারে তাকে কী বলে?",
    "Civil suits are instituted by presenting a:": "দেওয়ানি মামলা কী দাখিলের মাধ্যমে দায়ের করা হয়?",
    "A dying declaration is admissible under which section of the Evidence Act?": "সাক্ষ্য আইনের কোন ধারায় মৃত্যুকালীন জবানবন্দি গ্রহণযোগ্য?",
    "The principle that no one shall be tried twice for the same offence is called:": "একই অপরাধে কারও দুবার বিচার হবে না — এই নীতিকে কী বলে?",
}

OPT_BN = {
    # international answers and distractors
    "Pacific Ocean": "প্রশান্ত মহাসাগর", "Atlantic Ocean": "আটলান্টিক মহাসাগর", "Indian Ocean": "ভারত মহাসাগর", "Arctic Ocean": "উত্তর মহাসাগর",
    "Nile": "নীলনদ", "Amazon": "আমাজন", "Yangtze": "ইয়াংসি", "Mississippi": "মিসিসিপি", "Mount Everest": "মাউন্ট এভারেস্ট", "K2": "কে-টু",
    "Kangchenjunga": "কাঞ্চনজঙ্ঘা", "Makalu": "মাকালু", "Russia": "রাশিয়া", "Canada": "কানাডা", "China": "চীন", "United States": "যুক্তরাষ্ট্র",
    "Vatican City": "ভ্যাটিকান সিটি", "Monaco": "মোনাকো", "San Marino": "সান মারিনো", "Liechtenstein": "লিখটেনস্টাইন",
    "The Red Sea": "লোহিত সাগর", "The Black Sea": "কৃষ্ণসাগর", "The Arabian Sea": "আরব সাগর", "The Caspian Sea": "কাস্পিয়ান সাগর",
    "The Pacific Ocean": "প্রশান্ত মহাসাগর", "The Indian Ocean": "ভারত মহাসাগর", "The Arctic Ocean": "উত্তর মহাসাগর", "The Caribbean only": "কেবল ক্যারিবীয় সাগর",
    "San Francisco": "সান ফ্রান্সিসকো", "New Delhi": "নয়াদিল্লি", "Islamabad": "ইসলামাবাদ", "Japan": "জাপান", "South Korea": "দক্ষিণ কোরিয়া",
    "Thailand": "থাইল্যান্ড", "Bhutan": "ভুটান", "Nepal": "নেপাল", "Tibet": "তিব্বত", "Mongolia": "মঙ্গোলিয়া", "Radcliffe Line": "র‍্যাডক্লিফ লাইন",
    "Durand Line": "ডুরান্ড লাইন", "McMahon Line": "ম্যাকমোহন লাইন", "Maginot Line": "ম্যাজিনো লাইন", "Afghanistan": "আফগানিস্তান", "India": "ভারত",
    "Iran": "ইরান", "China (Tibet)": "চীন (তিব্বত)", "Myanmar": "মিয়ানমার", "France": "ফ্রান্স", "United Kingdom": "যুক্তরাজ্য", "Spain": "স্পেন",
    "Italy": "ইতালি", "Australia": "অস্ট্রেলিয়া", "Indonesia": "ইন্দোনেশিয়া", "Philippines": "ফিলিপাইন", "New Zealand": "নিউজিল্যান্ড",
    "Africa": "আফ্রিকা", "Asia": "এশিয়া", "South America": "দক্ষিণ আমেরিকা", "Greenhouse gas emissions": "গ্রিনহাউস গ্যাস নিঃসরণ",
    "Nuclear weapons": "পারমাণবিক অস্ত্র", "Ozone layer only": "কেবল ওজোন স্তর", "Whaling": "তিমি শিকার", "The ozone layer": "ওজোন স্তর",
    "Wetlands": "জলাভূমি", "Migratory birds": "পরিযায়ী পাখি", "Ocean fisheries": "সামুদ্রিক মৎস্যসম্পদ", "Deserts": "মরুভূমি", "Ozone": "ওজোন",
    "Nuclear tests": "পারমাণবিক পরীক্ষা", "Sweden": "সুইডেন", "Denmark": "ডেনমার্ক", "Finland": "ফিনল্যান্ড", "Switzerland": "সুইজারল্যান্ড",
    # science
    "Scurvy": "স্কার্ভি", "Rickets": "রিকেটস", "Night blindness": "রাতকানা", "Beriberi": "বেরিবেরি", "Goitre": "গলগণ্ড", "Anaemia": "রক্তস্বল্পতা",
    "Pellagra": "পেলাগ্রা", "Vitamin K": "ভিটামিন কে", "Vitamin A": "ভিটামিন এ", "Vitamin C": "ভিটামিন সি", "Vitamin E": "ভিটামিন ই",
    "Diabetes": "ডায়াবেটিস", "Pancreas": "অগ্ন্যাশয়", "Liver": "যকৃৎ", "Kidney": "বৃক্ক", "Thyroid": "থাইরয়েড", "Skin": "ত্বক", "Brain": "মস্তিষ্ক",
    "Lungs": "ফুসফুস", "Pituitary": "পিটুইটারি", "Karl Landsteiner": "কার্ল ল্যান্ডস্টাইনার", "Louis Pasteur": "লুই পাস্তুর", "Robert Koch": "রবার্ট কখ",
    "Edward Jenner": "এডওয়ার্ড জেনার", "Alexander Fleming": "আলেকজান্ডার ফ্লেমিং", "Joseph Lister": "জোসেফ লিস্টার",
    "37 °C (98.4 °F)": "৩৭° সে (৯৮.৪° ফা)", "35 °C (95 °F)": "৩৫° সে (৯৫° ফা)", "39 °C (102 °F)": "৩৯° সে (১০২° ফা)", "40 °C (104 °F)": "৪০° সে (১০৪° ফা)",
    "Solids": "কঠিন মাধ্যম", "Liquids": "তরল মাধ্যম", "Gases": "বায়বীয় মাধ্যম", "Vacuum": "শূন্য মাধ্যম",
    "8 minutes 20 seconds": "৮ মিনিট ২০ সেকেন্ড", "8 seconds": "৮ সেকেন্ড", "1 hour": "১ ঘণ্টা", "24 hours": "২৪ ঘণ্টা",
    "Nitrous oxide (N₂O)": "নাইট্রাস অক্সাইড (N₂O)", "Carbon monoxide (CO)": "কার্বন মনোক্সাইড (CO)", "Nitrogen dioxide (NO₂)": "নাইট্রোজেন ডাইঅক্সাইড (NO₂)",
    "Methane (CH₄)": "মিথেন (CH₄)", "Carbon dioxide": "কার্বন ডাইঅক্সাইড", "Water": "পানি", "Ammonia": "অ্যামোনিয়া", "Methane": "মিথেন",
    "Ethane": "ইথেন", "Hydrogen sulphide": "হাইড্রোজেন সালফাইড", "Diamond": "হীরা", "Quartz": "কোয়ার্টজ", "Graphite": "গ্রাফাইট",
    "Jupiter": "বৃহস্পতি", "Saturn": "শনি", "Neptune": "নেপচুন", "Earth": "পৃথিবী", "Venus": "শুক্র", "Mars": "মঙ্গল",
    "Seismology": "সিসমোলজি (ভূকম্পবিদ্যা)", "Meteorology": "মেটিওরোলজি (আবহবিদ্যা)", "Ecology": "ইকোলজি (বাস্তুবিদ্যা)", "Petrology": "পেট্রোলজি (শিলাবিদ্যা)",
    "Barometer": "ব্যারোমিটার", "Hygrometer": "হাইগ্রোমিটার", "Ammeter": "অ্যামিটার", "Thermometer": "থার্মোমিটার", "Anemometer": "অ্যানিমোমিটার",
    "Altimeter": "অল্টিমিটার", "Seismograph": "সিসমোগ্রাফ", "Haemoglobin": "হিমোগ্লোবিন", "Insulin": "ইনসুলিন", "Keratin": "কেরাটিন",
    "Chlorophyll": "ক্লোরোফিল", "O negative": "ও নেগেটিভ", "AB positive": "এবি পজিটিভ", "A positive": "এ পজিটিভ", "B negative": "বি নেগেটিভ",
    # ICT
    "CPU": "সিপিইউ", "Monitor": "মনিটর", "Keyboard": "কি-বোর্ড", "Printer": "প্রিন্টার", "RAM": "র‍্যাম", "ROM": "রম", "Hard disk": "হার্ডডিস্ক",
    "Pen drive": "পেনড্রাইভ", "Speaker": "স্পিকার", "Scanner": "স্ক্যানার", "Mouse": "মাউস", "Binary": "বাইনারি", "Decimal": "দশমিক", "Roman": "রোমান",
    "Octal only": "কেবল অক্টাল", "Linux": "লিনাক্স", "MS Word": "এমএস ওয়ার্ড", "Google Chrome": "গুগল ক্রোম", "Photoshop": "ফটোশপ",
    "Mozilla Firefox": "মজিলা ফায়ারফক্স", "MS Excel": "এমএস এক্সেল", "Windows": "উইন্ডোজ", "Oracle": "ওরাকল", "Malware": "ম্যালওয়্যার",
    "Firmware": "ফার্মওয়্যার", "Freeware": "ফ্রিওয়্যার", "Middleware": "মিডলওয়্যার", "Charles Babbage": "চার্লস ব্যাবেজ", "Alan Turing": "অ্যালান টুরিং",
    "Bill Gates": "বিল গেটস", "Tim Berners-Lee": "টিম বার্নার্স-লি", "Steve Jobs": "স্টিভ জবস", "Vint Cerf": "ভিন্ট সার্ফ", "Bit": "বিট", "Byte": "বাইট",
    "Nibble": "নিবল", "Word": "ওয়ার্ড", "Router": "রাউটার", "Plotter": "প্লটার", "Microsoft Excel": "মাইক্রোসফট এক্সেল", "Microsoft Word": "মাইক্রোসফট ওয়ার্ড",
    "Notepad": "নোটপ্যাড", "Paint": "পেইন্ট",
    # banking
    "Bangladesh Bank": "বাংলাদেশ ব্যাংক", "Sonali Bank": "সোনালী ব্যাংক", "Janata Bank": "জনতা ব্যাংক", "Agrani Bank": "অগ্রণী ব্যাংক",
    "Motijheel, Dhaka": "মতিঝিল, ঢাকা", "Agargaon, Dhaka": "আগারগাঁও, ঢাকা", "Gulshan, Dhaka": "গুলশান, ঢাকা", "Agrabad, Chattogram": "আগ্রাবাদ, চট্টগ্রাম",
    "Ministry of Finance": "অর্থ মন্ত্রণালয়", "National Board of Revenue": "জাতীয় রাজস্ব বোর্ড", "Ministry of Commerce": "বাণিজ্য মন্ত্রণালয়",
    "Election Commission": "নির্বাচন কমিশন", "Rise in prices": "দামের ঊর্ধ্বগতি", "Fall in prices": "দামের নিম্নগতি", "Rise in employment": "কর্মসংস্থান বৃদ্ধি",
    "Fall in money supply": "মুদ্রা সরবরাহ হ্রাস", "A crossed cheque": "দাগকাটা (ক্রসড) চেক", "A bearer cheque": "বাহক চেক", "An open cheque": "খোলা চেক",
    "A stale cheque": "মেয়াদোত্তীর্ণ চেক", "Stale cheque": "মেয়াদোত্তীর্ণ (স্টেল) চেক", "Post-dated cheque": "অগ্রিম তারিখের চেক",
    "Crossed cheque": "দাগকাটা চেক", "Bearer cheque": "বাহক চেক", "Ante-dated cheque": "পূর্ব তারিখের চেক", "Fixed deposit": "স্থায়ী আমানত",
    "Current deposit": "চলতি আমানত", "Demand draft": "ডিমান্ড ড্রাফট", "Overdraft": "ওভারড্রাফট", "Standing instruction": "স্থায়ী নির্দেশনা",
    "Remittance": "রেমিট্যান্স",
    # Bar
    "The Bangladesh Legal Practitioners and Bar Council Order, 1972": "বাংলাদেশ লিগ্যাল প্র্যাকটিশনার্স অ্যান্ড বার কাউন্সিল অর্ডার, ১৯৭২",
    "The Bar Councils Act, 1926": "বার কাউন্সিলস অ্যাক্ট, ১৯২৬", "The Advocates Act, 1961": "অ্যাডভোকেটস অ্যাক্ট, ১৯৬১",
    "The Legal Aid Act, 2000": "আইনগত সহায়তা প্রদান আইন, ২০০০", "The Attorney General": "অ্যাটর্নি জেনারেল", "The Chief Justice": "প্রধান বিচারপতি",
    "The Law Minister": "আইনমন্ত্রী", "The President of the Supreme Court Bar Association": "সুপ্রীম কোর্ট বার অ্যাসোসিয়েশনের সভাপতি",
    "Canons of Professional Conduct and Etiquette": "পেশাগত আচরণ ও শিষ্টাচারের বিধিমালা (ক্যাননস)", "Code of Civil Procedure": "দেওয়ানি কার্যবিধি",
    "Rules of Business": "কার্যপ্রণালী বিধি (রুলস অব বিজনেস)", "Government Servants (Conduct) Rules": "সরকারি কর্মচারী (আচরণ) বিধিমালা",
    "Habeas corpus": "হেবিয়াস কর্পাস", "Mandamus": "ম্যান্ডামাস", "Certiorari": "সার্শিওরারি", "Quo warranto": "কো-ওয়ারেন্টো", "Prohibition": "প্রহিবিশন",
    "Cognizable": "আমলযোগ্য", "Non-cognizable": "আমল-অযোগ্য", "Compoundable": "আপসযোগ্য", "Bailable": "জামিনযোগ্য", "Plaint": "আরজি",
    "Charge sheet": "অভিযোগপত্র", "Petition of appeal": "আপিলের দরখাস্ত", "First information report": "এজাহার (এফআইআর)",
    "Double jeopardy": "দ্বৈত বিপদ (ডাবল জিওপার্ডি)", "Res judicata": "রেস জুডিকাটা", "Estoppel": "এস্টোপেল", "Stare decisis": "স্টেয়ার ডিসাইসিস",
    # ICT data units
    "8 bits": "৮ বিট", "1024 bytes": "১০২৪ বাইট", "1024 kilobytes": "১০২৪ কিলোবাইট", "1024 megabytes": "১০২৪ মেগাবাইট",
    "1024 gigabytes": "১০২৪ গিগাবাইট", "4 bits": "৪ বিট", "16 bits": "১৬ বিট", "1000 bytes": "১০০০ বাইট", "2048 bytes": "২০৪৮ বাইট",
    "512 megabytes": "৫১২ মেগাবাইট",
    # logic gate leftovers
    "Undefined": "অনির্ধারিত", "Both 0 and 1": "০ ও ১ দুটোই",
}
DATA_UNIT_BN = {"1 byte": "১ বাইট", "1 kilobyte (binary)": "১ কিলোবাইট (বাইনারি)", "1 megabyte (binary)": "১ মেগাবাইট (বাইনারি)",
                "1 gigabyte (binary)": "১ গিগাবাইট (বাইনারি)", "1 terabyte (binary)": "১ টেরাবাইট (বাইনারি)", "1 nibble": "১ নিবল"}

# ---------------------------------------------------------------------------------------------
# Converter
# ---------------------------------------------------------------------------------------------
_BN = str.maketrans("0123456789", "০১২৩৪৫৬৭৮৯")
_SUFFIX = {"A": "ক", "B": "খ", "C": "গ", "D": "ঘ"}
_VOWEL_SIGNS = set("ািীুূৃেৈোৌ")
_INDEP_VOWELS = set("অআইঈউঊঋএঐওঔ")
ENGLISH_OPTION_CATS = {"english_synonym", "english_antonym", "english_oneword", "english_spelling", "english_idiom",
                       "english_grammar", "ict_acronym", "banking_terms"}


def digits(s):
    return str(s).translate(_BN)


def sec_num(n):
    """'304A' -> '৩০৪ক', '2(h)' -> '২(h)'."""
    m = re.match(r"^(\d+)([A-D])?(.*)$", n)
    if not m:
        return digits(n)
    return digits(m.group(1)) + (_SUFFIX[m.group(2)] if m.group(2) else "") + m.group(3)


def poss(word):
    """Bengali genitive: ঢাকা -> ঢাকার, হাইড্রোজেন -> হাইড্রোজেনের, CPU -> CPU-এর."""
    last = word[-1]
    if last in _VOWEL_SIGNS or last in _INDEP_VOWELS:
        return word + "র"
    if "ক" <= last <= "হ" or last in "ড়ঢ়য়":
        return word + "ের"
    return word + "-এর"


def _roman(r):
    vals = {"I": 1, "V": 5, "X": 10, "L": 50, "C": 100}
    total = 0
    for i, ch in enumerate(r):
        v = vals[ch]
        total += -v if i + 1 < len(r) and vals[r[i + 1]] > v else v
    return total


def cpc_order(o):
    """'Order XXXIX, rules 1 and 2' -> 'আদেশ ৩৯, বিধি ১ ও ২'."""
    m = re.match(r"^Order ([IVXLC]+)(?:, rules? (.+))?$", o)
    if not m:
        return None
    out = "আদেশ " + digits(_roman(m.group(1)))
    if m.group(2):
        out += ", বিধি " + digits(m.group(2).replace(" and ", " ও "))
    return out


def _lookup_tables():
    t = {}
    t.update(OPT_BN)
    t.update(DISTRICT_BN)
    for c, (cbn, _) in COUNTRY_BN.items():
        t.setdefault(c, cbn)
    t.update(CITY_BN)
    t.update(CURRENCY_BN)
    t.update(ELEMENT_BN)
    t.update(CONSTITUTION_BN)
    t.update(SECTION_BN)
    t.update(MAXIM_BN)
    t.update(ACT_BN)
    t.update(ORG_BN)
    return t


def option_bn(text, extra=None):
    t = text.strip()
    if extra and t in extra:
        return extra[t]
    if t in TABLE:
        return TABLE[t]
    if re.fullmatch(r"[\d.]+", t):
        return digits(t)
    if re.fullmatch(r"Ctrl \+ [A-Z]", t) or re.fullmatch(r"[A-Z][A-Za-z0-9₀-₉]{0,7}", t):
        return t  # key combinations and chemical formulae read the same in Bengali papers
    m = re.fullmatch(r"Article (\S+)", t)
    if m:
        return "অনুচ্ছেদ " + sec_num(m.group(1))
    m = re.fullmatch(r"Section (\S+)", t)
    if m:
        return "ধারা " + sec_num(m.group(1))
    return None


TABLE = _lookup_tables()


def build_extras(capitals, si_units):
    """Capital and SI-unit maps need the generator's own tables (English capital -> Bengali capital)."""
    ex = {}
    for country, cap in capitals:
        cb = COUNTRY_BN.get(country, (None, None))[1]
        if cb:
            ex[cap] = cb
    for qty, unit in si_units:
        if qty in SI_BN:
            ex[unit] = SI_BN[qty][1]
    return ex


def stem_bn(it, extra):
    """Bengali stem for an English-only item, or None if no rule fits."""
    q = it["q_en"]
    cat = it["category"]
    if q in STEM_BN:
        return STEM_BN[q]
    T = lambda s: TABLE.get(s) or extra.get(s)
    m = re.fullmatch(r"(.+) district is in which division\?", q)
    if m and T(m.group(1)):
        return "%s জেলা কোন বিভাগে অবস্থিত?" % T(m.group(1))
    m = re.fullmatch(r"Which of these districts is in (.+) division\?", q)
    if m and T(m.group(1)):
        return "নিচের কোন জেলাটি %s বিভাগে অবস্থিত?" % T(m.group(1))
    m = re.fullmatch(r"What is the capital of (.+)\?", q)
    if m and T(m.group(1)):
        return "%s রাজধানী কোনটি?" % poss(T(m.group(1)))
    m = re.fullmatch(r"(.+) is the capital of:", q)
    if m and T(m.group(1)):
        return "%s কোন দেশের রাজধানী?" % T(m.group(1))
    m = re.fullmatch(r"What is the currency of (.+)\?", q)
    if m and T(m.group(1)):
        return "%s মুদ্রার নাম কী?" % poss(T(m.group(1)))
    m = re.fullmatch(r"Where is the headquarters of the (.+)\?", q)
    if m and T(m.group(1)):
        return "%s সদর দপ্তর কোথায়?" % poss(T(m.group(1)))
    m = re.fullmatch(r"What is the chemical symbol of (.+)\?", q)
    if m and T(m.group(1)):
        return "%s রাসায়নিক প্রতীক কোনটি?" % poss(T(m.group(1)))
    m = re.fullmatch(r"Which element has the symbol '(.+)'\?", q)
    if m:
        return "'%s' কোন মৌলের প্রতীক?" % m.group(1)
    m = re.fullmatch(r"What is the atomic number of (.+)\?", q)
    if m and T(m.group(1)):
        return "%s পারমাণবিক সংখ্যা কত?" % poss(T(m.group(1)))
    m = re.fullmatch(r"What is the SI unit of (.+)\?", q)
    if m:
        for qty, (qb, _) in SI_BN.items():
            if qty.lower() == m.group(1):
                return "%s এসআই একক কোনটি?" % poss(qb)
    m = re.fullmatch(r"(.+) equals:", q)
    if m and m.group(1) in DATA_UNIT_BN:
        return "%s সমান কত?" % DATA_UNIT_BN[m.group(1)]
    m = re.fullmatch(r"What does (.+) stand for\?", q)
    if m:
        return "%s পূর্ণরূপ কী?" % poss(m.group(1))
    m = re.fullmatch(r"In banking and economics, '(.+)' stands for:", q)
    if m:
        return "ব্যাংকিং ও অর্থনীতিতে '%s'-এর পূর্ণরূপ কী?" % m.group(1)
    m = re.fullmatch(r"Article (\S+) of the Constitution of Bangladesh deals with:", q)
    if m:
        return "বাংলাদেশের সংবিধানের অনুচ্ছেদ %s-এর বিষয়বস্তু কী?" % sec_num(m.group(1))
    m = re.fullmatch(r"Which article of the Constitution of Bangladesh deals with '(.+)'\?", q)
    if m and T(m.group(1)):
        return "বাংলাদেশের সংবিধানের কোন অনুচ্ছেদে '%s' বিষয়টি রয়েছে?" % T(m.group(1))
    m = re.fullmatch(r"Section (\S+) of (.+) deals with:", q)
    if m and T(m.group(2)):
        return "%s ধারা %s-এর বিষয়বস্তু কী?" % (poss(T(m.group(2))), sec_num(m.group(1)))
    m = re.fullmatch(r"Under (.+?, \d{4}), '(.+)' is dealt with in which section\?", q)
    if m and T(m.group(1)) and T(m.group(2)):
        return "%s '%s' কোন ধারায় বর্ণিত?" % (T(m.group(1)) + "-এ", T(m.group(2)))
    m = re.fullmatch(r"(Order .+) of the Code of Civil Procedure deals with:", q)
    if m and cpc_order(m.group(1)):
        return "দেওয়ানি কার্যবিধির %s-এর বিষয়বস্তু কী?" % cpc_order(m.group(1))
    m = re.fullmatch(r"'(.+)' is a provision of which law\?", q)
    if m and T(m.group(1)):
        return "'%s' কোন আইনের বিধান?" % T(m.group(1))
    m = re.fullmatch(r"(.+) was enacted in:", q)
    if m and T(m.group(1)):
        return "%s কোন সালে প্রণীত হয়?" % T(m.group(1))
    m = re.fullmatch(r"What does '(.+)' mean\?", q)
    if m and cat == "law_maxims":
        return "'%s' কথাটির অর্থ কী?" % m.group(1)
    m = re.fullmatch(r"Which Latin term means '(.+)'\?", q)
    if m and T(m.group(1)):
        return "কোন লাতিন পরিভাষার অর্থ '%s'?" % T(m.group(1))
    # English section: Bengali instruction, English material
    m = re.fullmatch(r"Choose the synonym of '(.+)'\.", q)
    if m:
        return "'%s' শব্দের সমার্থক শব্দ কোনটি?" % m.group(1)
    m = re.fullmatch(r"Choose the antonym of '(.+)'\.", q)
    if m:
        return "'%s' শব্দের বিপরীত শব্দ কোনটি?" % m.group(1)
    m = re.fullmatch(r"One-word substitute: '(.+)'", q)
    if m:
        return "এক কথায় প্রকাশ করো: '%s'" % m.group(1)
    if q == "Which spelling is correct?":
        return "কোন বানানটি শুদ্ধ?"
    m = re.fullmatch(r"What does the idiom '(.+)' mean\?", q)
    if m:
        return "'%s' বাগধারাটির অর্থ কী?" % m.group(1)
    if cat == "english_grammar":
        if "___" in q:
            return "শূন্যস্থান পূরণ করো: " + q
        return "সঠিক উত্তরটি বেছে নাও: " + q
    return None


def bengalify(items, capitals, si_units):
    """Give every English-only item a Bengali stem and Bengali options. Returns a list of gaps."""
    extra = build_extras(capitals, si_units)
    gaps = []
    for it in items:
        if "q_bn" in it and it.get("options_bn"):
            continue
        if "q_en" not in it:
            continue
        stem = it.get("q_bn") or stem_bn(it, extra)
        if stem is None:
            gaps.append(("stem", it["id"], it["q_en"]))
            continue
        cat = it["category"]
        opts_en = it["options_en"]
        if cat in ENGLISH_OPTION_CATS or (cat == "science_chem" and "chemical symbol" in it["q_en"]) \
                or (cat == "law_maxims" and it["q_en"].startswith("Which Latin term")) or cat == "ict_number":
            opts = list(opts_en)
        else:
            opts = [option_bn(o, extra) for o in opts_en]
            missing = [o for o, b in zip(opts_en, opts) if b is None]
            if missing:
                gaps.append(("option", it["id"], missing))
                continue
            if len(set(opts)) != 4:
                gaps.append(("dupe", it["id"], opts))
                continue
        it["q_bn"] = stem
        it["options_bn"] = opts
        it["lang"] = "both"
    return gaps

