extends Node2D
## Kokuen - jogo de luta 2D para dois jogadores (Godot 4.5)
## Tudo roda neste script: logica, entrada, desenho e interface.

const SW := 960.0
const SH := 540.0
const GY := 460.0
const INK := Color(0.04, 0.03, 0.06)
const ACTS := ["l", "r", "u", "d", "lp", "hp", "lk", "hk", "bl", "s1", "s2"]
const KEYS := [
	{"l": KEY_A, "r": KEY_D, "u": KEY_W, "d": KEY_S, "lp": KEY_F, "hp": KEY_G, "lk": KEY_V, "hk": KEY_B, "bl": KEY_C, "s1": KEY_Q, "s2": KEY_E},
	{"l": KEY_LEFT, "r": KEY_RIGHT, "u": KEY_UP, "d": KEY_DOWN, "lp": KEY_K, "hp": KEY_L, "lk": KEY_COMMA, "hk": KEY_PERIOD, "bl": KEY_SLASH, "s1": KEY_SEMICOLON, "s2": KEY_APOSTROPHE},
]

# su = quadros de preparacao, ac = quadros ativos, rc = recuperacao
# d = dano, hs = stun no acerto, bs = stun na defesa, kb = empurrao, kd = derruba
const A := {
	"LP": {"su": 4, "ac": 3, "rc": 8, "d": 35.0, "hs": 14, "bs": 8, "kb": 3.0},
	"HP": {"su": 9, "ac": 4, "rc": 17, "d": 90.0, "hs": 22, "bs": 12, "kb": 7.0},
	"LK": {"su": 6, "ac": 4, "rc": 11, "d": 40.0, "hs": 16, "bs": 10, "kb": 4.0},
	"HK": {"su": 11, "ac": 5, "rc": 21, "d": 100.0, "hs": 24, "bs": 14, "kb": 9.0},
	"cLP": {"su": 4, "ac": 3, "rc": 8, "d": 30.0, "hs": 13, "bs": 8, "kb": 2.0},
	"cHP": {"su": 7, "ac": 5, "rc": 20, "d": 95.0, "hs": 30, "bs": 13, "kb": 6.0, "kd": 1},
	"cLK": {"su": 5, "ac": 3, "rc": 9, "d": 30.0, "hs": 13, "bs": 8, "kb": 2.0},
	"cHK": {"su": 10, "ac": 4, "rc": 24, "d": 80.0, "hs": 30, "bs": 12, "kb": 6.0, "kd": 1},
	"jP": {"su": 3, "ac": 12, "rc": 0, "d": 55.0, "hs": 18, "bs": 12, "kb": 3.0},
	"jK": {"su": 3, "ac": 12, "rc": 0, "d": 70.0, "hs": 18, "bs": 12, "kb": 3.0},
	"FB": {"su": 14, "ac": 0, "rc": 28, "d": 0.0, "hs": 0, "bs": 0, "kb": 0.0},
	"DP": {"su": 6, "ac": 14, "rc": 24, "d": 140.0, "hs": 30, "bs": 15, "kb": 5.0, "kd": 1},
}

var CH := [
	{"name": "RYO", "spd": 3.4, "bs": 8.0, "bd": 90.0, "br": 17.0, "col": Color("5aa9ff")},
	{"name": "LIAN", "spd": 3.9, "bs": 11.0, "bd": 80.0, "br": 14.0, "col": Color("ff3a5c")},
]


class Fighter:
	var i := 0
	var x := 0.0
	var y := 460.0
	var vx := 0.0
	var vy := 0.0
	var f := 1
	var hp := 1000.0
	var trail := 1000.0
	var st := "free"
	var stt := 0
	var sk := "h"
	var a = null
	var his: Array = []
	var inv := 0
	var wins := 0
	var combo := 0
	var duck := false
	var wk := 0.0
	var lie := false
	var dt := 0
	var bb := ""
	var bt := 0
	var hbx = null


class View extends Node2D:
	var cb: Callable

	func _draw() -> void:
		cb.call(self)


var atlas: Texture2D
var meta: Dictionary = {}
var font: Font

var fs: Array = []
var proj: Array = []
var sp: Array = []
var views: Array = []
var mode := "menu"
var mt := 0
var round_n := 1
var tm := 60.0
var rw := -1
var hitstop := 0
var shake := 0.0
var fx := 0
var T := 0
var lock := true
var dbg := false
var co = null
var npads := 0

var held := [{}, {}]
var prs := [{}, {}]
var start_prev := false
var start_edge := false
var dbg_prev := false


func _ready() -> void:
	atlas = load("res://assets/atlas.png")
	meta = JSON.parse_string(FileAccess.get_file_as_string("res://assets/atlas.json"))
	font = ThemeDB.fallback_font
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	for i in 2:
		for a in ACTS:
			held[i][a] = false
			prs[i][a] = false
	fs = [mk(0, 260.0, 1), mk(1, 700.0, -1)]
	for i in 2:
		var v := View.new()
		v.cb = Callable(self, "draw_fighter_view").bind(i)
		if i == 0:
			# Ryo (provisorio): troca o vermelho do sprite da Lian por azul
			var sh := Shader.new()
			sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tfloat k = smoothstep(0.2, 0.35, c.r - c.g);\n\tCOLOR = vec4(mix(c.rgb, c.bgr, k), c.a) * COLOR;\n}\n"
			var mat := ShaderMaterial.new()
			mat.shader = sh
			v.material = mat
		add_child(v)
		views.append(v)
	var ov := View.new()
	ov.cb = Callable(self, "draw_overlay")
	add_child(ov)
	views.append(ov)


func mk(i: int, x: float, f: int) -> Fighter:
	var p := Fighter.new()
	p.i = i
	p.x = x
	p.f = f
	return p


# ---------------------------------------------------------------- entrada
func poll_inputs() -> void:
	var cur := [{}, {}]
	for i in 2:
		for a in ACTS:
			cur[i][a] = Input.is_physical_key_pressed(KEYS[i][a])
	var start_now := Input.is_physical_key_pressed(KEY_ENTER) or Input.is_physical_key_pressed(KEY_KP_ENTER)
	var dbg_now := Input.is_physical_key_pressed(KEY_H)
	var pads := Input.get_connected_joypads()
	npads = pads.size()
	for pi in npads:
		# com 1 controle ele joga de Lian (jogador 2); com 2, o primeiro e o Ryo
		var pl: int = pi + (1 if npads == 1 else 0)
		if pl > 1:
			continue
		var d: int = pads[pi]
		var ax := Input.get_joy_axis(d, JOY_AXIS_LEFT_X)
		var ay := Input.get_joy_axis(d, JOY_AXIS_LEFT_Y)
		var c: Dictionary = cur[pl]
		c["l"] = c["l"] or Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_LEFT) or ax < -0.5
		c["r"] = c["r"] or Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_RIGHT) or ax > 0.5
		c["u"] = c["u"] or Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP) or ay < -0.6
		c["d"] = c["d"] or Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_DOWN) or ay > 0.5
		c["lp"] = c["lp"] or Input.is_joy_button_pressed(d, JOY_BUTTON_X)
		c["hp"] = c["hp"] or Input.is_joy_button_pressed(d, JOY_BUTTON_Y)
		c["lk"] = c["lk"] or Input.is_joy_button_pressed(d, JOY_BUTTON_A)
		c["hk"] = c["hk"] or Input.is_joy_button_pressed(d, JOY_BUTTON_B)
		c["bl"] = c["bl"] or Input.is_joy_button_pressed(d, JOY_BUTTON_LEFT_SHOULDER) or Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT) > 0.5
		c["s1"] = c["s1"] or Input.is_joy_button_pressed(d, JOY_BUTTON_RIGHT_SHOULDER)
		c["s2"] = c["s2"] or Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > 0.5
		if Input.is_joy_button_pressed(d, JOY_BUTTON_START):
			start_now = true
		if Input.is_joy_button_pressed(d, JOY_BUTTON_BACK):
			dbg_now = true
	for i in 2:
		for a in ACTS:
			if cur[i][a] and not held[i][a]:
				prs[i][a] = true
		held[i] = cur[i]
	start_edge = start_now and not start_prev
	start_prev = start_now
	if dbg_now and not dbg_prev:
		dbg = not dbg
	dbg_prev = dbg_now


func clear_prs() -> void:
	for i in 2:
		for a in ACTS:
			prs[i][a] = false


func hd(p: Fighter, k: String) -> bool:
	return (not lock) and held[p.i][k]


func pr(p: Fighter, k: String) -> bool:
	return (not lock) and prs[p.i][k]


func mo(p: Fighter, s: String) -> bool:
	var r := ""
	for e in p.his:
		if e["t"] > T - 32 and e["d"] != 5 and not r.ends_with(str(e["d"])):
			r += str(e["d"])
	return r.contains(s)


# ---------------------------------------------------------------- caixas
func hh(o: Fighter) -> float:
	if o.duck and o.y >= GY:
		return float(meta["_h"]["c"])
	return float(meta["_h"]["s"])


func hbox(p: Fighter, a: Dictionary) -> Array:
	var m: Array = meta["_hb"][a["n"]]
	var x0: float = p.x + float(m[0])
	if p.f < 0:
		x0 = p.x - float(m[2])
	return [x0, p.y + float(m[1]), float(m[2]) - float(m[0]), float(m[3]) - float(m[1])]


# ---------------------------------------------------------------- logica
func start_round() -> void:
	var w := [0, 0]
	for i in fs.size():
		w[i] = fs[i].wins
	fs = [mk(0, 340.0, 1), mk(1, 620.0, -1)]
	for i in 2:
		fs[i].wins = w[i]
	proj.clear()
	sp.clear()
	tm = 60.0
	mode = "intro"
	mt = 0


func new_match() -> void:
	fs = []
	round_n = 1
	start_round()


func upd(p: Fighter, o: Fighter) -> void:
	var c: Dictionary = CH[p.i]
	var air := p.y < GY
	if p.inv > 0:
		p.inv -= 1
	p.hbx = null
	var x := (1 if hd(p, "r") else 0) - (1 if hd(p, "l") else 0)
	var dn := hd(p, "d")
	var up := hd(p, "u")
	var rel := x * p.f
	var d := 5
	if dn:
		d = 1 if rel < 0 else (3 if rel > 0 else 2)
	elif up:
		d = 7 if rel < 0 else (9 if rel > 0 else 8)
	else:
		d = 4 if rel < 0 else (6 if rel > 0 else 5)
	if p.his.is_empty() or p.his[p.his.size() - 1]["d"] != d:
		p.his.append({"d": d, "t": T})
		if p.his.size() > 12:
			p.his.pop_front()

	if p.st == "free" and not air:
		if o.x != p.x:
			p.f = 1 if o.x > p.x else -1
		p.duck = dn
		var spd: float = c["spd"]
		if dn or hd(p, "bl"):
			p.vx = 0.0
		else:
			p.vx = x * spd * (0.75 if x * p.f < 0 else 1.0)
		if up and not dn and not hd(p, "bl"):
			p.vy = -15.0
			p.y -= 1.0
			p.vx = x * spd * 1.15

	var b := ""
	if pr(p, "lp"):
		b = "lp"
	elif pr(p, "hp"):
		b = "hp"
	elif pr(p, "lk"):
		b = "lk"
	elif pr(p, "hk"):
		b = "hk"
	var cancel: bool = p.st == "atk" and p.a["hit"] and not p.a["sp"]
	if b != "" and p.st == "atk" and not cancel:
		p.bb = b
		p.bt = 8
	elif b == "" and p.bt > 0 and p.st == "free":
		b = p.bb
		p.bt = 0
	if p.bt > 0:
		p.bt -= 1
	var s1 := pr(p, "s1")
	var s2 := pr(p, "s2")
	if (b != "" or s1 or s2) and (p.st == "free" or cancel):
		var pu := b.length() > 1 and b[1] == "p"
		var n := ""
		if p.y >= GY:
			if s2:
				n = "DP"
			elif s1:
				n = "FB"
		if n == "" and pu and p.y >= GY:
			if mo(p, "623") or mo(p, "6323"):
				n = "DP"
			elif mo(p, "236") or mo(p, "26"):
				n = "FB"
		if n == "" and b != "" and p.st == "free":
			if p.y < GY:
				n = "jP" if pu else "jK"
			else:
				n = ("c" if p.duck else "") + b.to_upper()
		if n != "":
			p.st = "atk"
			p.a = {"n": n, "t": 0, "hit": false, "sp": (n == "DP" or n == "FB"), "hv": (b == "" or b[0] == "h")}
			p.his = []
			if n == "DP" or n == "FB":
				var lian: bool = p.i == 1
				var nm := "TENSENRIN" if n == "DP" else "CHUVA ESCARLATE"
				if not lian:
					nm = "SUBIDA" if n == "DP" else "HADOUKEN"
				co = {"s": nm, "t": 60, "i": p.i}
			if n == "DP":
				p.vx = p.f * 3.5
				p.vy = -13.0
				p.y -= 1.0
				p.inv = 7

	if p.st == "atk":
		var a: Dictionary = p.a
		var D: Dictionary = A[a["n"]]
		a["t"] += 1
		if a["n"] != "DP" and p.y >= GY:
			p.vx *= 0.8
		if a["n"] == "FB":
			if a["t"] == D["su"] and not proj.any(func(r): return r["o"] == p.i):
				var mult := 1.25 if a["hv"] else 1.0
				proj.append({
					"x": p.x + p.f * 62.0, "y": GY - 152.0,
					"vx": p.f * float(c["bs"]) * mult, "o": p.i, "r": float(c["br"]),
					"d": float(c["bd"]) * (1.2 if a["hv"] else 1.0), "dead": false,
				})
		elif a["t"] > D["su"] and a["t"] <= D["su"] + D["ac"]:
			var bx := hbox(p, a)
			p.hbx = bx
			if not a["hit"] and o.inv <= 0 and not (o.st == "down" and o.y >= GY) \
					and o.x + 26.0 > bx[0] and o.x - 26.0 < bx[0] + bx[2] \
					and o.y > bx[1] and o.y - hh(o) < bx[1] + bx[3]:
				resolve(p, o, D, a)
		var nm2: String = a["n"]
		if nm2.substr(0, 1) != "j" and nm2 != "DP" and a["t"] >= D["su"] + D["ac"] + D["rc"]:
			p.st = "free"
	elif p.st == "stun":
		p.stt -= 1
		if p.stt <= 0:
			p.st = "free"
		p.vx *= 0.86
	elif p.st == "down":
		if p.y >= GY:
			if not p.lie:
				p.lie = true
				p.dt = 0
				shake = maxf(shake, 4.0)
			p.vx *= 0.8
			p.dt += 1
			if p.hp > 0.0 and p.dt > 40:
				p.st = "getup"
				p.stt = 16
				p.inv = 16
				p.lie = false
		else:
			p.vx *= 0.98
	elif p.st == "getup":
		p.stt -= 1
		if p.stt <= 0:
			p.st = "free"

	if p.y < GY or p.vy < 0.0:
		p.vy += 0.7
	p.x += p.vx
	p.y += p.vy
	if p.y >= GY:
		var landed := p.vy > 0.0
		p.y = GY
		p.vy = 0.0
		if landed and p.st == "atk":
			var an: String = p.a["n"]
			if an.substr(0, 1) == "j" or an == "DP":
				p.st = "free"


func resolve(p: Fighter, o: Fighter, D: Dictionary, a: Dictionary) -> void:
	a["hit"] = true
	var back_key := "l" if o.f > 0 else "r"
	var guard: bool = (not lock) and (held[o.i][back_key] or held[o.i]["bl"])
	var can_block: bool = (o.st == "free" or (o.st == "stun" and o.sk == "b")) and o.y >= GY and guard
	var sx := (p.x + o.x) / 2.0 + p.f * 8.0
	var sy := o.y - hh(o) * 0.6
	if can_block:
		o.st = "stun"
		o.sk = "b"
		o.stt = int(D["bs"])
		o.vx = p.f * (float(D["kb"]) + 2.0)
		if a.get("sp", false):
			o.hp = maxf(1.0, o.hp - float(D["d"]) * 0.12)
		if o.x <= 62.0 or o.x >= 898.0:
			p.vx = -p.f * 4.0
		sp.append({"x": sx, "y": sy, "t": 0, "big": false, "blk": true})
		hitstop = 5
	else:
		var in_combo: bool = (o.st == "stun" and o.sk == "h") or o.st == "down"
		var cs: int = p.combo if in_combo else 0
		o.hp -= float(D["d"]) * maxf(0.5, 1.0 - 0.12 * cs)
		if o.hp < 0.0:
			o.hp = 0.0
		p.combo = p.combo + 1 if in_combo else 1
		o.a = null
		o.duck = false
		if D.get("kd", 0) == 1 or o.y < GY or o.hp <= 0.0:
			o.st = "down"
			o.vy = -9.0
			o.vx = p.f * (float(D["kb"]) + 2.0)
			o.y -= 1.0
			o.lie = false
			fx = 3
		else:
			o.st = "stun"
			o.sk = "h"
			o.stt = int(D["hs"])
			o.vx = p.f * float(D["kb"])
		hitstop = 9 if float(D["d"]) > 60.0 else 6
		shake = maxf(shake, float(D["d"]) / 10.0)
		sp.append({"x": sx, "y": sy, "t": 0, "big": float(D["d"]) > 60.0, "blk": false})


func push_apart() -> void:
	var a: Fighter = fs[0]
	var b: Fighter = fs[1]
	if a.y >= GY - 90.0 and b.y >= GY - 90.0:
		var d := b.x - a.x
		var m := 62.0
		if absf(d) < m:
			var s := 1.0 if d >= 0.0 else -1.0
			var o := (m - absf(d)) / 2.0
			a.x -= s * o
			b.x += s * o
	for p in fs:
		p.x = clampf(p.x, 72.0, 888.0)


func step() -> void:
	if mode == "menu" or mode == "over":
		if start_edge:
			new_match()
		return
	if hitstop > 0:
		hitstop -= 1
		return
	if mode == "ko" and T % 3 != 0:
		return
	mt += 1
	lock = mode != "fight"
	for i in 2:
		upd(fs[i], fs[1 - i])
	clear_prs()
	push_apart()
	for r in proj:
		r["x"] += r["vx"]
		var o: Fighter = fs[1 - int(r["o"])]
		if o.inv <= 0 and not (o.st == "down" and o.y >= GY) and absf(r["x"] - o.x) < 26.0 + r["r"] \
				and r["y"] > o.y - hh(o) and r["y"] < o.y:
			resolve(fs[int(r["o"])], o, {"d": r["d"], "hs": 22, "bs": 14, "kb": 5.0}, {"sp": true, "hit": false})
			r["dead"] = true
	for r in proj:
		for q in proj:
			if r != q and absf(r["x"] - q["x"]) < r["r"] + q["r"] and absf(r["y"] - q["y"]) < 20.0:
				r["dead"] = true
				q["dead"] = true
	proj = proj.filter(func(r): return (not r["dead"]) and r["x"] > -40.0 and r["x"] < 1000.0)
	for s in sp:
		s["t"] += 1
	sp = sp.filter(func(s): return s["t"] < 9)
	for i in 2:
		var p: Fighter = fs[i]
		var q: Fighter = fs[1 - i]
		if p.trail > p.hp:
			p.trail = maxf(p.hp, p.trail - 3.0)
		if q.st != "stun" and q.st != "down":
			p.combo = 0
	if mode == "intro" and mt > 110:
		mode = "fight"
		mt = 0
	elif mode == "fight":
		tm -= 1.0 / 60.0
		if tm <= 0.0 or fs[0].hp <= 0.0 or fs[1].hp <= 0.0:
			var a: Fighter = fs[0]
			var b: Fighter = fs[1]
			rw = 0 if a.hp > b.hp else (1 if b.hp > a.hp else -1)
			if rw >= 0:
				fs[rw].wins += 1
			tm = maxf(0.0, tm)
			mode = "ko"
			mt = 0
			shake = 14.0
			fx = 4
	elif mode == "ko" and mt > 45:
		mode = "end"
		mt = 0
	elif mode == "end" and mt > 70:
		if fs[0].wins >= 2 or fs[1].wins >= 2:
			mode = "over"
		else:
			round_n += 1
			start_round()


func _physics_process(_delta: float) -> void:
	poll_inputs()
	step()
	T += 1
	if shake > 0.3:
		position = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
		shake *= 0.86
	else:
		position = Vector2.ZERO
	queue_redraw()
	for v in views:
		v.queue_redraw()


# ---------------------------------------------------------------- sprites
func spr_key(p: Fighter) -> Array:
	if p.st == "atk":
		var a: Dictionary = p.a
		var D: Dictionary = A[a["n"]]
		var n: int = meta[a["n"]].size()
		var t: int = a["t"]
		var i := 0
		if a["n"] == "FB":
			i = int(floor(float(t) / float(D["su"] + D["ac"] + D["rc"]) * n))
		elif a["n"] == "DP":
			if t <= D["su"]:
				i = int(floor(float(t - 1) / float(D["su"]) * 2.0))
			elif t <= D["su"] + D["ac"]:
				i = 2 + int(floor(float(t - D["su"] - 1) / float(D["ac"]) * 2.0))
			else:
				i = 4 + int(floor(float(t - D["su"] - D["ac"] - 1) / float(D["rc"]) * 3.0))
		else:
			var k: int = n / 2
			if t <= D["su"]:
				i = int(floor(float(t - 1) / float(D["su"]) * k))
			elif t <= D["su"] + D["ac"]:
				i = k
			elif D["rc"] > 0:
				i = k + 1 + int(floor(float(t - D["su"] - D["ac"] - 1) / float(D["rc"]) * (n - k - 1)))
			else:
				i = k + 1
		return [a["n"], clampi(i, 0, n - 1)]
	if p.st == "stun":
		if p.sk == "b":
			return ["cLK", 0] if p.duck else ["idle", 1]
		return ["fall", 0]
	if p.st == "down":
		return ["fall", 2 if p.lie else (0 if p.vy < 0.0 else 1)]
	if p.st == "getup":
		return ["fall", 3 + mini(2, int(floor(float(16 - p.stt) / 16.0 * 3.0)))]
	if (not lock) and p.y >= GY and held[p.i]["bl"]:
		return ["cLK", 0] if p.duck else ["idle", 1]
	if p.y < GY:
		return ["jK", 0 if p.vy < -2.0 else 1]
	if p.duck:
		return ["cLK", 0]
	if absf(p.vx) > 0.5:
		p.wk += absf(p.vx) * 0.09
		return ["walk", int(floor(p.wk)) % 7]
	return ["idle", int(floor(T / 8.0)) % 7]


func draw_fighter_view(c: CanvasItem, idx: int) -> void:
	var p: Fighter = fs[idx]
	var k := spr_key(p)
	var f: Dictionary = meta[k[0]][k[1]]
	c.draw_set_transform(Vector2(p.x, GY + 8.0), 0.0, Vector2(1.0, 0.2))
	c.draw_circle(Vector2.ZERO, maxf(18.0, 60.0 - (GY - p.y) * 0.15), Color(0, 0, 0, 0.4))
	var alpha := 1.0
	if p.inv > 0 and p.inv % 6 < 3 and p.st != "down":
		alpha = 0.5
	c.draw_set_transform(Vector2(roundf(p.x), roundf(p.y)), 0.0, Vector2(float(p.f), 1.0))
	c.draw_texture_rect_region(
		atlas,
		Rect2(-float(f["ax"]), -float(f["ay"]), float(f["w"]), float(f["h"])),
		Rect2(float(f["x"]), float(f["y"]), float(f["w"]), float(f["h"])),
		Color(1, 1, 1, alpha))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ---------------------------------------------------------------- cenario
func _draw() -> void:
	var steps := 27
	for i in steps:
		var t := float(i) / float(steps - 1)
		var col := Color("3a1d5c").lerp(Color("c2436a"), t / 0.5) if t < 0.5 else Color("c2436a").lerp(Color("ffb35c"), (t - 0.5) / 0.5)
		draw_rect(Rect2(0, i * GY / steps, SW, GY / steps + 1.0), col)
	draw_circle(Vector2(480, 310), 115.0, Color("ffe3a0"))
	var mts := PackedVector2Array([Vector2(0, 340)])
	for xx in range(0, 961, 80):
		mts.append(Vector2(xx, 250 + (44 if (xx / 80) % 2 == 1 else 0)))
	mts.append(Vector2(SW, GY))
	mts.append(Vector2(0, GY))
	draw_colored_polygon(mts, Color("7b3a6e"))
	_pagoda(170.0, GY - 10.0, 1.0)
	_pagoda(800.0, GY - 10.0, 0.85)
	draw_rect(Rect2(0, GY - 92, SW, 92), Color("24101f"))
	for x in range(0, 960, 60):
		draw_rect(Rect2(x, GY - 104, 56, 14), Color("8a1f35"))
		draw_rect(Rect2(x, GY - 90, 56, 6), Color("3a1630"))
		draw_rect(Rect2(x + 22, GY - 66, 12, 16), Color("ffcf5a"))
	for x in range(50, 960, 130):
		draw_circle(Vector2(x, GY - 190), 44.0, Color(1, 0.47, 0.24, 0.25))
		draw_rect(Rect2(x - 2, GY - 230, 4, 40), Color("3a1630"))
		draw_rect(Rect2(x - 16, GY - 210, 32, 38), Color("e0382c"))
		draw_rect(Rect2(x - 16, GY - 213, 32, 5), Color("ffcf5a"))
		draw_rect(Rect2(x - 16, GY - 176, 32, 5), Color("ffcf5a"))
	draw_rect(Rect2(0, GY, SW, SH - GY), Color("4a3446"))
	for r in 4:
		var y := GY + r * 22.0
		draw_rect(Rect2(0, y, SW, 3), Color("2e1d2e"))
		for x in range((r % 2) * 40, 960, 80):
			draw_rect(Rect2(x, y, 3, 22), Color("2e1d2e"))
	draw_rect(Rect2(0, GY, SW, 5), Color("e8c070"))


func _pagoda(cx: float, base: float, sc: float) -> void:
	for i in 5:
		var w := (170.0 - i * 26.0) * sc
		var y := base - i * 58.0 * sc
		draw_rect(Rect2(cx - w * 0.38, y - 46.0 * sc, w * 0.76, 46.0 * sc), Color("2a1226"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(cx - w * 0.65, y - 40.0 * sc), Vector2(cx + w * 0.65, y - 40.0 * sc),
			Vector2(cx + w * 0.42, y - 64.0 * sc), Vector2(cx - w * 0.42, y - 64.0 * sc)]), Color("b3263a"))
		draw_rect(Rect2(cx - w * 0.65, y - 42.0 * sc, w * 1.3, 5.0 * sc), Color("4a1a2e"))
	draw_rect(Rect2(cx - 3.0 * sc, base - 5.0 * 58.0 * sc - 30.0 * sc, 6.0 * sc, 40.0 * sc), Color("4a1a2e"))


# ---------------------------------------------------------------- interface
func txt(c: CanvasItem, s: String, x: float, y: float, size: int, col: Color, al := 0) -> void:
	var w := font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var px := x
	if al == 1:
		px = x - w / 2.0
	elif al == 2:
		px = x - w
	c.draw_string_outline(font, Vector2(px, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 8, INK)
	c.draw_string(font, Vector2(px, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func banner(c: CanvasItem, col: Color, y: float) -> void:
	c.draw_colored_polygon(PackedVector2Array([Vector2(0, y - 80), Vector2(SW, y - 110), Vector2(SW, y + 30), Vector2(0, y + 60)]), col)


func bar(c: CanvasItem, x0: float, dir: float, frac: float, col: Color) -> void:
	var w := 392.0 * frac
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, 24), Vector2(0, 24)])
	for i in pts.size():
		pts[i] = Vector2(x0 + pts[i].x * dir, 26.0 + pts[i].y)
	if w > 0.5:
		c.draw_colored_polygon(pts, col)


func draw_overlay(c: CanvasItem) -> void:
	# projeteis
	for r in proj:
		var col: Color = CH[int(r["o"])]["col"]
		var s := signf(r["vx"])
		c.draw_circle(Vector2(r["x"], r["y"]), r["r"] * 1.8, Color(col, 0.35))
		c.draw_colored_polygon(PackedVector2Array([
			Vector2(r["x"], r["y"] - r["r"]), Vector2(r["x"] - s * r["r"] * 4.0, r["y"]),
			Vector2(r["x"], r["y"] + r["r"])]), col)
		if int(r["o"]) == 1:
			for off in [[-12.0, -14.0], [4.0, 0.0], [-12.0, 14.0]]:
				var ox: float = r["x"] + s * off[0]
				var oy: float = r["y"] + off[1]
				c.draw_colored_polygon(PackedVector2Array([
					Vector2(ox - s * 16.0, oy), Vector2(ox + s * 6.0, oy - 4.0),
					Vector2(ox + s * 26.0, oy), Vector2(ox + s * 6.0, oy + 4.0)]), Color("cfd6e0"))
		else:
			c.draw_circle(Vector2(r["x"], r["y"]), r["r"], col)
			c.draw_circle(Vector2(r["x"], r["y"]), r["r"] * 0.55, Color.WHITE)
	# faiscas de impacto
	for s in sp:
		var k: float = (1.7 if s["big"] else 1.0) * (1.0 + s["t"] * 0.12)
		var pts := PackedVector2Array()
		for j in 16:
			var rad := (12.0 if j % 2 == 1 else 46.0) * k
			var an: float = j * PI / 8.0 + s["t"] * 0.1
			pts.append(Vector2(s["x"] + cos(an) * rad, s["y"] + sin(an) * rad))
		c.draw_colored_polygon(pts, Color("7fd0ff") if s["blk"] else Color.WHITE)
		if s["big"] and s["t"] < 5:
			for a in 24:
				var an2: float = a * 0.2618
				var l: float = 160.0 + (a % 3) * 50.0
				c.draw_line(Vector2(s["x"] + cos(an2) * 70.0, s["y"] + sin(an2) * 70.0), Vector2(s["x"] + cos(an2) * l, s["y"] + sin(an2) * l), Color(1, 1, 1, 0.8), 2.0)
	# caixas de golpe (tecla H / botao Select)
	if dbg:
		for p in fs:
			c.draw_rect(Rect2(p.x - 26.0, p.y - hh(p), 52.0, hh(p)), Color("44aaff"), false, 2.0)
			if p.hbx != null:
				c.draw_rect(Rect2(p.hbx[0], p.hbx[1], p.hbx[2], p.hbx[3]), Color("ff3333"), false, 2.0)
	# barras de vida
	if mode != "menu":
		for i in 2:
			var p: Fighter = fs[i]
			var dir := -1.0 if i == 1 else 1.0
			var x0 := SW - 30.0 if i == 1 else 30.0
			c.draw_rect(Rect2(minf(x0, x0 + 392.0 * dir) - 7.0, 19.0, 406.0, 38.0), INK)
			c.draw_rect(Rect2(minf(x0, x0 + 392.0 * dir) - 4.0, 22.0, 400.0, 32.0), Color("e8d8a0"))
			c.draw_rect(Rect2(minf(x0, x0 + 392.0 * dir), 26.0, 392.0, 24.0), Color("3a1020"))
			bar(c, x0, dir, maxf(0.0, p.trail) / 1000.0, Color("d4262e"))
			var frac := maxf(0.0, p.hp) / 1000.0
			bar(c, x0, dir, frac, Color("f6d33c") if frac > 0.3 else Color("ff7a2a"))
			txt(c, CH[i]["name"], x0, 84.0, 26, Color.WHITE, 2 if i == 1 else 0)
			for w in 2:
				var wx: float = x0 + dir * (w * 26.0) - (20.0 if i == 1 else 0.0)
				c.draw_rect(Rect2(wx - 2.0, 94.0, 24.0, 24.0), INK)
				c.draw_rect(Rect2(wx, 96.0, 20.0, 20.0), Color("f6d33c") if p.wins > w else Color("3a1020"))
			if p.combo > 1:
				txt(c, "%d HITS" % p.combo, SW - 60.0 if i == 1 else 60.0, 200.0, 40, Color("f6d33c"), 2 if i == 1 else 0)
		c.draw_rect(Rect2(SW / 2.0 - 62.0, 14.0, 124.0, 76.0), INK)
		c.draw_rect(Rect2(SW / 2.0 - 58.0, 18.0, 116.0, 68.0), Color("e8d8a0"))
		c.draw_rect(Rect2(SW / 2.0 - 52.0, 24.0, 104.0, 56.0), Color("3a1020"))
		txt(c, "%02d" % int(ceil(tm)), SW / 2.0, 72.0, 48, Color("f6d33c"), 1)
	if co != null and co["t"] > 0 and mode == "fight":
		var right: bool = co["i"] == 1
		txt(c, co["s"], SW - 40.0 if right else 40.0, 150.0, 32, Color("ff5a6e") if right else Color("6fc0ff"), 2 if right else 0)
		co["t"] -= 1
	# textos centrais
	if mode == "intro":
		if mt < 60:
			banner(c, Color(0.04, 0.03, 0.06, 0.8), 270.0)
			txt(c, "ROUND %d" % round_n, SW / 2.0 - maxf(0.0, 40.0 - mt) * 25.0, 295.0, 90, Color.WHITE, 1)
		elif mt < 105:
			banner(c, Color(1, 0.23, 0.36, 0.9), 270.0)
			txt(c, "FIGHT!", SW / 2.0, 305.0, 110, Color.WHITE, 1)
	elif mode == "ko":
		var ko: bool = fs[0].hp <= 0.0 or fs[1].hp <= 0.0
		txt(c, "K.O." if ko else "TEMPO!", SW / 2.0, 300.0, 150, Color("ff3a5c"), 1)
	elif mode == "end":
		txt(c, "EMPATE" if rw < 0 else CH[rw]["name"] + " VENCEU", SW / 2.0, 300.0, 90, Color.WHITE, 1)
	elif mode == "over":
		c.draw_rect(Rect2(0, 0, SW, SH), Color(0.03, 0.02, 0.06, 0.72))
		var wn: int = 0 if fs[0].wins >= 2 else 1
		txt(c, CH[wn]["name"] + " VENCEU A LUTA", SW / 2.0, 260.0, 64, CH[wn]["col"], 1)
		if T % 70 < 48:
			txt(c, "ENTER / START para revanche", SW / 2.0, 340.0, 28, Color.WHITE, 1)
	elif mode == "menu":
		c.draw_rect(Rect2(0, 0, SW, SH), Color(0.03, 0.02, 0.06, 0.5))
		txt(c, "KOKUEN", SW / 2.0, 210.0, 150, Color("ff3a5c"), 1)
		txt(c, "DUELO NA NOITE", SW / 2.0, 260.0, 30, Color.WHITE, 1)
		txt(c, "RYO (provisorio)", 260.0, 150.0, 30, Color("5aa9ff"), 1)
		txt(c, "LIAN", 700.0, 150.0, 30, Color("ff3a5c"), 1)
		txt(c, "CONTROLES: %d" % npads, SW / 2.0, 420.0, 22, Color("f6d33c"), 1)
		if T % 70 < 48:
			txt(c, "ENTER / START para lutar", SW / 2.0, 340.0, 28, Color.WHITE, 1)
	if fx > 0:
		c.draw_rect(Rect2(0, 0, SW, SH), Color(1, 1, 1, fx * 0.14))
		fx -= 1
