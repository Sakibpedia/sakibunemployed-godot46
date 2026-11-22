class_name TauntBank
extends RefCounted
## 124 Bengali taunts (with English) in 14 situations. Gatekeepers, strangers, police, the dying and
## ghosts all draw from here. Satire aimed at the job market, coaching culture and Sakib himself;
## never at anyone's religion, caste, body or family.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const TAUNTS := {
	"wrong": [
		{"bn": "এটাও পারলেন না? আপনার সার্টিফিকেট কি বাজার থেকে কেনা?", "en": "Couldn't even get that? Did you buy your certificate at the bazaar?"},
		{"bn": "ভুল! চাকরি তো দূরের কথা, টিউশনিও পাবেন না।", "en": "Wrong! Forget a job, you won't even land a tuition."},
		{"bn": "আহারে, এত পড়ে এই অবস্থা!", "en": "Oh dear, all that studying for this?"},
		{"bn": "গাইড বই মুখস্থ করেছেন, মাথায় কিছু ঢোকেনি।", "en": "You memorised the guidebook; nothing reached your head."},
		{"bn": "এই উত্তর দিলে ভাইভা বোর্ড হাসতে হাসতে মরে যাবে।", "en": "Give that answer and the viva board will die laughing."},
		{"bn": "ভাই, প্রশ্নটা আবার পড়েন। আস্তে আস্তে।", "en": "Brother, read the question again. Slowly."},
		{"bn": "বেকারত্বের কারণ এখন বুঝলাম।", "en": "Now I understand why you're unemployed."},
		{"bn": "আপনার চেয়ে আমার রিকশাওয়ালা ভালো জানে।", "en": "My rickshaw-puller knows more than you."},
		{"bn": "এটা তো ক্লাস ফাইভের প্রশ্ন ছিল!", "en": "That was a class five question!"},
		{"bn": "এলএলবি পাস? কোন বছর? কোন গ্রহে?", "en": "An LLB graduate? Which year? Which planet?"},
		{"bn": "ভুল উত্তর দিয়ে আত্মবিশ্বাসী মুখ, এটাই আসল প্রতিভা।", "en": "A wrong answer with a confident face. Now that's talent."},
		{"bn": "আপনার মামা-খালু কেউ নেই? তাহলে তো আরও পড়তে হবে।", "en": "No uncle in high places? Then you'd better study harder."},
		{"bn": "এভাবে চললে পরের বিসিএসেও লাইনে দাঁড়াবেন।", "en": "Keep this up and you'll be queuing for the next BCS too."},
		{"bn": "উত্তর না জানলে চুপ থাকাও একটা বিদ্যা।", "en": "Staying quiet when you don't know is also a skill."},
	],
	"slow": [
		{"bn": "ঘড়ি চলছে, আপনার মাথা চলছে না।", "en": "The clock is moving; your brain isn't."},
		{"bn": "এত ভাবলে তো পরীক্ষার হল বন্ধ হয়ে যাবে।", "en": "Think any longer and the exam hall will close."},
		{"bn": "জ্যামে আটকে আছেন নাকি? উত্তর দেন!", "en": "Stuck in a traffic jam? Answer!"},
		{"bn": "চা ঠান্ডা হয়ে গেল, উত্তর এখনো এল না।", "en": "The tea's gone cold and still no answer."},
		{"bn": "সময় শেষ! লোডশেডিং-এর মতো হঠাৎ।", "en": "Time's up! Sudden, like load-shedding."},
		{"bn": "প্রিলিতে এভাবে বসে থাকলে ওএমআর ফাঁকা যাবে।", "en": "Sit like this in the prelims and your OMR goes blank."},
		{"bn": "হা করে আছেন কেন? মশা ঢুকবে।", "en": "Why is your mouth hanging open? Mosquitoes will fly in."},
		{"bn": "উত্তর ডাউনলোড হচ্ছে? নেট স্লো নাকি?", "en": "Is the answer still downloading? Slow internet?"},
		{"bn": "ঘুমিয়ে পড়লেন নাকি?", "en": "Did you fall asleep?"},
		{"bn": "এত দেরি, সরকারি ফাইলও এর চেয়ে দ্রুত নড়ে।", "en": "So slow. Even a government file moves faster."},
	],
	"right_grudging": [
		{"bn": "হুম, ঠিক আছে। আন্দাজে মেরেছেন, তাই না?", "en": "Hmm, correct. A lucky guess, wasn't it?"},
		{"bn": "আচ্ছা, এবার পারলেন। পরেরটা দেখি।", "en": "Fine, you got this one. Let's see the next."},
		{"bn": "ঠিক! কিন্তু এতে চাকরি হবে না।", "en": "Right! But that won't get you a job."},
		{"bn": "বাহ, গাইড বইটা কাজে লাগল।", "en": "Well, the guidebook paid off."},
		{"bn": "ঠিক উত্তর। এত খুশি হওয়ার কিছু নেই।", "en": "Correct. Nothing to be so pleased about."},
		{"bn": "একটা ঠিক করেছেন, আর বাকি জীবন?", "en": "One right. And the rest of your life?"},
		{"bn": "চলবে। কোচিং-এর টাকা উসুল।", "en": "It'll do. Your coaching fee was worth it."},
		{"bn": "ঠিক আছে, ঠিক আছে, এত বুক ফুলাবেন না।", "en": "All right, all right, don't puff your chest out."},
	],
	"gun": [
		{"bn": "পিস্তল দিয়ে ডিগ্রি হয় না, ভাই।", "en": "A pistol won't get you a degree, brother."},
		{"bn": "অস্ত্র নামান! প্রশ্নের উত্তর দেন!", "en": "Lower the gun! Answer the question!"},
		{"bn": "গুলি করবেন? আগে বলেন, দণ্ডবিধির কোন ধারায় খুনের শাস্তি?", "en": "Going to shoot? First tell me: which Penal Code section punishes murder?"},
		{"bn": "বেকার মানুষের হাতে অস্ত্র, দেশের কী হবে!", "en": "An unemployed man with a gun. What will become of this country!"},
		{"bn": "ভয় পাই না। আমি তো এমনিতেই বেকারদের ইন্টারভিউ নিই।", "en": "I'm not scared. I interview the unemployed every day."},
		{"bn": "এটা যাত্রাবাড়ী, সিনেমা না।", "en": "This is Jatrabari, not a movie."},
		{"bn": "গুলির শব্দে পুরো মহল্লা জেগে গেল।", "en": "The whole neighbourhood woke up to that shot."},
		{"bn": "এই হাতে কলম ধরলে আজ ক্যাডার হতেন।", "en": "Hold a pen with that hand and you'd be a cadre by now."},
	],
	"ghost": [
		{"bn": "আমাকে মেরেছিস, আমার প্রশ্নের উত্তর দিসনি...", "en": "You killed me, and you never answered my question..."},
		{"bn": "রাত হয়েছে, সাকিব। উত্তর দে, নইলে ছাড়ব না।", "en": "Night has come, Sakib. Answer, or I won't let go."},
		{"bn": "কবরেও শান্তি নেই, তোর জন্য।", "en": "No peace even in the grave, because of you."},
		{"bn": "আলো নিভে গেছে... এবার আমার পালা।", "en": "The lights are out... now it's my turn."},
		{"bn": "জুরাইনের মাটি থেকে উঠে এলাম শুধু এই প্রশ্নটা করতে।", "en": "I rose from Jurain's soil just to ask you this."},
		{"bn": "তোর সিলেবাস শেষ হয়নি, আমার ক্ষমাও না।", "en": "Your syllabus isn't finished, and neither is my forgiveness."},
		{"bn": "সূর্য উঠলে পালাব, তার আগে না।", "en": "I'll flee when the sun rises, not before."},
		{"bn": "উত্তর দে... উত্তর দে... উত্তর দে...", "en": "Answer... answer... answer..."},
		{"bn": "আমার শেষ প্রশ্ন ছিল, তুই শুনিসনি।", "en": "I had one last question. You didn't listen."},
		{"bn": "ঘরে ঢুকে যা, নইলে আমি আসছি।", "en": "Get indoors, or I'm coming."},
		{"bn": "টর্চের ব্যাটারি কতক্ষণ চলবে, সাকিব?", "en": "How long will your torch batteries last, Sakib?"},
		{"bn": "এক প্রশ্নের দাম তুই জীবন দিয়ে দিবি।", "en": "You'll pay for one question with your life."},
	],
	"dying": [
		{"bn": "মরার আগে... একটা প্রশ্ন... উত্তর দাও...", "en": "Before I die... one question... answer it..."},
		{"bn": "আমার শেষ ইচ্ছা: তুমি এটা পারো কিনা দেখি।", "en": "My last wish: let me see if you know this."},
		{"bn": "উত্তর দিলে শান্তিতে যাব। না দিলে ফিরে আসব।", "en": "Answer and I go in peace. Don't, and I'll come back."},
		{"bn": "আমিও একদিন বিসিএস দিতে চেয়েছিলাম...", "en": "I once wanted to sit the BCS too..."},
		{"bn": "রক্ত ঝরছে... তাড়াতাড়ি উত্তর দাও।", "en": "I'm bleeding... answer quickly."},
		{"bn": "আমার মাকে বোলো... না, আগে প্রশ্নটা।", "en": "Tell my mother... no, the question first."},
		{"bn": "ভুল করলে রাতে দেখা হবে।", "en": "Get it wrong and we'll meet tonight."},
		{"bn": "এটাই আমার শেষ পরীক্ষা। তোমারও।", "en": "This is my last exam. Yours too."},
	],
	"stranger": [
		{"bn": "এই যে ভাই, চাকরি খুঁজছেন? একটা প্রশ্ন করি?", "en": "Hey brother, job-hunting? Mind if I ask you one?"},
		{"bn": "আপনাকে তো কোচিং-এ দেখি। দেখি কেমন পড়েছেন।", "en": "I see you at the coaching centre. Let's see what you learnt."},
		{"bn": "বাজি ধরি, এটা পারবেন না।", "en": "Bet you can't answer this one."},
		{"bn": "আমার ভাগ্নে প্রথম বারেই ক্যাডার। আপনি?", "en": "My nephew made cadre on his first try. And you?"},
		{"bn": "চা খাবেন? আগে উত্তর দেন।", "en": "Tea? Answer first."},
		{"bn": "আজকের পত্রিকায় এই প্রশ্নটা ছিল। জানেন?", "en": "This question was in today's paper. Know it?"},
		{"bn": "রাস্তায় দাঁড়িয়ে একটু মগজ খাটাই, কী বলেন?", "en": "Let's exercise our brains here on the street, shall we?"},
		{"bn": "আপনার মুখ দেখে মনে হয় সংবিধান মুখস্থ।", "en": "You look like someone who knows the constitution by heart."},
		{"bn": "পারলে একশ টাকা, না পারলে একশ টাকা।", "en": "Get it right, a hundred taka. Wrong, you pay a hundred."},
		{"bn": "মহল্লার সবাই বলে আপনি পড়ুয়া। প্রমাণ দেন।", "en": "Everyone says you're a bookworm. Prove it."},
	],
	"police": [
		{"bn": "দাঁড়ান! কাগজপত্র কোথায়? আচ্ছা, আগে এই প্রশ্নটা।", "en": "Stop! Where are your papers? Fine, this question first."},
		{"bn": "ঠিক উত্তর দিলে ছেড়ে দেব। ভুল হলে থানায়।", "en": "Answer right and you walk. Wrong and it's the station."},
		{"bn": "ধারা ৫৪ জানেন তো? তাহলে বুঝতেই পারছেন।", "en": "You know Section 54? Then you understand."},
		{"bn": "এত রাতে বাইরে কী করেন?", "en": "What are you doing out this late?"},
		{"bn": "গুলির শব্দ শুনলাম। আপনি কিছু জানেন?", "en": "I heard a shot. Know anything about it?"},
		{"bn": "হাত উপরে! আর মাথায় যা আছে বের করেন।", "en": "Hands up! And empty whatever's in your head."},
		{"bn": "রিমান্ডে নিলে সব উত্তর বের হবে।", "en": "A remand would get every answer out of you."},
		{"bn": "আইন জানেন, তাহলে আইন মানেন না কেন?", "en": "You know the law, so why don't you follow it?"},
	],
	"coaching": [
		{"bn": "শতভাগ গ্যারান্টি! না হলে টাকা ফেরত... না, ফেরত না।", "en": "Hundred percent guarantee! Or your money back... no, not back."},
		{"bn": "আমাদের কোচিং থেকে বিশজন ক্যাডার। বাকি দুই হাজার?", "en": "Twenty cadres from our coaching. The other two thousand?"},
		{"bn": "শর্টকাট শিখুন, লং-টার্মে বেকার থাকুন।", "en": "Learn the shortcut, stay unemployed for the long term."},
		{"bn": "মডেল টেস্টে ফেল? ভর্তি ফি আবার দিন।", "en": "Failed the model test? Pay the admission fee again."},
		{"bn": "প্রশ্ন ফাঁস? না না, আমরা শুধু 'সাজেশন' দিই।", "en": "Leaked questions? No, no, we only give 'suggestions'."},
		{"bn": "সাকিব ভাই, আপনার জন্য স্পেশাল ব্যাচ। ডাবল ফি।", "en": "Sakib bhai, a special batch for you. Double fee."},
		{"bn": "পড়তে হবে না, শুধু আমাদের শিট মুখস্থ করুন।", "en": "No need to study, just memorise our sheets."},
		{"bn": "চাকরি না পেলে আমাদের এখানে শিক্ষক হয়ে যান।", "en": "If you don't get a job, become a teacher here."},
	],
	"night": [
		{"bn": "সন্ধ্যা নামছে, বাসায় যান। জুরাইনে রাত ভালো না।", "en": "Dusk is falling, go home. Nights in Jurain aren't good."},
		{"bn": "লোডশেডিং হলে রাস্তায় থাকবেন না।", "en": "When the power goes, don't stay on the street."},
		{"bn": "কবরস্থানের পাশ দিয়ে রাতে যাবেন না, ভাই।", "en": "Don't pass the graveyard at night, brother."},
		{"bn": "ল্যাম্পপোস্টের আলোয় থাকুন, অন্ধকারে না।", "en": "Stay under the lamp posts, not in the dark."},
		{"bn": "রাতে কেউ প্রশ্ন করলে পেছন ফিরে তাকাবেন না।", "en": "If someone asks you a question at night, don't look back."},
		{"bn": "আজান দিল, আর বাইরে থাকবেন না।", "en": "The call to prayer has sounded; don't stay out."},
	],
	"bribe": [
		{"bn": "টাকা দিলে সব প্রশ্ন সহজ হয়ে যায়, তাই না?", "en": "Money makes every question easy, doesn't it?"},
		{"bn": "ঠিক আছে, এবারের মতো ছেড়ে দিলাম। কাউকে বলবেন না।", "en": "All right, I'll let it go this time. Tell no one."},
		{"bn": "এই দেশে মেধার চেয়ে মানিব্যাগ ভারী।", "en": "In this country the wallet weighs more than merit."},
		{"bn": "ঘুষ দিলেন, সততা গেল। খুশি?", "en": "You paid the bribe and lost your honesty. Happy?"},
		{"bn": "চা-নাস্তার খরচ দিলেন, আর কিছু না।", "en": "Just tea-and-snacks money, nothing more."},
		{"bn": "পরের বার দাম বাড়বে।", "en": "The price goes up next time."},
	],
	"lose": [
		{"bn": "ঠিক আছে, মানলাম আপনি পড়েছেন।", "en": "All right, I admit you've studied."},
		{"bn": "এই নিন, আপনার পুরস্কার। মহল্লায় বলবেন না আমি হেরেছি।", "en": "Here, your prize. Don't tell the neighbourhood I lost."},
		{"bn": "আপনি ক্যাডার হবেন, আমি লিখে দিলাম।", "en": "You'll make cadre, I'll put that in writing."},
		{"bn": "আজকের দিনটা আপনার।", "en": "Today is your day."},
		{"bn": "আমার ভাগ্নেকে আপনার কাছে পড়তে পাঠাব।", "en": "I'll send my nephew to study with you."},
		{"bn": "এত জানেন, তবু চাকরি নেই? দেশটাই উল্টো।", "en": "You know so much and still no job? This country is upside down."},
		{"bn": "হেরে গেলাম, কিন্তু মন খারাপ না।", "en": "I lost, but I'm not upset."},
		{"bn": "আবার দেখা হবে, তখন কঠিন প্রশ্ন করব।", "en": "We'll meet again, and I'll ask a harder one."},
	],
	"goon": [
		{"bn": "বস বলেছে তোকে থামাতে। প্রশ্নের উত্তর দিয়ে নয়।", "en": "The boss said to stop you. Not with answers."},
		{"bn": "ফাঁস প্রশ্ন কিনলে আজ এত ঝামেলা হতো না।", "en": "Buy the leaked paper and you'd have no trouble today."},
		{"bn": "এই এলাকা আমাদের। এখানে পড়াশোনা চলে না।", "en": "This area is ours. Studying doesn't work here."},
		{"bn": "সৎ হয়ে কী পেলি? বেকারত্ব।", "en": "What did honesty get you? Unemployment."},
		{"bn": "কোচিং-এর বিরুদ্ধে লাগলে এই হয়।", "en": "This is what happens when you go against the coaching centre."},
		{"bn": "ধর ওকে! ব্যাগে নোট আছে!", "en": "Grab him! There are notes in his bag!"},
		{"bn": "মহাসড়কে তোর জন্য অপেক্ষা করছি।", "en": "We're waiting for you on the highway."},
		{"bn": "এক প্রশ্নের দাম পাঁচ হাজার, তোর জান কত?", "en": "One question costs five thousand. What's your life worth?"},
	],
	"idle": [
		{"bn": "কী সাকিব, এখনো বেকার?", "en": "So Sakib, still unemployed?"},
		{"bn": "মা কী বলে? বিয়ের কথা চলছে?", "en": "What does your mother say? Marriage talk yet?"},
		{"bn": "সার্কুলার বের হয়েছে, দেখেছেন?", "en": "The circular's out, did you see?"},
		{"bn": "বয়স তো ত্রিশ ছুঁইছুঁই, ভাই।", "en": "You're nearly thirty, brother."},
		{"bn": "আজ কোন লাইব্রেরিতে? নাকি চায়ের দোকানে?", "en": "Which library today? Or the tea stall?"},
		{"bn": "আপনার বন্ধুরা সবাই চাকরি পেয়ে গেছে, না?", "en": "All your friends have jobs now, haven't they?"},
		{"bn": "এলএলবি করে এখন রাস্তায় হাঁটেন?", "en": "An LLB, and now you walk the streets?"},
		{"bn": "চাকরি পেলে মিষ্টি খাওয়াবেন কিন্তু।", "en": "When you get a job, you owe us sweets."},
		{"bn": "শুনলাম আপনি নাকি প্রশ্ন ফাঁস চক্রের পেছনে লেগেছেন?", "en": "I hear you're going after the question-leak gang?"},
		{"bn": "পোস্টারগুলো পড়েছেন? সব কোচিং-এর বিজ্ঞাপন।", "en": "Read the posters? All coaching adverts."},
	],
}


static func pick(category: String, rng: RandomNumberGenerator = null) -> Dictionary:
	var list: Array = TAUNTS.get(category, TAUNTS["idle"])
	if list.is_empty():
		return {"bn": "", "en": ""}
	var i := rng.randi_range(0, list.size() - 1) if rng != null else randi() % list.size()
	return list[i]


static func total() -> int:
	var n := 0
	for k in TAUNTS:
		var list: Array = TAUNTS[k]
		n += list.size()
	return n
