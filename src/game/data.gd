class_name GameData
## All authored content for the vertical slice: objectives and their graduated hints, clues,
## deductions, documents, collectibles, ghost cards, achievements, costumes and cheat codes.
## The sealed night is New Year's Eve, 1891. The year never ended.

const OBJECTIVES := {
	"pro_arrive": {"text": "Go up to the front door of Ashcombe House.", "chapter": 0,
		"hints": ["The house is the large, lit building at the end of the drive. You can't miss it, though you could try.",
			"Follow the gravel drive past the fountain to the porch steps.",
			"Walk to the front door at the top of the porch steps. It will do the rest."]},
	"ch1_look": {"text": "Look around the entrance hall. Something about the clocks.", "chapter": 1,
		"hints": ["Listen. The hall should be full of ticking. It isn't.",
			"Inspect the clocks: the Grand Clock on the landing, the mantel clock over the hearth, the wall clock by the desk.",
			"Inspect three clocks (any of the Grand Clock, the mantel clock, the wall clock near the desk, or the clock in the guest wing). They all say the same thing."]},
	"ch1_lantern": {"text": "Take the lantern from the table near the stairs.", "chapter": 1,
		"hints": ["There's a light in the hall that nobody lit.",
			"A small round table near the bottom of the staircase has a lantern on it.",
			"Walk to the round table left of the stairs and interact with the lantern."]},
	"ch1_corridor": {"text": "Follow the lantern's flame.", "chapter": 1,
		"hints": ["Watch the lantern's flame. It leans toward anything supernatural.",
			"The flame leans toward the west door, into the guest wing. Raise the lantern in the dark corridor.",
			"Hold the Use button to raise the lantern, and sweep it along the north wall of the corridor near the far end. A doorway is hiding there."]},
	"ch1_porter": {"text": "Find out what the Night Porter wants.", "chapter": 1,
		"hints": ["He's polite, he's confused, and he keeps doing the same thing. Watch what he does.",
			"Focus on the Porter for a few seconds to observe him. Notice where he keeps drifting.",
			"He keeps returning to the empty hook marked 7. Hang your coat on hook 7."]},
	"ch1_relight": {"text": "Relight your composure at the tea trolley.", "chapter": 1, "optional": true,
		"hints": ["Something calming would help.", "There's a tea trolley at the west end of the corridor.", "Interact with the tea set on the trolley to relight your candles."]},
	"ch1_return": {"text": "Go back to the entrance hall.", "chapter": 1,
		"hints": ["The Porter has gone back to his old post.", "Return to the entrance hall through the guest wing.", "Walk east along the corridor and through the door into the hall. The Porter is at the reception desk."]},
	"ch1_watch": {"text": "Use the Midnight Watch at the Grand Clock.", "chapter": 1,
		"hints": ["The Porter's gift is a pocket watch stopped at 11:59. Clocks remember things.",
			"Climb the staircase to the Grand Clock on the landing.",
			"Select the Midnight Watch (press 2, or use the equipment wheel) and use it in front of the Grand Clock."]},
	"ch1_deduce": {"text": "Make a deduction in your Field Journal.", "chapter": 1,
		"hints": ["You have two facts about time. Put them together.",
			"Open the Field Journal and look at your clues about the clocks and the guest register.",
			"In the Journal's Deductions page, link 'Every clock says 11:59' with 'The register stops at 11:58'."]},
	"ch2_enter": {"text": "Enter the Grand Ballroom.", "chapter": 2,
		"hints": ["The chains on the east doors are gone.", "The ballroom is through the double doors on the east side of the hall.", "Walk through the east double doors."]},
	"ch2_anchor": {"text": "Find the ballroom's anchor clock and shift to the sealed night.", "chapter": 2,
		"hints": ["One clock in here isn't stopped. It's holding its breath.",
			"Look for a gilded pedestal clock glowing green near the ballroom entrance.",
			"Stand at the green-glowing anchor clock, select the Midnight Watch and use it to shift the room to Then."]},
	"ch2_listen": {"text": "Find out what's wrong with the waltz.", "chapter": 2,
		"hints": ["Count along with the music.", "Stand near the musicians' stage and listen to a full phrase.", "Go up onto the stage and inspect the music stands."]},
	"ch2_fragments": {"text": "Find the three missing sheets of music.", "chapter": 2, "counter": "fragments",
		"hints": ["Three torn sheets: one in the present, one on the sealed night, one hidden in both.",
			"Try the broken piano in Now, the dancers in Then, and the painted folding screen near the stage.",
			"Moon sheet: on the piano (Now). Star sheet: held by a masked dancer near the floor's west side (Then). Sun sheet: push the folding screen aside in Then; it stays moved in Now."]},
	"ch2_order": {"text": "Recall where each musician stood.", "chapter": 2,
		"hints": ["The stands remember who played what.", "Use the Midnight Watch on the stage to see an echo of the band.", "Stand on the stage, select the Watch and use it. Watch which sheet each musician plays."]},
	"ch2_place": {"text": "Put each sheet on its musician's stand.", "chapter": 2,
		"hints": ["Match the symbol on each sheet to the musician who played it.",
			"The violin, cello and flute stands are carved with their instruments. Your echo showed who held which sheet.",
			"Violin (left) gets the Moon, cello (middle) gets the Star, flute (right) gets the Sun."]},
	"ch2_marks": {"text": "Reveal the hidden timing marks with the lantern.", "chapter": 2,
		"hints": ["The notes are right, but something is still missing from the page.", "Raise the lantern over each stand.", "Hold Use with the lantern selected while facing each of the three stands until the marks glow."]},
	"ch2_host": {"text": "Settle the Forgotten Host.", "chapter": 2,
		"hints": ["He's proud, he's lonely and he cannot leave before the last dance.",
			"Hit the mirror he's hiding in with a lantern flare. Then set the chairs on the glowing stars. Then dance.",
			"Phase 1: flare (F / X / □) the mirror that frosts over. Phase 2: push three chairs onto the stars while avoiding the dancers. Phase 3: press Interact on each beat '1'."]},
	"ch2_balcony": {"text": "Step out onto the balcony.", "chapter": 2,
		"hints": ["The Host gave you a key.", "The balcony door is the tall mirror in the middle of the north wall.", "Walk through the mirror-door on the north wall and interact with the figure on the balcony."]},
	"ch2_return": {"text": "Return to the Grand Clock.", "chapter": 2,
		"hints": ["Two chimes down, ten to go.", "The Grand Clock is on the hall's landing.", "Go back to the entrance hall and walk up to the Grand Clock."]},
	"slice_end": {"text": "Explore the estate freely. Ten chimes remain.", "chapter": 2,
		"hints": ["You've finished the vertical slice. Hunt for collectibles, try the costumes and the Paranormal Extras.",
			"Check the Collection page to see what you're missing.", "The map marks rooms that still have secrets."]},
}

const OBJECTIVE_ORDER := ["pro_arrive", "ch1_look", "ch1_lantern", "ch1_corridor", "ch1_porter", "ch1_return", "ch1_watch", "ch1_deduce",
	"ch2_enter", "ch2_anchor", "ch2_listen", "ch2_fragments", "ch2_order", "ch2_place", "ch2_marks", "ch2_host", "ch2_balcony", "ch2_return", "slice_end"]

const CLUES := {
	"c_clocks": {"title": "Every clock says 11:59", "text": "The Grand Clock, the mantel clock, the wall clock: all stopped at one minute to midnight. The Grand Clock's pendulum trembles as if it wants to swing.", "icon": "clock"},
	"c_register": {"title": "The register stops at 11:58", "text": "Guests of the Masquerade, 31st December 1891. The last name is signed at 11:58. The ink is still wet.", "icon": "book"},
	"c_coats": {"title": "Hook number seven", "text": "The Night Porter kept every guest's coat. Hook seven was empty for sixty years until I hung mine there.", "icon": "hook"},
	"c_king": {"title": "A king walked to the ballroom", "text": "Through the Midnight Watch: a figure in a crown and a white mask crossing the hall at 11:59. 'One more minute.'", "icon": "crown"},
	"c_master": {"title": "The master kept his coat on", "text": "The Porter: 'He never took his coat off. Said he'd be leaving at midnight.'", "icon": "coat"},
	"c_invite": {"title": "A New Year's masquerade", "text": "An invitation to the Ashcombe New Year's Eve Masquerade, 1891: 'Dancing until midnight. Carriages at one.'", "icon": "mask"},
	"c_host": {"title": "The host is waiting for the last dance", "text": "A ghost in a burgundy tailcoat is waiting in the ballroom. He can't leave before the last dance.", "icon": "mask"},
	"c_waltz": {"title": "The waltz loses a beat", "text": "In the fourth bar, the third beat never comes. Every time.", "icon": "note"},
	"c_sale": {"title": "The house was to be sold", "text": "Hollins & Vane would take the house at nine o'clock on the morning of 1st January 1892.", "icon": "letter"},
	"c_menu": {"title": "A 'final night' menu", "text": "The chef's menu for the masquerade is headed 'For our last night at Ashcombe'.", "icon": "letter"},
	"c_fire": {"title": "A newspaper says the house burned", "text": "A torn page from 1892: ASHCOMBE HOUSE LOST TO FIRE? The house is plainly not burned.", "icon": "letter"},
	"c_memory": {"title": "One more minute", "text": "A memory the Host found in his pocket: a man's voice, very close. 'One more minute, Margaret. Just give me one more minute.'", "icon": "crown"},
}

const DEDUCTIONS := {
	"d_minute": {"a": "c_clocks", "b": "c_register", "required": true, "title": "It happened in the last minute of the year",
		"text": "Everyone signed in by 11:58. Every clock stopped at 11:59. Whatever happened at Ashcombe, it happened in that one minute.",
		"line": "Everyone signed in by 11:58. Then every clock stopped at 11:59. Whatever happened here, it happened in that minute."},
	"d_party": {"a": "c_invite", "b": "c_host", "title": "The masquerade never ended",
		"text": "Dancing until midnight. Midnight never came. The party is still on, and the host still can't leave.",
		"line": "Dancing until midnight, carriages at one. If midnight never comes, nobody goes home."},
	"d_losing": {"a": "c_sale", "b": "c_menu", "title": "The family was losing the house",
		"text": "The sale would complete the next morning. The masquerade was a farewell.",
		"line": "A last-night menu, and a sale at nine the next morning. This wasn't a party. It was a goodbye."},
	"d_king": {"a": "c_king", "b": "c_master", "title": "The King may be the master of the house",
		"text": "The master never took off his coat, meaning to leave at midnight. The crowned figure walked to the ballroom at 11:59.",
		"line": "A man who planned to leave at midnight, and a king walking to the ballroom one minute before. I think they're the same man."},
}

const DOCUMENTS := {
	"doc_sale": {"title": "Final Notice of Sale", "text": "To Mr Edmund Ashcombe, Ashcombe House.\n\nSir,\n\nNotice is hereby given that Ashcombe House, together with its grounds, outbuildings and contents, will pass into the possession of Messrs Hollins & Vane at nine o'clock on the morning of the first of January, 1892, in full settlement of the debts outstanding.\n\nWe trust the family will have vacated by that hour.\n\nHollins & Vane, Solicitors", "clue": "c_sale"},
	"doc_survey": {"title": "Survey Assignment", "text": "HOLLINS TRUST — PROPERTY DIVISION\n\nSurveyor: A. Wren\nProperty: Ashcombe House (vacant)\nPurpose: condition survey prior to demolition\n\nAttend at 23:59 exactly. Do not be early. Do not be late.\n\nThe front door will be open.\n\nM. Hollins", "clue": ""},
	"doc_register": {"title": "The Guest Register", "text": "GUESTS OF THE MASQUERADE — 31st December 1891\n\nLady Pemberton & party .... 9.12\nMr & Mrs Albright .... 9.40\nThe Misses Crane .... 10.05\nCapt. H. Lowther .... 10.31\n...\nMr D. Okafor .... 11.47\nMiss E. Marsh .... 11.58\n\n(The last line is still wet.)", "clue": "c_register"},
	"doc_invitation": {"title": "Masquerade Invitation", "text": "Mr and Mrs Edmund Ashcombe request the pleasure of your company at a\n\nNEW YEAR'S EVE MASQUERADE\n\nAshcombe House, the 31st of December, 1891\n\nDancing until midnight. Carriages at one.\nMasks will be worn.", "clue": "c_invite"},
	"doc_menu": {"title": "The Chef's Menu", "text": "FOR OUR LAST NIGHT AT ASHCOMBE\n\nClear turtle soup\nSole in champagne\nRoast pheasant, bread sauce\nIced Nesselrode pudding\nThe New Year cake (to be cut at midnight)\n\nThe staff are thanked for their service and released at dawn. — A. Boilleau, Chef", "clue": "c_menu"},
	"doc_newspaper": {"title": "Torn Newspaper, 1892", "text": "...ASHCOMBE HOUSE LOST TO FIRE?\n\nNeighbours report a great light at the house in the last minutes of the old year. By morning the house stood untouched, and empty. Of the family and their guests there is as yet no...\n\n(The rest is torn away.)", "clue": "c_fire"},
	"doc_letter": {"title": "A Letter on the Balcony", "text": "Margaret,\n\nI know what Celeste says. I know what it will cost. But they cannot have the house if the morning never comes, and the morning cannot come if the minute does not end.\n\nOne more minute. That is all I am asking for.\n\nE.", "clue": ""},
}

const COLLECTIBLES := {
	# documents
	"doc_sale": {"kind": "document", "name": "Final Notice of Sale", "room": "exterior"},
	"doc_survey": {"kind": "document", "name": "Survey Assignment", "room": "exterior"},
	"doc_register": {"kind": "document", "name": "The Guest Register", "room": "hall"},
	"doc_invitation": {"kind": "document", "name": "Masquerade Invitation", "room": "guestroom"},
	"doc_menu": {"kind": "document", "name": "The Chef's Menu", "room": "ballroom"},
	"doc_newspaper": {"kind": "document", "name": "Torn Newspaper, 1892", "room": "ballroom"},
	"doc_letter": {"kind": "document", "name": "A Letter on the Balcony", "room": "balcony"},
	# portrait fragments
	"pf_gallery": {"kind": "portrait", "name": "Portrait Fragment: a child's hand", "room": "hall"},
	"pf_guest": {"kind": "portrait", "name": "Portrait Fragment: a lace collar", "room": "guestroom"},
	"pf_balcony": {"kind": "portrait", "name": "Portrait Fragment: a crown", "room": "balcony"},
	# music records
	"rec_hall": {"kind": "record", "name": "Record: The Entrance Hall", "room": "hall", "track": "hall"},
	"rec_waltz": {"kind": "record", "name": "Record: The Last Waltz", "room": "ballroom", "track": "lastdance"},
	"rec_porter": {"kind": "record", "name": "Record: The Long Minute", "room": "cloakroom", "track": "title"},
	# treasures
	"tr_snuffbox": {"kind": "treasure", "name": "Silver Snuffbox", "room": "hall", "text": "Engraved 'E.A. 1871'. Empty, apart from a single pressed violet."},
	"tr_compass": {"kind": "treasure", "name": "Brass Pocket Compass", "room": "exterior", "text": "Found in your own glovebox. It points at the house, wherever you stand."},
	"tr_cat": {"kind": "treasure", "name": "Porcelain Cat", "room": "cloakroom", "text": "Left on a hat shelf. It has a chipped ear and a very smug face."},
	"tr_mask": {"kind": "treasure", "name": "Jewelled Half-Mask", "room": "ballroom", "text": "Garnets and gold leaf. Someone left the party in a hurry, or didn't leave at all."},
	# hidden Ashcombe emblems (lantern reveals)
	"em_corridor": {"kind": "emblem", "name": "Hidden Emblem: the Guest Wing", "room": "corridor"},
	"em_hall": {"kind": "emblem", "name": "Hidden Emblem: the Gallery", "room": "hall"},
	"em_ballroom": {"kind": "emblem", "name": "Hidden Emblem: the Ballroom", "room": "ballroom"},
}

const GHOST_CARDS := ["porter", "pip", "host", "dancers"]

const ACHIEVEMENTS := {
	"fashionably_late": {"name": "Fashionably Late", "desc": "Arrive at Ashcombe House at exactly 11:59."},
	"lights_please": {"name": "Lights, Please", "desc": "Take the Gloam Lantern."},
	"coat_check": {"name": "Coat Check", "desc": "Settle the Night Porter."},
	"tea_and_sympathy": {"name": "Tea and Sympathy", "desc": "Relight a candle at a tea set."},
	"its_about_time": {"name": "It's About Time", "desc": "Make your first deduction."},
	"then_and_now": {"name": "Then and Now", "desc": "Shift a room to the sealed night."},
	"let_them_eat_cake": {"name": "Let Them Eat Cake", "desc": "Try the cake on the sealed night, then come back for seconds."},
	"perfect_pitch": {"name": "Perfect Pitch", "desc": "Complete the waltz without placing a sheet on the wrong stand."},
	"last_dance": {"name": "The Last Dance", "desc": "Settle the Forgotten Host."},
	"unflappable": {"name": "Unflappable", "desc": "Settle the Forgotten Host without losing a candle."},
	"sleepyhead": {"name": "Sleepyhead", "desc": "Discover how comfortable the guest bed is."},
	"lantern_keeper": {"name": "Lantern Keeper", "desc": "Reveal every hidden Ashcombe emblem."},
	"curiosity": {"name": "Curiosity Rewarded", "desc": "Find every collectible in the vertical slice."},
	"deductive": {"name": "Deductive Reasoning", "desc": "Make every deduction in the vertical slice."},
	"two_chimes": {"name": "Two Chimes", "desc": "Strike the Grand Clock's second chime."},
	"duet": {"name": "Duet", "desc": "Free Mara Bell from the Long Minute."},
}

const CHEAT_CODES := {
	"COOLSPIRITS": {"key": "sunglasses", "name": "Ghost Sunglasses"},
	"BIGTHINKER": {"key": "big_head", "name": "Big-Head Mode"},
	"BOOGIEWOOGIE": {"key": "disco", "name": "Disco Mansion"},
	"TINYTERROR": {"key": "tiny", "name": "Tiny Investigator"},
	"LONGMINUTE": {"key": "all_costumes", "name": "Every costume (cosmetic)"},
}

const CHEATS := [
	{"key": "slowmo", "group": "Experimental gameplay", "name": "Slow motion", "desc": "Everything runs at half speed, including ghosts and timers.", "experimental": true},
	{"key": "low_gravity", "group": "Experimental gameplay", "name": "Low gravity", "desc": "Dodges become long, floaty hops. Fall damage is still possible.", "experimental": true},
	{"key": "ghost_vision", "group": "Experimental gameplay", "name": "Ghost vision", "desc": "See ghosts and hidden traces through walls. Spoils some secrets.", "experimental": true},
	{"key": "extra_treasure", "group": "Experimental gameplay", "name": "Extra treasure", "desc": "Treasures and emblems sparkle from much further away.", "experimental": true},
	{"key": "unlocked_doors", "group": "Experimental gameplay", "name": "Unlocked doors", "desc": "Locked doors in rooms you have finished open freely.", "experimental": true},
	{"key": "fleet_feet", "group": "Experimental gameplay", "name": "Fleet feet", "desc": "Move half again as fast.", "experimental": true},
	{"key": "tiny", "group": "Cosmetic fun", "name": "Tiny investigator", "desc": "Half-size you. Ghosts are unimpressed.", "code": "TINYTERROR"},
	{"key": "big_head", "group": "Cosmetic fun", "name": "Big-head mode", "desc": "For thinking bigger thoughts.", "code": "BIGTHINKER"},
	{"key": "sunglasses", "group": "Cosmetic fun", "name": "Ghost sunglasses", "desc": "Every ghost gets shades.", "code": "COOLSPIRITS"},
	{"key": "disco", "group": "Cosmetic fun", "name": "Disco mansion", "desc": "Candles and chandeliers cycle colours. Ghosts approve.", "code": "BOOGIEWOOGIE"},
	{"key": "party_decor", "group": "Cosmetic fun", "name": "Party decorations", "desc": "Streamers and party hats in every room."},
	{"key": "ghost_costumes", "group": "Cosmetic fun", "name": "Alternate ghost costumes", "desc": "Ghosts wear party hats."},
	{"key": "filter", "group": "Visual filters", "name": "Filter", "type": "select", "options": [["none", "None"], ["retro", "Retro film"], ["mono", "Monochrome mystery"], ["vhs", "Soft VHS"]], "desc": "A look for the whole screen."},
	{"key": "silly_sfx", "group": "Audio fun", "name": "Silly sound effects", "desc": "Everything sounds slightly ridiculous."},
	{"key": "squeaky_steps", "group": "Audio fun", "name": "Squeaky footsteps", "desc": "Your shoes have opinions."},
	{"key": "playful_voices", "group": "Audio fun", "name": "Playful voices", "desc": "Everyone has had some helium."},
]

const TIPS := [
	"Your lantern's flame leans toward anything supernatural. When you're lost, watch the flame.",
	"Focus on a ghost for a few seconds to Observe it. Observations go in the Field Journal and often point to the solution.",
	"A change made on the sealed night carries into the present only if it would have survived the years. A moved screen stays moved. Cake does not.",
	"Tea sets relight your composure candles. Fainting costs you nothing but a short walk.",
	"Press H for a hint. The first hint only tells you what to notice; the solution is always the third.",
	"Link two clues in the Field Journal to make a deduction. Wrong pairs cost nothing.",
	"Anchor clocks glow green. Only there can the Midnight Watch shift a room between Now and Then.",
	"The Night Porter keeps the guest register at the hall desk. Sign it to save.",
	"A Midnight Code is a short password for your progress. Write it down and you can never lose your place.",
	"Ghosts aren't destroyed in this house. They're settled. Ask what they need.",
	"Assistance options never affect achievements. Cheats in Paranormal Extras are marked if they do.",
	"Wardrobe outfits never change what you can do, only how splendid you look doing it.",
]

const LORE := [
	"From the Ashcombe archive: 'The Grand Clock was built in 1871 with twelve chime lamps, one for each hour, and a mechanism Edmund refused to let the clockmaker see.'",
	"From the Ashcombe archive: 'Celeste Ashcombe charted the winter sky from the observatory dome. She drew one constellation no astronomer has found since.'",
	"From the Ashcombe archive: 'Staff were dismissed on the 31st December 1891, to leave at dawn. None are recorded as having left.'",
	"From the Ashcombe archive: 'The ballroom floor is sprung on horsehair and iron. It was said you could feel the waltz through your shoes from the hall.'",
	"From the Ashcombe archive: 'The youngest Ashcombe child is missing from every family portrait painted after midnight, 1891.'",
	"From a guest's diary: 'Mr Ashcombe wore a crown all evening and would not say why. Mrs Ashcombe did not laugh at it, which was strange.'",
]

const LOADING_LINES := {
	"textures": ["Hanging the wallpaper", "Polishing the marble", "Beating the rugs", "Waxing the parquet"],
	"world": ["Laying out the estate", "Building the imperial staircase", "Hanging the chandeliers", "Winding every clock to 11:59"],
	"characters": ["Waking the Night Porter", "Pressing the Host's tailcoat", "Counting the dancers", "Finding Pip (behind a curtain)"],
	"lighting": ["Lighting the candles", "Raising the moon", "Drawing the curtains back", "Dusting the moonbeams"],
	"shaders": ["Teaching the lantern to see", "Tuning the Midnight Watch", "Frosting the mirrors"],
}

## Fixed-order registry for Midnight Codes. Append only: never reorder or remove.
const CODE_REGISTRY := {
	"version": 1,
	"flags": ["intro_done", "entered_house", "clue_clocks", "has_lantern", "hidden_door", "porter_met", "porter_observed", "porter_resolved",
		"pip_met", "relit", "porter_at_desk", "has_watch", "echo_king", "chime1", "ballroom_open", "ballroom_entered", "first_shift",
		"waltz_heard", "frag_moon", "frag_star", "frag_sun", "screen_moved", "echo_band", "placed_violin", "placed_cello", "placed_flute",
		"marks_1", "marks_2", "marks_3", "waltz_complete", "host_met", "host_resolved", "balcony_open", "mara_freed", "chime2", "slice_done",
		"nightcap_secret", "cake_then", "cake_now", "car_boot", "wardrobe_open", "glovebox"],
	"clues": ["c_clocks", "c_register", "c_coats", "c_king", "c_master", "c_invite", "c_host", "c_waltz", "c_sale", "c_menu", "c_fire", "c_memory"],
	"deductions": ["d_minute", "d_party", "d_losing", "d_king"],
	"collectibles": ["doc_sale", "doc_survey", "doc_register", "doc_invitation", "doc_menu", "doc_newspaper", "doc_letter", "pf_gallery", "pf_guest", "pf_balcony",
		"rec_hall", "rec_waltz", "rec_porter", "tr_snuffbox", "tr_compass", "tr_cat", "tr_mask", "em_corridor", "em_hall", "em_ballroom"],
	"costumes": ["avery:shirtsleeves", "avery:raincoat", "avery:lanternkeeper", "avery:masquerade", "avery:nightcap", "avery:phantom", "mara:gown", "mara:masquerade"],
	"characters": ["avery", "mara"],
}
