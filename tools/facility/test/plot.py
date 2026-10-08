import sys, re
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap
import numpy as np

lines = sys.stdin.read().splitlines()
info = [l for l in lines if l.startswith("GRIDINFO")][0].split("\t")
X0, X1, Z0, Z1 = map(int, info[1:5])
rows = [l[4:] for l in lines if l.startswith("ROW\t")]
grid = np.zeros((len(rows), X1 - X0))
for i, r in enumerate(rows):
    for j, c in enumerate(r):
        grid[i, j] = {" ": 0, "#": 1, ".": 2, ",": 3}.get(c, 0)
cmap = ListedColormap(["#0e1116", "#7a7f87", "#3a5a4a", "#a03030"])
fig, ax = plt.subplots(figsize=(11, 20))
ax.imshow(grid, cmap=cmap, extent=[X0, X1, Z1, Z0], interpolation="nearest", vmin=0, vmax=3)
# marker overlays: "MARK\tkind\tname\tx\tz"
colors = {"PlayerSpawn": "#4aa3ff", "ChestSpawn": "#ffd24a", "Extraction": "#4aff7a", "EnemySpawn": "#ff4a4a", "NPCSpawn": "#c58aff", "PatrolPoint": "#ffffff"}
for l in lines:
    if l.startswith("MARK\t"):
        _, kind, name, x, z, extra = (l.split("\t") + [""])[:6]
        ax.plot(float(x), float(z), "o", ms=5 if kind == "PatrolPoint" else 8, color=colors.get(kind, "w"), mec="k", mew=0.6)
        if kind in ("ChestSpawn", "Extraction", "PlayerSpawn"):
            ax.annotate(extra or name, (float(x), float(z)), color="w", fontsize=6, xytext=(4, 4), textcoords="offset points")
ax.set_xlabel("X (studs)"); ax.set_ylabel("Z (studs)  - north is up")
ax.set_title("Facility plan: grey=blocked (props+walls, player-inflated) green=walkable red=walkable but unreachable")
ax.grid(alpha=0.15)
plt.tight_layout()
plt.savefig(sys.argv[1], dpi=110)
print("saved", sys.argv[1])
