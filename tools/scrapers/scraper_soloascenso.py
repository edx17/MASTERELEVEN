#!/usr/bin/env python3
"""
Scraper de SoloAscenso -> CSV estilo FIFA para VIRTUAL ELEVEN.

Qué saca de SoloAscenso (dato real):
  - club, nombre, puesto base (ARQ/DEF/MED/DEL)
  - edad, presencias, partidos como titular, goles (del perfil del jugador)
  - resultados del club (para estimar la fuerza del equipo)

Qué ESTIMA (SoloAscenso no lo publica):
  - overall y todos los atributos, posición detallada, altura, pie hábil,
    número de camiseta, nacionalidad (default Argentina)

Uso:
  pip install requests beautifulsoup4
  python scraper_soloascenso.py                 # las 3 categorías
  python scraper_soloascenso.py --solo b         # solo una (nacional | b | c)
  python scraper_soloascenso.py --sin-perfiles   # rápido: no baja perfiles

El HTML se cachea en ./cache_soloascenso, así que si se corta, relanzás y sigue.
Todo es determinístico: mismo jugador -> mismos atributos en cada corrida.
"""
import argparse, csv, hashlib, os, random, re, sys, time
from concurrent.futures import ThreadPoolExecutor

import requests
from bs4 import BeautifulSoup

BASE = "https://www.soloascenso.com.ar"
CATEGORIAS = {
    "nacional": dict(url=f"{BASE}/categoria/primera-nacional/1", liga="Primera B Nacional",
                     archivo="primera_b_nacional.csv", base_overall=63),
    "b":        dict(url=f"{BASE}/categoria/primera-b/2", liga="Primera B",
                     archivo="primera_b.csv", base_overall=58),
    "c":        dict(url=f"{BASE}/categoria/primera-c/3", liga="Primera C",
                     archivo="primera_c.csv", base_overall=53),
}
CLUBES_IGNORADOS = {"AFA", "SOLOASCENSO"}
CACHE_DIR = "cache_soloascenso"
DELAY = 0.6          # segundos entre requests por hilo (no le peguemos fuerte al sitio)
HILOS = 4
HEADERS = {"User-Agent": "Mozilla/5.0 (VirtualEleven data builder)"}

COLUMNAS = ("short_name,club_name,nationality_name,club_jersey_number,player_positions,preferred_foot,"
            "height_cm,age,overall,seleccion,pace,shooting,passing,dribbling,defending,physic,"
            "attacking_crossing,attacking_finishing,attacking_heading_accuracy,attacking_short_passing,"
            "attacking_volleys,skill_dribbling,skill_curve,skill_fk_accuracy,skill_long_passing,"
            "skill_ball_control,movement_acceleration,movement_sprint_speed,movement_agility,"
            "movement_reactions,movement_balance,power_shot_power,power_jumping,power_stamina,"
            "power_strength,power_long_shots,mentality_aggression,mentality_interceptions,"
            "mentality_positioning,mentality_vision,mentality_penalties,mentality_composure,"
            "defending_marking_awareness,defending_standing_tackle,defending_sliding_tackle,"
            "goalkeeping_diving,goalkeeping_handling,goalkeeping_kicking,goalkeeping_positioning,"
            "goalkeeping_reflexes,goalkeeping_speed,league_name").split(",")

ATTRS = COLUMNAS[16:45]          # attacking_crossing ... defending_sliding_tackle
GK_ATTRS = COLUMNAS[45:51]       # goalkeeping_*

# ------------------------------------------------------------------ HTTP + cache
_session = requests.Session()
_session.headers.update(HEADERS)

def get_html(url):
    os.makedirs(CACHE_DIR, exist_ok=True)
    path = os.path.join(CACHE_DIR, hashlib.sha1(url.encode()).hexdigest() + ".html")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            return f.read()
    for intento in range(4):
        try:
            r = _session.get(url, timeout=25)
            if r.status_code == 200:
                r.encoding = "utf-8"
                with open(path, "w", encoding="utf-8") as f:
                    f.write(r.text)
                time.sleep(DELAY)
                return r.text
            print(f"  ! HTTP {r.status_code} en {url}", file=sys.stderr)
        except requests.RequestException as e:
            print(f"  ! {e} en {url}", file=sys.stderr)
        time.sleep(2 * (intento + 1))
    return ""

# ------------------------------------------------------------------ parsing
RE_CLUB = re.compile(r"/club/([^/]+)/(\d+)")
RE_PERFIL = re.compile(r"/perfil/([^/]+)/(\d+)")
RE_LOGO = re.compile(r"/logos/(\d+)\.png")
RE_PLANTEL = re.compile(r"^\s*(.+?)\s+-\s+(ARQ|DEF|MED|DEL|DT)\s*$")
RE_SCORE = re.compile(r"^\s*(\d+)\s*-\s*(\d+)\s*$")

def parse_clubes(html):
    soup = BeautifulSoup(html, "html.parser")
    clubes, vistos = [], set()
    for a in soup.find_all("a", href=RE_CLUB):
        img = a.find("img")
        nombre = (img.get("title") if img else "") or a.get_text(strip=True)
        cid = RE_CLUB.search(a["href"]).group(2)
        if not nombre or nombre.upper() in CLUBES_IGNORADOS or cid in vistos:
            continue
        vistos.add(cid)
        clubes.append(dict(id=cid, nombre=nombre.strip(), url=BASE + RE_CLUB.search(a["href"]).group(0)))
    return clubes

def parse_club(html, club_id):
    soup = BeautifulSoup(html, "html.parser")
    jugadores, vistos = [], set()
    for s in soup.find_all(string=RE_PLANTEL):
        nombre, pos = RE_PLANTEL.match(s).groups()
        if pos == "DT":
            continue
        a = s.find_previous("a", href=RE_PERFIL)
        if not a:
            continue
        pid = RE_PERFIL.search(a["href"]).group(2)
        if pid in vistos:
            continue
        vistos.add(pid)
        jugadores.append(dict(id=pid, nombre=nombre.strip(), pos=pos,
                              url=BASE + RE_PERFIL.search(a["href"]).group(0)))
    # Resultados -> puntos por partido
    pj = pts = 0
    for a in soup.find_all("a", href=re.compile(r"/sintesis/")):
        m = RE_SCORE.match(a.get_text())
        if not m:
            continue
        hi, ai = a.find_previous("img", src=RE_LOGO), a.find_next("img", src=RE_LOGO)
        if not hi or not ai:
            continue
        h_id, a_id = RE_LOGO.search(hi["src"]).group(1), RE_LOGO.search(ai["src"]).group(1)
        gh, ga = map(int, m.groups())
        if h_id == club_id:
            gf, gc = gh, ga
        elif a_id == club_id:
            gf, gc = ga, gh
        else:
            continue
        pj += 1
        pts += 3 if gf > gc else (1 if gf == gc else 0)
    return jugadores, pj, (pts / pj if pj else None)

def parse_perfil(html):
    soup = BeautifulSoup(html, "html.parser")
    lineas = [l.strip() for l in soup.get_text("\n").split("\n") if l.strip()]
    datos = {}
    for i, l in enumerate(lineas[:-1]):
        if l.endswith(":") and not lineas[i + 1].endswith(":"):
            datos.setdefault(l[:-1].strip(), lineas[i + 1])
    def num(k):
        try:
            return int(re.sub(r"\D", "", datos.get(k, "")) or "x")
        except ValueError:
            return None
    return dict(edad=num("Edad"), presencias=num("Presencias"),
                titular=num("Partidos como titular"), goles=num("Goles"),
                puesto=datos.get("Puesto", ""))

# ------------------------------------------------------------------ estimación
ORDEN = ["attacking_crossing", "attacking_finishing", "attacking_heading_accuracy",
         "attacking_short_passing", "attacking_volleys", "skill_dribbling", "skill_curve",
         "skill_fk_accuracy", "skill_long_passing", "skill_ball_control", "movement_acceleration",
         "movement_sprint_speed", "movement_agility", "movement_reactions", "movement_balance",
         "power_shot_power", "power_jumping", "power_stamina", "power_strength", "power_long_shots",
         "mentality_aggression", "mentality_interceptions", "mentality_positioning",
         "mentality_vision", "mentality_penalties", "mentality_composure",
         "defending_marking_awareness", "defending_standing_tackle", "defending_sliding_tackle"]
assert ORDEN == ATTRS

# Offsets respecto del overall, en el orden de ORDEN
PLANTILLAS = {
    "CB":  [-15,-25,  3, -5,-25,-15,-20,-20, -8, -8, -6, -4,-12, -2,-10, -5,  3, -3,  5,-20,  3,  3,-25,-20,-20, -2,  3,  4,  2],
    "FB":  [  0,-18, -8, -2,-18, -4, -8,-14, -5, -3,  4,  5,  2, -2,  2, -6, -4,  4, -4,-14, -2, -2,-12,-10,-15, -4, -2, -1,  0],
    "CDM": [-10,-14, -4,  2,-16, -6,-10,-10,  0, -2, -6, -6, -6,  0, -4, -2, -2,  4,  2, -6,  3,  3, -8, -4,-10,  0,  1,  2,  0],
    "CM":  [ -4, -8,-10,  3,-10,  0, -3, -6,  2,  2, -2, -3,  0,  0,  0, -1, -8,  3, -4, -2, -4, -6, -3,  1, -6,  0, -8, -7,-10],
    "CAM": [ -2, -1,-15,  3, -4,  4,  2, -2, -2,  4,  2,  0,  4,  0,  3,  0,-12, -2,-10,  1,-12,-25,  1,  4, -2,  1,-28,-30,-32],
    "WM":  [  2, -6,-14,  0, -8,  2,  0, -6, -4,  1,  5,  5,  4, -1,  3, -3,-10,  3, -8, -5, -8,-18, -3, -2, -6, -3,-20,-20,-22],
    "W":   [  0, -1,-14, -1, -4,  4,  0, -6, -8,  2,  7,  7,  6,  0,  4, -1,-10,  0,-10, -3,-14,-30,  2, -2, -4, -2,-32,-34,-36],
    "ST":  [-12,  4,  1, -6,  0, -2, -8,-10,-16,  0,  1,  2, -2,  1, -4,  2,  1, -4,  3, -4, -6,-36,  4,-10,  0,  1,-36,-38,-40],
    "GK":  [-45,-50,-40,-25,-50,-45,-45,-45,-28,-30,-25,-25,-25, -4,-20,-20,-12,-25,-10,-45,-25,-35,-50,-25,-40,-20,-45,-45,-45],
}
ARQUETIPO = {"GK": "GK", "CB": "CB", "RB": "FB", "LB": "FB", "CDM": "CDM", "CM": "CM",
             "CAM": "CAM", "RM": "WM", "LM": "WM", "RW": "W", "LW": "W", "ST": "ST"}
POS_DETALLE = {  # (posición, peso)
    "ARQ": [("GK", 1)],
    "DEF": [("CB", 50), ("RB", 25), ("LB", 25)],
    "MED": [("CM", 30), ("CDM", 25), ("CAM", 15), ("RM", 15), ("LM", 15)],
    "DEL": [("ST", 55), ("RW", 22), ("LW", 23)],
}
SECUNDARIA = {"CB": ["CDM", "RB"], "RB": ["RM", "LB"], "LB": ["LM", "RB"], "CDM": ["CM", "CB"],
              "CM": ["CDM", "CAM"], "CAM": ["CM", "ST"], "RM": ["RW", "LM"], "LM": ["LW", "RM"],
              "RW": ["RM", "ST"], "LW": ["LM", "ST"], "ST": ["CAM", "RW"]}
ALTURA = {"GK": (186, 4), "CB": (184, 4), "FB": (175, 4), "CDM": (178, 5), "CM": (175, 5),
          "CAM": (173, 5), "WM": (173, 5), "W": (172, 5), "ST": (180, 5)}
DORSALES = {"GK": [1, 12, 25, 30], "CB": [2, 6, 4, 13, 24], "RB": [4, 14, 26], "LB": [3, 15, 27],
            "CDM": [5, 16, 22], "CM": [8, 16, 18], "CAM": [10, 20, 21], "RM": [7, 17], "LM": [11, 23],
            "RW": [7, 17, 19], "LW": [11, 23, 28], "ST": [9, 19, 29, 31]}

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

def elegir(rng, opciones):
    total = sum(p for _, p in opciones)
    x, acc = rng.uniform(0, total), 0
    for op, p in opciones:
        acc += p
        if x <= acc:
            return op
    return opciones[-1][0]

def short_name(nombre):
    partes = nombre.split()
    return nombre if len(partes) < 2 else f"{partes[0][0]}. {' '.join(partes[1:])}"

def estimar_jugador(j, club, liga_cfg, team_adj, partidos_club):
    rng = random.Random(f"mastereleven-{j['id']}")
    p = j.get("perfil") or {}
    edad = p.get("edad") or rng.choice([19, 21, 23, 25, 27, 29, 31])
    pres, tit, goles = p.get("presencias"), p.get("titular"), p.get("goles") or 0

    # Posición detallada (los goleadores de MED tienden a ser enganche)
    opciones = list(POS_DETALLE[j["pos"]])
    if j["pos"] == "MED" and pres and goles / max(pres, 1) > 0.2:
        opciones = [("CAM", 50), ("RM", 15), ("LM", 15), ("CM", 20)]
    pos = elegir(rng, opciones)
    arq = ARQUETIPO[pos]

    # Overall
    ov = liga_cfg["base_overall"] + team_adj
    if tit is not None and partidos_club:
        r = tit / max(partidos_club, 1)
        ov += -4 + 9 * min(1.0, r * 1.15)
    elif pres == 0:
        ov -= 3
    if edad < 20:   ov -= 4
    elif edad < 23: ov -= 2
    elif edad < 26: ov += 0
    elif edad < 32: ov += 1
    elif edad >= 35: ov -= 1
    if j["pos"] in ("MED", "DEL") and pres:
        gpp = goles / pres
        ov += 3 if gpp > 0.5 else (1.5 if gpp > 0.3 else 0)
    ov = int(round(clamp(ov + rng.gauss(0, 1.5), 40, 80)))

    # Atributos
    a = {}
    for k, off in zip(ATTRS, PLANTILLAS[arq]):
        a[k] = ov + off + rng.gauss(0, 3)
    if pres and goles / pres > 0.3:
        a["attacking_finishing"] += 4; a["mentality_positioning"] += 3
    if edad >= 32:
        for k in ("movement_acceleration", "movement_sprint_speed"): a[k] -= 4
        for k in ("movement_reactions", "mentality_composure", "mentality_vision"): a[k] += 2
    elif edad < 21:
        for k in ("movement_acceleration", "movement_sprint_speed"): a[k] += 2
        for k in ("movement_reactions", "mentality_composure"): a[k] -= 3
    a = {k: int(round(clamp(v, 10, 94))) for k, v in a.items()}

    if arq == "GK":
        g = dict(goalkeeping_diving=ov + 1, goalkeeping_handling=ov - 1, goalkeeping_kicking=ov - 6,
                 goalkeeping_positioning=ov, goalkeeping_reflexes=ov + 2, goalkeeping_speed=ov - 22)
        g = {k: int(round(clamp(v + rng.gauss(0, 2.5), 10, 94))) for k, v in g.items()}
    else:
        g = {k: rng.randint(6, 15) for k in GK_ATTRS}

    # Stats de carta (fórmulas aproximadas a las de FIFA)
    w = lambda pares: int(round(sum(a[k] * f for k, f in pares)))
    cara = dict(
        pace=w([("movement_acceleration", .45), ("movement_sprint_speed", .55)]),
        shooting=w([("attacking_finishing", .45), ("power_long_shots", .20), ("power_shot_power", .20),
                    ("mentality_positioning", .05), ("attacking_volleys", .05), ("mentality_penalties", .05)]),
        passing=w([("attacking_short_passing", .35), ("mentality_vision", .20), ("attacking_crossing", .20),
                   ("skill_long_passing", .15), ("skill_curve", .05), ("skill_fk_accuracy", .05)]),
        dribbling=w([("skill_dribbling", .40), ("skill_ball_control", .35), ("movement_agility", .10),
                     ("movement_balance", .05), ("movement_reactions", .05), ("mentality_composure", .05)]),
        defending=w([("defending_marking_awareness", .30), ("defending_standing_tackle", .30),
                     ("mentality_interceptions", .20), ("attacking_heading_accuracy", .10),
                     ("defending_sliding_tackle", .10)]),
        physic=w([("power_strength", .50), ("power_stamina", .25), ("mentality_aggression", .20),
                  ("power_jumping", .05)]),
    )

    # Varios
    zurdo = pos in ("LB", "LM", "LW")
    pie = "Left" if rng.random() < (0.7 if zurdo else 0.22) else "Right"
    mu, sd = ALTURA[arq]
    altura = int(round(clamp(rng.gauss(mu, sd), 160, 201)))
    posiciones = pos
    if pos != "GK" and rng.random() < 0.45:
        posiciones += ", " + rng.choice(SECUNDARIA[pos])

    fila = dict(short_name=short_name(j["nombre"]), club_name=club["nombre"],
                nationality_name="Argentina", club_jersey_number="", player_positions=posiciones,
                preferred_foot=pie, height_cm=altura, age=edad, overall=ov, seleccion="",
                league_name=liga_cfg["liga"], **cara, **a, **g)
    fila["_pos"], fila["_tit"] = pos, tit or 0
    return fila

def asignar_dorsales(filas):
    usados = set()
    for f in sorted(filas, key=lambda f: (-f["_tit"], -f["overall"])):
        num = next((n for n in DORSALES.get(f["_pos"], []) if n not in usados), None)
        if num is None:
            num = next(n for n in range(2, 100) if n not in usados)
        usados.add(num)
        f["club_jersey_number"] = num

# ------------------------------------------------------------------ main
def procesar_categoria(clave, sin_perfiles):
    cfg = CATEGORIAS[clave]
    print(f"\n=== {cfg['liga']} ===")
    clubes = parse_clubes(get_html(cfg["url"]))
    print(f"{len(clubes)} clubes")

    for c in clubes:
        c["jugadores"], c["pj"], c["ppg"] = parse_club(get_html(c["url"]), c["id"])
        print(f"  {c['nombre']}: {len(c['jugadores'])} jugadores, {c['pj']} PJ")

    if not sin_perfiles:
        todos = [j for c in clubes for j in c["jugadores"]]
        print(f"Bajando {len(todos)} perfiles...")
        def bajar(j):
            j["perfil"] = parse_perfil(get_html(j["url"]))
        with ThreadPoolExecutor(HILOS) as ex:
            for i, _ in enumerate(ex.map(bajar, todos), 1):
                if i % 100 == 0:
                    print(f"  {i}/{len(todos)}")

    ppgs = [c["ppg"] for c in clubes if c["ppg"] is not None]
    media = sum(ppgs) / len(ppgs) if ppgs else 1.35

    filas = []
    for c in clubes:
        team_adj = clamp(((c["ppg"] or media) - media) * 4, -3, 3)
        filas_club = [estimar_jugador(j, c, cfg, team_adj, c["pj"]) for j in c["jugadores"]]
        asignar_dorsales(filas_club)
        filas += filas_club

    with open(cfg["archivo"], "w", newline="", encoding="utf-8") as f:
        wr = csv.DictWriter(f, fieldnames=COLUMNAS, extrasaction="ignore")
        wr.writeheader()
        wr.writerows(filas)
    print(f"-> {cfg['archivo']} ({len(filas)} jugadores)")

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--solo", choices=CATEGORIAS.keys())
    ap.add_argument("--sin-perfiles", action="store_true")
    args = ap.parse_args()
    for clave in ([args.solo] if args.solo else CATEGORIAS):
        procesar_categoria(clave, args.sin_perfiles)