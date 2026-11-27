extends Node2D
## SKY HOP
## Game pantul vertikal bergaya gambar tangan untuk Godot 4.2+.
## Semua gambar dan suara dibuat lewat kode, jadi project ini tidak butuh file aset.
##
## Cara main: pantul terus ke atas, injak musuh dari atas, ambil koin.
## Kalau jatuh, kamu dapat Bounce Back: pantulan besar dari jaring karet.
## Nyawa habis = game over.

const W := 480.0
const H := 800.0
const R := 18.0
const GRAV := 1500.0
const JUMP_V := 720.0
const SPRING_V := 1080.0
const BOUNCE_BACK_V := 1500.0
const GROUND_Y := 720.0
const MAX_LIVES := 3

const INK := Color(0.17, 0.13, 0.25)
const PAPER := Color(1.0, 0.96, 0.86)

var state := "title"
var paused := false
var time := 0.0
var boil := 0
var font: Font

var pos := Vector2.ZERO
var vel := Vector2.ZERO
var squash := 0.0
var invuln := 0.0
var combo := 0
var lives := MAX_LIVES
var coins := 0
var bonus := 0
var best := 0
var new_record := false

var cam_y := 0.0
var top_y := 0.0
var gen_y := 0.0
var last_type := "normal"
var shake := 0.0
var shake_off := Vector2.ZERO
var hitstop := 0.0
var net_t := 0.0
var over_t := 0.0

var platforms: Array = []
var birds: Array = []
var particles: Array = []
var popups: Array = []
var clouds: Array = []
var sfx_bank := {}
var players: Array = []


# ---------------------------------------------------------------- setup

func _ready() -> void:
	randomize()
	font = ThemeDB.fallback_font
	# Mau font sendiri? Taruh file TTF di res://fonts/main.ttf, otomatis dipakai.
	if ResourceLoader.exists("res://fonts/main.ttf"):
		var custom := load("res://fonts/main.ttf") as Font
		if custom != null:
			font = custom
	load_best()
	for i in range(12):
		clouds.append({
			"x": randf() * W,
			"y": randf() * (H + 240.0),
			"s": randf_range(0.7, 1.5),
			"f": randf_range(0.15, 0.4),
		})
	for i in range(6):
		var pl := AudioStreamPlayer.new()
		pl.volume_db = -6.0
		add_child(pl)
		players.append(pl)
	build_sfx()
	reset_world()
	state = "title"


func reset_world() -> void:
	platforms.clear()
	birds.clear()
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
	combo = 0
	invuln = 0.0
	squash = 0.0
	shake = 0.0
	net_t = 0.0
	hitstop = 0.0
	new_record = false
	platforms.append(make_platform(-20.0, GROUND_Y, W + 40.0, "ground"))
	generate()


func start_game() -> void:
	paused = false
	reset_world()
	state = "play"
	play_sfx("bounce")


func make_platform(x: float, y: float, w: float, type: String) -> Dictionary:
	return {
		"x": x, "y": y, "w": w, "type": type,
		"vx": 0.0, "crumble": -1.0, "fall_v": 0.0, "broken": false,
		"spring": false, "spring_t": 0.0,
		"coin": false, "heart": false, "taken": false,
		"enemy": false, "en_x": 0.0, "en_dir": 1.0, "en_alive": true,
	}


func generate() -> void:
	while gen_y > cam_y - 300.0:
		var hm: float = maxf(0.0, (GROUND_Y - gen_y) / 10.0)
		var diff: float = clampf(hm / 500.0, 0.0, 1.0)
		gen_y -= randf_range(70.0, lerpf(110.0, 150.0, diff))
		var w: float = randf_range(lerpf(120.0, 82.0, diff), lerpf(150.0, 108.0, diff))
		var x: float = randf_range(10.0, W - w - 10.0)
		var r: float = randf()
		var kind := "normal"
		if diff > 0.06 and r < 0.10 + diff * 0.18:
			kind = "move"
		elif diff > 0.03 and r < 0.28 + diff * 0.10 and last_type != "crumble":
			kind = "crumble"
		last_type = kind
		var p := make_platform(x, gen_y, w, kind)
		if kind == "move":
			p["vx"] = randf_range(55.0, 105.0) * (1.0 if randf() < 0.5 else -1.0)
		if kind != "crumble" and randf() < 0.09:
			p["spring"] = true
		elif randf() < 0.45:
			p["coin"] = true
			if randf() < 0.05:
				p["heart"] = true
				p["coin"] = false
		if kind == "normal" and not p["spring"] and w >= 100.0 and diff > 0.1 and randf() < 0.16 + diff * 0.14:
			p["enemy"] = true
			p["en_x"] = w * 0.5
			p["en_dir"] = 1.0 if randf() < 0.5 else -1.0
			p["coin"] = false
			p["heart"] = false
		platforms.append(p)
		if diff > 0.3 and randf() < 0.07:
			birds.append({
				"x": randf_range(40.0, W - 40.0),
				"y": gen_y - 70.0,
				"vx": randf_range(70.0, 120.0) * (1.0 if randf() < 0.5 else -1.0),
				"t": randf() * 6.0,
				"alive": true,
			})


func cull() -> void:
	var limit: float = cam_y + H + 260.0
	for i in range(platforms.size() - 1, -1, -1):
		if platforms[i]["y"] > limit:
			platforms.remove_at(i)
	for i in range(birds.size() - 1, -1, -1):
		if birds[i]["y"] > limit or not birds[i]["alive"]:
			birds.remove_at(i)


# ---------------------------------------------------------------- loop

func _process(delta: float) -> void:
	if paused:
		queue_redraw()
		return
	time += delta
	boil = int(time * 7.0) % 3
	if state == "title":
		var s: float = sin(time * 3.0)
		pos = Vector2(W * 0.5, GROUND_Y - R - absf(s) * 150.0)
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
	vel.y += GRAV * delta
	pos += vel * delta
	if pos.x < -14.0:
		pos.x = W + 14.0
	elif pos.x > W + 14.0:
		pos.x = -14.0
	update_platforms(delta)
	update_birds(delta)
	if vel.y > 0.0:
		check_landing(prev_y)
	top_y = minf(top_y, pos.y)
	cam_y = minf(cam_y, pos.y - 300.0)
	generate()
	cull()
	check_things()
	if state != "play":
		return
	if pos.y > cam_y + H + 40.0:
		lose_life(true)
		if state != "play":
			return
	invuln = maxf(0.0, invuln - delta)
	squash = lerpf(squash, 0.0, 1.0 - exp(-10.0 * delta))
	if vel.y < -950.0 and randf() < 0.7:
		burst(pos + Vector2(0.0, 14.0), 1, [Color(1.0, 0.9, 0.5), Color(1.0, 0.6, 0.4)], 20.0, -30.0, 2)


func get_axis() -> float:
	var a := 0.0
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A):
		a -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D):
		a += 1.0
	if a == 0.0 and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var dx: float = get_global_mouse_position().x - pos.x
		if absf(dx) > 12.0:
			a = signf(dx)
	return a


func update_platforms(delta: float) -> void:
	for p in platforms:
		if p["type"] == "move" and not p["broken"]:
			p["x"] += p["vx"] * delta
			if p["x"] < 8.0:
				p["x"] = 8.0
				p["vx"] = absf(p["vx"])
			elif p["x"] + p["w"] > W - 8.0:
				p["x"] = W - 8.0 - p["w"]
				p["vx"] = -absf(p["vx"])
		if p["crumble"] > 0.0:
			p["crumble"] -= delta
			if p["crumble"] <= 0.0:
				p["broken"] = true
				p["crumble"] = -2.0
				burst(Vector2(p["x"] + p["w"] * 0.5, p["y"]), 10, [Color(0.9, 0.78, 0.55), Color(0.72, 0.55, 0.38)], 120.0, 40.0, 0)
				play_sfx("crumble")
		if p["broken"]:
			p["fall_v"] += 1200.0 * delta
			p["y"] += p["fall_v"] * delta
		p["spring_t"] = maxf(0.0, p["spring_t"] - delta)
		if p["enemy"] and p["en_alive"]:
			p["en_x"] += p["en_dir"] * 48.0 * delta
			if p["en_x"] < 18.0:
				p["en_x"] = 18.0
				p["en_dir"] = 1.0
			elif p["en_x"] > p["w"] - 18.0:
				p["en_x"] = p["w"] - 18.0
				p["en_dir"] = -1.0


func update_birds(delta: float) -> void:
	for b in birds:
		b["t"] += delta
		b["x"] += b["vx"] * delta
		if b["x"] < 24.0:
			b["x"] = 24.0
			b["vx"] = absf(b["vx"])
		elif b["x"] > W - 24.0:
			b["x"] = W - 24.0
			b["vx"] = -absf(b["vx"])


func check_landing(prev_y: float) -> void:
	var prev_bottom: float = prev_y + R
	var bottom: float = pos.y + R
	for p in platforms:
		if p["broken"]:
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


func check_things() -> void:
	for p in platforms:
		if p["broken"]:
			continue
		if (p["coin"] or p["heart"]) and not p["taken"]:
			var cp := Vector2(p["x"] + p["w"] * 0.5, p["y"] - 52.0)
			if pos.distance_to(cp) < R + 14.0:
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
		if p["enemy"] and p["en_alive"]:
			var ep := Vector2(p["x"] + p["en_x"], p["y"] - 17.0)
			if pos.distance_to(ep) < R + 15.0:
				if vel.y > 80.0 and pos.y < ep.y - 4.0:
					stomp(ep)
					p["en_alive"] = false
				elif invuln <= 0.0:
					lose_life(false)
					return
	for b in birds:
		if not b["alive"]:
			continue
		var bp := Vector2(b["x"], b["y"] + sin(b["t"] * 3.0) * 6.0)
		if pos.distance_to(bp) < R + 14.0:
			if vel.y > 80.0 and pos.y < bp.y - 3.0:
				stomp(bp)
				b["alive"] = false
			elif invuln <= 0.0:
				lose_life(false)
				return


func stomp(ep: Vector2) -> void:
	combo += 1
	var pts: int = 50 * combo
	bonus += pts
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


func lose_life(from_fall: bool) -> void:
	lives -= 1
	if lives <= 0:
		game_over()
		return
	invuln = 1.8
	shake = 14.0
	if from_fall:
		net_t = 0.7
		pos.y = cam_y + H - 30.0
		pos.x = clampf(pos.x, 40.0, W - 40.0)
		vel = Vector2(0.0, -BOUNCE_BACK_V)
		squash = 0.5
		combo = 0
		play_sfx("bounceback")
		popup_text("BOUNCE BACK!", Vector2(W * 0.5, cam_y + H - 170.0), Color(1.0, 0.85, 0.2))
		burst(Vector2(pos.x, cam_y + H - 10.0), 40, [Color(1.0, 0.45, 0.5), Color(1.0, 0.85, 0.3), Color(0.5, 0.85, 1.0), Color(1.0, 1.0, 1.0)], 380.0, 300.0, 1)
	else:
		vel.y = -620.0
		squash = 0.3
		play_sfx("hurt")
		popup_text("Aduh!", pos + Vector2(0.0, -34.0), Color(1.0, 0.55, 0.5))
		burst(pos, 12, [Color(1.0, 0.55, 0.35), Color(1.0, 0.8, 0.6)], 220.0, 100.0, 0)


func game_over() -> void:
	state = "over"
	over_t = 0.0
	if score() > best:
		best = score()
		new_record = true
		save_best()
	burst(pos, 40, [Color(1.0, 0.52, 0.35), Color(1.0, 0.8, 0.6), Color(1.0, 1.0, 1.0)], 340.0, 160.0, 1)
	shake = 16.0
	play_sfx("lose")


func height_m() -> int:
	return int(maxf(0.0, (GROUND_Y - R - top_y) / 10.0))


func score() -> int:
	return height_m() + bonus


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
		if popups[i]["t"] > 1.1:
			popups.remove_at(i)
	shake *= exp(-9.0 * delta)
	if shake < 0.2:
		shake = 0.0
	shake_off = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	net_t = maxf(0.0, net_t - delta)
	over_t += delta


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
	popups.append({"s": s, "p": p, "c": c, "t": 0.0})


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	var go := false
	var k := event as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.keycode == KEY_SPACE or k.keycode == KEY_ENTER or k.keycode == KEY_KP_ENTER:
			go = true
		if k.keycode == KEY_P and state == "play":
			paused = not paused
			return
	var m := event as InputEventMouseButton
	if m != null and m.pressed:
		go = true
	if not go:
		return
	if paused:
		paused = false
	elif state == "title":
		start_game()
	elif state == "over" and over_t > 0.7:
		start_game()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "play":
		paused = true


# ---------------------------------------------------------------- save / suara

func load_best() -> void:
	if FileAccess.file_exists("user://best.dat"):
		var f := FileAccess.open("user://best.dat", FileAccess.READ)
		if f != null:
			best = f.get_32()


func save_best() -> void:
	var f := FileAccess.open("user://best.dat", FileAccess.WRITE)
	if f != null:
		f.store_32(best)


func tone(f0: float, f1: float, dur: float, vol: float, wave: int = 0) -> AudioStreamWAV:
	var rate: int = 22050
	var n: int = int(float(rate) * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var phase: float = 0.0
	for i in range(n):
		var t: float = float(i) / float(n)
		phase += TAU * lerpf(f0, f1, t) / float(rate)
		var s: float = sin(phase)
		if wave == 1:
			s = 0.6 if s >= 0.0 else -0.6
		elif wave == 2:
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


# ---------------------------------------------------------------- helper gambar

func xf(p: Vector2, rot: float = 0.0, sc: Vector2 = Vector2.ONE) -> void:
	draw_set_transform(p + shake_off - Vector2(0.0, cam_y), rot, sc)


func xf_screen() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# Angka acak yang selalu sama untuk masukan yang sama (dipakai untuk goyangan garis).
func jit(i: int, k: int) -> float:
	var v: float = sin(float(i) * 12.9898 + float(k) * 78.233) * 43758.5453
	return (v - floorf(v)) * 2.0 - 1.0


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


# Bentuk berisi warna dengan garis tepi tinta tebal, seperti stiker.
func shape(pts: PackedVector2Array, fill: Color, width: float = 3.0) -> void:
	draw_colored_polygon(pts, fill)
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


# ---------------------------------------------------------------- gambar

func _draw() -> void:
	draw_sky()
	draw_hills()
	for p in platforms:
		draw_platform(p)
	for b in birds:
		if b["alive"]:
			draw_bird(b)
	draw_particles()
	if state != "over":
		draw_player()
	draw_popups()
	draw_net()
	xf_screen()
	if state == "title":
		draw_title()
	else:
		draw_hud()
		if state == "over":
			draw_over()
	if paused:
		draw_pause()


func draw_sky() -> void:
	xf_screen()
	var h: float = clampf(-cam_y / 7000.0, 0.0, 1.0)
	var c0 := Color(0.53, 0.82, 0.96)
	var c1 := Color(0.62, 0.42, 0.78)
	var c2 := Color(0.12, 0.09, 0.27)
	var top: Color
	if h < 0.5:
		top = c0.lerp(c1, h * 2.0)
	else:
		top = c1.lerp(c2, (h - 0.5) * 2.0)
	var bot: Color = top.lerp(Color(1.0, 0.9, 0.78), 0.55 * (1.0 - h))
	var quad := PackedVector2Array([Vector2(0.0, 0.0), Vector2(W, 0.0), Vector2(W, H), Vector2(0.0, H)])
	draw_polygon(quad, PackedColorArray([top, top, bot, bot]))
	# bintang muncul saat sudah tinggi
	var sa: float = clampf((h - 0.35) * 2.5, 0.0, 1.0)
	if sa > 0.0:
		for i in range(40):
			var sx: float = (jit(i, 1) * 0.5 + 0.5) * W
			var sy: float = fposmod((jit(i, 2) * 0.5 + 0.5) * H - cam_y * 0.12, H)
			var tw: float = 0.5 + 0.5 * sin(time * 2.0 + float(i))
			var sc := Color(1.0, 0.97, 0.8, sa * tw)
			draw_line(Vector2(sx - 3.0, sy), Vector2(sx + 3.0, sy), sc, 2.0)
			draw_line(Vector2(sx, sy - 3.0), Vector2(sx, sy + 3.0), sc, 2.0)
	# awan paralaks
	var ca: float = 1.0 - h * 0.85
	for c in clouds:
		var cy: float = fposmod(c["y"] - cam_y * c["f"], H + 240.0) - 120.0
		var cs: float = c["s"]
		var cx: float = c["x"]
		var puffs := [Vector2(0.0, 0.0), Vector2(26.0, -10.0), Vector2(54.0, 0.0), Vector2(26.0, 6.0)]
		var rads := [20.0, 26.0, 18.0, 20.0]
		for i in range(puffs.size()):
			draw_circle(Vector2(cx, cy) + puffs[i] * cs, (rads[i] + 3.0) * cs, Color(INK.r, INK.g, INK.b, 0.5 * ca))
		for i in range(puffs.size()):
			draw_circle(Vector2(cx, cy) + puffs[i] * cs, rads[i] * cs, Color(1.0, 1.0, 1.0, 0.9 * ca))


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
	var petals := [Color(1.0, 0.5, 0.55), Color(1.0, 0.85, 0.3), Color(0.9, 0.6, 1.0)]
	for i in range(6):
		var fx: float = 50.0 + float(i) * 78.0 + jit(i, 7) * 16.0
		draw_line(Vector2(fx, y + 2.0), Vector2(fx, y - 14.0), INK, 3.0)
		draw_circle(Vector2(fx, y - 17.0), 7.0, INK)
		draw_circle(Vector2(fx, y - 17.0), 5.0, petals[i % 3])
		draw_circle(Vector2(fx, y - 17.0), 2.0, Color(1.0, 0.95, 0.6))


func draw_platform(p: Dictionary) -> void:
	var kind: String = p["type"]
	if kind == "ground":
		draw_ground(p)
		return
	var x: float = p["x"]
	var y: float = p["y"]
	var w: float = p["w"]
	var k: int = (int(absf(y)) % 89) + boil * 13
	var off := Vector2.ZERO
	if kind == "crumble" and p["crumble"] > 0.0:
		off = Vector2(jit(int(time * 60.0), 3) * 2.5, 0.0)
	xf(off)
	var h := 20.0
	var body := Color(0.55, 0.36, 0.25)
	var topc := Color(0.45, 0.78, 0.32)
	if kind == "move":
		body = Color(0.33, 0.52, 0.86)
		topc = Color(0.55, 0.75, 1.0)
	elif kind == "crumble":
		body = Color(0.72, 0.55, 0.38)
		topc = Color(0.9, 0.78, 0.55)
	draw_colored_polygon(wob_rect(x + 5.0, y + 6.0, w, h, k, 1.5), Color(0.0, 0.0, 0.0, 0.18))
	shape(wob_rect(x, y, w, h, k, 1.6), body)
	shape(wob_rect(x, y, w, 8.0, k + 5, 1.2), topc)
	if kind == "normal":
		for i in range(int(w / 24.0)):
			var tx: float = x + 14.0 + float(i) * 24.0 + jit(i, k) * 3.0
			draw_polyline(PackedVector2Array([Vector2(tx - 3.0, y), Vector2(tx, y - 6.0), Vector2(tx + 3.0, y)]), INK, 2.0, true)
	elif kind == "move":
		var cx: float = x + w * 0.5
		draw_polyline(PackedVector2Array([Vector2(cx - 12.0, y + 11.0), Vector2(cx - 18.0, y + 15.0), Vector2(cx - 12.0, y + 19.0)]), INK, 2.5, true)
		draw_polyline(PackedVector2Array([Vector2(cx + 12.0, y + 11.0), Vector2(cx + 18.0, y + 15.0), Vector2(cx + 12.0, y + 19.0)]), INK, 2.5, true)
	elif kind == "crumble":
		var cx2: float = x + w * 0.4
		draw_polyline(PackedVector2Array([Vector2(cx2, y + 2.0), Vector2(cx2 + 5.0, y + 9.0), Vector2(cx2 - 3.0, y + 13.0), Vector2(cx2 + 4.0, y + 19.0)]), INK, 2.0, true)
	if p["spring"]:
		draw_spring(x + w * 0.5, y, p["spring_t"])
	if (p["coin"] or p["heart"]) and not p["taken"]:
		var cp := Vector2(x + w * 0.5, y - 52.0)
		if p["heart"]:
			draw_heart_pickup(cp)
		else:
			draw_coin(cp, int(x))
	if p["enemy"] and p["en_alive"]:
		draw_enemy(Vector2(x + p["en_x"], y - 17.0), p["en_dir"])


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
	xf(c + Vector2(0.0, bob), 0.0, Vector2.ONE)
	var hp := heart_pts(s)
	shape(hp, Color(1.0, 0.35, 0.45), 3.0)
	draw_circle(Vector2(-6.0, -6.0), 2.5, Color(1.0, 0.85, 0.88))


func draw_enemy(ep: Vector2, dir: float) -> void:
	var bob: float = sin(time * 10.0 + ep.x * 0.1) * 1.5
	xf(ep + Vector2(0.0, bob), time * dir * 1.2, Vector2.ONE)
	shape(star_pts(18.0, 12.0, 8, boil * 7), Color(0.86, 0.28, 0.42), 3.0)
	xf(ep + Vector2(0.0, bob))
	for sgn in [-1.0, 1.0]:
		draw_circle(Vector2(5.5 * sgn, -2.0), 5.6, INK)
		draw_circle(Vector2(5.5 * sgn, -2.0), 4.4, Color(1.0, 1.0, 1.0))
		draw_circle(Vector2(5.5 * sgn + dir * 1.5, -1.0), 2.0, INK)
		draw_line(Vector2(5.5 * sgn + 6.0 * sgn, -9.0), Vector2(5.5 * sgn - 2.0 * sgn, -6.0), INK, 3.0)


func draw_bird(b: Dictionary) -> void:
	var f: float = sin(b["t"] * 14.0)
	var d: float = 1.0
	if b["vx"] < 0.0:
		d = -1.0
	xf(Vector2(b["x"], b["y"] + sin(b["t"] * 3.0) * 6.0), 0.0, Vector2(d, 1.0))
	var wing := PackedVector2Array([Vector2(-4.0, 0.0), Vector2(-26.0, -10.0 + f * 12.0), Vector2(-20.0, 8.0 + f * 5.0)])
	shape(wing, Color(0.55, 0.45, 0.85), 2.5)
	shape(circle_pts(13.0, 14, boil * 3, 0.9), Color(0.35, 0.28, 0.6), 3.0)
	shape(PackedVector2Array([Vector2(11.0, -1.0), Vector2(21.0, 3.0), Vector2(11.0, 6.0)]), Color(1.0, 0.75, 0.2), 2.5)
	draw_circle(Vector2(4.0, -4.0), 4.6, INK)
	draw_circle(Vector2(4.0, -4.0), 3.6, Color(1.0, 1.0, 1.0))
	draw_circle(Vector2(5.0, -4.0), 1.6, INK)
	draw_line(Vector2(0.0, -10.0), Vector2(8.0, -7.0), INK, 2.5)


func draw_player() -> void:
	if invuln > 0.0 and int(time * 18.0) % 2 == 0:
		return
	var stretch: float = clampf(absf(vel.y) / 2600.0, 0.0, 0.28)
	var sy: float = 1.0 + stretch - squash
	var sx: float = 1.0 - stretch * 0.6 + squash * 0.9
	xf(pos, 0.0, Vector2(sx, sy))
	var tip := Vector2(-vel.x * 0.03, -R - 16.0 - clampf(-vel.y * 0.01, -4.0, 6.0))
	var stalk := PackedVector2Array([Vector2(0.0, -R + 2.0), Vector2(tip.x * 0.4, -R - 8.0), tip])
	draw_polyline(stalk, INK, 3.0, true)
	draw_circle(tip, 5.0, INK)
	draw_circle(tip, 3.4, Color(1.0, 0.85, 0.3))
	shape(circle_pts(R, 22, boil * 5, 0.8), Color(1.0, 0.52, 0.35), 3.5)
	draw_circle(Vector2(0.0, 6.0), 9.0, Color(1.0, 0.76, 0.58))
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


func draw_particles() -> void:
	for q in particles:
		var a: float = clampf(q["life"] / 0.35, 0.0, 1.0)
		var c: Color = q["c"]
		c.a = a
		var sz: float = q["sz"]
		xf(q["p"], float(q["rot"]) + float(q["life"]) * 6.0, Vector2.ONE)
		var kind: int = q["kind"]
		if kind == 1:
			draw_rect(Rect2(-sz, -sz * 0.6, sz * 2.0, sz * 1.2), c)
		elif kind == 2:
			draw_line(Vector2(-sz, 0.0), Vector2(sz, 0.0), c, 2.5)
			draw_line(Vector2(0.0, -sz), Vector2(0.0, sz), c, 2.5)
		else:
			draw_circle(Vector2.ZERO, sz * 0.7, c)


func draw_popups() -> void:
	xf(Vector2.ZERO)
	for pp in popups:
		var t: float = pp["t"]
		var p: Vector2 = pp["p"]
		p.y -= 40.0 * t
		var a: float = clampf(1.0 - (t - 0.7) / 0.4, 0.0, 1.0)
		var s: float = 1.0 + maxf(0.0, 0.3 - t) * 2.0
		label(pp["s"], p.x, p.y, int(26.0 * s), pp["c"], true, a)


func draw_net() -> void:
	if net_t <= 0.0:
		return
	xf_screen()
	var t: float = net_t / 0.7
	var pts := PackedVector2Array()
	for i in range(25):
		var x: float = W * float(i) / 24.0
		var bow: float = 70.0 * t * sin(PI * float(i) / 24.0)
		pts.append(Vector2(x, H - 8.0 - bow + sin(float(i) * 1.1 + time * 30.0) * 3.0 * t))
	draw_polyline(pts, INK, 18.0, true)
	draw_polyline(pts, Color(1.0, 0.45, 0.55), 11.0, true)
	draw_polyline(pts, Color(1.0, 0.8, 0.85), 3.0, true)


func draw_hud() -> void:
	xf_screen()
	label(str(score()), 16.0, 46.0, 40, Color(1.0, 0.96, 0.8))
	label(str(height_m()) + " m", 18.0, 72.0, 20, Color(0.8, 0.95, 1.0))
	draw_set_transform(Vector2(26.0, 96.0), 0.0, Vector2.ONE)
	draw_circle(Vector2.ZERO, 10.0, INK)
	draw_circle(Vector2.ZERO, 7.5, Color(1.0, 0.82, 0.2))
	xf_screen()
	label("x" + str(coins), 42.0, 103.0, 20, Color(1.0, 0.9, 0.5))
	for i in range(MAX_LIVES):
		var cx: float = W - 32.0 - float(i) * 36.0
		draw_set_transform(Vector2(cx, 32.0), 0.0, Vector2.ONE)
		var hp := heart_pts(0.85)
		if i < lives:
			shape(hp, Color(1.0, 0.35, 0.45), 3.0)
		else:
			var o := PackedVector2Array(hp)
			o.append(hp[0])
			draw_polyline(o, Color(INK.r, INK.g, INK.b, 0.55), 2.0, true)
	xf_screen()
	label("Rekor " + str(best), W - 68.0, 70.0, 16, Color(1.0, 0.95, 0.8), true)


func title_text(s: String, y: float, size: int) -> void:
	var total: float = font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x: float = (W - total) * 0.5
	var cols := [Color(1.0, 0.55, 0.35), Color(1.0, 0.85, 0.3), Color(0.5, 0.85, 0.5), Color(0.45, 0.75, 1.0), Color(0.9, 0.55, 0.9), Color(1.0, 0.55, 0.35)]
	for i in range(s.length()):
		var ch: String = s.substr(i, 1)
		var cw: float = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		var oy: float = sin(time * 4.0 + float(i) * 0.7) * 7.0
		var rot: float = sin(time * 3.0 + float(i) * 1.3) * 0.08
		draw_set_transform(Vector2(x + cw * 0.5, y + oy), rot, Vector2.ONE)
		draw_string_outline(font, Vector2(-cw * 0.5, 0.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 14, INK)
		draw_string(font, Vector2(-cw * 0.5, 0.0), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size, cols[i % cols.size()])
		x += cw
	xf_screen()


func draw_title() -> void:
	xf_screen()
	draw_rect(Rect2(0.0, 0.0, W, H), Color(0.1, 0.07, 0.2, 0.2))
	title_text("SKY", 200.0, 92)
	title_text("HOP!", 290.0, 92)
	label("Pantul setinggi mungkin", W * 0.5, 340.0, 22, PAPER, true)
	label("Injak musuh, ambil koin", W * 0.5, 368.0, 22, PAPER, true)
	label("Jatuh? Kamu bisa bangkit lagi!", W * 0.5, 396.0, 22, Color(1.0, 0.85, 0.3), true)
	if best > 0:
		label("Rekor: " + str(best), W * 0.5, 440.0, 22, Color(0.8, 0.95, 1.0), true)
	if int(time * 2.0) % 2 == 0:
		label("Tekan SPASI atau klik untuk mulai", W * 0.5, 560.0, 22, Color(1.0, 1.0, 1.0), true)
	label("Panah kiri/kanan atau A / D. Mouse/sentuh: geser. P: jeda", W * 0.5, 780.0, 14, PAPER, true)


func draw_over() -> void:
	xf_screen()
	draw_rect(Rect2(0.0, 0.0, W, H), Color(0.05, 0.03, 0.12, 0.45))
	var slide: float = clampf(over_t / 0.35, 0.0, 1.0)
	var oy: float = (1.0 - slide) * -300.0
	draw_set_transform(Vector2(0.0, oy), 0.0, Vector2.ONE)
	draw_colored_polygon(wob_rect(66.0, 236.0, 360.0, 320.0, 4, 1.5), Color(0.0, 0.0, 0.0, 0.25))
	shape(wob_rect(60.0, 230.0, 360.0, 320.0, boil * 3, 1.5), PAPER, 4.0)
	label("SPLAT!", W * 0.5, 300.0, 56, Color(1.0, 0.4, 0.4), true)
	label("Skor  " + str(score()), W * 0.5, 360.0, 34, Color(1.0, 0.85, 0.3), true)
	label("Tinggi " + str(height_m()) + " m   Koin " + str(coins), W * 0.5, 400.0, 20, Color(0.8, 0.95, 1.0), true)
	if new_record:
		label("REKOR BARU!", W * 0.5, 450.0, 28, Color(0.5, 0.9, 0.55), true)
	else:
		label("Rekor " + str(best), W * 0.5, 450.0, 24, Color(1.0, 0.95, 0.8), true)
	if over_t > 0.7 and int(time * 2.0) % 2 == 0:
		label("SPASI / klik: pantul lagi", W * 0.5, 510.0, 20, Color(1.0, 1.0, 1.0), true)
	xf_screen()


func draw_pause() -> void:
	xf_screen()
	draw_rect(Rect2(0.0, 0.0, W, H), Color(0.05, 0.03, 0.12, 0.55))
	label("JEDA", W * 0.5, 390.0, 64, Color(1.0, 0.85, 0.3), true)
	label("Tekan P atau klik untuk lanjut", W * 0.5, 440.0, 20, Color(1.0, 1.0, 1.0), true)
