# Ayudas para escribir data/db/leagues/*.json (se corre con python3, fuera de Godot).
import json, os
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "data", "db", "leagues")

def K(shirt, shorts=None, socks=None, pat=None, pcol=None):
    shorts = shorts or shirt
    socks = socks or shirt
    s = "%s/%s/%s" % (shirt, shorts, socks)
    if pat:
        s += "|%s|%s" % (pat, pcol)
    return s

def C(id, name, short, home, away, stadium="", cap=0, r=0, keeper="1a1a1a", formation=None):
    d = {"id": id, "name": name, "short": short, "home": home, "away": away, "stadium": stadium, "cap": cap}
    if r: d["r"] = r
    if keeper != "1a1a1a": d["keeper"] = keeper
    if formation: d["formation"] = formation
    return d

def D(id, name, level, clubs, season):
    return {"id": id, "name": name, "level": level, "season": season, "clubs": clubs}

def write(country_id, name, nationality, names, skin, divisions):
    os.makedirs(OUT, exist_ok=True)
    ids = set()
    for d in divisions:
        for c in d["clubs"]:
            assert c["id"] not in ids, c["id"]
            ids.add(c["id"])
    data = {"id": country_id, "name": name, "nationality": nationality, "names": names, "skin": skin,
            "divisions": divisions}
    path = os.path.join(OUT, country_id + ".json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=1)
    print(path, [(d["id"], len(d["clubs"])) for d in divisions])
