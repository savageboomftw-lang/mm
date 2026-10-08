#!/usr/bin/env python3
"""Rough software preview of the facility from the headless mock scene dump.

Not Roblox rendering: boxes + 12-sided prisms, per-room point-light falloff, no shadows.
It exists to sanity check composition, lighting zones and colour, not final quality.

usage: render.py scene.txt out.png "x,y,z" "tx,ty,tz" [fov=72] [W=1280] [H=720]
"""
import sys, math
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.collections import PolyCollection

scene, out = sys.argv[1], sys.argv[2]
cam = np.array([float(v) for v in sys.argv[3].split(",")])
tgt = np.array([float(v) for v in sys.argv[4].split(",")])
fov = float(sys.argv[5]) if len(sys.argv) > 5 else 72
W = int(sys.argv[6]) if len(sys.argv) > 6 else 1280
H = int(sys.argv[7]) if len(sys.argv) > 7 else 720

parts, lights = [], []
for line in open(scene):
    f = line.rstrip("\n").split("\t")
    if f[0] == "PART":
        c = np.array(f[2].split(), float)
        r = np.array(f[3].split(), float).reshape(3, 3)
        s = np.array(f[4].split(), float)
        col = np.array(f[5].split(), float)
        parts.append(dict(room=f[1], c=c, r=r, s=s, col=col, mat=f[6].split(".")[1], tr=float(f[7]),
                          shape=f[8].split(".")[1], name=f[9], cc=f[10] == "1"))
    elif f[0] == "LIGHT":
        lights.append(dict(room=f[1], p=np.array(f[2].split(), float), col=np.array(f[3].split(), float),
                           b=float(f[4]), rng=float(f[5])))

# camera basis
fwd = tgt - cam
fwd /= np.linalg.norm(fwd)
right = np.cross(fwd, np.array([0, 1.0, 0]))
right /= np.linalg.norm(right)
up = np.cross(right, fwd)
fpx = 0.5 * W / math.tan(math.radians(fov) / 2)

BOX_FACES = [(0, 1, 3, 2), (4, 6, 7, 5), (0, 4, 5, 1), (2, 3, 7, 6), (0, 2, 6, 4), (1, 5, 7, 3)]
def box_corners(p):
    sx, sy, sz = p["s"] / 2
    pts = np.array([[sgn_x * sx, sgn_y * sy, sgn_z * sz] for sgn_x in (-1, 1) for sgn_y in (-1, 1) for sgn_z in (-1, 1)])
    return pts @ p["r"].T + p["c"]

def prism_faces(p, n=12):
    sx, sy, sz = p["s"]
    rad = min(sy, sz) / 2
    ang = np.linspace(0, 2 * math.pi, n, endpoint=False)
    ring = np.stack([np.zeros(n), np.cos(ang) * rad, np.sin(ang) * rad], 1)
    a = ring + np.array([-sx / 2, 0, 0])
    b = ring + np.array([sx / 2, 0, 0])
    faces = []
    for i in range(n):
        j = (i + 1) % n
        faces.append(np.array([a[i], a[j], b[j], b[i]]))
    faces.append(a[::-1].copy())
    faces.append(b.copy())
    return [f @ p["r"].T + p["c"] for f in faces]

def face_polys(p):
    if p["shape"] == "Cylinder":
        return prism_faces(p)
    cs = box_corners(p)
    return [cs[list(f)] for f in BOX_FACES]

def subdivide(poly, maxlen=7.0):
    # split large quads into cells so per-face lighting varies across big walls/floors
    if len(poly) != 4:
        return [poly]
    e1, e2 = poly[1] - poly[0], poly[3] - poly[0]
    n1, n2 = max(1, int(np.linalg.norm(e1) // maxlen)), max(1, int(np.linalg.norm(e2) // maxlen))
    n1, n2 = min(n1 + 1 if np.linalg.norm(e1) > maxlen else 1, 8), min(n2 + 1 if np.linalg.norm(e2) > maxlen else 1, 8)
    if n1 == 1 and n2 == 1:
        return [poly]
    res = []
    for i in range(n1):
        for j in range(n2):
            o = poly[0] + e1 * i / n1 + e2 * j / n2
            res.append(np.array([o, o + e1 / n1, o + e1 / n1 + e2 / n2, o + e2 / n2]))
    return res

AMB = {"Reception": 0.07, "Security": 0.07, "MainCorridor": 0.06, "ResearchLab": 0.06, "Medical": 0.06,
       "StorageB": 0.05, "Maintenance": 0.05, "ServiceHallA": 0.04, "ServiceHallB": 0.04, "Decon": 0.05,
       "Containment": 0.035, "Extraction": 0.06}
EMISSIVE = {"Neon"}

def shade(p, poly):
    cen = poly.mean(0)
    v1, v2 = poly[1] - poly[0], poly[2] - poly[0]
    n = np.cross(v1, v2)
    nl = np.linalg.norm(n)
    n = n / nl if nl > 1e-9 else np.array([0, 1.0, 0])
    if np.dot(n, cen - p["c"]) < 0:
        n = -n
    base = p["col"]
    if p["mat"] in EMISSIVE:
        return np.clip(base * 1.25 + 0.15, 0, 1)
    acc = np.full(3, AMB.get(p["room"], 0.05))
    for L in lights:
        if L["room"] != p["room"] and p["room"] not in ("Doorways", "GameplayMarkers"):
            continue
        d = L["p"] - cen
        dist = np.linalg.norm(d)
        if dist > L["rng"] or dist < 1e-6:
            continue
        att = (1 - dist / L["rng"]) ** 2
        lam = max(0.0, np.dot(n, d / dist)) * 0.8 + 0.2
        acc += L["col"] * L["b"] * att * lam * 0.55
    lit = base * acc
    if p["mat"] in ("Metal", "DiamondPlate", "CorrodedMetal", "Marble", "CeramicTiles"):
        lit = lit * 1.1
    return np.clip(1 - np.exp(-lit * 2.4), 0, 1)

def project(pts):
    d = pts - cam
    x, y, z = d @ right, d @ up, d @ fwd
    return x, y, z

def clip_near(x, y, z, near=0.4):
    out = []
    n = len(z)
    for i in range(n):
        j = (i + 1) % n
        a_in, b_in = z[i] >= near, z[j] >= near
        if a_in:
            out.append((x[i], y[i], z[i]))
        if a_in != b_in:
            t = (near - z[i]) / (z[j] - z[i])
            out.append((x[i] + t * (x[j] - x[i]), y[i] + t * (y[j] - y[i]), near))
    return out

polys, colors, depth, alphas = [], [], [], []
for p in parts:
    if p["tr"] >= 0.99:
        continue
    if np.linalg.norm(p["c"] - cam) - np.linalg.norm(p["s"]) / 2 > 110:
        continue
    dc = (p["c"] - cam) @ fwd
    if dc < -np.linalg.norm(p["s"]):
        continue
    glass = p["mat"] in ("Glass",) or p["tr"] > 0.05
    for poly in face_polys(p):
        if not glass:
            nrm = np.cross(poly[1] - poly[0], poly[2] - poly[0])
            cen0 = poly.mean(0)
            if np.dot(nrm, cen0 - p["c"]) < 0:
                nrm = -nrm
            if np.dot(nrm, cam - cen0) <= 0:
                continue
        for sp in subdivide(poly):
            col = shade(p, sp)
            x, y, z = project(sp)
            if (z < 0.4).all():
                continue
            pts = clip_near(x, y, z) if (z < 0.4).any() else list(zip(x, y, z))
            if len(pts) < 3:
                continue
            sc = [(W / 2 + fpx * px / pz, H / 2 - fpx * py / pz) for px, py, pz in pts]
            zz = np.mean([q[2] for q in pts])
            fog = 1 - math.exp(-zz / 90.0)
            col = col * (1 - fog * 0.6)
            a = 1.0
            if glass:
                a = max(0.12, 1 - p["tr"]) * 0.7
            polys.append(sc)
            colors.append((*col, a))
            depth.append(zz)

order = np.argsort(depth)[::-1]
fig = plt.figure(figsize=(W / 100, H / 100), dpi=100)
ax = fig.add_axes([0, 0, 1, 1])
ax.set_xlim(0, W)
ax.set_ylim(H, 0)
ax.axis("off")
ax.set_facecolor("#05060a")
fig.patch.set_facecolor("#05060a")
pc = PolyCollection([polys[i] for i in order], facecolors=[colors[i] for i in order], edgecolors="none", linewidths=0, antialiaseds=False)
ax.add_collection(pc)
fig.savefig(out, dpi=100, facecolor=fig.get_facecolor())
print("rendered", len(polys), "polys ->", out)
