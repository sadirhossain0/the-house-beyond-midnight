class_name Cast
## The cast: which model each character uses, how they move, how they glow, their outfits and bios.

const PLAYABLE := ["avery", "mara"]

## Wardrobe. `model` is the Blender-built glb in res://assets/models/chars/.
const COSTUMES := {
	"avery": {
		"fieldcoat": {"label": "Field Coat", "family": "Classic explorer", "unlock": "Starting outfit", "model": "avery_fieldcoat"},
		"shirtsleeves": {"label": "Shirtsleeves & Waistcoat", "family": "Classic explorer", "unlock": "Leave your coat with the Night Porter", "model": "avery_shirtsleeves"},
		"raincoat": {"label": "Storm Raincoat", "family": "Classic explorer", "unlock": "Search the boot of your car", "model": "avery_raincoat"},
		"lanternkeeper": {"label": "Lantern Keeper", "family": "Classic explorer", "unlock": "Reveal every hidden Ashcombe emblem", "model": "avery_lanternkeeper"},
		"masquerade": {"label": "Masquerade Attire", "family": "Estate formalwear", "unlock": "Settle the Forgotten Host", "model": "avery_masquerade"},
		"nightcap": {"label": "Oversized Nightcap", "family": "Comedic", "unlock": "Find out how comfortable the guest bed is", "model": "avery_nightcap"},
		"phantom": {"label": "Friendly Phantom Hood", "family": "Ghostly", "unlock": "Fill in every ghost card in the slice", "model": "avery_phantom", "glow": Color(0.6, 1.0, 0.92)},
		"stargazer": {"label": "Stargazer Coat", "family": "Adventure", "unlock": "Chapter 10: The Frozen Observatory", "locked": true},
		"carnival": {"label": "Carnival Performer", "family": "Adventure", "unlock": "Chapter 9: The Phantom Carnival", "locked": true},
	},
	"mara": {
		"performer": {"label": "Performer's Jacket", "family": "Classic", "unlock": "Starting outfit", "model": "mara_performer"},
		"gown": {"label": "Emerald Evening Gown", "family": "Estate formalwear", "unlock": "Free Mara from the Long Minute", "model": "mara_gown"},
		"masquerade": {"label": "Masquerade Mask", "family": "Estate formalwear", "unlock": "Settle the Forgotten Host as Mara", "model": "mara_masquerade"},
		"carnival": {"label": "Ringmaster Red", "family": "Adventure", "unlock": "Chapter 9: The Phantom Carnival", "locked": true},
	},
}

const DEFAULT_COSTUME := {"avery": "fieldcoat", "mara": "performer"}

## Non-wardrobe characters. `look`: "solid" (alive), "ghost" (glowing, translucent), "echo" (sepia memory).
const NPCS := {
	"porter": {"name": "The Night Porter", "model": "porter", "gait": "porter", "look": "ghost", "voice": "porter", "expr": "sad",
		"ghost": {"color": Color(0.56, 0.91, 0.82), "rim": Color(0.94, 1.0, 0.98), "opacity": 0.82, "keep": 0.5, "tail": true}},
	"pip": {"name": "Pip", "model": "pip", "gait": "pip", "look": "ghost", "voice": "pip", "expr": "curious",
		"ghost": {"color": Color(0.69, 1.0, 0.89), "rim": Color(1, 1, 1), "opacity": 0.8, "keep": 0.45, "tail": true}},
	"host": {"name": "The Forgotten Host", "model": "host", "gait": "host", "look": "ghost", "voice": "host", "expr": "smug",
		"ghost": {"color": Color(1.0, 0.69, 0.76), "rim": Color(1.0, 0.94, 0.96), "opacity": 0.88, "keep": 0.62, "wobble": 0.6}},
	"dancer_lady": {"name": "Masked Dancer", "model": "dancer_lady", "gait": "dancer", "look": "ghost", "voice": "dancer",
		"ghost": {"color": Color(0.78, 0.69, 1.0), "rim": Color(0.96, 0.93, 1.0), "opacity": 0.74, "keep": 0.4, "wobble": 0.3}},
	"dancer_gent": {"name": "Masked Dancer", "model": "dancer_gent", "gait": "dancer", "look": "ghost", "voice": "dancer",
		"ghost": {"color": Color(0.72, 0.69, 1.0), "rim": Color(0.96, 0.93, 1.0), "opacity": 0.74, "keep": 0.4, "wobble": 0.3}},
	"king": {"name": "The Masked King", "model": "king", "gait": "echo", "look": "echo"},
	"musician": {"name": "Musician", "model": "musician", "gait": "echo", "look": "echo"},
	"edmund": {"name": "Edmund Ashcombe", "model": "edmund", "gait": "echo", "look": "echo"},
	"margaret": {"name": "Margaret Ashcombe", "model": "margaret", "gait": "echo", "look": "echo"},
	"celeste": {"name": "Celeste Ashcombe", "model": "celeste", "gait": "echo", "look": "echo"},
	"youngest": {"name": "The Youngest", "model": "youngest", "gait": "echo", "look": "echo"},
	"theo": {"name": "Theo Finch", "model": "theo", "gait": "theo", "look": "solid", "voice": "theo"},
	"june": {"name": "June Calder", "model": "june", "gait": "june", "look": "solid", "voice": "june"},
	"mara_frozen": {"name": "Mara Bell", "model": "mara_performer", "gait": "mara", "look": "solid", "voice": "mara"},
}

const BIOS := {
	"avery": {"title": "Avery Wren", "role": "Building surveyor", "text": "Hired by the Hollins Trust to value Ashcombe House before demolition. Paces every room to measure it, then checks the tape anyway. Wears the wristwatch over the coat sleeve so it can be read without a fuss, keeps a pencil behind one ear and a folding rule in the breast pocket, and cut that fringe with kitchen scissors. Has never been late. Tonight they were exactly on time."},
	"mara": {"title": "Mara Bell", "role": "Performer", "text": "Came to Ashcombe to sing at a theatre revival that never happened, followed a waltz into the ballroom, and stopped halfway through a costume change, which is why only one sleeve is sequinned. Impossible to embarrass. Counts in threes when nervous: three bangles, three curls, three deep breaths."},
	"theo": {"title": "Theo Finch", "role": "Archive student", "text": "Missing. Last seen researching the Ashcombe family records. Somewhere in the Endless Library."},
	"june": {"title": "June Calder", "role": "Mechanic", "text": "Missing. Sent to fix the estate generator. Somewhere in the kitchen wing, by the sound of it."},
	"porter": {"title": "The Night Porter", "role": "Ghost, Chapter 1", "text": "Polite to a fault and stooped from leaning over a counter for sixty years. Still carries an empty coat hanger and the ticket for hook seven in his cap band. Hums the house theme slightly flat. Now runs the entrance hall and keeps the register that holds your place.", "observed": "Keeps drifting back to the empty hook marked 7."},
	"pip": {"title": "Pip", "role": "Ghost, page boy", "text": "The youngest of the household staff, in a cap two sizes too big. Snuffs candles when frightened, which is often, and carries the snuffer like a sword. Collects lost buttons and sews them onto his jacket wherever there's room.", "observed": "Hides behind curtains, peeks out when the lantern is lowered."},
	"host": {"title": "The Forgotten Host", "role": "Ghost, Chapter 2 encounter", "text": "Master of ceremonies at the last Ashcombe masquerade. The dance card tied to his wrist has not one name on it, and the carnation in his lapel gave up around 1891. He cannot leave before the last dance, and the band never finished the waltz.", "observed": "Hides in mirrors. Hums before he sweeps out. Cannot resist a correct count of three."},
	"dancers": {"title": "The Masked Dancers", "role": "Echoes of the sealed night", "text": "Guests from the masquerade, caught mid-twirl. They do not see you. One of them is holding something that does not belong to the music.", "observed": "Frozen in Then. In the encounter they waltz in wide loops: gaps open on the third beat."},
	"king": {"title": "The Masked King", "role": "???", "text": "A figure in a crown and a white mask, seen only in echoes. Walks toward the ballroom at 11:59. Never looks back.", "observed": "Seen through the Midnight Watch at the Grand Clock."},
}

static func costume(char_id: String, costume_id: String) -> Dictionary:
	var set_: Dictionary = COSTUMES.get(char_id, {})
	var c: Dictionary = set_.get(costume_id, {})
	if c.is_empty() or c.get("locked", false): c = set_.get(DEFAULT_COSTUME.get(char_id, ""), {})
	return c

static func model_path(model: String) -> String:
	return "res://assets/models/chars/%s.glb" % model
