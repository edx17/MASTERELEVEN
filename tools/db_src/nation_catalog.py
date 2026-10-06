# Catálogo de selecciones que no están en data/db/nations.json: el importador
# crea una cuando un CSV trae jugadores de ese país. Banderas simplificadas
# (ver FlagPainter) y camisetas titular/suplente "camiseta/pantalón/medias".
# python3 tools/db_src/nation_catalog.py
import json, os

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "data", "db", "nation_catalog.json")

EU_N = [95, 5, 0, 0]; EU = [90, 8, 2, 0]; BAL = [90, 10, 0, 0]; CAUC = [70, 30, 0, 0]
ARAB = [10, 70, 15, 5]; NAF = [5, 60, 30, 5]; AFR = [0, 5, 35, 60]; LAT = [30, 60, 7, 3]
CAR = [0, 10, 40, 50]; ASIA = [55, 45, 0, 0]; SAS = [5, 70, 25, 0]; OCE = [10, 50, 30, 10]

def e(k, c, x=0.5, y=0.5, r=0.15): return {"k": k, "c": c, "x": x, "y": y, "r": r}
def h(*c, em=None): return _f({"t": "h", "c": list(c)}, em)
def v(*c, em=None): return _f({"t": "v", "c": list(c)}, em)
def hw(c, w, em=None): return _f({"t": "hw", "c": c, "w": w}, em)
def vw(c, w, em=None): return _f({"t": "vw", "c": c, "w": w}, em)
def plain(c, em=None): return _f({"t": "plain", "c": [c]}, em)
def nordic(*c, em=None): return _f({"t": "nordic", "c": list(c)}, em)
def cross(a, b, em=None): return _f({"t": "cross", "c": [a, b]}, em)
def saltire(a, b, em=None): return _f({"t": "saltire", "c": [a, b]}, em)
def disc(a, b): return {"t": "disc", "c": [a, b]}
def ensign(c, em=None): return _f({"t": "ensign", "c": [c]}, em)
def tri(c, k, d=0.4, w=None, em=None):
    f = {"t": "tri", "c": c, "k": k, "d": d}
    if w: f["w"] = w
    return _f(f, em)
def canton(c, k, cw=0.4, ch=0.5, w=None, em=None):
    f = {"t": "canton", "c": c, "k": k, "cw": cw, "ch": ch}
    if w: f["w"] = w
    return _f(f, em)
def diag(a, b, k, f=None, d=1, em=None):
    s = {"t": "diag", "c": [a, b], "k": k, "d": d}
    if f: s["f"] = f
    return _f(s, em)
def _f(spec, em):
    if em: spec["e"] = em
    return spec
def stripes(a, b, n): return [a if i % 2 == 0 else b for i in range(n)]

NATIONS = []
def N(id, name, conf, level, names, skin, flag, home, away, aka=(), formation="4-4-2", keeper="1a1a1a", short=None):
    NATIONS.append({"id": id, "name": name, "short": short or id.upper(), "conf": conf, "wc": "", "level": level,
        "names": names, "skin": skin, "formation": formation, "flag": flag, "home": home, "away": away,
        "keeper": keeper, "aka": list(aka)})

# --- UEFA ---------------------------------------------------------------------------
N("alb", "Albania", "UEFA", 68, "balkan", BAL, plain("e41e20", e("disc", "000000", r=0.2)), "e41e20/e41e20/e41e20", "ffffff/ffffff/ffffff")
N("and", "Andorra", "UEFA", 52, "es_es", EU, v("10069f", "fedf00", "d50032", em=e("disc", "c7b37f", r=0.1)), "1a3e8f/d50032/1a3e8f", "fedf00/fedf00/fedf00")
N("arm", "Armenia", "UEFA", 63, "balkan", CAUC, h("d90012", "0033a0", "f2a800"), "d90012/d90012/d90012", "ffffff/ffffff/ffffff")
N("aze", "Azerbaiyán", "UEFA", 62, "tr", CAUC, h("00b5e2", "ef3340", "509e2f", em=e("cstar", "ffffff", 0.48, 0.5, 0.12)), "ffffff/ffffff/ffffff", "e31b23/e31b23/e31b23", ["azerbaijan"])
N("blr", "Bielorrusia", "UEFA", 62, "ru", EU_N, hw(["c8313e", "4aa657"], [2, 1]), "ffffff/ffffff/ffffff", "c8313e/c8313e/c8313e", ["belarus", "belarus"])
N("bih", "Bosnia y Herzegovina", "UEFA", 69, "balkan", BAL, diag("002395", "002395", "fecb00", d=-1), "1a3e8f/1a3e8f/1a3e8f", "ffffff/ffffff/ffffff", ["bosnia-herzegovina", "bosnia herzegovina", "bosnia and herzegovina", "bosnia"])
N("bul", "Bulgaria", "UEFA", 64, "balkan", BAL, h("ffffff", "00966e", "d62612"), "ffffff/1a8a4c/ffffff", "1a8a4c/1a8a4c/1a8a4c")
N("cyp", "Chipre", "UEFA", 60, "balkan", EU, plain("ffffff", e("disc", "d57800", r=0.18)), "1a3e8f/ffffff/1a3e8f", "ffffff/ffffff/ffffff", ["cyprus"])
N("cze", "Chequia", "UEFA", 73, "balkan", EU_N, tri(["ffffff", "d7141a"], "11457e", 0.5), "d7141a/ffffff/1a3e8f", "ffffff/ffffff/ffffff", ["republica checa", "czech republic", "czechia"])
N("est", "Estonia", "UEFA", 58, "nordic", EU_N, h("0072ce", "000000", "ffffff"), "1a5fb4/000000/ffffff", "ffffff/ffffff/ffffff")
N("fro", "Islas Feroe", "UEFA", 56, "nordic", EU_N, nordic("ffffff", "0065bd", "ed2939"), "ffffff/1a3e8f/ffffff", "1a3e8f/1a3e8f/1a3e8f", ["faroe islands", "feroe"])
N("fin", "Finlandia", "UEFA", 67, "nordic", EU_N, nordic("ffffff", "002f6c"), "ffffff/1a2a5c/ffffff", "1a2a5c/1a2a5c/1a2a5c", ["finland"])
N("geo", "Georgia", "UEFA", 70, "balkan", CAUC, cross("ffffff", "ff0000"), "ffffff/ffffff/ffffff", "c8102e/c8102e/c8102e")
N("gib", "Gibraltar", "UEFA", 48, "en", EU, hw(["ffffff", "da000c"], [2, 1], em=e("disc", "da000c", 0.5, 0.4, 0.12)), "c8102e/ffffff/c8102e", "ffffff/ffffff/ffffff")
N("gre", "Grecia", "UEFA", 72, "balkan", EU, canton(stripes("0d5eaf", "ffffff", 9), "0d5eaf", 0.37, 0.56), "ffffff/ffffff/ffffff", "1a5fb4/1a5fb4/1a5fb4", ["greece"])
N("hun", "Hungría", "UEFA", 73, "balkan", EU_N, h("cd2a3e", "ffffff", "436f4d"), "c8102e/ffffff/1a7a3c", "ffffff/ffffff/ffffff", ["hungary"])
N("isl", "Islandia", "UEFA", 65, "nordic", EU_N, nordic("02529c", "ffffff", "dc1e35"), "1a3e8f/1a3e8f/1a3e8f", "ffffff/ffffff/ffffff", ["iceland"])
N("irl", "Irlanda", "UEFA", 70, "en", EU_N, v("169b62", "ffffff", "ff883e"), "1a8a4c/ffffff/1a8a4c", "ffffff/ffffff/ffffff", ["ireland", "republic of ireland", "republica de irlanda"])
N("isr", "Israel", "UEFA", 66, "balkan", CAUC, hw(["ffffff", "0038b8", "ffffff", "0038b8", "ffffff"], [1, 1, 3, 1, 1], em=e("ring", "0038b8", r=0.14)), "ffffff/1a3e8f/ffffff", "1a3e8f/1a3e8f/1a3e8f")
N("kaz", "Kazajistán", "UEFA", 60, "ru", ASIA, plain("00afca", e("disc", "fec50c", r=0.14)), "fec50c/1a9ecf/fec50c", "1a9ecf/1a9ecf/1a9ecf", ["kazakhstan"])
N("lva", "Letonia", "UEFA", 56, "nordic", EU_N, hw(["9e3039", "ffffff", "9e3039"], [2, 1, 2]), "9e3039/ffffff/9e3039", "ffffff/ffffff/ffffff", ["latvia"])
N("lie", "Liechtenstein", "UEFA", 48, "ch_at", EU_N, h("002b7f", "ce1126", em=e("disc", "ffd83d", 0.25, 0.25, 0.08)), "1a3e8f/c8102e/1a3e8f", "c8102e/c8102e/c8102e")
N("ltu", "Lituania", "UEFA", 58, "nordic", EU_N, h("fdb913", "006a44", "c1272d"), "fdb913/1a7a3c/fdb913", "1a7a3c/1a7a3c/1a7a3c", ["lithuania"])
N("lux", "Luxemburgo", "UEFA", 60, "fr", EU, h("ef3340", "ffffff", "00a3e0"), "c8102e/ffffff/c8102e", "ffffff/ffffff/ffffff", ["luxembourg"])
N("mlt", "Malta", "UEFA", 52, "it", EU, v("ffffff", "cf142b", em=e("disc", "c0c0c0", 0.12, 0.15, 0.06)), "c8102e/ffffff/c8102e", "ffffff/ffffff/ffffff")
N("mda", "Moldavia", "UEFA", 55, "balkan", EU, v("0046ae", "ffd200", "cc092f", em=e("disc", "8a5a2b", r=0.12)), "1a3e8f/1a3e8f/1a3e8f", "c8102e/c8102e/c8102e", ["moldova"])
N("mne", "Montenegro", "UEFA", 64, "balkan", BAL, plain("c40308", e("disc", "d4af37", r=0.2)), "c8102e/c8102e/c8102e", "ffffff/ffffff/ffffff")
N("mkd", "Macedonia del Norte", "UEFA", 64, "balkan", BAL, plain("d20000", e("sun", "f8e92e", r=0.3)), "c8102e/c8102e/c8102e", "f8e92e/f8e92e/f8e92e", ["north macedonia", "macedonia"])
N("nir", "Irlanda del Norte", "UEFA", 65, "en", EU_N, cross("ffffff", "cc0000", em=e("disc", "cc0000", r=0.1)), "1a7a3c/ffffff/1a7a3c", "ffffff/ffffff/ffffff", ["northern ireland"])
N("rou", "Rumania", "UEFA", 71, "balkan", EU, v("002b7f", "fcd116", "ce1126"), "f6d21c/f6d21c/f6d21c", "1a3e8f/1a3e8f/1a3e8f", ["romania"])
N("smr", "San Marino", "UEFA", 40, "it", EU, h("ffffff", "5eb6e4", em=e("disc", "d4af37", r=0.1)), "5eb6e4/5eb6e4/5eb6e4", "ffffff/ffffff/ffffff")
N("srb", "Serbia", "UEFA", 74, "balkan", BAL, h("c6363c", "0c4076", "ffffff", em=e("disc", "c6363c", 0.35, 0.45, 0.16)), "c6363c/1a3e8f/ffffff", "ffffff/ffffff/ffffff")
N("svk", "Eslovaquia", "UEFA", 71, "balkan", EU_N, h("ffffff", "0b4ea2", "ee1c25", em=e("disc", "ee1c25", 0.33, 0.5, 0.17)), "1a3e8f/1a3e8f/1a3e8f", "ffffff/ffffff/ffffff", ["slovakia"])
N("svn", "Eslovenia", "UEFA", 70, "balkan", EU_N, h("ffffff", "0000ff", "ff0000", em=e("disc", "0000ff", 0.3, 0.35, 0.1)), "ffffff/ffffff/ffffff", "1a7a3c/1a7a3c/1a7a3c", ["slovenia"])
N("swe", "Suecia", "UEFA", 74, "nordic", EU_N, nordic("006aa7", "fecc00"), "fecc00/1a5fb4/fecc00", "1a5fb4/1a5fb4/1a5fb4", ["sweden"])
N("ukr", "Ucrania", "UEFA", 73, "ru", EU_N, h("0057b7", "ffd700"), "f6d21c/f6d21c/f6d21c", "1a5fb4/1a5fb4/1a5fb4", ["ukraine"])
N("wal", "Gales", "UEFA", 70, "en", EU_N, h("ffffff", "00b140", em=e("disc", "c8102e", r=0.2)), "c8102e/c8102e/c8102e", "f6d21c/1a7a3c/f6d21c", ["wales"])

# --- CONMEBOL -----------------------------------------------------------------------
N("ven", "Venezuela", "CONMEBOL", 72, "es_lat", LAT, h("ffcc00", "00247d", "cf142b", em=e("ring", "ffffff", r=0.14)), "7a1f2b/ffffff/7a1f2b", "ffffff/7a1f2b/ffffff", ["vinotinto"])

# --- CONCACAF -----------------------------------------------------------------------
N("crc", "Costa Rica", "CONCACAF", 68, "es_lat", LAT, hw(["002b7f", "ffffff", "ce1126", "ffffff", "002b7f"], [1, 1, 2, 1, 1]), "c8102e/1a3e8f/ffffff", "ffffff/ffffff/ffffff")
N("hon", "Honduras", "CONCACAF", 63, "es_lat", LAT, h("0073cf", "ffffff", "0073cf", em=e("star", "0073cf", r=0.07)), "ffffff/ffffff/ffffff", "1a5fb4/1a5fb4/1a5fb4")
N("slv", "El Salvador", "CONCACAF", 58, "es_lat", LAT, h("0047ab", "ffffff", "0047ab", em=e("disc", "d4af37", r=0.08)), "1a3e8f/1a3e8f/1a3e8f", "ffffff/ffffff/ffffff", ["salvador"])
N("gua", "Guatemala", "CONCACAF", 58, "es_lat", LAT, v("4997d0", "ffffff", "4997d0", em=e("disc", "6c8e3a", r=0.1)), "ffffff/1a5fb4/ffffff", "1a5fb4/1a5fb4/1a5fb4")
N("tri", "Trinidad y Tobago", "CONCACAF", 57, "caribe", CAR, diag("ce1126", "ce1126", "000000", "ffffff", d=-1), "c8102e/000000/c8102e", "ffffff/ffffff/ffffff", ["trinidad and tobago", "trinidad"])
N("cub", "Cuba", "CONCACAF", 50, "es_lat", CAR, tri(stripes("002a8f", "ffffff", 5), "cf142b", 0.45, em=e("star", "ffffff", 0.14, 0.5, 0.08)), "c8102e/1a3e8f/c8102e", "ffffff/ffffff/ffffff")
N("dom", "República Dominicana", "CONCACAF", 52, "es_lat", CAR, cross("002d62", "ffffff", em=e("disc", "ce1126", r=0.06)), "1a3e8f/1a3e8f/1a3e8f", "ffffff/ffffff/ffffff", ["dominican republic", "rep dominicana"])
N("nca", "Nicaragua", "CONCACAF", 50, "es_lat", LAT, h("0067c6", "ffffff", "0067c6", em=e("disc", "d4af37", r=0.07)), "1a5fb4/ffffff/1a5fb4", "ffffff/ffffff/ffffff")
N("ber", "Bermudas", "CONCACAF", 46, "caribe", CAR, ensign("c8102e", e("disc", "ffffff", 0.75, 0.5, 0.12)), "c8102e/1a3e8f/c8102e", "ffffff/ffffff/ffffff", ["bermuda"])
N("pur", "Puerto Rico", "CONCACAF", 46, "es_lat", LAT, tri(stripes("ed0a3f", "ffffff", 5), "0050f0", 0.45, em=e("star", "ffffff", 0.14, 0.5, 0.08)), "c8102e/1a3e8f/c8102e", "ffffff/ffffff/ffffff")
N("blz", "Belice", "CONCACAF", 44, "caribe", CAR, hw(["ce1126", "003f87", "ce1126"], [1, 8, 1], em=e("disc", "ffffff", r=0.2)), "1a3e8f/c8102e/1a3e8f", "ffffff/ffffff/ffffff", ["belize"])
N("guy", "Guyana", "CONCACAF", 46, "caribe", CAR, tri(["009e49"], "ce1126", 0.5), "f6d21c/1a7a3c/f6d21c", "1a7a3c/1a7a3c/1a7a3c")
N("brb", "Barbados", "CONCACAF", 42, "caribe", CAR, vw(["00267f", "ffc726", "00267f"], [1, 1, 1]), "f6d21c/1a3e8f/f6d21c", "1a3e8f/1a3e8f/1a3e8f")
N("gpe", "Guadalupe", "CONCACAF", 50, "fr", CAR, plain("cf142b", e("sun", "fcd116", r=0.2)), "c8102e/c8102e/c8102e", "ffffff/ffffff/ffffff", ["guadeloupe"])
N("mtq", "Martinica", "CONCACAF", 50, "fr", CAR, tri(["009e49", "000000"], "ce1126", 0.5), "1a7a3c/1a7a3c/1a7a3c", "ffffff/ffffff/ffffff", ["martinique"])
N("guf", "Guayana Francesa", "CONCACAF", 46, "fr", CAR, diag("5eb6e4", "5eb6e4", "fcd116", d=-1), "f6d21c/1a7a3c/f6d21c", "ffffff/ffffff/ffffff", ["french guiana"])

# --- CAF ----------------------------------------------------------------------------
N("mli", "Malí", "CAF", 71, "africa_w", AFR, v("14b53a", "fcd116", "ce1126"), "f6d21c/1a7a3c/c8102e", "ffffff/ffffff/ffffff", ["mali"])
N("bfa", "Burkina Faso", "CAF", 69, "africa_w", AFR, h("ef2b2d", "009e49", em=e("star", "fcd116", r=0.1)), "1a7a3c/1a7a3c/1a7a3c", "ffffff/ffffff/ffffff")
N("gui", "Guinea", "CAF", 67, "africa_w", AFR, v("ce1126", "fcd116", "009460"), "c8102e/f6d21c/1a7a3c", "ffffff/ffffff/ffffff")
N("gab", "Gabón", "CAF", 66, "africa_c", AFR, h("009e60", "fcd116", "3a75c4"), "f6d21c/1a5fb4/f6d21c", "1a7a3c/1a7a3c/1a7a3c", ["gabon"])
N("zam", "Zambia", "CAF", 63, "africa_en", AFR, plain("198a00", e("disc", "ef7d00", 0.85, 0.25, 0.07)), "1a7a3c/1a7a3c/1a7a3c", "ffffff/ffffff/ffffff")
N("zim", "Zimbabue", "CAF", 61, "africa_en", AFR, tri(["006400", "ffd200", "d40000", "000000", "d40000", "ffd200", "006400"], "ffffff", 0.45), "f6d21c/1a7a3c/f6d21c", "ffffff/ffffff/ffffff", ["zimbabwe"])
N("ang", "Angola", "CAF", 64, "africa_c", AFR, h("cc092f", "000000", em=e("disc", "ffcb00", r=0.12)), "c8102e/000000/c8102e", "ffffff/ffffff/ffffff")
N("ben", "Benín", "CAF", 62, "africa_w", AFR, canton(["fcd116", "e8112d"], "008751", 0.4, 1.0), "f6d21c/1a7a3c/f6d21c", "1a7a3c/1a7a3c/1a7a3c", ["benin"])
N("tog", "Togo", "CAF", 60, "africa_w", AFR, canton(stripes("006a4e", "ffce00", 5), "d21034", 0.4, 0.6, em=e("star", "ffffff", 0.2, 0.3, 0.1)), "f6d21c/1a7a3c/f6d21c", "ffffff/ffffff/ffffff")
N("uga", "Uganda", "CAF", 62, "africa_en", AFR, h("000000", "fcdc04", "d90000", "000000", "fcdc04", "d90000", em=e("disc", "ffffff", r=0.13)), "c8102e/000000/c8102e", "f6d21c/f6d21c/f6d21c")
N("ken", "Kenia", "CAF", 60, "africa_en", AFR, hw(["000000", "ffffff", "bb0000", "ffffff", "006600"], [3, 1, 3, 1, 3], em=e("disc", "bb0000", r=0.14)), "c8102e/c8102e/c8102e", "ffffff/ffffff/ffffff", ["kenya"])
N("tan", "Tanzania", "CAF", 58, "africa_en", AFR, diag("1eb53a", "00a3dd", "000000", "fcd116"), "1a7a3c/000000/1a7a3c", "ffffff/ffffff/ffffff")
N("moz", "Mozambique", "CAF", 58, "pt_pt", AFR, tri(["007168", "000000", "fce100"], "d21034", 0.45), "c8102e/000000/c8102e", "ffffff/ffffff/ffffff")
N("nam", "Namibia", "CAF", 56, "africa_en", AFR, diag("003580", "009543", "d21034", "ffffff"), "c8102e/1a3e8f/c8102e", "ffffff/ffffff/ffffff")
N("mad", "Madagascar", "CAF", 56, "fr", AFR, canton(["fc3d32", "007e3a"], "ffffff", 0.33, 1.0), "c8102e/ffffff/1a7a3c", "ffffff/ffffff/ffffff")
N("eqg", "Guinea Ecuatorial", "CAF", 60, "africa_c", AFR, tri(["3e9a00", "ffffff", "e32118"], "0073ce", 0.3), "c8102e/1a3e8f/c8102e", "ffffff/ffffff/ffffff", ["equatorial guinea"])
N("gnb", "Guinea-Bisáu", "CAF", 57, "pt_pt", AFR, canton(["fcd116", "009e49"], "ce1126", 0.33, 1.0, em=e("star", "000000", 0.16, 0.5, 0.08)), "c8102e/1a7a3c/c8102e", "ffffff/ffffff/ffffff", ["guinea-bissau", "guinea bissau", "guinea-bisau"])
N("sle", "Sierra Leona", "CAF", 56, "africa_w", AFR, h("1eb53a", "ffffff", "0072c6"), "1a7a3c/ffffff/1a5fb4", "ffffff/ffffff/ffffff", ["sierra leone"])
N("lby", "Libia", "CAF", 58, "arab", ARAB, hw(["e70013", "000000", "239e46"], [1, 2, 1], em=e("crescent", "ffffff", r=0.12)), "c8102e/000000/c8102e", "ffffff/ffffff/ffffff", ["libya"])
N("sud", "Sudán", "CAF", 56, "arab", AFR, tri(["d21034", "ffffff", "000000"], "007229", 0.35), "c8102e/ffffff/c8102e", "ffffff/ffffff/ffffff", ["sudan"])
N("mtn", "Mauritania", "CAF", 58, "arab", NAF, hw(["d01c1f", "00a95c", "d01c1f"], [1, 6, 1], em=e("crescent", "ffd700", r=0.16)), "1a7a3c/f6d21c/1a7a3c", "ffffff/ffffff/ffffff")
N("gam", "Gambia", "CAF", 58, "africa_w", AFR, hw(["ce1126", "ffffff", "0c1c8c", "ffffff", "3a7728"], [6, 1, 4, 1, 6]), "c8102e/1a3e8f/1a7a3c", "ffffff/ffffff/ffffff", ["the gambia"])
N("com", "Comoras", "CAF", 54, "fr", AFR, tri(["ffc61e", "ffffff", "ce1126", "3a75c4"], "3d8e33", 0.4), "1a7a3c/1a7a3c/1a7a3c", "ffffff/ffffff/ffffff", ["comoros"])
N("cgo", "Congo", "CAF", 58, "africa_c", AFR, diag("009543", "dc241f", "fbde4a"), "c8102e/c8102e/c8102e", "ffffff/ffffff/ffffff", ["republica del congo", "congo brazzaville", "republic of the congo"])
N("eth", "Etiopía", "CAF", 54, "africa_en", AFR, h("078930", "fcdd09", "da121a", em=e("disc", "0f47af", r=0.14)), "1a7a3c/f6d21c/c8102e", "ffffff/ffffff/ffffff", ["ethiopia"])
N("rwa", "Ruanda", "CAF", 55, "africa_en", AFR, hw(["00a1de", "fad201", "20603d"], [2, 1, 1], em=e("sun", "fad201", 0.8, 0.25, 0.08)), "f6d21c/1a5fb4/1a7a3c", "ffffff/ffffff/ffffff", ["rwanda"])
N("nig", "Níger", "CAF", 54, "africa_w", AFR, h("e05206", "ffffff", "0db02b", em=e("disc", "e05206", r=0.08)), "ef7d00/ef7d00/ef7d00", "ffffff/ffffff/ffffff", ["niger"])
N("mwi", "Malaui", "CAF", 54, "africa_en", AFR, h("000000", "ce1126", "339e35", em=e("sun", "ce1126", 0.5, 0.17, 0.1)), "c8102e/c8102e/c8102e", "ffffff/ffffff/ffffff", ["malawi"])
N("bot", "Botsuana", "CAF", 52, "africa_en", AFR, hw(["75aadb", "ffffff", "000000", "ffffff", "75aadb"], [9, 1, 4, 1, 9]), "75aadb/000000/75aadb", "ffffff/ffffff/ffffff", ["botswana"])
N("lbr", "Liberia", "CAF", 52, "africa_w", AFR, canton(stripes("bf0a30", "ffffff", 11), "002868", 0.35, 0.45, em=e("star", "ffffff", 0.17, 0.22, 0.1)), "c8102e/1a3e8f/c8102e", "ffffff/ffffff/ffffff")
N("bdi", "Burundi", "CAF", 52, "africa_en", AFR, saltire("ce1126", "ffffff", em=e("disc", "ffffff", r=0.2)), "c8102e/1a7a3c/c8102e", "ffffff/ffffff/ffffff")
N("les", "Lesoto", "CAF", 48, "africa_en", AFR, h("00209f", "ffffff", "009543"), "1a3e8f/1a7a3c/1a3e8f", "ffffff/ffffff/ffffff", ["lesotho"])
N("ssd", "Sudán del Sur", "CAF", 48, "africa_en", AFR, tri(["000000", "da121a", "078930"], "0f47af", 0.4), "ffffff/ffffff/ffffff", "c8102e/c8102e/c8102e", ["south sudan"])
N("stp", "Santo Tomé y Príncipe", "CAF", 42, "pt_pt", AFR, tri(["12ad2b", "ffce00", "12ad2b"], "d21034", 0.3), "1a7a3c/1a7a3c/1a7a3c", "ffffff/ffffff/ffffff", ["sao tome and principe"])

# --- AFC ----------------------------------------------------------------------------
N("uae", "Emiratos Árabes Unidos", "AFC", 64, "arab", ARAB, canton(["00732f", "ffffff", "000000"], "ff0000", 0.25, 1.0), "ffffff/ffffff/ffffff", "c8102e/c8102e/c8102e", ["united arab emirates", "emiratos arabes", "eau"])
N("oma", "Omán", "AFC", 62, "arab", ARAB, canton(["ffffff", "db161b", "008000"], "db161b", 0.25, 1.0), "c8102e/c8102e/c8102e", "ffffff/ffffff/ffffff", ["oman"])
N("bhr", "Baréin", "AFC", 61, "arab", ARAB, vw(["ffffff", "ce1126"], [1, 3]), "c8102e/c8102e/c8102e", "ffffff/ffffff/ffffff", ["bahrain", "barein", "bahrein"])
N("kuw", "Kuwait", "AFC", 56, "arab", ARAB, tri(["007a3d", "ffffff", "ce1126"], "000000", 0.3), "1a5fb4/1a5fb4/1a5fb4", "ffffff/ffffff/ffffff", ["kuwait"])
N("syr", "Siria", "AFC", 62, "arab", ARAB, h("007a3d", "ffffff", "000000", em=[e("star", "ce1126", 0.35, 0.5, 0.06), e("star", "ce1126", 0.5, 0.5, 0.06), e("star", "ce1126", 0.65, 0.5, 0.06)]), "c8102e/ffffff/c8102e", "ffffff/ffffff/ffffff", ["syria"])
N("lbn", "Líbano", "AFC", 58, "arab", ARAB, hw(["ed1c24", "ffffff", "ed1c24"], [1, 2, 1], em=e("disc", "00a651", r=0.16)), "c8102e/ffffff/c8102e", "ffffff/ffffff/ffffff", ["lebanon", "libano"])
N("ple", "Palestina", "AFC", 60, "arab", ARAB, tri(["000000", "ffffff", "007a3d"], "ce1126", 0.4), "ffffff/1a7a3c/ffffff", "c8102e/000000/c8102e", ["palestine"])
N("ind", "India", "AFC", 56, "en", SAS, h("ff9933", "ffffff", "138808", em=e("ring", "000080", r=0.09)), "1a5fb4/ffffff/1a5fb4", "ffffff/ffffff/ffffff")
N("tha", "Tailandia", "AFC", 60, "cn", ASIA, hw(["a51931", "f4f5f8", "2d2a4a", "f4f5f8", "a51931"], [1, 1, 2, 1, 1]), "1a3e8f/1a3e8f/1a3e8f", "ffffff/ffffff/ffffff", ["thailand"])
N("vie", "Vietnam", "AFC", 58, "cn", ASIA, plain("da251d", e("star", "ffff00", r=0.25)), "c8102e/c8102e/c8102e", "ffffff/ffffff/ffffff", ["viet nam"])
N("idn", "Indonesia", "AFC", 60, "cn", SAS, h("ff0000", "ffffff"), "c8102e/ffffff/c8102e", "ffffff/ffffff/ffffff")
N("mas", "Malasia", "AFC", 55, "cn", SAS, canton(stripes("cc0001", "ffffff", 14), "010066", 0.5, 0.57, em=e("cstar", "ffcc00", 0.2, 0.28, 0.12)), "f6d21c/000000/f6d21c", "000000/000000/000000", ["malaysia"])
N("phi", "Filipinas", "AFC", 54, "en", SAS, tri(["0038a8", "ce1126"], "ffffff", 0.45, em=e("sun", "fcd116", 0.14, 0.5, 0.07)), "1a3e8f/1a3e8f/1a3e8f", "ffffff/ffffff/ffffff", ["philippines"])
N("kgz", "Kirguistán", "AFC", 54, "ru", ASIA, plain("e8112d", e("sun", "ffef00", r=0.2)), "c8102e/c8102e/c8102e", "ffffff/ffffff/ffffff", ["kyrgyzstan"])
N("tjk", "Tayikistán", "AFC", 56, "ir_uz", ASIA, hw(["cc0000", "ffffff", "006600"], [2, 3, 2], em=e("disc", "f8c300", r=0.08)), "ffffff/ffffff/ffffff", "c8102e/c8102e/c8102e", ["tajikistan"])
N("tkm", "Turkmenistán", "AFC", 52, "ir_uz", ASIA, plain("00843d", e("crescent", "ffffff", 0.3, 0.25, 0.1)), "1a7a3c/1a7a3c/1a7a3c", "ffffff/ffffff/ffffff", ["turkmenistan"])
N("prk", "Corea del Norte", "AFC", 58, "kr", ASIA, hw(["024fa2", "ffffff", "ed1c27", "ffffff", "024fa2"], [6, 1, 15, 1, 6], em=[e("disc", "ffffff", 0.35, 0.5, 0.14), e("star", "ed1c27", 0.35, 0.5, 0.12)]), "c8102e/c8102e/c8102e", "ffffff/ffffff/ffffff", ["north korea", "korea dpr", "corea del norte"])
N("hkg", "Hong Kong", "AFC", 52, "cn", ASIA, plain("de2910", e("disc", "ffffff", r=0.18)), "c8102e/ffffff/c8102e", "ffffff/ffffff/ffffff")
N("sin", "Singapur", "AFC", 50, "cn", SAS, h("ef3340", "ffffff", em=e("crescent", "ffffff", 0.2, 0.25, 0.1)), "c8102e/c8102e/c8102e", "ffffff/ffffff/ffffff", ["singapore"])
N("yem", "Yemen", "AFC", 50, "arab", ARAB, h("ce1126", "ffffff", "000000"), "c8102e/ffffff/c8102e", "ffffff/ffffff/ffffff")
N("afg", "Afganistán", "AFC", 48, "ir_uz", SAS, v("000000", "d32011", "007a36", em=e("disc", "ffffff", r=0.12)), "c8102e/c8102e/c8102e", "ffffff/ffffff/ffffff", ["afghanistan"])
N("mya", "Myanmar", "AFC", 48, "cn", SAS, h("fecb00", "34b233", "ea2839", em=e("star", "ffffff", r=0.22)), "c8102e/ffffff/c8102e", "ffffff/ffffff/ffffff", ["birmania"])
N("cam", "Camboya", "AFC", 44, "cn", SAS, hw(["032ea1", "e00025", "032ea1"], [1, 2, 1], em=e("disc", "ffffff", r=0.12)), "1a3e8f/1a3e8f/1a3e8f", "c8102e/c8102e/c8102e", ["cambodia"])
N("mgl", "Mongolia", "AFC", 42, "cn", ASIA, v("c4272f", "015197", "c4272f", em=e("disc", "ffd900", 0.17, 0.5, 0.08)), "c8102e/c8102e/c8102e", "ffffff/ffffff/ffffff")
N("bgd", "Bangladés", "AFC", 44, "en", SAS, plain("006a4e", e("disc", "f42a41", 0.45, 0.5, 0.2)), "c8102e/1a7a3c/c8102e", "ffffff/ffffff/ffffff", ["bangladesh"])
N("pak", "Pakistán", "AFC", 44, "en", SAS, canton(["01411c"], "ffffff", 0.25, 1.0, em=e("cstar", "ffffff", 0.6, 0.5, 0.2)), "1a7a3c/1a7a3c/1a7a3c", "ffffff/ffffff/ffffff", ["pakistan"])

# --- OFC ----------------------------------------------------------------------------
N("fij", "Fiyi", "OFC", 50, "nz_oc", OCE, ensign("68bfe5", e("disc", "ffffff", 0.75, 0.5, 0.12)), "ffffff/000000/000000", "1a5fb4/1a5fb4/1a5fb4", ["fiji"])
N("tah", "Tahití", "OFC", 46, "fr", OCE, hw(["ce1126", "ffffff", "ce1126"], [1, 2, 1], em=e("disc", "fcd116", r=0.14)), "c8102e/ffffff/c8102e", "ffffff/ffffff/ffffff", ["tahiti"])
N("sol", "Islas Salomón", "OFC", 46, "nz_oc", OCE, diag("0051ba", "215b33", "fcd116"), "f6d21c/1a3e8f/ffffff", "1a3e8f/1a3e8f/1a3e8f", ["solomon islands"])
N("png", "Papúa Nueva Guinea", "OFC", 44, "nz_oc", OCE, diag("000000", "ce1126", "000000", d=-1, em=e("star", "fcd116", 0.7, 0.3, 0.08)), "c8102e/000000/c8102e", "ffffff/ffffff/ffffff", ["papua new guinea"])
N("van", "Vanuatu", "OFC", 42, "nz_oc", OCE, tri(["d21034", "009543"], "000000", 0.45), "f6d21c/000000/f6d21c", "ffffff/ffffff/ffffff")

ids = set()
for n in NATIONS:
    assert n["id"] not in ids, n["id"]
    ids.add(n["id"])
base = json.load(open(os.path.join(os.path.dirname(OUT), "nations.json"), encoding="utf-8"))
clash = ids & {n["id"] for n in base["nations"]}
assert not clash, clash
with open(OUT, "w", encoding="utf-8") as f:
    json.dump({"nations": NATIONS}, f, ensure_ascii=False, indent=1)
print(OUT, len(NATIONS))
