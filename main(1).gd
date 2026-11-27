extends Node2D
## SKY HOP
## Game pantul vertikal bergaya gambar tangan untuk Godot 4.2+.
## Semua gambar, suara, dan musik dibuat lewat kode, jadi tidak butuh file aset.
##
## Layar penuh: kolom permainan selalu 480 piksel lebar di tengah. Sisa layar di kiri
## dan kanan diisi pemandangan dan kartu info (aktif otomatis di layar lebar).
##
## Isi: 5 zona ketinggian, 5 jenis platform, 3 power-up, 4 jenis musuh, 4 skin
## yang terbuka lewat skor, dan 2 trek musik.

const W := 480.0
const R := 18.0
const GRAV := 1500.0
const JUMP_V := 720.0
const SPRING_V := 1080.0
const BOUNCE_BACK_V := 1500.0
const GROUND_Y := 720.0
const MAX_LIVES := 3
const PROP_TIME := 3.2
const MAGNET_TIME := 9.0

const ZONE_KEYS := [0.0, 150.0, 400.0, 700.0, 1000.0]
const ZONE_NAMES := ["PADANG HIJAU", "LANGIT PAGI", "SENJA", "MALAM BERBINTANG", "LUAR ANGKASA"]
const ZONE_SHORT := ["Padang", "Pagi", "Senja", "Malam", "Angkasa"]

const INK := Color(0.17, 0.13, 0.25)
const PAPER := Color(1.0, 0.96, 0.86)
const REG := Vector2(2.2, 1.6)

var state := "title"
var paused := false
var time := 0.0
var boil := 0
var font: Font
var vw := 480.0
var vh := 800.0
var ox := 0.0

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var squash := 0.0
var invuln := 0.0
var combo := 0
var lives := MAX_LIVES
var coins := 0
var bonus := 0
var stomps := 0
var best := 0
var new_record := false
var unlocked_msg := ""
var skin := 0
var prop_t := 0.0
var magnet_t := 0.0
var shield := false

var cam_y := 0.0
var top_y := 0.0
var gen_y := 0.0
var last_type := "normal"
var next_mile := 1
var cur_zone := 0
var banner_t := 0.0
var banner_text := ""
var banner_sub := ""
var shake := 0.0
var shake_off := Vector2.ZERO
var hitstop := 0.0
var net_t := 0.0
var over_t := 0.0
var music_on := true
var music_track := 0

var platforms: Array = []
var flyers: Array = []
var particles: Array = []
var popups: Array = []
var clouds: Array = []
var grain: Array = []
var players: Array = []
var tracks: Array = []
var sfx_bank := {}
var music: AudioStreamPlayer

var sky_top: Array = [Color(0.45, 0.78, 0.96), Color(0.36, 0.64, 0.95), Color(0.82, 0.5, 0.58), Color(0.14, 0.12, 0.36), Color(0.05, 0.04, 0.14)]
var sky_bot: Array = [Color(1.0, 0.93, 0.8), Color(0.85, 0.95, 1.0), Color(1.0, 0.78, 0.5), Color(0.38, 0.28, 0.6), Color(0.16, 0.1, 0.34)]
var skins: Array = [
	{"name": "Jeruk", "c": Color(1.0, 0.52, 0.35), "l": Color(1.0, 0.76, 0.58), "need": 0},
	{"name": "Blueberry", "c": Color(0.4, 0.55, 0.95), "l": Color(0.72, 0.82, 1.0), "need": 300},
	{"name": "Melon", "c": Color(0.45, 0.8, 0.42), "l": Color(0.8, 0.96, 0.66), "need": 800},
	{"name": "Permen", "c": Color(1.0, 0.5, 0.74), "l": Color(1.0, 0.82, 0.92), "need": 1500},
]


# ================================================================ setup

func _ready() -> void:
	randomize()
	font = ThemeDB.fallback_font
	# Mau font sendiri? Taruh TTF di res://fonts/main.ttf, otomatis dipakai.
	if ResourceLoader.exists("res://fonts/main.ttf"):
		var custom := load("res://fonts/main.ttf") as Font
		if custom != null:
			font = custom
	load_save()
	for i in range(14):
		clouds.append({
			"x": randf() * W,
			"y": randf() * 1100.0,
			"s": randf_range(0.7, 1.5),
			"f": randf_range(0.15, 0.4),
		})
	for i in range(260):
		grain.append(Vector2(randf(), randf()))
	for i in range(8):
		var pl := AudioStreamPlayer.new()
		pl.volume_db = -6.0
		add_child(pl)
		players.append(pl)
	build_sfx()
	tracks = [build_music(0), build_music(1)]
	music = AudioStreamPlayer.new()
	music.stream = tracks[0]
	music.volume_db = -15.0
	add_child(music)
	music.play()
	reset_world()
	state = "title"


func reset_world() -> void:
	platforms.clear()
	flyers.clear()
	particles.clear()
	popups.clear()
	cam_y = 0.0
	pos = Vector2(W * 0.5, GROUND_Y - R)
	vel = Vector2(0.0, -JUMP_V)
	top_y = pos.y
	gen_y = GROUND_Y
	last_type = "normal"
	lives = MAX_LIVES
	coins = 0
	bonus = 0
	stomps = 0
	combo = 0
	invuln = 0.0
	squash = 0.0
	shake = 0.0
	net_t = 0.0
	hitstop = 0.0
	prop_t = 0.0
	magnet_t = 0.0
	shield = false
	new_record = false
	unlocked_msg = ""
	next_mile = 1
	cur_zone = 0
	banner_t = 0.0
	platforms.append(make_platform(-20.0, GROUND_Y, W + 40.0, "ground", 0))
	generate()


func start_game() -> void:
	paused = false
	reset_world()
	state = "play"
	set_track(0)
	banner_text = ZONE_NAMES[0]
	banner_sub = "ZONA 1"
	banner_t = 2.2
	play_sfx("bounce")


func make_platform(x: float, y: float, w: float, type: String, z: int) -> Dictionary:
	return {
		"x": x, "y": y, "y0": y, "w": w, "type": type, "z": z,
		"vx": 0.0, "ph": randf() * 6.28, "bt": randf() * 2.6,
		"crumble": -1.0, "fall_v": 0.0, "broken": false,
		"spring": false, "spring_t": 0.0,
		"coin": false, "heart": false, "taken": false, "power": "",
		"enemy": false, "en_x": 0.0, "en_dir": 1.0, "en_alive": true,
	}


func zone_of(hm: float) -> int:
	var z := 0
	for i in range(ZONE_KEYS.size()):
		if hm >= float(ZONE_KEYS[i]):
			z = i
	return z


func zone_f(hm: float) -> float:
	var z: int = zone_of(hm)
	if z >= ZONE_KEYS.size() - 1:
		return float(z)
	var a: float = float(ZONE_KEYS[z])
	var b: float = float(ZONE_KEYS[z + 1])
	return float(z) + clampf((hm - a) / (b - a), 0.0, 1.0)


func generate() -> void:
	while gen_y > cam_y - 300.0:
		var hm: float = maxf(0.0, (GROUND_Y - gen_y) / 10.0)
		var diff: float = clampf(hm / 700.0, 0.0, 1.0)
		var z: int = zone_of(hm)
		var r: float = randf()
		var kind := "normal"
		var soft: bool = last_type == "crumble" or last_type == "blink"
		if hm > 40.0 and r < 0.10 + diff * 0.12:
			kind = "move"
		elif hm > 120.0 and r < 0.20 + diff * 0.08:
			kind = "bob"
		elif hm > 25.0 and r < 0.30 + diff * 0.08 and not soft:
			kind = "crumble"
		elif hm > 300.0 and r < 0.40 + diff * 0.06 and not soft:
			kind = "blink"
		var gmax: float = lerpf(110.0, 150.0, diff)
		if kind == "bob" or last_type == "bob":
			gmax = minf(gmax, 105.0)
		gen_y -= randf_range(70.0, gmax)
		last_type = kind
		var w: float = randf_range(lerpf(120.0, 82.0, diff), lerpf(150.0, 108.0, diff))
		var x: float = randf_range(10.0, W - w - 10.0)
		var p := make_platform(x, gen_y, w, kind, z)
		if kind == "move":
			p["vx"] = randf_range(55.0, 105.0) * (1.0 if randf() < 0.5 else -1.0)
		var solid_ok: bool = kind != "crumble" and kind != "blink"
		if solid_ok and randf() < 0.09:
			p["spring"] = true
		elif randf() < 0.45:
			p["coin"] = true
			if randf() < 0.05:
				p["heart"] = true
				p["coin"] = false
		if solid_ok and not p["spring"] and not p["heart"] and randf() < 0.055:
			var pw: Array = ["prop", "shield", "magnet"]
			p["power"] = pw[randi() % 3]
			p["coin"] = false
		if kind == "normal" and not p["spring"] and p["power"] == "" and w >= 100.0 and diff > 0.1 and randf() < 0.16 + diff * 0.14:
			p["enemy"] = true
			p["en_x"] = w * 0.5
			p["en_dir"] = 1.0 if randf() < 0.5 else -1.0
			p["coin"] = false
			p["heart"] = false
		platforms.append(p)
		if kind == "blink":
			var bx: float = x + w + 24.0
			if x > W * 0.5:
				bx = x - 24.0 - 90.0
			if bx > 8.0 and bx + 90.0 < W - 8.0:
				platforms.append(make_platform(bx, gen_y, 90.0, "normal", z))
		if diff > 0.3 and z <= 2 and randf() < 0.07:
			add_flyer("bird", gen_y - 70.0)
		if z >= 3 and randf() < 0.08:
			add_flyer("ghost", gen_y - 80.0)
		if z >= 4 and randf() < 0.08:
			add_flyer("ufo", gen_y - 90.0)


func add_flyer(kind: String, y: float) -> void:
	var sp: float = randf_range(70.0, 120.0)
	if kind == "ufo":
		sp = randf_range(80.0, 130.0)
	flyers.append({
		"kind": kind,
		"x": randf_range(40.0, W - 40.0),
		"y": y,
		"vx": sp * (1.0 if randf() < 0.5 else -1.0),
		"t": randf() * 6.0,
		"ph": randf() * 4.0,
		"alive": true,
	})


func cull() -> void:
	var limit: float = cam_y + vh + 260.0
	for i in range(platforms.size() - 1, -1, -1):
		if platforms[i]["y"] > limit:
			platforms.remove_at(i)
	for i in range(flyers.size() - 1, -1, -1):
		if flyers[i]["y"] > limit or not flyers[i]["alive"]:
			flyers.remove_at(i)


# ================================================================ loop

func _process(delta: float) -> void:
	var vs: Vector2 = get_viewport_rect().size
	vw = maxf(vs.x, W)
	vh = maxf(vs.y, 800.0)
	ox = floorf((vw - W) * 0.5)
	if paused:
		queue_redraw()
		return
	time += delta
	boil = int(time * 7.0) % 3
	if state == "title":
		var s: float = sin(time * 3.0)
		pos = Vector2(W * 0.5, GROUND_Y - R - absf(s) * 110.0)
		vel = Vector2(0.0, -cos(time * 3.0) * 450.0 * signf(s))
		squash = 0.0
	elif state == "play":
		update_play(delta)
	update_fx(delta)
	queue_redraw()


func update_play(delta: float) -> void:
	if hitstop > 0.0:
		hitstop -= delta
		return
	var prev_y: float = pos.y
	var axis: float = get_axis()
	vel.x = lerpf(vel.x, axis * 290.0, 1.0 - exp(-14.0 * delta))
	if prop_t > 0.0:
		prop_t -= delta
		vel.y = lerpf(vel.y, -640.0, 1.0 - exp(-8.0 * delta))
		if prop_t <= 0.0:
			vel.y = -520.0
			play_sfx("pop")
		if randf() < 0.8:
			burst(pos + Vector2(0.0, 16.0), 1, [Color(1.0, 1.0, 1.0), Color(1.0, 0.9, 0.6)], 40.0, -60.0, 0)
	else:
		vel.y += GRAV * delta
	pos += vel * delta
	if pos.x < -14.0:
		pos.x = W + 14.0
	elif pos.x > W + 14.0:
		pos.x = -14.0
	update_platforms(delta)
	update_flyers(delta)
	if vel.y > 0.0 and prop_t <= 0.0:
		check_landing(prev_y)
	top_y = minf(top_y, pos.y)
	cam_y = minf(cam_y, pos.y - vh * 0.375)
	generate()
	cull()
	check_things()
	if state != "play":
		return
	if pos.y > cam_y + vh + 40.0:
		lose_life(true)
		if state != "play":
			return
	invuln = maxf(0.0, invuln - delta)
	magnet_t = maxf(0.0, magnet_t - delta)
	squash = lerpf(squash, 0.0, 1.0 - exp(-10.0 * delta))
	check_progress()
	if vel.y < -950.0 and prop_t <= 0.0 and randf() < 0.7:
		burst(pos + Vector2(0.0, 14.0), 1, [Color(1.0, 0.9, 0.5), Color(1.0, 0.6, 0.4)], 20.0, -30.0, 2)


func get_axis() -> float:
	var a := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		a -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		a += 1.0
	if a == 0.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var dx: float = get_global_mouse_position().x - ox - pos.x
		if absf(dx) > 12.0:
			a = signf(dx)
	return a


func height_f() -> float:
	return maxf(0.0, (GROUND_Y - R - top_y) / 10.0)


func height_m() -> int:
	return int(height_f())


func score() -> int:
	return height_m() + bonus


func check_progress() -> void:
	var hm: int = height_m()
	while hm >= next_mile * 100:
		var mp := Vector2(W * 0.5, cam_y + 190.0)
		popup_text(str(next_mile * 100) + " METER!", mp, Color(1.0, 0.9, 0.35))
		burst(mp, 30, [Color(1.0, 0.5, 0.4), Color(1.0, 0.85, 0.3), Color(0.5, 0.85, 0.5), Color(0.45, 0.75, 1.0), Color(0.9, 0.55, 0.9)], 330.0, 120.0, 1)
		play_sfx("mile")
		next_mile += 1
	var z: int = zone_of(float(hm))
	if z != cur_zone:
		cur_zone = z
		banner_text = ZONE_NAMES[z]
		banner_sub = "ZONA " + str(z + 1)
		banner_t = 2.4
		play_sfx("zone")
		if z >= 3:
			set_track(1)
		else:
			set_track(0)


func update_platforms(delta: float) -> void:
	for p in platforms:
		var kind: String = p["type"]
		if kind == "move" and not p["broken"]:
			p["x"] += p["vx"] * delta
			if p["x"] < 8.0:
				p["x"] = 8.0
				p["vx"] = absf(p["vx"])
			elif p["x"] + p["w"] > W - 8.0:
				p["x"] = W - 8.0 - p["w"]
				p["vx"] = -absf(p["vx"])
		elif kind == "bob":
			p["y"] = float(p["y0"]) + sin(time * 1.6 + float(p["ph"])) * 30.0
		elif kind == "blink":
			p["bt"] += delta
		if p["crumble"] > 0.0:
			p["crumble"] -= delta
			if p["crumble"] <= 0.0:
				p["broken"] = true
				p["crumble"] = -2.0
				burst(Vector2(float(p["x"]) + float(p["w"]) * 0.5, p["y"]), 10, [Color(0.9, 0.78, 0.55), Color(0.72, 0.55, 0.38)], 120.0, 40.0, 0)
				play_sfx("crumble")
		if p["broken"]:
			p["fall_v"] += 1200.0 * delta
			p["y"] += p["fall_v"] * delta
		p["spring_t"] = maxf(0.0, float(p["spring_t"]) - delta)
		if p["enemy"] and p["en_alive"]:
			p["en_x"] += p["en_dir"] * 48.0 * delta
			if p["en_x"] < 18.0:
				p["en_x"] = 18.0
				p["en_dir"] = 1.0
			elif p["en_x"] > p["w"] - 18.0:
				p["en_x"] = p["w"] - 18.0
				p["en_dir"] = -1.0


func blink_solid(p: Dictionary) -> bool:
	return fposmod(float(p["bt"]), 2.6) < 1.8


func update_flyers(delta: float) -> void:
	for b in flyers:
		b["t"] += delta
		var k: String = b["kind"]
		if k == "ghost":
			if absf(pos.y - float(b["y"])) < 420.0:
				b["x"] += clampf(pos.x - float(b["x"]), -1.0, 1.0) * 46.0 * delta
			b["x"] = clampf(float(b["x"]), 24.0, W - 24.0)
		else:
			b["x"] += b["vx"] * delta
			if b["x"] < 30.0:
				b["x"] = 30.0
				b["vx"] = absf(b["vx"])
			elif b["x"] > W - 30.0:
				b["x"] = W - 30.0
				b["vx"] = -absf(b["vx"])


func flyer_pos(b: Dictionary) -> Vector2:
	var amp: float = 6.0
	if b["kind"] == "ghost":
		amp = 12.0
	return Vector2(b["x"], float(b["y"]) + sin(float(b["t"]) * 3.0) * amp)


func ufo_beam(b: Dictionary) -> bool:
	var t: float = fposmod(float(b["t"]) + float(b["ph"]), 4.0)
	return t > 2.6 and t < 3.4


func ufo_charge(b: Dictionary) -> bool:
	var t: float = fposmod(float(b["t"]) + float(b["ph"]), 4.0)
	return t > 2.0 and t <= 2.6


func check_landing(prev_y: float) -> void:
	var prev_bottom: float = prev_y + R
	var bottom: float = pos.y + R
	for p in platforms:
		if p["broken"]:
			continue
		if p["type"] == "blink" and not blink_solid(p):
			continue
		if pos.x > p["x"] - 8.0 and pos.x < p["x"] + p["w"] + 8.0:
			if prev_bottom <= p["y"] + 6.0 and bottom >= p["y"]:
				land_on(p)
				return


func land_on(p: Dictionary) -> void:
	pos.y = p["y"] - R
	combo = 0
	squash = 0.38
	var feet := Vector2(pos.x, p["y"])
	if p["spring"]:
		vel.y = -SPRING_V
		p["spring_t"] = 0.3
		shake = maxf(shake, 4.0)
		play_sfx("spring")
		burst(feet, 10, [Color(1.0, 0.45, 0.4), Color(1.0, 0.9, 0.5)], 180.0, 60.0, 1)
	else:
		vel.y = -JUMP_V
		play_sfx("bounce")
		burst(feet, 5, [Color(1.0, 1.0, 1.0)], 90.0, 20.0, 0)
	if p["type"] == "crumble" and p["crumble"] < 0.0 and not p["broken"]:
		p["crumble"] = 0.35


func give_power(kind: String, at: Vector2) -> void:
	play_sfx("power")
	burst(at, 16, [Color(1.0, 1.0, 1.0), Color(0.6, 0.9, 1.0), Color(1.0, 0.9, 0.4)], 240.0, 90.0, 2)
	if kind == "prop":
		prop_t = PROP_TIME
		popup_text("BALING-BALING!", at + Vector2(0.0, -30.0), Color(1.0, 0.55, 0.5))
	elif kind == "shield":
		shield = true
		popup_text("TAMENG!", at + Vector2(0.0, -30.0), Color(0.6, 0.9, 1.0))
	else:
		magnet_t = MAGNET_TIME
		popup_text("MAGNET!", at + Vector2(0.0, -30.0), Color(1.0, 0.6, 0.7))


func check_things() -> void:
	var reach: float = R + 14.0
	if magnet_t > 0.0:
		reach = 150.0
	for p in platforms:
		if p["broken"]:
			continue
		var cp := Vector2(float(p["x"]) + float(p["w"]) * 0.5, float(p["y"]) - 52.0)
		if (p["coin"] or p["heart"]) and not p["taken"]:
			var rr: float = reach if p["coin"] else R + 14.0
			if pos.distance_to(cp) < rr:
				p["taken"] = true
				if p["heart"]:
					if lives < MAX_LIVES:
						lives += 1
						popup_text("+1 nyawa!", cp, Color(1.0, 0.5, 0.6))
					else:
						bonus += 25
						popup_text("+25", cp, Color(1.0, 0.5, 0.6))
					play_sfx("heart")
					burst(cp, 14, [Color(1.0, 0.4, 0.5), Color(1.0, 0.8, 0.85)], 200.0, 80.0, 1)
				else:
					coins += 1
					bonus += 10
					play_sfx("coin")
					burst(cp, 8, [Color(1.0, 0.85, 0.25), Color(1.0, 0.97, 0.7)], 150.0, 60.0, 2)
		if p["power"] != "" and not p["taken"]:
			var pp := Vector2(float(p["x"]) + float(p["w"]) * 0.5, float(p["y"]) - 54.0)
			if pos.distance_to(pp) < R + 18.0:
				p["taken"] = true
				give_power(p["power"], pp)
		if p["enemy"] and p["en_alive"]:
			var ep := Vector2(float(p["x"]) + float(p["en_x"]), float(p["y"]) - 17.0)
			if pos.distance_to(ep) < R + 15.0:
				if prop_t > 0.0:
					stomp(ep, false)
					p["en_alive"] = false
				elif vel.y > 80.0 and pos.y < ep.y - 4.0:
					stomp(ep, true)
					p["en_alive"] = false
				elif invuln <= 0.0:
					take_hit()
					if state != "play":
						return
	for b in flyers:
		if not b["alive"]:
			continue
		var bp: Vector2 = flyer_pos(b)
		var kind: String = b["kind"]
		var hit := false
		if kind == "ufo":
			hit = absf(pos.x - bp.x) < 36.0 and absf(pos.y - bp.y) < 26.0
		elif kind == "ghost":
			hit = pos.distance_to(bp) < R + 16.0
		else:
			hit = pos.distance_to(bp) < R + 14.0
		if hit:
			if prop_t > 0.0:
				stomp(bp, false)
				b["alive"] = false
			elif vel.y > 80.0 and pos.y < bp.y - 3.0:
				stomp(bp, true)
				b["alive"] = false
			elif invuln <= 0.0:
				take_hit()
				if state != "play":
					return
		elif kind == "ufo" and ufo_beam(b) and invuln <= 0.0 and prop_t <= 0.0:
			if absf(pos.x - bp.x) < 22.0 and pos.y > bp.y + 12.0 and pos.y < bp.y + 190.0:
				take_hit()
				if state != "play":
					return


func stomp(ep: Vector2, bounce: bool) -> void:
	combo += 1
	stomps += 1
	var pts: int = 50 * combo
	bonus += pts
	if bounce:
		vel.y = -680.0
		squash = 0.3
	hitstop = 0.07
	shake = maxf(shake, 7.0)
	play_sfx("stomp")
	burst(ep, 18, [Color(1.0, 0.45, 0.55), Color(1.0, 0.85, 0.3), Color(0.5, 0.85, 1.0)], 280.0, 120.0, 1)
	var msg := "+" + str(pts)
	if combo > 1:
		msg += "  x" + str(combo) + "!"
	popup_text(msg, ep + Vector2(0.0, -24.0), Color(1.0, 0.85, 0.25))


func take_hit() -> void:
	if invuln > 0.0 or prop_t > 0.0:
		return
	if shield:
		shield = false
		invuln = 1.2
		vel.y = -560.0
		shake = maxf(shake, 8.0)
		play_sfx("shield")
		burst(pos, 18, [Color(0.6, 0.9, 1.0), Color(1.0, 1.0, 1.0), Color(0.5, 0.75, 1.0)], 260.0, 80.0, 0)
		popup_text("Tameng pecah!", pos + Vector2(0.0, -34.0), Color(0.6, 0.9, 1.0))
		return
	lose_life(false)


func lose_life(from_fall: bool) -> void:
	lives -= 1
	if lives <= 0:
		game_over()
		return
	invuln = 1.8
	shake = 14.0
	prop_t = 0.0
	if from_fall:
		net_t = 0.7
		pos.y = cam_y + vh - 30.0
		pos.x = clampf(pos.x, 40.0, W - 40.0)
		vel = Vector2(0.0, -BOUNCE_BACK_V)
		squash = 0.5
		combo = 0
		play_sfx("bounceback")
		popup_text("BOUNCE BACK!", Vector2(W * 0.5, cam_y + vh - 170.0), Color(1.0, 0.85, 0.2))
		burst(Vector2(pos.x, cam_y + vh - 10.0), 40, [Color(1.0, 0.45, 0.5), Color(1.0, 0.85, 0.3), Color(0.5, 0.85, 1.0), Color(1.0, 1.0, 1.0)], 380.0, 300.0, 1)
	else:
		vel.y = -620.0
		squash = 0.3
		play_sfx("hurt")
		popup_text("Aduh!", pos + Vector2(0.0, -34.0), Color(1.0, 0.55, 0.5))
		burst(pos, 12, [Color(1.0, 0.55, 0.35), Color(1.0, 0.8, 0.6)], 220.0, 100.0, 0)


func game_over() -> void:
	state = "over"
	over_t = 0.0
	var old_best: int = best
	if score() > best:
		best = score()
		new_record = true
	for i in range(skins.size()):
		var need: int = skins[i]["need"]
		if need > old_best and need <= best:
			unlocked_msg = str(skins[i]["name"])
	save_game()
	burst(pos, 40, [Color(1.0, 0.52, 0.35), Color(1.0, 0.8, 0.6), Color(1.0, 1.0, 1.0)], 340.0, 160.0, 1)
	shake = 16.0
	play_sfx("lose")


# ================================================================ efek

func update_fx(delta: float) -> void:
	for i in range(particles.size() - 1, -1, -1):
		var q: Dictionary = particles[i]
		q["life"] -= delta
		if q["life"] <= 0.0:
			particles.remove_at(i)
			continue
		var v: Vector2 = q["v"]
		v.y += 700.0 * delta
		q["v"] = v
		var pp: Vector2 = q["p"]
		q["p"] = pp + v * delta
	for i in range(popups.size() - 1, -1, -1):
		popups[i]["t"] += delta
		if popups[i]["t"] > 1.2:
			popups.remove_at(i)
	shake *= exp(-9.0 * delta)
	if shake < 0.2:
		shake = 0.0
	shake_off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	net_t = maxf(0.0, net_t - delta)
	banner_t = maxf(0.0, banner_t - delta)
	over_t += delta
	if state == "over" and new_record and over_t > 0.4 and randf() < 0.07:
		var fp := Vector2(randf_range(60.0, W - 60.0), cam_y + randf_range(90.0, 420.0))
		burst(fp, 24, [Color(1.0, 0.5, 0.4), Color(1.0, 0.85, 0.3), Color(0.5, 0.85, 0.5), Color(0.45, 0.75, 1.0)], 300.0, 40.0, 2)
		burst(fp, 10, [Color(1.0, 0.9, 0.5), Color(1.0, 0.6, 0.7)], 240.0, 40.0, 1)
		play_sfx("pop")


func burst(p: Vector2, n: int, cols: Array, spd: float, up: float = 0.0, kind: int = 0) -> void:
	for i in range(n):
		var a: float = randf() * TAU
		var s: float = randf_range(0.3, 1.0) * spd
		particles.append({
			"p": p,
			"v": Vector2(cos(a), sin(a)) * s + Vector2(0.0, -up),
			"life": randf_range(0.4, 0.9),
			"c": cols[randi() % cols.size()],
			"sz": randf_range(3.0, 7.0),
			"rot": randf() * TAU,
			"kind": kind,
		})


func popup_text(s: String, p: Vector2, c: Color) -> void:
	popups.append({"s": s, "p": p, "c": c, "t": 0.0, "rot": randf_range(-0.08, 0.08)})


# ================================================================ input

func _unhandled_input(event: InputEvent) -> void:
	var press := false
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.keycode == KEY_SPACE or k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			press = true
		elif k.keycode == KEY_P and state == "play":
			paused = not paused
			return
		elif k.keycode == KEY_M:
			music_on = not music_on
			music.stream_paused = not music_on
			return
		elif k.keycode == KEY_F or k.keycode == KEY_F11:
			toggle_fullscreen()
			return
		elif k.keycode == KEY_ESCAPE:
			if is_fullscreen():
				toggle_fullscreen()
			elif state == "play":
				paused = not paused
			return
		elif state == "title":
			if k.keycode == KEY_LEFT or k.keycode == KEY_A:
				change_skin(-1)
				return
			if k.keycode == KEY_RIGHT or k.keycode == KEY_D:
				change_skin(1)
				return
	var m := event as InputEventMouseButton
	if m != null and m.pressed and m.button_index == MOUSE_BUTTON_LEFT:
		if state == "title":
			var mp: Vector2 = get_global_mouse_position() - Vector2(ox, 0.0)
			if Rect2(60.0, 460.0, 90.0, 80.0).has_point(mp):
				change_skin(-1)
				return
			if Rect2(330.0, 460.0, 90.0, 80.0).has_point(mp):
				change_skin(1)
				return
		press = true
	if paused:
		if press:
			paused = false
		return
	if press:
		if state == "title":
			start_game()
		elif state == "over" and over_t > 0.8:
			start_game()


func change_skin(d: int) -> void:
	var n: int = skins.size()
	skin = (skin + d + n) % n
	play_sfx("coin")
	save_game()


func skin_unlocked(i: int) -> bool:
	return best >= int(skins[i]["need"])


func is_fullscreen() -> bool:
	var m: int = DisplayServer.window_get_mode()
	return m == DisplayServer.WINDOW_MODE_FULLSCREEN or m == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func toggle_fullscreen() -> void:
	if is_fullscreen():
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "play":
		paused = true


# ================================================================ save / suara

func load_save() -> void:
	var path := "user://skyhop.dat"
	if not FileAccess.file_exists(path):
		path = "user://best.dat"
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f != null:
			best = f.get_32()
			if f.get_position() < f.get_length():
				skin = clampi(int(f.get_32()), 0, skins.size() - 1)
	if not skin_unlocked(skin):
		skin = 0


func save_game() -> void:
	var f := FileAccess.open("user://skyhop.dat", FileAccess.WRITE)
	if f != null:
		f.store_32(best)
		f.store_32(skin)


func tone(f0: float, f1: float, dur: float, vol: float, wave_type: int = 0, vib: float = 0.0) -> AudioStreamWAV:
	var rate: int = 22050
	var n: int = int(float(rate) * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(n)
		var f: float = lerpf(f0, f1, t) * (1.0 + vib * sin(t * dur * 60.0))
		phase += TAU * f / float(rate)
		var s: float = sin(phase)
		if wave_type == 1:
			s = 0.6 if s >= 0.0 else -0.6
		elif wave_type == 2:
			s = randf() * 2.0 - 1.0
		var env: float = (1.0 - t) * minf(1.0, float(i) / 120.0)
		data.encode_s16(i * 2, int(clampf(s * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	return w


func build_sfx() -> void:
	sfx_bank = {
		"bounce": tone(360.0, 640.0, 0.14, 0.5),
		"spring": tone(260.0, 980.0, 0.28, 0.5, 1),
		"coin": tone(880.0, 1320.0, 0.14, 0.35, 1),
		"heart": tone(520.0, 1040.0, 0.30, 0.4, 1),
		"stomp": tone(520.0, 110.0, 0.18, 0.6),
		"hurt": tone(300.0, 80.0, 0.30, 0.6, 2),
		"crumble": tone(100.0, 60.0, 0.15, 0.35, 2),
		"bounceback": tone(180.0, 1100.0, 0.55, 0.55, 1),
		"lose": tone(420.0, 70.0, 0.70, 0.55),
		"power": tone(420.0, 1250.0, 0.32, 0.4, 1, 0.04),
		"shield": tone(900.0, 300.0, 0.25, 0.5, 1),
		"pop": tone(700.0, 250.0, 0.10, 0.4),
		"mile": tone(600.0, 1200.0, 0.30, 0.4, 1),
		"zone": tone(330.0, 660.0, 0.50, 0.4, 1, 0.05),
	}


func play_sfx(key: String) -> void:
	if not sfx_bank.has(key):
		return
	for pl in players:
		if not pl.playing:
			pl.stream = sfx_bank[key]
			pl.play()
			return
	players[0].stream = sfx_bank[key]
	players[0].play()


func set_track(i: int) -> void:
	if i == music_track:
		return
	music_track = i
	music.stream = tracks[i]
	music.play()
	music.stream_paused = not music_on


func add_bell(buf: PackedFloat32Array, start: int, freq: float, dur: float, amp: float, rate: int) -> void:
	var count: int = int(dur * float(rate))
	for i in range(count):
		var t: float = float(i) / float(rate)
		var env: float = exp(-t * 6.0) * minf(1.0, float(i) / 40.0)
		var v: float = (sin(TAU * freq * t) + 0.45 * sin(TAU * freq * 2.76 * t) + 0.2 * sin(TAU * freq * 5.4 * t)) * env * amp
		buf[(start + i) % buf.size()] += v


func add_thump(buf: PackedFloat32Array, start: int, freq: float, dur: float, amp: float, rate: int) -> void:
	var count: int = int(dur * float(rate))
	for i in range(count):
		var t: float = float(i) / float(rate)
		var env: float = exp(-t * 18.0)
		var f: float = freq * (1.0 + 1.5 * exp(-t * 40.0))
		buf[(start + i) % buf.size()] += sin(TAU * f * t) * env * amp


func build_music(variant: int) -> AudioStreamWAV:
	var rate: int = 12000
	var step: float = 0.24
	if variant == 1:
		step = 0.3
	var steps: int = 32
	var n: int = int(float(rate) * step * float(steps))
	var buf := PackedFloat32Array()
	buf.resize(n)
	var scale: Array = []
	var mel: Array = []
	var b1: float = 130.81
	var b2: float = 98.0
	if variant == 0:
		scale = [261.63, 293.66, 329.63, 392.0, 440.0, 523.25]
		mel = [0, -1, 2, -1, 3, 2, -1, 4, 3, -1, 2, 0, -1, 1, 2, -1, 4, -1, 5, 4, -1, 3, 2, -1, 3, -1, 2, 1, 0, -1, -1, -1]
	else:
		scale = [220.0, 261.63, 293.66, 329.63, 392.0, 440.0]
		mel = [0, -1, -1, 2, -1, 1, -1, -1, 3, -1, 2, -1, 1, -1, 0, -1, 4, -1, -1, 3, -1, 2, -1, -1, 1, -1, 0, -1, -1, -1, -1, -1]
		b1 = 110.0
		b2 = 82.41
	for s in range(steps):
		var st: int = int(float(s) * step * float(rate))
		var mi: int = mel[s % mel.size()]
		if mi >= 0:
			add_bell(buf, st, scale[mi], 0.5, 0.18, rate)
		if s % 4 == 0:
			var bass: float = b1 if ((s >> 3) % 2 == 0) else b2
			add_bell(buf, st, bass, 0.6, 0.2, rate)
		if s % 8 == 0:
			add_thump(buf, st, 85.0, 0.2, 0.3, rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in range(n):
		data.encode_s16(i * 2, int(clampf(buf[i] * 0.8, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	return w


# ================================================================ helper gambar

func xs() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func xc() -> void:
	draw_set_transform(Vector2(ox, 0.0), 0.0, Vector2.ONE)


func xf(p: Vector2, rot: float = 0.0, sc: Vector2 = Vector2.ONE) -> void:
	draw_set_transform(p + Vector2(ox, 0.0) + shake_off - Vector2(0.0, cam_y), rot, sc)


func xl(p: Vector2, rot: float = 0.0, sc: float = 1.0) -> void:
	draw_set_transform(p, rot, Vector2(sc, sc))


func jit(i: int, k: int) -> float:
	var v: float = sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453
	return (v - floorf(v)) * 2.0 - 1.0


func shifted(pts: PackedVector2Array, v: Vector2) -> PackedVector2Array:
	var o := PackedVector2Array()
	for p in pts:
		o.append(p + v)
	return o


func wob_rect(x: float, y: float, w: float, h: float, k: int, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var nx: int = maxi(2, int(w / 26.0))
	var ny: int = maxi(1, int(h / 26.0))
	for i in range(nx):
		pts.append(Vector2(x + w * float(i) / float(nx) + jit(i, k) * amp, y + jit(i + 40, k) * amp))
	for i in range(ny):
		pts.append(Vector2(x + w + jit(i + 80, k) * amp, y + h * float(i) / float(ny) + jit(i + 120, k) * amp))
	for i in range(nx):
		pts.append(Vector2(x + w - w * float(i) / float(nx) + jit(i + 160, k) * amp, y + h + jit(i + 200, k) * amp))
	for i in range(ny):
		pts.append(Vector2(x + jit(i + 280, k) * amp, y + h - h * float(i) / float(ny) + jit(i + 320, k) * amp))
	return pts


func circle_pts(r: float, n: int, k: int, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a: float = TAU * float(i) / float(n)
		pts.append(Vector2(cos(a), sin(a)) * (r + jit(i, k) * amp))
	return pts


func ellipse_pts(rx: float, ry: float, n: int, k: int, amp: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n):
		var a: float = TAU * float(i) / float(n)
		var j: float = jit(i, k) * amp
		pts.append(Vector2(cos(a) * (rx + j), sin(a) * (ry + j)))
	return pts


func star_pts(r1: float, r2: float, n: int, k: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(n * 2):
		var a: float = TAU * float(i) / float(n * 2)
		var rr: float = (r1 if i % 2 == 0 else r2) + jit(i, k)
		pts.append(Vector2(cos(a), sin(a)) * rr)
	return pts


func heart_pts(s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(24):
		var t: float = TAU * float(i) / 24.0
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(Vector2(x, y) * s)
	return pts


# Seperti cetak sablon: warna sedikit meleset dari garis tinta.
func shape(pts: PackedVector2Array, fill: Color, width: float = 3.0) -> void:
	draw_colored_polygon(shifted(pts, REG), fill)
	var o := PackedVector2Array(pts)
	o.append(pts[0])
	draw_polyline(o, INK, width, true)


func label(s: String, x: float, y: float, size: int, col: Color, center: bool = false, a: float = 1.0) -> void:
	if center:
		x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	var fill := col
	fill.a = a
	var edge := Color(INK.r, INK.g, INK.b, a)
	draw_string_outline(font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(float(size) * 0.3), edge)
	draw_string(font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fill)


func plain(s: String, x: float, y: float, size: int, col: Color, center: bool = false) -> void:
	if center:
		x -= font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x * 0.5
	draw_string(font, Vector2(x, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func sky_colors(f: float) -> Array:
	var i: int = mini(int(floorf(f)), sky_top.size() - 1)
	var j: int = mini(i + 1, sky_top.size() - 1)
	var t: float = smoothstep(0.0, 1.0, f - float(i))
	var a: Color = sky_top[i]
	var b: Color = sky_top[j]
	var c: Color = sky_bot[i]
	var d: Color = sky_bot[j]
	return [a.lerp(b, t), c.lerp(d, t)]


func draw_cloud_shape(c: Vector2, cs: float, fill: Color, edge: Color) -> void:
	var puffs: Array = [Vector2(0.0, 0.0), Vector2(26.0, -10.0), Vector2(54.0, 0.0), Vector2(26.0, 6.0)]
	var rads: Array = [20.0, 26.0, 18.0, 20.0]
	for i in range(puffs.size()):
		draw_circle(c + puffs[i] * cs, (float(rads[i]) + 3.0) * cs, edge)
	for i in range(puffs.size()):
		draw_circle(c + puffs[i] * cs, float(rads[i]) * cs, fill)


# ================================================================ gambar

func _draw() -> void:
	draw_sky()
	draw_hills()
	draw_markers()
	for p in platforms:
		var sy: float = float(p["y"]) - cam_y
		if sy < -90.0 or sy > vh + 90.0:
			continue
		draw_platform(p)
	for b in flyers:
		if b["alive"]:
			draw_flyer(b)
	draw_particles()
	if state != "over":
		draw_player()
	draw_popups()
	draw_net()
	draw_panels()
	draw_vignette()
	draw_cards()
	if state == "title":
		draw_title()
	else:
		draw_hud()
		if state == "over":
			draw_over()
	if paused:
		draw_pause()


func draw_sky() -> void:
	xs()
	var hm: float = height_f()
	var f: float = zone_f(hm)
	var cols: Array = sky_colors(f)
	var top: Color = cols[0]
	var bot: Color = cols[1]
	var quad := PackedVector2Array([Vector2(0.0, 0.0), Vector2(vw, 0.0), Vector2(vw, vh), Vector2(0.0, vh)])
	draw_polygon(quad, PackedColorArray([top, top, bot, bot]))
	xc()
	# bintang
	var sa: float = clampf((f - 2.2) / 1.2, 0.0, 1.0)
	if sa > 0.0:
		for i in range(46):
			var sx: float = (jit(i, 1) * 0.5 + 0.5) * W
			var sy: float = fposmod((jit(i, 2) * 0.5 + 0.5) * vh - cam_y * 0.12, vh)
			var tw: float = 0.5 + 0.5 * sin(time * 2.0 + float(i))
			var sc := Color(1.0, 0.97, 0.8, sa * tw)
			draw_line(Vector2(sx - 3.0, sy), Vector2(sx + 3.0, sy), sc, 2.0)
			draw_line(Vector2(sx, sy - 3.0), Vector2(sx, sy + 3.0), sc, 2.0)
	# matahari
	var sun_a: float = clampf(1.7 - f, 0.0, 1.0)
	if sun_a > 0.0:
		draw_set_transform(Vector2(ox + W - 80.0, 96.0 + (1.0 - sun_a) * 80.0), time * 0.08, Vector2.ONE)
		for i in range(12):
			var a: float = TAU * float(i) / 12.0
			var r1: float = 46.0 + jit(i, boil) * 4.0
			draw_line(Vector2(cos(a), sin(a)) * 36.0, Vector2(cos(a), sin(a)) * r1, Color(1.0, 0.8, 0.3, sun_a), 4.0)
		draw_circle(Vector2.ZERO, 30.0, Color(INK.r, INK.g, INK.b, sun_a))
		draw_circle(Vector2.ZERO, 27.0, Color(1.0, 0.86, 0.35, sun_a))
		xc()
	# bulan
	var moon_a: float = clampf((f - 2.6), 0.0, 1.0) * clampf(4.5 - f, 0.0, 1.0)
	if moon_a > 0.0:
		draw_set_transform(Vector2(ox + 90.0, 120.0), 0.0, Vector2.ONE)
		draw_circle(Vector2.ZERO, 40.0, Color(1.0, 0.95, 0.7, moon_a * 0.18))
		draw_circle(Vector2.ZERO, 31.0, Color(INK.r, INK.g, INK.b, moon_a))
		draw_circle(Vector2.ZERO, 28.0, Color(1.0, 0.96, 0.78, moon_a))
		draw_circle(Vector2(-8.0, -6.0), 5.0, Color(0.88, 0.82, 0.62, moon_a))
		draw_circle(Vector2(10.0, 8.0), 4.0, Color(0.88, 0.82, 0.62, moon_a))
		draw_circle(Vector2(6.0, -12.0), 3.0, Color(0.88, 0.82, 0.62, moon_a))
		xc()
	# planet
	var pa: float = clampf((f - 3.1) / 0.8, 0.0, 1.0)
	if pa > 0.0:
		var py: float = fposmod(260.0 - cam_y * 0.05, vh + 300.0) - 150.0
		draw_set_transform(Vector2(ox + W * 0.74, py), 0.0, Vector2.ONE)
		draw_circle(Vector2.ZERO, 66.0, Color(INK.r, INK.g, INK.b, pa))
		draw_circle(Vector2.ZERO, 62.0, Color(0.9, 0.55, 0.45, pa))
		draw_arc(Vector2(0.0, -14.0), 50.0, 0.3, 2.8, 14, Color(0.98, 0.78, 0.6, pa), 9.0)
		draw_arc(Vector2(0.0, 16.0), 54.0, 0.2, 2.9, 14, Color(0.8, 0.42, 0.4, pa), 7.0)
		var ring := PackedVector2Array()
		for i in range(33):
			var ra: float = TAU * float(i) / 32.0
			ring.append(Vector2(cos(ra) * 104.0, sin(ra) * 24.0).rotated(-0.35))
		draw_polyline(ring, Color(INK.r, INK.g, INK.b, pa), 10.0, true)
		draw_polyline(ring, Color(1.0, 0.9, 0.65, pa), 5.0, true)
		xc()
	# awan
	var ca: float = clampf(1.0 - maxf(0.0, f - 2.0) * 0.7, 0.0, 1.0)
	if ca > 0.0:
		var tint := Color(1.0, 1.0, 1.0).lerp(bot, 0.3)
		for c in clouds:
			var cy: float = fposmod(float(c["y"]) - cam_y * float(c["f"]), 1100.0) - 120.0
			draw_cloud_shape(Vector2(c["x"], cy), c["s"], Color(tint.r, tint.g, tint.b, 0.92 * ca), Color(INK.r, INK.g, INK.b, 0.5 * ca))


func draw_hills() -> void:
	if cam_y < -900.0:
		return
	xf(Vector2.ZERO)
	for layer in range(2):
		var base: float = GROUND_Y - 30.0 - float(layer) * 40.0
		var pts := PackedVector2Array()
		for i in range(26):
			var x: float = float(i) * 20.0
			pts.append(Vector2(x, base - 50.0 - 38.0 * sin(x * 0.012 + float(layer) * 2.0) - 14.0 * jit(i, layer)))
		pts.append(Vector2(W + 20.0, GROUND_Y + 10.0))
		pts.append(Vector2(0.0, GROUND_Y + 10.0))
		var col := Color(0.5, 0.76, 0.5)
		if layer == 1:
			col = Color(0.62, 0.84, 0.55)
		shape(pts, col, 3.0)


func draw_markers() -> void:
	var k0: int = maxi(1, int(ceilf((GROUND_Y - R - (cam_y + vh)) / 1000.0)))
	var k1: int = int(floorf((GROUND_Y - R - cam_y) / 1000.0))
	for k in range(k0, k1 + 1):
		var wy: float = GROUND_Y - R - float(k) * 1000.0
		xf(Vector2(0.0, wy))
		var cl := Color(INK.r, INK.g, INK.b, 0.35)
		var x: float = 0.0
		while x < W:
			draw_line(Vector2(x, 0.0), Vector2(x + 14.0, 0.0), cl, 3.0)
			x += 28.0
		var s: String = str(k * 100) + " M"
		var tw: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		label(s, W - 14.0 - tw, -8.0, 20, Color(1.0, 0.95, 0.8))
		var fp := PackedVector2Array([Vector2(12.0, -4.0), Vector2(12.0, -34.0), Vector2(40.0, -26.0), Vector2(12.0, -18.0)])
		draw_line(Vector2(12.0, 0.0), Vector2(12.0, -36.0), INK, 4.0)
		shape(fp, Color(1.0, 0.45, 0.4), 2.5)


func draw_ground(p: Dictionary) -> void:
	xf(Vector2.ZERO)
	var y: float = p["y"]
	var k: int = boil * 11
	shape(wob_rect(-20.0, y, W + 40.0, 900.0, k, 1.4), Color(0.58, 0.38, 0.26))
	shape(wob_rect(-20.0, y, W + 40.0, 14.0, k + 3, 1.2), Color(0.45, 0.78, 0.32))
	for i in range(8):
		var rx: float = 30.0 + float(i) * 60.0 + jit(i, 5) * 14.0
		var ry: float = y + 40.0 + 24.0 * (jit(i, 9) + 1.0)
		draw_circle(Vector2(rx, ry), 5.0 + 3.0 * (jit(i, 2) + 1.0), Color(0.48, 0.31, 0.22))
	var petals: Array = [Color(1.0, 0.5, 0.55), Color(1.0, 0.85, 0.3), Color(0.9, 0.6, 1.0)]
	for i in range(6):
		var fx: float = 130.0 + float(i) * 62.0 + jit(i, 7) * 14.0
		draw_line(Vector2(fx, y + 2.0), Vector2(fx, y - 14.0), INK, 3.0)
		draw_circle(Vector2(fx, y - 17.0), 7.0, INK)
		draw_circle(Vector2(fx, y - 17.0), 5.0, petals[i % 3])
		draw_circle(Vector2(fx, y - 17.0), 2.0, Color(1.0, 0.95, 0.6))
	# jamur
	for mx in [372.0, 432.0]:
		draw_line(Vector2(mx, y + 1.0), Vector2(mx, y - 10.0), INK, 8.0)
		draw_line(Vector2(mx, y + 1.0), Vector2(mx, y - 10.0), PAPER, 4.0)
		shape(shifted(ellipse_pts(13.0, 9.0, 10, k, 0.5), Vector2(mx, y - 12.0)), Color(0.92, 0.32, 0.3), 2.5)
		draw_circle(Vector2(mx - 4.0, y - 14.0), 2.5, PAPER)
		draw_circle(Vector2(mx + 5.0, y - 11.0), 2.0, PAPER)
	# papan petunjuk
	xf(Vector2(66.0, y))
	draw_line(Vector2(0.0, 2.0), Vector2(0.0, -68.0), INK, 10.0)
	draw_line(Vector2(0.0, 2.0), Vector2(0.0, -68.0), Color(0.62, 0.42, 0.26), 6.0)
	shape(wob_rect(-34.0, -104.0, 68.0, 36.0, k, 1.0), Color(0.95, 0.74, 0.3), 3.0)
	shape(PackedVector2Array([Vector2(-9.0, -108.0), Vector2(0.0, -124.0), Vector2(9.0, -108.0)]), Color(0.92, 0.32, 0.3), 2.5)
	plain("NAIK!", 0.0, -79.0, 19, INK, true)
	# pagar kecil
	xf(Vector2(190.0, y))
	for i in range(4):
		var fx2: float = float(i) * 14.0
		shape(PackedVector2Array([Vector2(fx2, 0.0), Vector2(fx2, -18.0), Vector2(fx2 + 5.0, -23.0), Vector2(fx2 + 10.0, -18.0), Vector2(fx2 + 10.0, 0.0)]), PAPER, 2.5)
	draw_line(Vector2(-2.0, -12.0), Vector2(52.0, -12.0), INK, 3.0)


func plat_colors(z: int) -> Array:
	if z == 0:
		return [Color(0.55, 0.36, 0.25), Color(0.45, 0.78, 0.32)]
	if z == 1:
		return [Color(0.82, 0.9, 1.0), Color(1.0, 1.0, 1.0)]
	if z == 2:
		return [Color(0.72, 0.38, 0.38), Color(1.0, 0.72, 0.4)]
	if z == 3:
		return [Color(0.34, 0.3, 0.62), Color(0.62, 0.58, 0.92)]
	return [Color(0.2, 0.55, 0.66), Color(0.55, 0.95, 0.9)]


func draw_platform(p: Dictionary) -> void:
	var kind: String = p["type"]
	if kind == "ground":
		draw_ground(p)
		return
	var x: float = p["x"]
	var y: float = p["y"]
	var w: float = p["w"]
	var z: int = p["z"]
	var k: int = (int(absf(float(p["y0"]))) % 89) + boil * 13
	var off := Vector2.ZERO
	if kind == "crumble" and p["crumble"] > 0.0:
		off = Vector2(jit(int(time * 60.0), 3) * 2.5, 0.0)
	xf(off)
	var h := 20.0
	var pc: Array = plat_colors(z)
	var body: Color = pc[0]
	var topc: Color = pc[1]
	if kind == "move":
		body = Color(0.33, 0.52, 0.86)
		topc = Color(0.55, 0.75, 1.0)
	elif kind == "crumble":
		body = Color(0.72, 0.55, 0.38)
		topc = Color(0.9, 0.78, 0.55)
	elif kind == "blink":
		body = Color(0.6, 0.38, 0.82)
		topc = Color(0.85, 0.65, 1.0)
	elif kind == "bob":
		body = Color(0.22, 0.62, 0.6)
		topc = Color(0.5, 0.9, 0.8)
	if kind == "blink":
		var solid: bool = blink_solid(p)
		var bt: float = fposmod(float(p["bt"]), 2.6)
		if not solid:
			var xo: float = 0.0
			while xo < w:
				draw_line(Vector2(x + xo, y + 2.0), Vector2(x + minf(xo + 10.0, w), y + 2.0), Color(0.85, 0.65, 1.0, 0.8), 3.0)
				draw_line(Vector2(x + xo, y + 18.0), Vector2(x + minf(xo + 10.0, w), y + 18.0), Color(0.85, 0.65, 1.0, 0.8), 3.0)
				xo += 20.0
			return
		if bt > 1.4 and int(time * 16.0) % 2 == 0:
			return
	draw_colored_polygon(wob_rect(x + 5.0, y + 6.0, w, h, k, 1.5), Color(0.0, 0.0, 0.0, 0.18))
	shape(wob_rect(x, y, w, h, k, 1.6), body)
	shape(wob_rect(x, y, w, 8.0, k + 5, 1.2), topc)
	if kind == "normal" or kind == "bob" or kind == "move":
		if z == 0:
			for i in range(int(w / 24.0)):
				var tx: float = x + 14.0 + float(i) * 24.0 + jit(i, k) * 3.0
				draw_polyline(PackedVector2Array([Vector2(tx - 3.0, y), Vector2(tx, y - 6.0), Vector2(tx + 3.0, y)]), INK, 2.0, true)
		elif z == 1:
			for i in range(int(w / 36.0)):
				var cx0: float = x + 20.0 + float(i) * 36.0
				draw_circle(Vector2(cx0, y - 2.0), 8.0, INK)
				draw_circle(Vector2(cx0, y - 2.0), 6.0, Color(1.0, 1.0, 1.0))
		elif z == 2:
			for i in range(int(w / 30.0)):
				var fx: float = x + 16.0 + float(i) * 30.0
				draw_line(Vector2(fx, y), Vector2(fx, y - 11.0), INK, 2.5)
				shape(PackedVector2Array([Vector2(fx, y - 11.0), Vector2(fx + 9.0, y - 8.0), Vector2(fx, y - 5.0)]), Color(1.0, 0.45, 0.4), 2.0)
		elif z == 3:
			for i in range(int(w / 30.0)):
				draw_circle(Vector2(x + 14.0 + float(i) * 30.0 + jit(i, k) * 4.0, y + 14.0), 3.0, Color(0.22, 0.2, 0.46))
		else:
			for i in range(int(w / 26.0)):
				var gl: float = 0.5 + 0.5 * sin(time * 4.0 + float(i))
				draw_circle(Vector2(x + 14.0 + float(i) * 26.0, y + 14.0), 3.0, Color(0.7, 1.0, 0.95, 0.4 + 0.6 * gl))
	if kind == "move":
		var cx: float = x + w * 0.5
		draw_polyline(PackedVector2Array([Vector2(cx - 12.0, y + 11.0), Vector2(cx - 18.0, y + 15.0), Vector2(cx - 12.0, y + 19.0)]), INK, 2.5, true)
		draw_polyline(PackedVector2Array([Vector2(cx + 12.0, y + 11.0), Vector2(cx + 18.0, y + 15.0), Vector2(cx + 12.0, y + 19.0)]), INK, 2.5, true)
	elif kind == "bob":
		var cxb: float = x + w * 0.5
		draw_polyline(PackedVector2Array([Vector2(cxb - 6.0, y + 12.0), Vector2(cxb, y + 8.0), Vector2(cxb + 6.0, y + 12.0)]), INK, 2.5, true)
		draw_polyline(PackedVector2Array([Vector2(cxb - 6.0, y + 17.0), Vector2(cxb, y + 21.0), Vector2(cxb + 6.0, y + 17.0)]), INK, 2.5, true)
	elif kind == "crumble":
		var cx2: float = x + w * 0.4
		draw_polyline(PackedVector2Array([Vector2(cx2, y + 2.0), Vector2(cx2 + 5.0, y + 9.0), Vector2(cx2 - 3.0, y + 13.0), Vector2(cx2 + 4.0, y + 19.0)]), INK, 2.0, true)
	elif kind == "blink":
		draw_circle(Vector2(x + w * 0.5, y + 14.0), 3.5, Color(1.0, 0.95, 0.7))
	if p["spring"]:
		draw_spring(x + w * 0.5, y, p["spring_t"])
	if (p["coin"] or p["heart"]) and not p["taken"]:
		var cp := Vector2(x + w * 0.5, y - 52.0)
		if p["heart"]:
			draw_heart_pickup(cp)
		else:
			draw_coin(cp, int(x))
	if p["power"] != "" and not p["taken"]:
		draw_power(Vector2(x + w * 0.5, y - 54.0), p["power"])
	if p["enemy"] and p["en_alive"]:
		draw_enemy(Vector2(x + float(p["en_x"]), y - 17.0), p["en_dir"])


func draw_spring(sx: float, y: float, t: float) -> void:
	var hh: float = 22.0 + 12.0 * (t / 0.3)
	var pts := PackedVector2Array()
	for i in range(7):
		var yy: float = y - hh * float(i) / 6.0
		var xx: float = sx + (9.0 if i % 2 == 0 else -9.0)
		if i == 0 or i == 6:
			xx = sx
		pts.append(Vector2(xx, yy))
	draw_polyline(pts, INK, 6.0, true)
	draw_polyline(pts, Color(0.85, 0.85, 0.92), 3.0, true)
	shape(wob_rect(sx - 15.0, y - hh - 8.0, 30.0, 9.0, boil, 0.8), Color(1.0, 0.4, 0.4))


func draw_coin(c: Vector2, seed_i: int) -> void:
	var sx: float = maxf(0.18, absf(cos(time * 4.0 + float(seed_i))))
	var bob: float = sin(time * 3.0 + float(seed_i)) * 3.0
	xf(c + Vector2(0.0, bob), 0.0, Vector2(sx, 1.0))
	draw_circle(Vector2.ZERO, 13.0, INK)
	draw_circle(Vector2.ZERO, 10.0, Color(1.0, 0.82, 0.2))
	draw_arc(Vector2.ZERO, 6.0, 0.6, 2.4, 8, Color(1.0, 0.96, 0.7), 2.0)


func draw_heart_pickup(c: Vector2) -> void:
	var bob: float = sin(time * 4.0) * 4.0
	var s: float = 0.85 + 0.08 * sin(time * 8.0)
	xf(c + Vector2(0.0, bob))
	shape(heart_pts(s), Color(1.0, 0.35, 0.45), 3.0)
	draw_circle(Vector2(-6.0, -6.0), 2.5, Color(1.0, 0.85, 0.88))


func draw_power(c: Vector2, kind: String) -> void:
	var bob: float = sin(time * 3.5 + c.x) * 4.0
	xf(c + Vector2(0.0, bob))
	var pulse: float = 0.5 + 0.5 * sin(time * 6.0)
	draw_circle(Vector2.ZERO, 22.0 + pulse * 3.0, Color(1.0, 1.0, 1.0, 0.25))
	draw_circle(Vector2.ZERO, 18.0, INK)
	draw_circle(Vector2.ZERO, 15.5, Color(1.0, 0.97, 0.88))
	if kind == "prop":
		shape(shifted(ellipse_pts(9.0, 6.0, 10, 1, 0.3), Vector2(0.0, 2.0)), Color(0.92, 0.32, 0.3), 2.5)
		draw_line(Vector2(0.0, -3.0), Vector2(0.0, -9.0), INK, 3.0)
		var rw: float = cos(time * 30.0) * 11.0
		draw_line(Vector2(-rw, -9.0), Vector2(rw, -9.0), INK, 3.5)
	elif kind == "shield":
		var sp := PackedVector2Array([Vector2(-9.0, -9.0), Vector2(9.0, -9.0), Vector2(9.0, 1.0), Vector2(0.0, 11.0), Vector2(-9.0, 1.0)])
		shape(sp, Color(0.45, 0.72, 1.0), 2.5)
		draw_line(Vector2(0.0, -6.0), Vector2(0.0, 5.0), Color(1.0, 1.0, 1.0), 2.5)
	else:
		draw_arc(Vector2(0.0, 1.0), 8.0, PI, TAU, 10, INK, 8.0)
		draw_arc(Vector2(0.0, 1.0), 8.0, PI, TAU, 10, Color(0.88, 0.3, 0.35), 4.0)
		draw_line(Vector2(-8.0, 1.0), Vector2(-8.0, 8.0), INK, 8.0)
		draw_line(Vector2(8.0, 1.0), Vector2(8.0, 8.0), INK, 8.0)
		draw_line(Vector2(-8.0, 1.0), Vector2(-8.0, 6.0), Color(0.88, 0.3, 0.35), 4.0)
		draw_line(Vector2(8.0, 1.0), Vector2(8.0, 6.0), Color(0.88, 0.3, 0.35), 4.0)
		draw_line(Vector2(-8.0, 6.0), Vector2(-8.0, 9.0), Color(0.88, 0.9, 0.95), 4.0)
		draw_line(Vector2(8.0, 6.0), Vector2(8.0, 9.0), Color(0.88, 0.9, 0.95), 4.0)


func draw_enemy(ep: Vector2, dir: float) -> void:
	var bob: float = sin(time * 10.0 + ep.x * 0.1) * 1.5
	xf(ep + Vector2(0.0, bob), time * dir * 1.2, Vector2.ONE)
	shape(star_pts(18.0, 12.0, 8, boil * 7), Color(0.88, 0.28, 0.42), 3.0)
	xf(ep + Vector2(0.0, bob))
	for sgn in [-1.0, 1.0]:
		draw_circle(Vector2(5.5 * sgn, -2.0), 5.6, INK)
		draw_circle(Vector2(5.5 * sgn, -2.0), 4.4, Color(1.0, 1.0, 1.0))
		draw_circle(Vector2(5.5 * sgn + dir * 1.5, -1.0), 2.0, INK)
		draw_line(Vector2(5.5 * sgn + 6.0 * sgn, -9.0), Vector2(5.5 * sgn - 2.0 * sgn, -6.0), INK, 3.0)


func draw_flyer(b: Dictionary) -> void:
	var kind: String = b["kind"]
	var fp: Vector2 = flyer_pos(b)
	if fp.y - cam_y < -120.0 or fp.y - cam_y > vh + 120.0:
		return
	var d: float = 1.0
	if b["vx"] < 0.0:
		d = -1.0
	var t: float = b["t"]
	if kind == "bird":
		var f: float = sin(t * 14.0)
		xf(fp, 0.0, Vector2(d, 1.0))
		shape(PackedVector2Array([Vector2(-4.0, 0.0), Vector2(-26.0, -10.0 + f * 12.0), Vector2(-20.0, 8.0 + f * 5.0)]), Color(0.55, 0.45, 0.85), 2.5)
		shape(circle_pts(13.0, 14, boil * 3, 0.9), Color(0.35, 0.28, 0.6), 3.0)
		shape(PackedVector2Array([Vector2(11.0, -1.0), Vector2(21.0, 3.0), Vector2(11.0, 6.0)]), Color(1.0, 0.75, 0.2), 2.5)
		draw_circle(Vector2(4.0, -4.0), 4.6, INK)
		draw_circle(Vector2(4.0, -4.0), 3.6, Color(1.0, 1.0, 1.0))
		draw_circle(Vector2(5.0, -4.0), 1.6, INK)
		draw_line(Vector2(0.0, -10.0), Vector2(8.0, -7.0), INK, 2.5)
	elif kind == "ghost":
		xf(fp)
		var pts := PackedVector2Array()
		for i in range(13):
			var a: float = PI + PI * float(i) / 12.0
			pts.append(Vector2(cos(a) * 16.0, sin(a) * 16.0 - 2.0))
		for i in range(7):
			var gx: float = 16.0 - float(i) * 32.0 / 6.0
			pts.append(Vector2(gx, 14.0 + sin(t * 8.0 + float(i) * 1.6) * 4.0))
		shape(pts, Color(0.93, 0.93, 1.0), 3.0)
		for sgn in [-1.0, 1.0]:
			draw_circle(Vector2(6.0 * sgn, -4.0), 4.0, INK)
			draw_circle(Vector2(5.0 * sgn, -5.0), 1.3, Color(1.0, 1.0, 1.0))
		draw_arc(Vector2(0.0, 6.0), 4.0, PI + 0.4, TAU - 0.4, 8, INK, 2.2)
		draw_circle(Vector2(-11.0, 2.0), 3.0, Color(1.0, 0.6, 0.7, 0.6))
		draw_circle(Vector2(11.0, 2.0), 3.0, Color(1.0, 0.6, 0.7, 0.6))
	else:
		var beam: bool = ufo_beam(b)
		var charge: bool = ufo_charge(b)
		if beam:
			var bt := PackedVector2Array([Vector2(-16.0, 12.0), Vector2(16.0, 12.0), Vector2(30.0, 190.0), Vector2(-30.0, 190.0)])
			xf(fp)
			draw_colored_polygon(bt, Color(1.0, 0.95, 0.4, 0.4 + 0.2 * sin(time * 30.0)))
			draw_polyline(PackedVector2Array([Vector2(-16.0, 12.0), Vector2(-30.0, 190.0)]), Color(1.0, 0.9, 0.3), 3.0)
			draw_polyline(PackedVector2Array([Vector2(16.0, 12.0), Vector2(30.0, 190.0)]), Color(1.0, 0.9, 0.3), 3.0)
		elif charge:
			xf(fp)
			for i in range(6):
				draw_circle(Vector2(0.0, 28.0 + float(i) * 26.0), 3.0, Color(1.0, 0.95, 0.5, 0.7))
		xf(fp)
		shape(shifted(circle_pts(13.0, 12, 2, 0.5), Vector2(0.0, -8.0)), Color(0.6, 0.9, 0.95), 3.0)
		draw_circle(Vector2(0.0, -8.0), 6.0, Color(0.55, 0.9, 0.45))
		draw_circle(Vector2(-2.0, -9.0), 1.5, INK)
		draw_circle(Vector2(2.5, -9.0), 1.5, INK)
		shape(ellipse_pts(30.0, 9.0, 14, boil, 0.4), Color(0.72, 0.74, 0.85), 3.0)
		for i in range(5):
			var lx: float = -20.0 + float(i) * 10.0
			var on: bool = int(time * 6.0 + float(i)) % 2 == 0
			draw_circle(Vector2(lx, 1.0), 2.8, Color(1.0, 0.85, 0.3) if on else Color(0.9, 0.4, 0.4))


func draw_player() -> void:
	if invuln > 0.0 and state == "play" and int(time * 18.0) % 2 == 0:
		return
	draw_player_at(pos.x)
	if pos.x < R + 24.0:
		draw_player_at(pos.x + W)
	elif pos.x > W - R - 24.0:
		draw_player_at(pos.x - W)


func draw_accessory(idx: int, col: Color) -> void:
	if prop_t > 0.0:
		shape(shifted(ellipse_pts(11.0, 7.0, 10, 1, 0.3), Vector2(0.0, -R + 1.0)), Color(0.92, 0.32, 0.3), 2.5)
		draw_line(Vector2(0.0, -R - 4.0), Vector2(0.0, -R - 12.0), INK, 3.5)
		var rw: float = cos(time * 40.0) * 26.0
		draw_line(Vector2(-rw, -R - 13.0), Vector2(rw, -R - 13.0), INK, 5.0)
		draw_line(Vector2(-rw, -R - 13.0), Vector2(rw, -R - 13.0), Color(1.0, 0.85, 0.3), 2.5)
		return
	if idx == 0:
		var tip := Vector2(-vel.x * 0.03, -R - 16.0 - clampf(-vel.y * 0.01, -4.0, 6.0))
		var stalk := PackedVector2Array([Vector2(0.0, -R + 2.0), Vector2(tip.x * 0.4, -R - 8.0), tip])
		draw_polyline(stalk, INK, 3.0, true)
		draw_circle(tip, 5.0, INK)
		draw_circle(tip, 3.4, Color(1.0, 0.85, 0.3))
	elif idx == 1:
		shape(PackedVector2Array([Vector2(-15.0, -R + 6.0), Vector2(-13.0, -R - 12.0), Vector2(-3.0, -R + 1.0)]), col, 2.5)
		shape(PackedVector2Array([Vector2(15.0, -R + 6.0), Vector2(13.0, -R - 12.0), Vector2(3.0, -R + 1.0)]), col, 2.5)
		draw_colored_polygon(PackedVector2Array([Vector2(-12.0, -R + 2.0), Vector2(-12.0, -R - 6.0), Vector2(-6.0, -R)]), Color(1.0, 0.7, 0.8))
		draw_colored_polygon(PackedVector2Array([Vector2(12.0, -R + 2.0), Vector2(12.0, -R - 6.0), Vector2(6.0, -R)]), Color(1.0, 0.7, 0.8))
	elif idx == 2:
		draw_line(Vector2(0.0, -R + 3.0), Vector2(0.0, -R - 8.0), INK, 5.0)
		draw_line(Vector2(0.0, -R + 3.0), Vector2(0.0, -R - 8.0), Color(0.35, 0.65, 0.3), 2.5)
		shape(shifted(ellipse_pts(8.0, 4.5, 10, 2, 0.2), Vector2(-8.0, -R - 9.0)), Color(0.5, 0.85, 0.4), 2.5)
		shape(shifted(ellipse_pts(8.0, 4.5, 10, 3, 0.2), Vector2(8.0, -R - 11.0)), Color(0.5, 0.85, 0.4), 2.5)
	else:
		shape(PackedVector2Array([Vector2(0.0, -R - 2.0), Vector2(-14.0, -R - 11.0), Vector2(-14.0, -R + 5.0)]), Color(1.0, 0.95, 0.5), 2.5)
		shape(PackedVector2Array([Vector2(0.0, -R - 2.0), Vector2(14.0, -R - 11.0), Vector2(14.0, -R + 5.0)]), Color(1.0, 0.95, 0.5), 2.5)
		draw_circle(Vector2(0.0, -R - 2.0), 5.0, INK)
		draw_circle(Vector2(0.0, -R - 2.0), 3.4, Color(0.4, 0.75, 1.0))


func draw_player_at(px: float) -> void:
	var sk: Dictionary = skins[skin]
	var body: Color = sk["c"]
	var belly: Color = sk["l"]
	var stretch: float = clampf(absf(vel.y) / 2600.0, 0.0, 0.28)
	var sy: float = 1.0 + stretch - squash
	var sx: float = 1.0 - stretch * 0.6 + squash * 0.9
	xf(Vector2(px, pos.y), 0.0, Vector2(sx, sy))
	draw_accessory(skin, body)
	shape(circle_pts(R, 22, boil * 5, 0.8), body, 3.5)
	draw_circle(Vector2(0.0, 6.0), 9.0, belly)
	draw_circle(Vector2(-11.0, 3.0), 3.4, Color(1.0, 0.4, 0.5, 0.7))
	draw_circle(Vector2(11.0, 3.0), 3.4, Color(1.0, 0.4, 0.5, 0.7))
	var lx: float = clampf(vel.x / 200.0, -1.0, 1.0) * 1.8
	var ly: float = clampf(vel.y / 600.0, -1.0, 1.0) * 1.5
	for sgn in [-1.0, 1.0]:
		draw_circle(Vector2(7.0 * sgn, -4.0), 6.4, INK)
		draw_circle(Vector2(7.0 * sgn, -4.0), 5.2, Color(1.0, 1.0, 1.0))
		draw_circle(Vector2(7.0 * sgn + lx, -4.0 + ly), 2.6, INK)
	if vel.y < 0.0:
		draw_arc(Vector2(0.0, 3.0), 6.0, 0.25, PI - 0.25, 8, INK, 2.5)
	else:
		draw_circle(Vector2(0.0, 9.0), 3.0, INK)
	if shield:
		var pulse: float = 0.5 + 0.5 * sin(time * 8.0)
		draw_circle(Vector2.ZERO, R + 9.0, Color(0.5, 0.78, 1.0, 0.22 + 0.1 * pulse))
		draw_arc(Vector2.ZERO, R + 9.0, 0.0, TAU, 28, Color(INK.r, INK.g, INK.b, 0.7), 3.5)
		draw_arc(Vector2.ZERO, R + 9.0, 0.0, TAU, 28, Color(0.7, 0.9, 1.0, 0.9), 1.8)
		draw_arc(Vector2.ZERO, R + 5.0, 3.6, 4.5, 6, Color(1.0, 1.0, 1.0, 0.9), 2.5)
	if magnet_t > 0.0:
		var mr: float = 52.0 + 10.0 * sin(time * 6.0)
		draw_arc(Vector2.ZERO, mr, 0.0, TAU, 30, Color(1.0, 0.5, 0.6, 0.3), 3.0)


func draw_particles() -> void:
	for q in particles:
		var a: float = clampf(float(q["life"]) / 0.35, 0.0, 1.0)
		var c: Color = q["c"]
		c.a = a
		var sz: float = q["sz"]
		xf(q["p"], float(q["rot"]) + float(q["life"]) * 6.0)
		var kind: int = q["kind"]
		if kind == 1:
			draw_rect(Rect2(-sz, -sz * 0.6, sz * 2.0, sz * 1.2), c)
		elif kind == 2:
			draw_line(Vector2(-sz, 0.0), Vector2(sz, 0.0), c, 2.5)
			draw_line(Vector2(0.0, -sz), Vector2(0.0, sz), c, 2.5)
		else:
			draw_circle(Vector2.ZERO, sz * 0.7, c)


func draw_popups() -> void:
	for pp in popups:
		var t: float = pp["t"]
		var p: Vector2 = pp["p"]
		p.y -= 40.0 * t
		var a: float = clampf(1.0 - (t - 0.7) / 0.4, 0.0, 1.0)
		var s: float = 1.0 + maxf(0.0, 0.3 - t) * 2.0
		xf(p, pp["rot"], Vector2(s, s))
		label(pp["s"], 0.0, 0.0, 26, pp["c"], true, a)


func draw_net() -> void:
	if net_t <= 0.0:
		return
	xc()
	var t: float = net_t / 0.7
	var pts := PackedVector2Array()
	for i in range(25):
		var x: float = W * float(i) / 24.0
		var bow: float = 70.0 * t * sin(PI * float(i) / 24.0)
		pts.append(Vector2(x, vh - 8.0 - bow + sin(float(i) * 1.1 + time * 30.0) * 3.0 * t))
	draw_polyline(pts, INK, 18.0, true)
	draw_polyline(pts, Color(1.0, 0.45, 0.55), 11.0, true)
	draw_polyline(pts, Color(1.0, 0.8, 0.85), 3.0, true)


# ---------------------------------------------------------------- panel samping

func draw_panels() -> void:
	if ox < 4.0:
		return
	var f: float = zone_f(height_f())
	var cols: Array = sky_colors(f)
	var top: Color = Color(cols[0]).darkened(0.1)
	var bot: Color = Color(cols[1]).darkened(0.1)
	xs()
	var lq := PackedVector2Array([Vector2(0.0, 0.0), Vector2(ox, 0.0), Vector2(ox, vh), Vector2(0.0, vh)])
	var rq := PackedVector2Array([Vector2(ox + W, 0.0), Vector2(vw, 0.0), Vector2(vw, vh), Vector2(ox + W, vh)])
	draw_polygon(lq, PackedColorArray([top, top, bot, bot]))
	draw_polygon(rq, PackedColorArray([top, top, bot, bot]))
	draw_side(0.0, ox, 0, f)
	draw_side(ox + W, ox, 1, f)
	# bingkai panggung dan bendera kecil
	xs()
	for i in range(2):
		var ex: float = ox if i == 0 else ox + W
		draw_line(Vector2(ex, 0.0), Vector2(ex, vh), INK, 7.0)
		draw_line(Vector2(ex + (-5.0 if i == 0 else 5.0), 0.0), Vector2(ex + (-5.0 if i == 0 else 5.0), vh), Color(1.0, 0.95, 0.8, 0.5), 3.0)
		var dirx: float = -1.0 if i == 0 else 1.0
		var n: int = int(vh / 44.0) + 1
		var fcols: Array = [Color(1.0, 0.45, 0.4), Color(1.0, 0.85, 0.3), Color(0.5, 0.85, 0.5), Color(0.45, 0.75, 1.0), Color(0.9, 0.55, 0.9)]
		for j in range(n):
			var fy: float = 14.0 + float(j) * 44.0
			var sw: float = sin(time * 2.5 + float(j) * 0.9 + float(i)) * 3.0
			shape(PackedVector2Array([Vector2(ex, fy), Vector2(ex + dirx * 20.0, fy + 11.0 + sw), Vector2(ex, fy + 22.0)]), fcols[j % 5], 2.0)


func draw_side(x0: float, pw: float, side: int, f: float) -> void:
	var gy: float = GROUND_Y - cam_y
	if pw >= 130.0:
		if f < 2.0:
			draw_side_ground(x0, pw, side, gy)
		draw_side_deco(x0, pw, side)


func draw_side_ground(x0: float, pw: float, side: int, gy: float) -> void:
	if gy > vh + 160.0:
		return
	xs()
	# bukit di belakang
	var hp := PackedVector2Array()
	var steps: int = int(pw / 24.0) + 1
	for i in range(steps + 1):
		var hx: float = x0 + pw * float(i) / float(steps)
		hp.append(Vector2(hx, gy - 40.0 - 34.0 * sin(hx * 0.011 + float(side) * 2.0) - 12.0 * jit(i, side)))
	hp.append(Vector2(x0 + pw, gy + 10.0))
	hp.append(Vector2(x0, gy + 10.0))
	shape(hp, Color(0.58, 0.8, 0.52), 3.0)
	# pohon dan semak
	var n: int = int(pw / 95.0) + 1
	for i in range(n):
		var sd: int = i * 11 + side * 37
		var px: float = x0 + 56.0 + (float(i) + 0.5 + jit(sd, 1) * 0.3) * (pw - 112.0) / float(n)
		var opts: Array = [0, 1, 2, 0, 3]
		var kind: int = opts[int((jit(sd, 3) * 0.5 + 0.5) * 5.0) % 5]
		deco(kind, Vector2(px, gy + 4.0), 0.9 + (jit(sd, 4) * 0.5 + 0.5) * 0.5, sd)
	# tanah
	xs()
	if gy < vh + 20.0:
		shape(wob_rect(x0 - 6.0, gy, pw + 12.0, vh - gy + 60.0, boil * 11 + side, 1.4), Color(0.58, 0.38, 0.26))
		shape(wob_rect(x0 - 6.0, gy, pw + 12.0, 14.0, boil * 11 + 3 + side, 1.2), Color(0.45, 0.78, 0.32))


func deco_options(z: int) -> Array:
	if z == 0:
		return [4, 6, 8, 4]
	if z == 1:
		return [4, 5, 6, 5, 4]
	if z == 2:
		return [7, 9, 8, 7, 6]
	if z == 3:
		return [10, 11, 12, 9, 10]
	return [13, 14, 15, 16, 10]


func draw_side_deco(x0: float, pw: float, side: int) -> void:
	for layer in range(2):
		var f: float = 0.5 if layer == 0 else 0.85
		var stp: float = 170.0 if layer == 0 else 230.0
		var c0: int = maxi(1, int(floorf((GROUND_Y - (cam_y * f + vh + 90.0)) / stp)))
		var c1: int = int(ceilf((GROUND_Y - (cam_y * f - 90.0)) / stp))
		for c in range(c0, c1 + 1):
			var sd: int = c * 7 + layer * 131 + side * 53
			if jit(sd, 1) < -0.25:
				continue
			var ly: float = GROUND_Y - float(c) * stp
			var sy: float = ly - cam_y * f
			var px: float = x0 + 58.0 + (jit(sd, 2) * 0.5 + 0.5) * maxf(10.0, pw - 116.0)
			var a_eq: float = float(c) * stp / 10.0 / f
			var z: int = zone_of(a_eq)
			var opts: Array = deco_options(z)
			var kind: int = opts[int((jit(sd, 3) * 0.5 + 0.5) * float(opts.size())) % opts.size()]
			var sc: float = 0.8 + (jit(sd, 4) * 0.5 + 0.5) * 0.6
			if layer == 0:
				sc *= 0.75
			deco(kind, Vector2(px, sy), sc, sd)


# Satu fungsi untuk semua hiasan samping. Titik asal: dasar (pohon dll) atau tengah (benda terbang).
func deco(kind: int, p: Vector2, s: float, sd: int) -> void:
	xl(p, 0.0, s)
	if kind == 0:
		draw_line(Vector2(0.0, 0.0), Vector2(0.0, -34.0), INK, 12.0)
		draw_line(Vector2(0.0, 0.0), Vector2(0.0, -34.0), Color(0.5, 0.34, 0.22), 7.0)
		var cs: Array = [Vector2(-14.0, -44.0), Vector2(14.0, -44.0), Vector2(0.0, -62.0)]
		for c in cs:
			draw_circle(c, 23.0, INK)
		for c in cs:
			draw_circle(c, 20.0, Color(0.38, 0.72, 0.4))
		draw_circle(Vector2(-6.0, -66.0), 7.0, Color(0.55, 0.85, 0.5))
	elif kind == 1:
		var bs: Array = [Vector2(-16.0, -10.0), Vector2(16.0, -10.0), Vector2(0.0, -18.0)]
		for c in bs:
			draw_circle(c, 17.0, INK)
		for c in bs:
			draw_circle(c, 14.0, Color(0.34, 0.68, 0.38))
	elif kind == 2:
		var pc: Array = [Color(1.0, 0.5, 0.55), Color(1.0, 0.85, 0.3), Color(0.9, 0.6, 1.0)]
		for i in range(3):
			var fx: float = -16.0 + float(i) * 16.0
			var fh: float = 18.0 + float(i % 2) * 8.0
			draw_line(Vector2(fx, 0.0), Vector2(fx, -fh), INK, 3.0)
			draw_circle(Vector2(fx, -fh - 3.0), 8.0, INK)
			draw_circle(Vector2(fx, -fh - 3.0), 6.0, pc[i])
			draw_circle(Vector2(fx, -fh - 3.0), 2.4, Color(1.0, 0.95, 0.6))
	elif kind == 3:
		shape(PackedVector2Array([Vector2(-16.0, 0.0), Vector2(-9.0, -66.0), Vector2(9.0, -66.0), Vector2(16.0, 0.0)]), Color(0.96, 0.9, 0.78), 3.0)
		shape(PackedVector2Array([Vector2(-12.0, -66.0), Vector2(0.0, -82.0), Vector2(12.0, -66.0)]), Color(0.88, 0.35, 0.3), 3.0)
		for i in range(4):
			var a: float = time * 0.8 + float(i) * PI * 0.5
			var tip := Vector2(cos(a), sin(a)) * 36.0
			draw_line(Vector2(0.0, -62.0), Vector2(0.0, -62.0) + tip, INK, 8.0)
			draw_line(Vector2(0.0, -62.0), Vector2(0.0, -62.0) + tip, Color(1.0, 0.97, 0.88), 4.5)
		draw_circle(Vector2(0.0, -62.0), 5.0, INK)
	elif kind == 4 or kind == 7:
		var fill := Color(1.0, 1.0, 1.0, 0.92)
		if kind == 7:
			fill = Color(1.0, 0.85, 0.75, 0.92)
		draw_cloud_shape(Vector2(-27.0, 0.0), 1.0, fill, Color(INK.r, INK.g, INK.b, 0.5))
	elif kind == 5:
		var by: float = sin(time * 1.2 + float(sd)) * 6.0
		xl(p + Vector2(0.0, by), 0.0, s)
		for i in range(2):
			var bx: float = -14.0 + float(i) * 28.0
			draw_line(Vector2(bx, 22.0), Vector2(bx * 0.5, 44.0), INK, 2.5)
		shape(ellipse_pts(26.0, 32.0, 18, sd % 7, 0.6), Color(0.92, 0.35, 0.38), 3.0)
		draw_colored_polygon(ellipse_pts(9.0, 31.0, 14, 1, 0.2), Color(1.0, 0.85, 0.3))
		shape(wob_rect(-9.0, 44.0, 18.0, 13.0, sd % 5, 0.5), Color(0.62, 0.42, 0.26), 2.5)
	elif kind == 6:
		for i in range(3):
			var bo := Vector2(float(i - 1) * 26.0, absf(float(i - 1)) * 10.0)
			var fl: float = sin(time * 5.0 + float(i) + float(sd)) * 4.0
			draw_polyline(PackedVector2Array([bo + Vector2(-9.0, -4.0 - fl), bo, bo + Vector2(9.0, -4.0 - fl)]), INK, 3.0, true)
	elif kind == 8:
		var sw: float = sin(time * 1.6 + float(sd)) * 0.15
		xl(p, sw, s)
		shape(PackedVector2Array([Vector2(0.0, -26.0), Vector2(16.0, 0.0), Vector2(0.0, 26.0), Vector2(-16.0, 0.0)]), Color(1.0, 0.55, 0.4), 3.0)
		draw_colored_polygon(PackedVector2Array([Vector2(0.0, -26.0), Vector2(16.0, 0.0), Vector2(0.0, 0.0)]), Color(1.0, 0.85, 0.3))
		draw_line(Vector2(0.0, -26.0), Vector2(0.0, 26.0), INK, 2.0)
		draw_line(Vector2(-16.0, 0.0), Vector2(16.0, 0.0), INK, 2.0)
		var tail := PackedVector2Array()
		for i in range(7):
			tail.append(Vector2(sin(time * 3.0 + float(i)) * 5.0, 26.0 + float(i) * 7.0))
		draw_polyline(tail, INK, 2.5, true)
	elif kind == 9:
		var sw2: float = sin(time * 1.8 + float(sd)) * 0.12
		xl(p, sw2, s)
		draw_circle(Vector2(0.0, 6.0), 30.0, Color(1.0, 0.8, 0.3, 0.18))
		draw_line(Vector2(0.0, -28.0), Vector2(0.0, -18.0), INK, 2.5)
		shape(ellipse_pts(14.0, 18.0, 14, sd % 5, 0.4), Color(0.95, 0.35, 0.3), 3.0)
		draw_line(Vector2(-14.0, 0.0), Vector2(14.0, 0.0), Color(1.0, 0.85, 0.4), 2.0)
		draw_line(Vector2(0.0, 18.0), Vector2(0.0, 30.0), Color(1.0, 0.85, 0.4), 3.0)
	elif kind == 10:
		for i in range(3):
			var so := Vector2(float(i - 1) * 24.0, float((i * 7) % 3) * 12.0 - 10.0)
			var tw: float = 0.5 + 0.5 * sin(time * 2.5 + float(i) + float(sd))
			var c := Color(1.0, 0.97, 0.78, 0.4 + 0.6 * tw)
			var r: float = 5.0 + 3.0 * tw
			draw_line(so + Vector2(-r, 0.0), so + Vector2(r, 0.0), c, 2.5)
			draw_line(so + Vector2(0.0, -r), so + Vector2(0.0, r), c, 2.5)
	elif kind == 11:
		draw_circle(Vector2.ZERO, 40.0, Color(1.0, 0.95, 0.7, 0.14))
		draw_circle(Vector2.ZERO, 27.0, INK)
		draw_circle(Vector2.ZERO, 24.0, Color(1.0, 0.96, 0.78))
		draw_circle(Vector2(-7.0, -5.0), 4.5, Color(0.88, 0.82, 0.62))
		draw_circle(Vector2(8.0, 7.0), 3.5, Color(0.88, 0.82, 0.62))
	elif kind == 12:
		for i in range(6):
			var fo := Vector2(sin(time * 0.9 + float(i) * 2.0 + float(sd)) * 26.0, cos(time * 0.7 + float(i) * 1.7) * 20.0)
			var fl2: float = 0.4 + 0.6 * absf(sin(time * 2.2 + float(i)))
			draw_circle(fo, 7.0, Color(1.0, 0.95, 0.4, 0.2 * fl2))
			draw_circle(fo, 2.6, Color(1.0, 0.97, 0.6, fl2))
	elif kind == 13:
		var pcs: Array = [Color(0.9, 0.55, 0.45), Color(0.5, 0.75, 0.95), Color(0.6, 0.85, 0.55), Color(0.85, 0.65, 0.95)]
		var pcol: Color = pcs[sd % 4]
		draw_circle(Vector2.ZERO, 31.0, INK)
		draw_circle(Vector2.ZERO, 28.0, pcol)
		draw_arc(Vector2(0.0, -6.0), 20.0, 0.3, 2.8, 10, pcol.lightened(0.3), 5.0)
		var ring := PackedVector2Array()
		for i in range(25):
			var ra: float = TAU * float(i) / 24.0
			ring.append(Vector2(cos(ra) * 50.0, sin(ra) * 11.0).rotated(-0.4))
		draw_polyline(ring, INK, 7.0, true)
		draw_polyline(ring, Color(1.0, 0.92, 0.7), 3.5, true)
	elif kind == 14:
		shape(circle_pts(17.0, 10, sd % 9, 4.0), Color(0.62, 0.6, 0.7), 3.0)
		draw_circle(Vector2(-5.0, -3.0), 3.5, Color(0.48, 0.46, 0.58))
		draw_circle(Vector2(6.0, 5.0), 2.5, Color(0.48, 0.46, 0.58))
	elif kind == 15:
		xl(p, sin(time * 0.6 + float(sd)) * 0.3, s)
		shape(wob_rect(-9.0, -9.0, 18.0, 18.0, sd % 5, 0.4), Color(0.85, 0.85, 0.9), 3.0)
		shape(wob_rect(-34.0, -6.0, 22.0, 12.0, 2, 0.4), Color(0.4, 0.6, 0.95), 2.5)
		shape(wob_rect(12.0, -6.0, 22.0, 12.0, 3, 0.4), Color(0.4, 0.6, 0.95), 2.5)
		draw_line(Vector2(0.0, -9.0), Vector2(0.0, -20.0), INK, 2.5)
		draw_circle(Vector2(0.0, -21.0), 3.0, Color(1.0, 0.4, 0.4))
	elif kind == 16:
		var tl: float = 70.0
		draw_polygon(PackedVector2Array([Vector2(0.0, -7.0), Vector2(tl, -22.0), Vector2(tl, 22.0), Vector2(0.0, 7.0)]), PackedColorArray([Color(1.0, 0.95, 0.7, 0.8), Color(1.0, 0.6, 0.4, 0.0), Color(1.0, 0.6, 0.4, 0.0), Color(1.0, 0.95, 0.7, 0.8)]))
		draw_circle(Vector2.ZERO, 10.0, INK)
		draw_circle(Vector2.ZERO, 7.5, Color(1.0, 0.97, 0.85))


func draw_cards() -> void:
	if ox < 190.0:
		return
	xs()
	var cw: float = 150.0
	var lx: float = (ox - cw) * 0.5
	var rx: float = ox + W + (ox - cw) * 0.5
	# kartu kiri: kontrol
	shape(wob_rect(lx, 70.0, cw, 290.0, boil * 3, 1.2), PAPER, 3.5)
	plain("KONTROL", lx + cw * 0.5, 100.0, 20, INK, true)
	draw_line(Vector2(lx + 14.0, 110.0), Vector2(lx + cw - 14.0, 110.0), INK, 2.0)
	var lines: Array = ["A / D atau panah", "Tahan klik: geser", "P atau Esc: jeda", "M: musik", "F / F11: layar penuh", "Spasi: mulai"]
	for i in range(lines.size()):
		plain(str(lines[i]), lx + 14.0, 136.0 + float(i) * 26.0, 13, Color(0.3, 0.22, 0.3))
	plain("REKOR", lx + cw * 0.5, 318.0, 14, Color(0.6, 0.4, 0.35), true)
	plain(str(best), lx + cw * 0.5, 346.0, 28, INK, true)
	# kartu kanan: meteran ketinggian
	shape(wob_rect(rx, 70.0, cw, 520.0, boil * 3 + 1, 1.2), PAPER, 3.5)
	plain("KETINGGIAN", rx + cw * 0.5, 100.0, 20, INK, true)
	draw_line(Vector2(rx + 14.0, 110.0), Vector2(rx + cw - 14.0, 110.0), INK, 2.0)
	var mx: float = rx + 30.0
	for z in range(5):
		var seg_top: float = 130.0 + float(4 - z) * 72.0
		var ct: Color = sky_top[z]
		var cb: Color = sky_bot[z]
		draw_polygon(PackedVector2Array([Vector2(mx - 10.0, seg_top), Vector2(mx + 10.0, seg_top), Vector2(mx + 10.0, seg_top + 72.0), Vector2(mx - 10.0, seg_top + 72.0)]), PackedColorArray([ct, ct, cb, cb]))
		plain(str(ZONE_SHORT[z]), mx + 20.0, seg_top + 42.0, 15, Color(0.3, 0.22, 0.3))
	var o := wob_rect(mx - 10.0, 130.0, 20.0, 360.0, 3, 0.5)
	o.append(o[0])
	draw_polyline(o, INK, 3.0, true)
	var hm: float = height_f()
	var z2: int = zone_of(hm)
	var zf: float = float(z2)
	if z2 >= 4:
		zf += clampf((hm - 1000.0) / 500.0, 0.0, 0.98)
	else:
		zf = zone_f(hm)
	var my: float = 490.0 - zf * 72.0
	var sk: Dictionary = skins[skin]
	var sc: Color = sk["c"]
	draw_circle(Vector2(mx, my), 11.0, INK)
	draw_circle(Vector2(mx, my), 8.5, sc)
	plain(str(int(hm)) + " m", rx + cw * 0.5, 530.0, 26, INK, true)
	plain(ZONE_NAMES[z2], rx + cw * 0.5, 556.0, 11, Color(0.5, 0.35, 0.35), true)


func draw_vignette() -> void:
	xs()
	var dark := Color(0.12, 0.05, 0.1, 0.3)
	var clear := Color(0.12, 0.05, 0.1, 0.0)
	draw_polygon(PackedVector2Array([Vector2(0.0, 0.0), Vector2(100.0, 0.0), Vector2(100.0, vh), Vector2(0.0, vh)]), PackedColorArray([dark, clear, clear, dark]))
	draw_polygon(PackedVector2Array([Vector2(vw - 100.0, 0.0), Vector2(vw, 0.0), Vector2(vw, vh), Vector2(vw - 100.0, vh)]), PackedColorArray([clear, dark, dark, clear]))
	var gc := Color(INK.r, INK.g, INK.b, 0.06)
	var gox: float = float(boil) * 0.137
	var goy: float = float(boil) * 0.071
	for g in grain:
		var gp: Vector2 = g
		draw_circle(Vector2(fposmod(gp.x + gox, 1.0) * vw, fposmod(gp.y + goy, 1.0) * vh), 1.2, gc)


# ---------------------------------------------------------------- UI

func draw_hud() -> void:
	xc()
	label(str(score()), 16.0, 46.0, 40, Color(1.0, 0.96, 0.8))
	label(str(height_m()) + " m", 18.0, 72.0, 20, Color(0.8, 0.95, 1.0))
	draw_set_transform(Vector2(ox + 26.0, 96.0), 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 10.0, INK)
	draw_circle(Vector2.ZERO, 7.5, Color(1.0, 0.82, 0.2))
	xc()
	label("x" + str(coins), 42.0, 103.0, 20, Color(1.0, 0.9, 0.5))
	for i in range(MAX_LIVES):
		var cx: float = W - 32.0 - float(i) * 36.0
		draw_set_transform(Vector2(ox + cx, 32.0), 0.0, Vector2.ONE)
		var hp := heart_pts(0.85)
		if i < lives:
			shape(hp, Color(1.0, 0.35, 0.45), 3.0)
		else:
			var o := PackedVector2Array(hp)
			o.append(hp[0])
			draw_polyline(o, Color(INK.r, INK.g, INK.b, 0.55), 2.0, true)
	xc()
	label("Rekor " + str(best), W - 68.0, 70.0, 16, Color(1.0, 0.95, 0.8), true)
	# power-up aktif
	var py: float = 100.0
	if prop_t > 0.0:
		hud_chip("prop", py, prop_t / PROP_TIME)
		py += 30.0
	if magnet_t > 0.0:
		hud_chip("magnet", py, magnet_t / MAGNET_TIME)
		py += 30.0
	if shield:
		hud_chip("shield", py, 1.0)
	if banner_t > 0.0 and state == "play":
		var u: float = clampf(banner_t / 2.4, 0.0, 1.0)
		var a: float = clampf(minf(u * 4.0, (1.0 - u) * 6.0 + 0.2), 0.0, 1.0)
		draw_set_transform(Vector2(ox + W * 0.5, 200.0), sin(time * 2.0) * 0.03, Vector2.ONE)
		label(banner_text, 0.0, 0.0, 40, Color(1.0, 0.85, 0.3), true, a)
		label(banner_sub, 0.0, 30.0, 20, Color(0.8, 0.95, 1.0), true, a)
		xc()
	if state == "play" and not paused and height_m() < 12:
		label("Geser mouse, A / D, atau panah", W * 0.5, vh - 110.0, 20, PAPER, true)


func hud_chip(kind: String, y: float, frac: float) -> void:
	draw_set_transform(Vector2(ox + W - 100.0, y), 0.0, Vector2.ONE)
	shape(wob_rect(0.0, 2.0, 84.0, 16.0, boil, 0.6), PAPER, 2.5)
	var col := Color(1.0, 0.55, 0.5)
	var nm := "BALING"
	if kind == "magnet":
		col = Color(0.9, 0.35, 0.45)
		nm = "MAGNET"
	elif kind == "shield":
		col = Color(0.45, 0.72, 1.0)
		nm = "TAMENG"
	draw_rect(Rect2(4.0, 6.0, 76.0 * clampf(frac, 0.0, 1.0), 8.0), col)
	var tw: float = font.get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	label(nm, -tw - 8.0, 16.0, 12, PAPER)
	xc()


func title_text(s: String, y: float, size: int) -> void:
	var total: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x: float = (W - total) * 0.5
	var cols: Array = [Color(1.0, 0.55, 0.35), Color(1.0, 0.85, 0.3), Color(0.5, 0.85, 0.5), Color(0.45, 0.75, 1.0), Color(0.9, 0.55, 0.9)]
	for i in range(s.length()):
		var ch: String = s.substr(i, 1)
		var cw: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var oy: float = sin(time * 4.0 + float(i) * 0.7) * 7.0
		var rot: float = sin(time * 3.0 + float(i) * 1.3) * 0.08
		draw_set_transform(Vector2(ox + x + cw * 0.5, y + oy), rot, Vector2.ONE)
		draw_string_outline(font, Vector2(-cw * 0.5, 0.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14, INK)
		draw_string(font, Vector2(-cw * 0.5, 0.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, cols[i % cols.size()])
		x += cw
	xc()


func draw_arrow(cx: float, cy: float, dir: float, active: bool) -> void:
	var pts := PackedVector2Array([Vector2(cx + dir * 14.0, cy - 18.0), Vector2(cx - dir * 14.0, cy), Vector2(cx + dir * 14.0, cy + 18.0)])
	var col := Color(1.0, 0.85, 0.3)
	if not active:
		col = Color(0.8, 0.75, 0.7)
	shape(pts, col, 3.0)


func draw_title() -> void:
	xc()
	draw_rect(Rect2(-ox, 0.0, vw, vh), Color(0.12, 0.05, 0.1, 0.12))
	title_text("SKY", 190.0, 92)
	title_text("HOP!", 286.0, 92)
	label("Pantul. Naik. Bangkit lagi!", W * 0.5, 340.0, 22, PAPER, true)
	shape(wob_rect(110.0, 370.0, 260.0, 42.0, boil * 3, 1.2), PAPER, 3.0)
	if int(time * 2.0) % 2 == 0:
		plain("Tekan SPASI atau klik", W * 0.5, 399.0, 22, INK, true)
	else:
		plain("Tekan SPASI atau klik", W * 0.5, 401.0, 22, Color(0.7, 0.3, 0.25), true)
	# pilih skin
	var sk: Dictionary = skins[skin]
	var ok: bool = skin_unlocked(skin)
	draw_arrow(100.0, 500.0, -1.0, true)
	draw_arrow(380.0, 500.0, 1.0, true)
	label(str(sk["name"]), W * 0.5, 490.0, 26, Color(1.0, 0.95, 0.8), true)
	if not ok:
		label("Terkunci: butuh skor " + str(sk["need"]), W * 0.5, 516.0, 16, Color(1.0, 0.6, 0.55), true)
	else:
		label("A / D untuk ganti karakter", W * 0.5, 516.0, 14, PAPER, true)
	if best > 0:
		label("Rekor: " + str(best), W * 0.5, 440.0, 22, Color(0.8, 0.95, 1.0), true)
	label("Esc / F: layar penuh   M: musik   P: jeda", W * 0.5, vh - 22.0, 14, PAPER, true)


func draw_over() -> void:
	xs()
	draw_rect(Rect2(0.0, 0.0, vw, vh), Color(0.08, 0.03, 0.12, 0.45))
	xc()
	var slide: float = clampf(over_t / 0.35, 0.0, 1.0)
	draw_set_transform(Vector2(ox, (1.0 - slide) * -500.0), 0.0, Vector2.ONE)
	draw_colored_polygon(wob_rect(66.0, 156.0, 360.0, 370.0, 4, 1.5), Color(0.0, 0.0, 0.0, 0.25))
	shape(wob_rect(60.0, 150.0, 360.0, 370.0, boil * 3, 1.5), PAPER, 4.0)
	label("SPLAT!", W * 0.5, 220.0, 56, Color(1.0, 0.4, 0.4), true)
	label("Skor  " + str(score()), W * 0.5, 280.0, 34, Color(1.0, 0.85, 0.3), true)
	plain("Tinggi " + str(height_m()) + " m   Koin " + str(coins), W * 0.5, 318.0, 20, INK, true)
	plain("Musuh diinjak " + str(stomps) + "   Zona " + str(zone_of(height_f()) + 1), W * 0.5, 346.0, 18, INK, true)
	if new_record:
		label("REKOR BARU!", W * 0.5, 396.0, 30, Color(0.5, 0.9, 0.55), true)
	else:
		plain("Rekor " + str(best), W * 0.5, 396.0, 22, INK, true)
	if unlocked_msg != "":
		label("Karakter baru: " + unlocked_msg + "!", W * 0.5, 436.0, 22, Color(0.55, 0.75, 1.0), true)
	if over_t > 0.8 and int(time * 2.0) % 2 == 0:
		plain("SPASI / klik: pantul lagi", W * 0.5, 490.0, 20, Color(0.7, 0.3, 0.25), true)
	xc()


func draw_pause() -> void:
	xs()
	draw_rect(Rect2(0.0, 0.0, vw, vh), Color(0.08, 0.03, 0.12, 0.6))
	xc()
	label("JEDA", W * 0.5, 380.0, 64, Color(1.0, 0.85, 0.3), true)
	label("Tekan P atau klik untuk lanjut", W * 0.5, 426.0, 20, Color(1.0, 1.0, 1.0), true)
