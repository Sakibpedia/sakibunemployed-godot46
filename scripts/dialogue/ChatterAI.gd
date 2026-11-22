class_name ChatterAI
extends RefCounted
## What people say. Lines are put together from the speaker's profession and temperament, the time
## of day, the district, the weather of the night (load-shedding, ghosts) and what Sakib has done
## lately (GameState.recent_events, so gossip spreads). No language model: rules and phrase banks,
## so it runs anywhere and every line is fit to print.
## Developed by S M Nazmuz Sakib. Copyright (c) 2026 S M Nazmuz Sakib. All rights reserved.

const GREET := [
	{"bn": "আসসালামু আলাইকুম, সাকিব ভাই।", "en": "Assalamu alaikum, Sakib bhai."},
	{"bn": "কী খবর, ভাই? কেমন আছেন?", "en": "What's the news, brother? How are you?"},
	{"bn": "আরে সাকিব! অনেক দিন পর।", "en": "Hey, Sakib! It's been a while."},
	{"bn": "হ্যাঁ বলেন, কী লাগবে?", "en": "Yes, tell me, what do you need?"},
	{"bn": "ভাই, তাড়া আছে, তাড়াতাড়ি বলেন।", "en": "Brother, I'm in a hurry, be quick."},
]
const BYE := [
	{"bn": "আচ্ছা, যান। পড়াশোনা করেন।", "en": "Alright, off you go. Study."},
	{"bn": "দেখা হবে, ভাই।", "en": "See you, brother."},
	{"bn": "ভালো থাকবেন। চাকরি হলে মিষ্টি।", "en": "Take care. Sweets when you get the job."},
	{"bn": "সাবধানে চলবেন, রাস্তা ভালো না।", "en": "Go carefully, the roads are bad."},
]
const SMALLTALK := [
	{"bn": "যাত্রাবাড়ীর জ্যাম আজ আবার চার ঘণ্টা।", "en": "The Jatrabari jam was four hours again today."},
	{"bn": "পেঁয়াজের দাম আবার বেড়েছে, শুনেছেন?", "en": "Onion prices went up again, did you hear?"},
	{"bn": "কাল রাতে তিনবার কারেন্ট গেছে।", "en": "The power went three times last night."},
	{"bn": "এবারের মশা ডেঙ্গুর চেয়েও বড়।", "en": "This year's mosquitoes are bigger than dengue itself."},
	{"bn": "কাজলার ফ্লাইওভারের নিচে নতুন চায়ের দোকান হয়েছে।", "en": "A new tea stall opened under the Kajla flyover."},
	{"bn": "দনিয়া কলেজের সামনে আবার পোস্টার লাগিয়েছে।", "en": "They've stuck posters outside Dania College again."},
	{"bn": "পুকুরপাড়ে সন্ধ্যার পর কেউ বসে না আর।", "en": "Nobody sits by the pond after dusk any more."},
	{"bn": "বাসভাড়া আবার দশ টাকা বেড়ে গেল।", "en": "Bus fares went up ten taka again."},
	{"bn": "ছাদে কাপড় শুকাতে দিলে চুরি হয়ে যায়।", "en": "Hang laundry on the roof and it gets stolen."},
	{"bn": "সার্কুলারে বয়সসীমা ত্রিশ। আপনার আর কয় মাস?", "en": "The circular's age limit is thirty. How many months do you have?"},
]
const PROFESSION := {
	"rickshaw": [{"bn": "সোনটেক যাবেন? ষাট টাকা, এক টাকা কম না।", "en": "Going to Sontek? Sixty taka, not a taka less."},
		{"bn": "সারাদিন প্যাডেল মারি, তবু মাস শেষে কিছু থাকে না।", "en": "I pedal all day and still nothing's left at month's end."}],
	"tea": [{"bn": "এক কাপ রং চা? দুধ চা পনেরো।", "en": "Red tea? Milk tea is fifteen."},
		{"bn": "আমার দোকানে বসে কত ছেলে ক্যাডার হয়েছে জানেন?", "en": "Know how many boys made cadre sitting at my stall?"}],
	"shop": [{"bn": "বাকি দেওয়া যাবে না, দেখছেন না লেখা?", "en": "No credit. Can't you see the sign?"},
		{"bn": "পরীক্ষার কলম লাগবে? এক্সপোর্ট কোয়ালিটি।", "en": "Need an exam pen? Export quality."}],
	"student": [{"bn": "ভাই, আপনি কি এবার প্রিলি দিচ্ছেন?", "en": "Bhai, are you sitting the prelims this time?"},
		{"bn": "কোচিং-এর মডেল টেস্টে আবার ফেল।", "en": "Failed the coaching model test again."}],
	"guard": [{"bn": "পরিচয়পত্র ছাড়া ভেতরে যাওয়া যাবে না।", "en": "No entry without an ID card."},
		{"bn": "রাতে গেট বন্ধ, মালিকের অর্ডার।", "en": "The gate's locked at night, the owner's orders."}],
	"police": [{"bn": "এদিকে ঘোরাঘুরি কেন? কী কাজ?", "en": "Why are you loitering here? What's your business?"},
		{"bn": "রাতে বাইরে থাকবেন না, এলাকা গরম।", "en": "Don't stay out at night, the area's tense."}],
	"goon": [{"bn": "এখানে কী? পথ ছাড়।", "en": "What are you doing here? Get out of the way."},
		{"bn": "বসের সাথে লাগতে আসিস না।", "en": "Don't mess with the boss."}],
	"teacher": [{"bn": "পড়াশোনার কোনো শর্টকাট নেই, সাকিব।", "en": "There's no shortcut to study, Sakib."},
		{"bn": "প্রতিদিন দুই পাতা সংবিধান পড়বে।", "en": "Read two pages of the constitution every day."}],
	"lawyer": [{"bn": "বার কাউন্সিলের লিখিত পরীক্ষায় দণ্ডবিধি আর সাক্ষ্য আইন আসবেই।", "en": "The Bar written exam always has the Penal Code and the Evidence Act."},
		{"bn": "আইন পড়েছ, এবার আদালতে দাঁড়াতে শেখো।", "en": "You've read law; now learn to stand in court."}],
	"aunty": [{"bn": "বাবা, চাকরি না হলে বিয়ে দেব কীভাবে?", "en": "Son, how can we marry you off without a job?"},
		{"bn": "আমার মেয়ের জন্য ভালো টিউটর খুঁজছি।", "en": "I'm looking for a good tutor for my daughter."}],
	"elder": [{"bn": "আমাদের সময়ে ম্যাট্রিক পাশেই চাকরি হতো।", "en": "In our day a matric pass got you a job."},
		{"bn": "সৎ থাকবি, বাবা। আল্লাহ দেখবেন।", "en": "Stay honest, son. God will see to the rest."}],
	"clerk": [{"bn": "ফাইল আজ হবে না, কাল আসেন।", "en": "The file won't move today, come tomorrow."},
		{"bn": "প্রবেশপত্রের জন্য লাইনে দাঁড়ান।", "en": "Queue for your admit card."}],
	"journalist": [{"bn": "প্রশ্ন ফাঁসের খবর পেলে আমাকে জানাবেন।", "en": "If you hear of a leak, tell me."},
		{"bn": "সত্য লিখলে বিপদ, না লিখলে লজ্জা।", "en": "Write the truth and you're in danger; don't, and you're ashamed."}],
}
const WARN_NIGHT := [
	{"bn": "সন্ধ্যা হয়ে আসছে, ভাই। বাসায় যান।", "en": "Evening's coming, brother. Go home."},
	{"bn": "রাতে অন্ধকার গলিতে যাবেন না। ওরা বের হয়।", "en": "Don't take dark lanes at night. They come out."},
	{"bn": "লাইটের নিচে থাকবেন, আলো থাকলে ওরা আসে না।", "en": "Stay under the lights; they don't come where it's lit."},
	{"bn": "কারেন্ট চলে গেলে দৌড়ে ঘরে ঢুকবেন।", "en": "If the power goes, run indoors."},
]
const REACT_GUN := [
	{"bn": "পিস্তল! সবাই সরেন!", "en": "A pistol! Everyone move!"},
	{"bn": "ভাই, মাফ করেন, আমি কিছু করিনি!", "en": "Brother, please, I've done nothing!"},
	{"bn": "পুলিশ ডাকো! পুলিশ!", "en": "Call the police! Police!"},
	{"bn": "আল্লাহ রে! গুলি!", "en": "Oh God! Shots!"},
]
const REACT_GHOST := [
	{"bn": "ওটা কী! ভূত! ভূত!", "en": "What's that! A ghost! A ghost!"},
	{"bn": "দোয়া পড়েন, দৌড় দেন!", "en": "Say a prayer and run!"},
	{"bn": "আমি কিছু দেখিনি, কিছু দেখিনি!", "en": "I saw nothing, nothing!"},
]
const QUIZ_OFFER := [
	{"bn": "দাঁড়ান, একটা প্রশ্নের উত্তর দিয়ে যান।", "en": "Wait, answer me one question before you go."},
	{"bn": "আপনি তো পড়ুয়া মানুষ। দেখি কয়টা পারেন।", "en": "You're the studious type. Let's see how many you get."},
	{"bn": "জিতলে টাকা দেব, হারলে আপনি দেবেন। রাজি?", "en": "Win and I pay you; lose and you pay me. Deal?"},
]
const RUMOUR := {
	"shooting": {"bn": "শুনলাম %s-এ গুলি হয়েছে। আপনি ছিলেন নাকি?", "en": "I heard there was shooting in %s. Were you there?"},
	"killing": {"bn": "%s-এ একজন মারা গেছে। লোকে বলে খুনি নাকি পড়ুয়া ছেলে।", "en": "Someone died in %s. People say the killer looked like a student."},
	"ghost_seen": {"bn": "কাল রাতে %s-এ নাকি ভূত দেখা গেছে!", "en": "They say a ghost was seen in %s last night!"},
	"duel_won": {"bn": "আপনি নাকি %s-এ প্রশ্নের লড়াইয়ে জিতেছেন! বাহ!", "en": "I hear you won a question duel in %s! Well done!"},
	"duel_lost": {"bn": "%s-এ নাকি প্রশ্নে হেরে গেছেন? হা হা।", "en": "Lost a question duel in %s, did you? Ha ha."},
	"poster_torn": {"bn": "%s-এ কে যেন ফাঁস-চক্রের পোস্টার ছিঁড়ছে।", "en": "Someone's been tearing down the leak gang's posters in %s."},
	"bribe": {"bn": "%s-এ আপনাকে ঘুষ দিতে দেখেছে কেউ কেউ।", "en": "Some people saw you paying a bribe in %s."},
	"banished": {"bn": "%s-এর ভূতটা নাকি মুক্তি পেয়েছে। আপনার কাজ?", "en": "They say the ghost of %s was set free. Your doing?"},
	"helped": {"bn": "%s-এ একজনকে সাহায্য করেছেন শুনলাম। ভালো কাজ।", "en": "I heard you helped someone in %s. Good work."},
}
const QUIZ_WIN := [
	{"bn": "বাহ! আপনি সত্যিই পড়েছেন।", "en": "Wow! You really have studied."},
	{"bn": "মানতেই হবে, মাথা আছে।", "en": "I have to admit it, you've got brains."},
]
const QUIZ_LOSE := [
	{"bn": "হা হা! আরও পড়েন, ভাই।", "en": "Ha ha! Study more, brother."},
	{"bn": "টাকাটা দেন। আর পড়ার টেবিলে ফেরত যান।", "en": "Pay up. And get back to your desk."},
]


static func _any(list: Array, rng: RandomNumberGenerator) -> Dictionary:
	if list.is_empty():
		return {"bn": "...", "en": "..."}
	return list[rng.randi_range(0, list.size() - 1)]


## ctx: {district{bn,en}, hour, armed: bool, ghosts_out: bool, power_out: bool}
static func line(profile: Dictionary, topic: String, ctx: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var prof := String(profile.get("profession", ""))
	var temper := float((profile.get("personality", {}) as Dictionary).get("temper", 0.3))
	match topic:
		"greet":
			if temper > 0.7:
				return {"bn": "কী চাই? বিরক্ত করবেন না।", "en": "What do you want? Don't bother me."}
			return _any(GREET, rng)
		"bye":
			return _any(BYE, rng)
		"smalltalk":
			if PROFESSION.has(prof) and rng.randf() < 0.55:
				return _any(PROFESSION[prof], rng)
			var h := float(ctx.get("hour", 12.0))
			if h > 16.8 and h < 18.2 and rng.randf() < 0.6:
				return _any(WARN_NIGHT, rng)
			if bool(ctx.get("power_out", false)):
				return {"bn": "আবার লোডশেডিং! এই অন্ধকারে কেউ বাইরে থাকে?", "en": "Load-shedding again! Who stays out in this dark?"}
			if rng.randf() < 0.3:
				return TauntBank.pick("idle", rng)
			return _any(SMALLTALK, rng)
		"rumour":
			for e in GameState.recent_events:
				var ev: Dictionary = e
				var kind := String(ev.get("kind", ""))
				if RUMOUR.has(kind) and rng.randf() < 0.7:
					var t: Dictionary = RUMOUR[kind]
					var dname := String(ev.get("district", "Jatrabari"))
					var dn := _district_names(dname)
					return {"bn": String(t["bn"]) % dn["bn"], "en": String(t["en"]) % dn["en"]}
			return _any(SMALLTALK, rng)
		"warn_night":
			return _any(WARN_NIGHT, rng)
		"react_gun":
			if prof == "goon" or prof == "police":
				return TauntBank.pick("gun", rng)
			return _any(REACT_GUN, rng)
		"react_ghost":
			return _any(REACT_GHOST, rng)
		"quiz_offer":
			if prof == "police":
				return TauntBank.pick("police", rng)
			if rng.randf() < 0.5:
				return TauntBank.pick("stranger", rng)
			return _any(QUIZ_OFFER, rng)
		"quiz_win":
			return TauntBank.pick("lose", rng) if rng.randf() < 0.5 else _any(QUIZ_WIN, rng)
		"quiz_lose":
			return TauntBank.pick("wrong", rng) if rng.randf() < 0.5 else _any(QUIZ_LOSE, rng)
	return _any(SMALLTALK, rng)


static func _district_names(id: String) -> Dictionary:
	match id:
		"sontek":
			return {"bn": "সোনটেক", "en": "Sontek"}
		"dania":
			return {"bn": "দনিয়া", "en": "Dania"}
		"jurain":
			return {"bn": "জুরাইন", "en": "Jurain"}
		"kajla":
			return {"bn": "কাজলা", "en": "Kajla"}
		"jatrabari":
			return {"bn": "যাত্রাবাড়ী", "en": "Jatrabari"}
	return {"bn": "মহল্লা", "en": "the neighbourhood"}
