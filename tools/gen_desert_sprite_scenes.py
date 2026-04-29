# 一次性工具：从「荒漠素材.png」按非白连通域切图并生成 Sprite2D 场景（region_rect）。
# 运行：在项目根目录执行  python tools/gen_desert_sprite_scenes.py

from __future__ import annotations

import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PNG = ROOT / "assets/sprites/scene/荒漠素材.png"
OUT_DIR = ROOT / "scenes/sceneItems/desert_sheet"
TEXTURE_UID = "uid://djs6e5ws5ynrg"
TEXTURE_PATH = "res://assets/sprites/scene/荒漠素材.png"
MIN_AREA = 80


def load_components():
    """读取 PNG，按非白像素做四连通 flood fill，返回面积 ≥ MIN_AREA 的包围盒列表（阅读顺序排序）。"""
    from PIL import Image

    im = Image.open(PNG).convert("RGBA")
    w, h = im.size
    px = im.load()

    def is_fg(c):
        r, g, b, a = c
        if a < 128:
            return False
        if r > 250 and g > 250 and b > 250:
            return False
        return True

    mask = [[is_fg(px[x, y]) for x in range(w)] for y in range(h)]
    vis = [[False] * w for _ in range(h)]

    def flood(sx: int, sy: int):
        if not mask[sy][sx] or vis[sy][sx]:
            return None
        stack = [(sx, sy)]
        vis[sy][sx] = True
        minx = maxx = sx
        miny = maxy = sy
        area = 0
        while stack:
            cx, cy = stack.pop()
            area += 1
            minx = min(minx, cx)
            maxx = max(maxx, cx)
            miny = min(miny, cy)
            maxy = max(maxy, cy)
            for dx, dy in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                nx, ny = cx + dx, cy + dy
                if 0 <= nx < w and 0 <= ny < h and not vis[ny][nx] and mask[ny][nx]:
                    vis[ny][nx] = True
                    stack.append((nx, ny))
        return (minx, miny, maxx + 1, maxy + 1, area)

    comps: list[tuple[int, int, int, int, int]] = []
    for y in range(h):
        for x in range(w):
            if mask[y][x] and not vis[y][x]:
                b = flood(x, y)
                if b:
                    comps.append(b)
    comps = [c for c in comps if c[4] >= MIN_AREA]
    comps.sort(key=lambda c: ((c[1] + c[3]) / 2, (c[0] + c[2]) / 2))
    return comps


def classify_word(c: tuple[int, int, int, int, int]) -> str:
    """按包围盒与面积粗分英文类名（与 tree1 同类风格）；不保证与美术一一对应，仅便于区分。"""
    x0, y0, x1, y1, area = c
    w, h = x1 - x0, y1 - y0
    cx = (x0 + x1) / 2
    cy = (y0 + y1) / 2
    ar = h / max(w, 1)

    # 噪点 / 碎屑（略放宽以吃掉底部小点与小土块）
    if area < 2500 and max(w, h) < 88:
        return "speck"
    # 右上大型风滚草团
    if cy < 330 and cx > 2100 and w > 450:
        return "weed"
    # 右侧中型枯草团
    if cx > 2480 and 580 < cy < 720 and 15000 < area < 28000:
        return "weed"
    # 中上仙人掌丛
    if cy < 400 and 1450 < cx < 1950 and area > 70000:
        return "cactus"
    # 站立骨架（整牛）
    if 900 < cx < 1300 and 150 < cy < 450 and 30000 < area < 60000:
        return "skeleton"
    # 左上骨堆 + 碎骨大簇
    if cx < 550 and cy < 400 and area > 90000:
        return "bone"
    # 秃鹫（左组）
    if 850 < cx < 1200 and 580 < cy < 780 and 15000 < area < 22000:
        return "bird"
    # 秃鹫 / 鸟（右组）
    if 2100 < cx < 2400 and 550 < cy < 720 and 20000 < area < 27000:
        return "bird"
    # 高瘦鸵鸟状
    if 1880 < cx < 2080 and 550 < cy < 820 and h > 380 and 35000 < area < 50000:
        return "beast"
    # 头骨 + 碎骨小簇（左中下）
    if cx < 300 and 600 < cy < 900 and area > 20000:
        return "skull"
    # 兔子
    if 450 < cx < 700 and 750 < cy < 900 and 18000 < area < 28000:
        return "rabbit"
    # 蜥蜴竖条
    if 1750 < cx < 2000 and 750 < cy < 1050 and ar > 2.5 and area < 20000:
        return "lizard"
    # 圆桶掌
    if 2100 < cx and 800 < cy < 1000 and w > 200 and h > 150:
        return "barrel"
    # 中型灌木（中右大块）
    if 1300 < cx < 1800 and 750 < cy < 950 and 40000 < area < 60000:
        return "bush"
    # 左下小灌木团
    if 250 < cx < 400 and 800 < cy < 920 and 3000 < area < 7000:
        return "bush"
    # 中下横向灌丛
    if 850 < cx < 1100 and cy > 850 and w > 280 and area < 25000:
        return "bush"
    # 中底单行小草（面积较小）
    if 1020 < cy < 1240 and area < 12000 and max(w, h) < 130:
        return "grass"
    # 底部草丛 / 条状草（成片）
    if cy > 1120 and area > 8000:
        if area > 20000:
            return "grass"
        return "tuft"
    # 底部石块堆 / 小石块
    if cy > 1180 and 500 < area < 22000 and 0.35 < w / max(h, 1) < 3.0:
        return "rock"
    # 细长枯枝
    if max(w, h) > 180 and min(w, h) < 90:
        return "twig"
    # 横向短草茎 / 枯枝
    if 1800 < cx < 2000 and cy > 1100 and w < 160 and h < 100:
        return "stick"
    # 竖条碎片
    if ar > 2.0 and area < 15000 and cy < 1250:
        return "stick"
    # 横向倒地木 / 长条堆
    if cy > 1300 and w > 200 and h < 120:
        return "log"
    return "dune"


def sanitize_stem(word: str, n: int) -> str:
    stem = f"{word}{n}"
    if not re.match(r"^[a-z][a-z0-9]*$", stem):
        raise ValueError(stem)
    return stem


def make_uid(seed: str) -> str:
    # 稳定、可读：短 hash 十六进制
    import hashlib

    h = hashlib.sha256(seed.encode()).hexdigest()[:12]
    return f"uid://des{h}"


def write_tscn(path: Path, node_name: str, rect: tuple[float, float, float, float]) -> None:
    x, y, rw, rh = (int(round(v)) for v in rect)
    uid = make_uid(node_name + repr((x, y, rw, rh)))
    text = f"""[gd_scene format=3 uid="{uid}"]

[ext_resource type="Texture2D" uid="{TEXTURE_UID}" path="{TEXTURE_PATH}" id="1_tex"]

[node name="{node_name}" type="Sprite2D"]
texture = ExtResource("1_tex")
region_enabled = true
region_rect = Rect2({x}, {y}, {rw}, {rh})
"""
    path.write_text(text, encoding="utf-8")


def main() -> None:
    """生成 `desert_sheet/*.tscn` 与 `manifest.json`；运行前会删除目录内旧 .tscn。"""
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for old in OUT_DIR.glob("*.tscn"):
        old.unlink()
    comps = load_components()
    counts: dict[str, int] = defaultdict(int)
    used_names: set[str] = set()
    manifest: list[dict] = []

    for c in comps:
        x0, y0, x1, y1, _area = c
        w, h = x1 - x0, y1 - y0
        word = classify_word(c)
        counts[word] += 1
        n = counts[word]
        stem = sanitize_stem(word, n)
        # 重名则顺延数字
        while stem in used_names:
            counts[word] += 1
            n = counts[word]
            stem = sanitize_stem(word, n)
        used_names.add(stem)

        rect = (float(x0), float(y0), float(w), float(h))
        path = OUT_DIR / f"{stem}.tscn"
        write_tscn(path, stem, rect)
        manifest.append(
            {
                "scene": str(path.relative_to(ROOT)).replace("\\", "/"),
                "node": stem,
                "region_rect": [x0, y0, w, h],
                "class": word,
            }
        )

    (OUT_DIR / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(f"Wrote {len(manifest)} scenes to {OUT_DIR}")
    print(f"Manifest: {OUT_DIR / 'manifest.json'}")


if __name__ == "__main__":
    main()
