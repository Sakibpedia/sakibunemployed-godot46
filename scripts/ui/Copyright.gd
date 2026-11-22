extends Control
## Copyright screen. Text is embedded so it ships in every export.

const TEXT := """[center][font_size=36]© ২০২৬ এস এম নাজমুয সাকিব। সর্বস্বত্ব সংরক্ষিত।[/font_size][/center]

"এস এম নাজমুয সাকিব বেকার" গেমটির নকশা, গল্প, চরিত্র, শিল্পকর্ম এবং এর জন্য লেখা সমস্ত কোড এস এম নাজমুয সাকিবের সম্পত্তি। তার লিখিত অনুমতি ছাড়া কোনো অংশ কপি, বিতরণ বা পরিবর্তন করা যাবে না।

তৃতীয় পক্ষের সফটওয়্যার ও ফন্ট নিজ নিজ লাইসেন্সে ব্যবহৃত, যা ক্রেডিটে তালিকাভুক্ত; সেই অংশগুলোর ক্ষেত্রে এই নোটিশ নয়, ওই লাইসেন্সগুলোই প্রযোজ্য।

এটি একটি কাল্পনিক কাহিনি। শর্টকাট কোচিং, শাহজাহান, বুলু ভাই এবং অন্য সব চরিত্র, ব্যবসা ও সংগঠন কাল্পনিক; বাস্তব কারো সঙ্গে মিল কাকতালীয়। বাস্তব রাস্তা ও প্রতিষ্ঠান শুধু স্থান হিসেবে এসেছে; কোনো বাস্তব প্রতিষ্ঠানকে অন্যায়ে জড়িত দেখানো হয়নি।

১৭৩টি প্রশ্ন সরকারি পরীক্ষার প্রকাশিত প্রশ্নপত্র থেকে ভাবার্থে নেওয়া, শুধু পড়া ও খেলার জন্য; মূল প্রশ্নপত্রের মালিক সংশ্লিষ্ট কর্তৃপক্ষ, যারা এই গেমটি অনুমোদন করেনি। বাকি ২,৫০০+ প্রশ্ন এই গেমের জন্য লেখা অনুশীলনী প্রশ্ন। পরীক্ষার আগে সরকারি উৎস থেকে তথ্য যাচাই করুন।

এই গেমের কিছুই আইনি পরামর্শ নয়; বার কাউন্সিলের অংশ শুধু অনুশীলনের জন্য।

[font_size=18]© 2026 S M Nazmuz Sakib. All rights reserved. "S M Nazmuz Sakib is unemployed", its design, story, characters, artwork and code belong to S M Nazmuz Sakib; no part may be copied, distributed or modified without his written permission. Third-party components are under their own licences (see Credits). A work of fiction: every character, business and organisation is invented. 173 questions are paraphrased from public exam papers (their issuing bodies have not endorsed this game); the other 2,500+ are original practice questions. Nothing here is legal advice.[/font_size]
"""


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.theme()
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.07, 0.08)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 160
	box.offset_right = -160
	box.offset_top = 60
	box.offset_bottom = -40
	add_child(box)
	var logo := TextureRect.new()
	logo.texture = load("res://art/logo.png")
	logo.custom_minimum_size = Vector2(0, 150)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	box.add_child(logo)
	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override(&"normal_font_size", 20)
	text.text = TEXT
	box.add_child(text)
	var back := Button.new()
	back.text = "ফিরে যাও"
	back.custom_minimum_size = Vector2(200, 44)
	back.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	box.add_child(back)
