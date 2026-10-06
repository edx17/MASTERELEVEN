#!/usr/bin/env python3
"""
Scraper de Transfermarkt -> CSV estilo FIFA para MASTERELEVEN.

Dato REAL (de la vista detallada del plantel de Transfermarkt):
  nombre, dorsal, posición principal, edad, nacionalidad, altura, pie hábil,
  valor de mercado, club (en selecciones: el club donde juega cada convocado)

ESTIMADO:
  overall (sale del valor de mercado + edad + ajuste por liga), atributos,
  posición secundaria. Si falta altura/pie/dorsal, también se estiman.

Grupos (corrélos por separado, así no se hace eterno):
  python scraper_transfermarkt.py selecciones
  python scraper_transfermarkt.py continentes
  python scraper_transfermarkt.py ligas
  python scraper_transfermarkt.py sub20
  python scraper_transfermarkt.py ligas --solo ARGC     # una sola competición

Columna "seleccion": se llena con el país si el jugador aparece en algún plantel
de 'selecciones' o 'continentes'. Por eso conviene correr esos dos primero.

Requisitos: pip install requests beautifulsoup4
El HTML se cachea en ./cache_transfermarkt (si se corta, relanzás y sigue).
"""
import argparse, csv, hashlib, json, math, os, random, re, sys, time

# charset_normalizer está roto en Python 3.15 y no lo necesitamos (forzamos UTF-8).
# Con esto requests y BeautifulSoup lo ignoran en vez de romperse.
sys.modules.setdefault("charset_normalizer", None)

import requests
from bs4 import BeautifulSoup

TM = "https://www.transfermarkt.com.ar"

# (código, url, nombre de liga en el CSV, ajuste de overall, overall base si no hay valor)
GRUPOS = {
    "selecciones": [
        ("FIWC", f"{TM}/copa-del-mundo/startseite/pokalwettbewerb/FIWC", "Copa del Mundo", 0, 62),
        ("UNLA", f"{TM}/uefa-nations-league-a/startseite/pokalwettbewerb/UNLA", "UEFA Nations League A", 0, 64),
        ("UNLB", f"{TM}/uefa-nations-league-b/startseite/pokalwettbewerb/UNLB", "UEFA Nations League B", 0, 60),
        ("UNLC", f"{TM}/uefa-nations-league-c/startseite/pokalwettbewerb/UNLC", "UEFA Nations League C", 0, 56),
    ],
    "continentes": [
        ("COPA", f"{TM}/copa-america/startseite/pokalwettbewerb/COPA", "Copa América", 1, 62),
        ("EURO", f"{TM}/eurocopa/startseite/pokalwettbewerb/EURO", "Eurocopa", 0, 64),
        ("GOCU", f"{TM}/copa-oro/startseite/pokalwettbewerb/GOCU", "Copa Oro", 0, 58),
        ("AFCN", f"{TM}/copa-de-africa/startseite/pokalwettbewerb/AFCN", "Copa Africana de Naciones", 1, 60),
        ("AFAC", f"{TM}/afc-asian-cup/startseite/pokalwettbewerb/AFAC", "Copa Asiática", 0, 58),
    ],
    "ligas": [
        ("ARGC", f"{TM}/torneo-final/startseite/wettbewerb/ARGC", "Primera División Argentina", 2, 63),
        ("BRA1", f"{TM}/campeonato-brasileiro-serie-a/startseite/wettbewerb/BRA1", "Brasileirao Serie A", 1, 64),
        ("GB1", f"{TM}/premier-league/startseite/wettbewerb/GB1", "Premier League", -2, 68),
        ("ES1", f"{TM}/laliga/startseite/wettbewerb/ES1", "LaLiga", 0, 67),
        ("IT1", f"{TM}/serie-a/startseite/wettbewerb/IT1", "Serie A", 0, 66),
        ("L1", f"{TM}/bundesliga/startseite/wettbewerb/L1", "Bundesliga", -1, 66),
        ("FR1", f"{TM}/ligue-1/startseite/wettbewerb/FR1", "Ligue 1", 0, 65),
        ("NL1", f"{TM}/eredivisie/startseite/wettbewerb/NL1", "Eredivisie", 0, 63),
        ("PO1", f"{TM}/liga-portugal/startseite/wettbewerb/PO1", "Liga Portugal", 0, 63),
        ("MLS1", f"{TM}/major-league-soccer/startseite/wettbewerb/MLS1", "Major League Soccer", -1, 62),
        ("MEX1", f"{TM}/liga-mx-clausura/startseite/wettbewerb/MEX1", "Liga MX", 0, 63),
        ("CLPD", f"{TM}/liga-de-primera/startseite/wettbewerb/CLPD", "Primera División de Chile", 2, 60),
    ],
    "sub20": [
        ("CLPI", f"{TM}/copa-lpf-proyeccion-apertura/startseite/wettbewerb/CLPI", "Copa LPF Proyección", 0, 54),
        ("CLIY", f"{TM}/copa-libertadores-sub-20/startseite/pokalwettbewerb/CLIY", "Copa Libertadores Sub-20", 0, 54),
        ("19YL", f"{TM}/uefa-youth-league/startseite/pokalwettbewerb/19YL", "UEFA Youth League", 0, 55),
        # Página índice: el script entra a cada liga juvenil europea que liste
        ("EUJ", f"{TM}/wettbewerbe/europaJugend/wettbewerbe?plus=1", None, 0, 52),
    ],
}
GRUPOS_SELECCION = ("selecciones", "continentes")

CACHE_DIR = "cache_transfermarkt"
SALIDA_DIR = "csv_transfermarkt"
INDICE_SELECCIONES = os.path.join(SALIDA_DIR, "indice_selecciones.json")
DELAY = 3.0   # Transfermarkt bloquea si le pegás rápido; no lo bajes de 2
HEADERS = {
    "User-Agent": ("Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
                   "(KHTML, like Gecko) Chrome/128.0 Safari/537.36"),
    "Accept-Language": "es-AR,es;q=0.9",
}

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
ATTRS = COLUMNAS[16:45]
GK_ATTRS = COLUMNAS[45:51]

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
            r = _session.get(url, timeout=30)
            if r.status_code == 200:
                r.encoding = "utf-8"
                with open(path, "w", encoding="utf-8") as f:
                    f.write(r.text)
                time.sleep(DELAY)
                return r.text
            print(f"  ! HTTP {r.status_code} en {url}", file=sys.stderr)
            if r.status_code in (403, 429):
                time.sleep(30 * (intento + 1))   # nos frenaron: esperar
                continue
        except requests.RequestException as e:
            print(f"  ! {e} en {url}", file=sys.stderr)
        time.sleep(5 * (intento + 1))
    return ""

# ------------------------------------------------------------------ parsing
RE_EQUIPO = re.compile(r"^(?:https?://[^/]+)?/([^/]+)/startseite/verein/(\d+)(?:/saison_id/(\d+))?")
RE_COMPE = re.compile(r"^(?:https?://[^/]+)?/([^/]+)/startseite/(wettbewerb|pokalwettbewerb)/([A-Z0-9]+)")
RE_JUGADOR = re.compile(r"/profil/spieler/(\d+)")

def parse_equipos(html):
    """Equipos (clubes o selecciones) que participan de una competición."""
    soup = BeautifulSoup(html, "html.parser")
    equipos, vistos = [], set()
    for tabla in soup.select("table.items"):
        for a in tabla.find_all("a", href=RE_EQUIPO):
            slug, eid, temp = RE_EQUIPO.match(a["href"]).groups()
            nombre = (a.get("title") or a.get_text(strip=True)).strip()
            if not nombre or eid in vistos:
                continue
            vistos.add(eid)
            sufijo = f"/saison_id/{temp}" if temp else ""
            equipos.append(dict(id=eid, nombre=nombre,
                                url=f"{TM}/{slug}/kader/verein/{eid}{sufijo}/plus/1"))
    return equipos

def parse_competiciones(html):
    """Para páginas índice (ligas juveniles europeas)."""
    soup = BeautifulSoup(html, "html.parser")
    compes, vistos = [], set()
    for a in soup.select("table.items a[href]"):
        m = RE_COMPE.match(a["href"])
        if not m:
            continue
        slug, tipo, cod = m.groups()
        nombre = (a.get("title") or a.get_text(strip=True)).strip()
        if cod in vistos or not nombre:
            continue
        vistos.add(cod)
        compes.append((cod, f"{TM}/{slug}/startseite/{tipo}/{cod}", nombre))
    return compes

RE_EDAD = re.compile(r"\((\d{1,2})\)")
RE_ALTURA = re.compile(r"(\d)[,.](\d{2})\s*m\b")
RE_VALOR = re.compile(r"([\d.,]+)\s*(mil\s*mill\.?|mill\.?|mio\.?|m|mil|k|th\.?)\s*€", re.I)

def parse_valor(texto):
    m = RE_VALOR.search(texto or "")
    if not m:
        return None
    num = float(m.group(1).replace(".", "").replace(",", "."))
    u = m.group(2).lower().replace(" ", "")
    if u.startswith("milmill"):
        return num * 1e9
    if u.startswith(("mill", "mio")) or u == "m":
        return num * 1e6
    return num * 1e3

def parse_pie(texto):
    t = texto.lower()
    if "ambidiestro" in t or "ambos" in t or "both" in t:
        return "Both"
    if "izquierdo" in t or "left" in t:
        return "Left"
    if "derecho" in t or "right" in t:
        return "Right"
    return None

def parse_plantel(html):
    soup = BeautifulSoup(html, "html.parser")
    jugadores = []
    for tr in soup.select("table.items > tbody > tr"):
        a = tr.select_one("td.hauptlink a[href*='/profil/spieler/']")
        if not a:
            continue
        texto = " ".join(tr.stripped_strings)
        filas_inline = tr.select("table.inline-table tr")
        pos_txt = filas_inline[1].get_text(" ", strip=True) if len(filas_inline) > 1 else ""
        num_div = tr.select_one(".rn_nummer")
        dorsal = num_div.get_text(strip=True) if num_div else ""
        banderas = [img.get("title", "") for img in tr.select("img.flaggenrahmen") if img.get("title")]
        club = ""
        for c in tr.find_all("a", href=RE_EQUIPO):
            club = (c.get("title") or "").strip() or (c.img.get("alt", "") if c.img else "")
            if club:
                break
        valor_td = tr.select_one("td.rechts.hauptlink")
        alt = RE_ALTURA.search(texto)
        edad = RE_EDAD.search(texto)
        jugadores.append(dict(
            id=RE_JUGADOR.search(a["href"]).group(1),
            nombre=a.get_text(strip=True),
            posicion_tm=pos_txt,
            dorsal=int(dorsal) if dorsal.isdigit() else None,
            edad=int(edad.group(1)) if edad else None,
            nacionalidad=banderas[0] if banderas else "",
            altura=int(alt.group(1)) * 100 + int(alt.group(2)) if alt else None,
            pie=parse_pie(texto),
            valor=parse_valor(valor_td.get_text(" ", strip=True) if valor_td else texto),
            club_actual=club,
        ))
    return jugadores

# ------------------------------------------------------------------ posiciones
def mapear_posicion(txt):
    t = txt.lower()
    reglas = [
        (("portero", "arquero", "goalkeeper"), "GK"),
        (("lateral izq", "left-back"), "LB"),
        (("lateral der", "right-back"), "RB"),
        (("defensa central", "defensor central", "centre-back", "zaguero"), "CB"),
        (("pivote", "mediocentro defensivo", "defensive midfield", "volante central"), "CDM"),
        (("mediocentro ofensivo", "mediapunta", "attacking midfield", "enganche"), "CAM"),
        (("interior der", "volante der", "right midfield"), "RM"),
        (("interior izq", "volante izq", "left midfield"), "LM"),
        (("mediocentro", "central midfield"), "CM"),
        (("extremo izq", "left winger"), "LW"),
        (("extremo der", "right winger"), "RW"),
        (("segundo delantero", "second striker"), "CF"),
        (("delantero", "centre-forward", "striker"), "ST"),
        (("defensa", "defender"), "CB"),
        (("medio", "midfield"), "CM"),
    ]
    for claves, pos in reglas:
        if any(k in t for k in claves):
            return pos
    return None

# ------------------------------------------------------------------ estimación
PLANTILLAS = {  # offsets respecto del overall, en el orden de ATTRS
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
ARQUETIPO = {"GK": "GK", "CB": "CB", "RB": "FB", "LB": "FB", "CDM": "CDM", "CM": "CM", "CAM": "CAM",
             "RM": "WM", "LM": "WM", "RW": "W", "LW": "W", "ST": "ST", "CF": "ST"}
SECUNDARIA = {"CB": ["CDM", "RB"], "RB": ["RM", "LB"], "LB": ["LM", "RB"], "CDM": ["CM", "CB"],
              "CM": ["CDM", "CAM"], "CAM": ["CM", "CF"], "RM": ["RW", "LM"], "LM": ["LW", "RM"],
              "RW": ["RM", "ST"], "LW": ["LM", "ST"], "ST": ["CF", "LW"], "CF": ["ST", "CAM"]}
ALTURA = {"GK": (188, 4), "CB": (186, 4), "FB": (177, 4), "CDM": (180, 5), "CM": (177, 5),
          "CAM": (175, 5), "WM": (175, 5), "W": (174, 5), "ST": (182, 5)}
POS_AZAR = [("CB", 18), ("RB", 8), ("LB", 8), ("CDM", 10), ("CM", 12), ("CAM", 8),
            ("RM", 4), ("LM", 4), ("RW", 7), ("LW", 7), ("ST", 12), ("GK", 10)]
DORSALES = {"GK": [1, 12, 13, 23], "CB": [2, 4, 6, 5, 15], "RB": [2, 4, 16], "LB": [3, 18],
            "CDM": [5, 6, 16], "CM": [8, 14, 18], "CAM": [10, 20, 22], "RM": [7, 17], "LM": [11, 21],
            "RW": [7, 17, 19], "LW": [11, 21, 27], "ST": [9, 19, 29], "CF": [9, 10, 19]}

# Valor de mercado (€) -> overall de referencia para un jugador de ~26 años
TABLA_VALOR = [(2.5e4, 52), (1e5, 57), (3e5, 61), (1e6, 66), (3e6, 70), (1e7, 75),
               (3e7, 80), (6e7, 84), (1e8, 87), (2e8, 91)]

def clamp(v, lo, hi):
    return max(lo, min(hi, v))

def overall_por_valor(valor):
    x = math.log10(max(valor, 1))
    pts = [(math.log10(v), o) for v, o in TABLA_VALOR]
    if x <= pts[0][0]:
        return pts[0][1] - (pts[0][0] - x) * 4
    for (x0, o0), (x1, o1) in zip(pts, pts[1:]):
        if x <= x1:
            return o0 + (o1 - o0) * (x - x0) / (x1 - x0)
    return pts[-1][1] + (x - pts[-1][0]) * 3

def ajuste_edad(edad):
    # El valor de los pibes está inflado por el potencial y el de los veteranos desinflado
    tabla = {17: -7, 18: -6, 19: -5, 20: -4, 21: -3, 22: -2, 23: -1}
    if edad is None:
        return 0
    if edad <= 23:
        return tabla.get(edad, -7)
    return {29: 1, 30: 2, 31: 3, 32: 4}.get(edad, 0 if edad < 29 else 5)

def elegir(rng, opciones):
    total = sum(p for _, p in opciones)
    x, acc = rng.uniform(0, total), 0
    for op, p in opciones:
        acc += p
        if x <= acc:
            return op
    return opciones[-1][0]

def short_name(nombre, nacionalidad):
    partes = nombre.split()
    if len(partes) < 2 or nacionalidad in ("Brasil", "Portugal"):
        return nombre        # "Vinícius Júnior" queda entero, no "V. Júnior"
    return f"{partes[0][0]}. {' '.join(partes[1:])}"

def estimar(j, club_name, liga, ajuste_liga, base_sin_valor, seleccion, nacionalidad_forzada=None):
    rng = random.Random(f"mastereleven-tm-{j['id']}")
    pos = mapear_posicion(j["posicion_tm"]) or elegir(rng, POS_AZAR)
    arq = ARQUETIPO[pos]
    edad = j["edad"] or rng.randint(20, 30)

    if j["valor"]:
        ov = overall_por_valor(j["valor"]) + ajuste_edad(edad) + ajuste_liga
    else:
        ov = base_sin_valor + ajuste_edad(edad) / 2
    ov = int(round(clamp(ov + rng.gauss(0, 1.2), 40, 93)))

    a = {k: ov + off + rng.gauss(0, 3) for k, off in zip(ATTRS, PLANTILLAS[arq])}
    if edad >= 31:
        for k in ("movement_acceleration", "movement_sprint_speed"): a[k] -= 2 + (edad - 31)
        for k in ("movement_reactions", "mentality_composure", "mentality_vision"): a[k] += 2
    elif edad < 21:
        for k in ("movement_acceleration", "movement_sprint_speed"): a[k] += 2
        for k in ("movement_reactions", "mentality_composure"): a[k] -= 3

    altura = j["altura"] or int(round(clamp(rng.gauss(*ALTURA[arq]), 160, 203)))
    # La altura real modula el físico: altos cabecean y aguantan, bajos giran
    d = (altura - ALTURA[arq][0]) / 5
    if arq != "GK":
        a["attacking_heading_accuracy"] += 2 * d; a["power_jumping"] += 1.5 * d
        a["power_strength"] += 2 * d
        a["movement_agility"] -= 1.5 * d; a["movement_balance"] -= 2 * d
    a = {k: int(round(clamp(v, 10, 95))) for k, v in a.items()}

    if arq == "GK":
        g = dict(goalkeeping_diving=ov + 1, goalkeeping_handling=ov - 1, goalkeeping_kicking=ov - 6,
                 goalkeeping_positioning=ov, goalkeeping_reflexes=ov + 2, goalkeeping_speed=ov - 22)
        g = {k: int(round(clamp(v + rng.gauss(0, 2.5), 10, 95))) for k, v in g.items()}
    else:
        g = {k: rng.randint(6, 15) for k in GK_ATTRS}

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

    pie = j["pie"] or ("Left" if rng.random() < (0.7 if pos in ("LB", "LM", "LW") else 0.22) else "Right")
    posiciones = pos
    if pos != "GK" and rng.random() < 0.5:
        posiciones += ", " + rng.choice(SECUNDARIA[pos])
    nac = nacionalidad_forzada or j["nacionalidad"] or ""

    fila = dict(short_name=short_name(j["nombre"], nac), club_name=club_name, nationality_name=nac,
                club_jersey_number=j["dorsal"] or "", player_positions=posiciones, preferred_foot=pie,
                height_cm=altura, age=edad, overall=ov, seleccion=seleccion, league_name=liga,
                **cara, **a, **g)
    fila["_pos"] = pos
    return fila

def completar_dorsales(filas):
    usados = {f["club_jersey_number"] for f in filas if f["club_jersey_number"]}
    for f in sorted(filas, key=lambda f: -f["overall"]):
        if f["club_jersey_number"]:
            continue
        num = next((n for n in DORSALES.get(f["_pos"], []) if n not in usados), None)
        if num is None:
            num = next(n for n in range(2, 100) if n not in usados)
        usados.add(num)
        f["club_jersey_number"] = num

# ------------------------------------------------------------------ main
def slug_archivo(texto):
    t = texto.lower()
    for a, b in zip("áéíóúüñ", "aeiouun"):
        t = t.replace(a, b)
    return re.sub(r"[^a-z0-9]+", "_", t).strip("_")

def cargar_indice():
    if os.path.exists(INDICE_SELECCIONES):
        with open(INDICE_SELECCIONES, encoding="utf-8") as f:
            return json.load(f)
    return {}

def procesar_competicion(grupo, cod, url, liga, ajuste, base, indice, es_seleccion):
    html = get_html(url)
    equipos = parse_equipos(html)
    if not equipos and "/startseite/" in url:      # copas: probar la página de participantes
        equipos = parse_equipos(get_html(url.replace("/startseite/", "/teilnehmer/")))
    print(f"\n=== {liga} ({cod}): {len(equipos)} equipos ===")
    filas = []
    for e in equipos:
        jugadores = parse_plantel(get_html(e["url"]))
        print(f"  {e['nombre']}: {len(jugadores)} jugadores")
        filas_eq = []
        for j in jugadores:
            if es_seleccion:
                indice[j["id"]] = e["nombre"]
                fila = estimar(j, j["club_actual"] or e["nombre"], liga, ajuste, base,
                               seleccion=e["nombre"], nacionalidad_forzada=e["nombre"])
            else:
                fila = estimar(j, e["nombre"], liga, ajuste, base, seleccion=indice.get(j["id"], ""))
            filas_eq.append(fila)
        if not es_seleccion:
            completar_dorsales(filas_eq)
        filas += filas_eq
    if not filas:
        print("  (sin jugadores, se omite el CSV)")
        return
    carpeta = os.path.join(SALIDA_DIR, grupo)
    os.makedirs(carpeta, exist_ok=True)
    archivo = os.path.join(carpeta, slug_archivo(liga) + ".csv")
    with open(archivo, "w", newline="", encoding="utf-8") as f:
        wr = csv.DictWriter(f, fieldnames=COLUMNAS, extrasaction="ignore")
        wr.writeheader()
        wr.writerows(filas)
    print(f"-> {archivo} ({len(filas)} jugadores)")

def procesar_grupo(grupo, solo=None):
    indice = cargar_indice()
    es_sel = grupo in GRUPOS_SELECCION
    for cod, url, liga, ajuste, base in GRUPOS[grupo]:
        if solo and cod != solo:
            continue
        if liga is None:   # página índice: expandir a cada competición
            for sub_cod, sub_url, sub_nombre in parse_competiciones(get_html(url)):
                procesar_competicion(grupo, sub_cod, sub_url, sub_nombre, ajuste, base, indice, es_sel)
        else:
            procesar_competicion(grupo, cod, url, liga, ajuste, base, indice, es_sel)
    if es_sel:
        os.makedirs(SALIDA_DIR, exist_ok=True)
        with open(INDICE_SELECCIONES, "w", encoding="utf-8") as f:
            json.dump(indice, f, ensure_ascii=False)

if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("grupo", choices=list(GRUPOS) + ["todo"])
    ap.add_argument("--solo", help="código de una competición, ej: ARGC, BRA1, FIWC")
    args = ap.parse_args()
    orden = ["selecciones", "continentes", "ligas", "sub20"] if args.grupo == "todo" else [args.grupo]
    for g in orden:
        procesar_grupo(g, args.solo)