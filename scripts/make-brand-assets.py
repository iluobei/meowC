#!/usr/bin/env python3
# 从 design/brand/ 的源图生成 Android / Windows 全部品牌资源（需要 Pillow）。
#   head-black.png     用户手绘的黑发猫娘头像（透明底）→ 奶白底 = 浅色图标
#   head-silver.png    银发版（透明底）→ 深色底 = 深色图标
#   menubar-color.png  彩色「启动前 | 启动后」两格 → Windows 托盘彩色（未运行）
#   menubar-mono.png   单色「启动前 | 启动后」两格（白底黑图）→ Windows 托盘黑 / 白剪影（运行中）
#   control-glyph.png  白色剪影（透明底）→ Android 通知小图标 / 快捷设置磁贴 / 快捷方式
# 与 iOS 端同一套源图，产物尺寸按各平台规范。用法：python3 scripts/make-brand-assets.py
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BRAND = os.path.join(ROOT, "design/brand")
RES = os.path.join(ROOT, "android/app/src/main/res")
IMAGES = os.path.join(ROOT, "assets/images")
LIGHT_BG = (252, 250, 244)   # 与 iOS 浅色图标一致
DARK_BG = (59, 56, 65)
DENSITY = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

def out(path):
    os.makedirs(os.path.dirname(path), exist_ok=True); return path

def head(path):
    im = Image.open(path).convert("RGBA")
    return im.crop(im.split()[3].point(lambda v: 255 if v > 10 else 0).getbbox())

def fit(im, side, fill):
    scale = side * fill / max(im.size)
    return im.resize((max(1, round(im.width * scale)), max(1, round(im.height * scale))), Image.LANCZOS)

def head_on(path, bg, side, fill):
    # 头像长边缩到 side×fill，居中放在纯色方块上
    h = fit(head(path), side, fill)
    canvas = Image.new("RGBA", (side, side), bg + (255,))
    canvas.paste(h, ((side - h.width) // 2, (side - h.height) // 2), h)
    return canvas

def rounded(im, ratio):
    im = im.convert("RGBA"); w, hh = im.size
    m = Image.new("L", (w, hh), 0)
    ImageDraw.Draw(m).rounded_rectangle((0, 0, w - 1, hh - 1), radius=int(w * ratio), fill=255)
    im.putalpha(m); return im

def circle(im):
    im = im.convert("RGBA"); w, hh = im.size
    m = Image.new("L", (w, hh), 0); ImageDraw.Draw(m).ellipse((0, 0, w - 1, hh - 1), fill=255)
    im.putalpha(m); return im

def transparent(path, side, fill, tint=None):
    # 透明底上的头像；tint 给定时只保留 alpha 并涂成该色（单色层）
    h = fit(head(path), side, fill)
    if tint is not None:
        solid = Image.new("RGBA", h.size, tint + (255,)); solid.putalpha(h.split()[3]); h = solid
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(h, ((side - h.width) // 2, (side - h.height) // 2), h)
    return canvas

def save_densities(make, name, folder, dp):
    for q, k in DENSITY.items():
        make(round(dp * k)).save(out(os.path.join(RES, f"{folder}-{q}", f"{name}.png")), optimize=True)

black, silver = os.path.join(BRAND, "head-black.png"), os.path.join(BRAND, "head-silver.png")
light_art = head_on(black, LIGHT_BG, 1024, 0.80)
dark_art = head_on(silver, DARK_BG, 1024, 0.80)

# ---- Android 自适应图标：108dp 画布、系统只保证中央 66dp 圆内可见 → 头像长边占 54%（圆形遮罩下耳尖略被裁，squircle 完整） ----
save_densities(lambda px: transparent(black, px, 0.54), "ic_launcher_fg_light", "mipmap", 108)
save_densities(lambda px: transparent(silver, px, 0.54), "ic_launcher_fg_dark", "mipmap", 108)
save_densities(lambda px: transparent(black, px, 0.54, tint=(255, 255, 255)), "ic_launcher_mono", "mipmap", 108)
for name, bg, fg in (("light", LIGHT_BG, "ic_launcher_fg_light"), ("dark", DARK_BG, "ic_launcher_fg_dark")):
    for base in (f"ic_launcher_{name}", f"ic_launcher_round_{name}"):
        xml = base if name == "light" else base.replace("_dark", "")   # 深色版沿用 Bettbox 的 ic_launcher / ic_launcher_round 文件名
        with open(out(os.path.join(RES, "mipmap-anydpi-v26", f"{xml}.xml")), "w") as f:
            f.write('<?xml version="1.0" encoding="utf-8"?>\n<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                    f'    <background android:drawable="@color/ic_launcher_bg_{name}" />\n'
                    f'    <foreground android:drawable="@mipmap/{fg}" />\n'
                    '    <monochrome android:drawable="@mipmap/ic_launcher_mono" />\n</adaptive-icon>\n')
with open(out(os.path.join(RES, "values", "ic_launcher_colors.xml")), "w") as f:
    f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_launcher_bg_light">#%02X%02X%02X</color>\n    <color name="ic_launcher_bg_dark">#%02X%02X%02X</color>\n</resources>\n' % (LIGHT_BG + DARK_BG))

# ---- Android 启动画面图标：288dp 画布、圆形遮罩内 192dp → 圆盘底色 + 头像 ----
def splash(bg, src):
    def make(px):
        disc = circle(head_on(src, bg, round(px * 192 / 288), 0.70))
        canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
        canvas.paste(disc, ((px - disc.width) // 2, (px - disc.height) // 2), disc)
        return canvas
    return make
save_densities(splash(LIGHT_BG, black), "splash_text_light", "drawable", 288)
save_densities(splash(DARK_BG, silver), "splash_text_dark", "drawable", 288)

# ---- Android 通知小图标 / 磁贴 / 快捷方式：白色（或黑色）剪影 ----
def glyph_alpha():
    # control-glyph.png 是不透明画布上的白色剪影（alpha 全 255）：按亮度取形，只看中央 60% 区域，再去掉小斑点
    src = Image.open(os.path.join(BRAND, "control-glyph.png")).convert("L")
    W, H = src.size
    alpha = src.point(lambda v: 0 if v < 150 else min(255, int((v - 150) * 255 / 80)))
    center = alpha.crop((int(W * 0.2), int(H * 0.18), int(W * 0.8), int(H * 0.82)))
    cb = center.point(lambda v: 255 if v > 128 else 0).getbbox()
    alpha = alpha.crop((cb[0] + int(W * 0.2), cb[1] + int(H * 0.18), cb[2] + int(W * 0.2), cb[3] + int(H * 0.18)))
    labels = alpha.point(lambda v: 255 if v > 128 else 0); px = labels.load(); w, hh = labels.size; tags = []
    for y in range(hh):
        for x in range(w):
            if px[x, y] == 255:
                t = 1 + len(tags) % 200; ImageDraw.floodfill(labels, (x, y), t); tags.append(t)
    hist = labels.histogram(); sizes = {t: hist[t] for t in set(tags)}
    keep = {t for t, n in sizes.items() if n >= max(sizes.values()) * 0.02}
    mask = labels.point(lambda v: 255 if v in keep else 0)
    alpha.paste(0, mask=mask.point(lambda v: 255 - v))          # 斑点清零
    out_ = Image.new("RGBA", alpha.size, (255, 255, 255, 255)); out_.putalpha(alpha)
    return out_
glyph = glyph_alpha()
def glyph_img(px, color, fill=0.92):
    g = fit(glyph, px, fill)
    solid = Image.new("RGBA", g.size, color + (255,)); solid.putalpha(g.split()[3])
    canvas = Image.new("RGBA", (px, px), (0, 0, 0, 0))
    canvas.paste(solid, ((px - g.width) // 2, (px - g.height) // 2), solid)
    return canvas
save_densities(lambda px: glyph_img(px, (255, 255, 255)), "ic", "drawable", 24)
glyph_img(550, (0, 0, 0), 0.80).save(out(os.path.join(RES, "drawable", "ic_shortcut_black.png")), optimize=True)
glyph_img(550, (255, 255, 255), 0.80).save(out(os.path.join(RES, "drawable", "ic_shortcut_white.png")), optimize=True)

# ---- Android TV 横幅 320×180 ----
banner = Image.new("RGBA", (640, 360), DARK_BG + (255,))
h = fit(head(silver), 360, 0.80); banner.paste(h, ((640 - h.width) // 2, (360 - h.height) // 2), h)
banner.convert("RGB").resize((320, 180), Image.LANCZOS).save(out(os.path.join(RES, "drawable-xhdpi", "tv_banner.png")), optimize=True)

# ---- App 内 / 关于页 / 窗口标题图标：icon.png = 深色版、icon_light.png = 浅色版（沿用 Bettbox 的取名与 isDark 分支）----
rounded(dark_art, 0.22).save(out(os.path.join(IMAGES, "icon.png")), optimize=True)
rounded(light_art, 0.22).save(out(os.path.join(IMAGES, "icon_light.png")), optimize=True)

# ---- Windows 可执行文件 / 安装包图标 ----
ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]
rounded(light_art, 0.22).resize((256, 256), Image.LANCZOS).save(out(os.path.join(ROOT, "windows/runner/resources/app_icon.ico")), sizes=ICO_SIZES)

# ---- Windows 托盘：lib/common/utils.dart 的取名——浅色任务栏：未运行 icon / 运行中 icon_black；深色任务栏：未运行 icon_light / 运行中 icon_white ----
def half(im, idx, max_h=None):
    w, hh = im.size
    sub = im.crop((0, 0, w // 2, hh) if idx == 0 else (w // 2, 0, w, hh))
    if max_h: sub = sub.crop((0, 0, sub.width, min(sub.height, max_h)))
    return sub
def square(im, side=256, fill=0.94):
    im = fit(im, side, fill)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(im, ((side - im.width) // 2, (side - im.height) // 2), im)
    return canvas
color = Image.open(os.path.join(BRAND, "menubar-color.png")).convert("RGBA")
idle = half(color, 0, 470); idle = idle.crop(idle.split()[3].point(lambda v: 255 if v > 20 else 0).getbbox())
mono = Image.open(os.path.join(BRAND, "menubar-mono.png")).convert("L")
active_alpha = half(mono, 1).point(lambda v: 255 - v); active_alpha = active_alpha.crop(active_alpha.point(lambda v: 255 if v > 40 else 0).getbbox())
def mono_rgba(alpha, color):
    im = Image.new("RGBA", alpha.size, color + (255,)); im.putalpha(alpha); return im
TRAY_SIZES = [(16, 16), (20, 20), (24, 24), (32, 32), (48, 48), (64, 64), (256, 256)]
tray = {"icon": square(idle), "icon_light": square(idle),
        "icon_black": square(mono_rgba(active_alpha, (0, 0, 0))), "icon_white": square(mono_rgba(active_alpha, (255, 255, 255)))}
for name, im in tray.items():
    im.save(out(os.path.join(IMAGES, f"{name}.ico")), sizes=TRAY_SIZES)
    if name in ("icon_black", "icon_white"):   # 非 Windows 桌面端托盘用 png
        im.resize((550, 550), Image.LANCZOS).save(out(os.path.join(IMAGES, f"{name}.png")), optimize=True)
print("done")
