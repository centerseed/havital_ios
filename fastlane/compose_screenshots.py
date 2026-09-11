#!/usr/bin/env python3
"""把模擬器原始截圖合成 App Store 用的 6.9" 行銷圖。

原始圖放 fastlane/screenshots-raw/<locale>/NN_*.png（6.3"，1206x2622），
輸出覆蓋 fastlane/screenshots/<locale>/NN_*.png（1320x2868，deliver 認的 6.9" 尺寸）。

背景漸層、強調色取自 App2Theme 的 hero gradient，跟 App 內視覺同一套。

日文標題需要 fastlane/fonts/NotoSansJP-Bold.ttf（macOS 沒有 PIL 讀得到的 Hiragino
Sans；缺檔會退回 PingFang TC，但「歩」這類字會變成中文字形）。取得方式：
  curl -fsSL -o fastlane/fonts/NotoSansJP-Bold.ttf \
    https://github.com/notofonts/noto-cjk/raw/main/Sans/SubsetOTF/JP/NotoSansJP-Bold.otf
TC 同理（把 JP 換成 TC）。字型不進 git。
"""
import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(ROOT, "screenshots-raw")
OUT = os.path.join(ROOT, "screenshots")
FONT_DIR = os.path.join(ROOT, "fonts")

W, H = 1320, 2868
SIDE = 76
DEVICE_W = 1040
DEVICE_TOP = 528
BEZEL = 13
HEAD_TOP = 138

# App2Theme.shadowHeroGradient
GRAD = [(0.00, (11, 95, 176)), (0.58, (18, 58, 114)), (1.00, (11, 13, 22))]
HEAD_COLOR = (255, 255, 255)
SUB_COLOR = (159, 184, 210)

# 標題／副標。第一個 \n 之後是第二行；副標一行。
COPY = {
    "01_home": {
        "zh-Hant": ("每天一眼看懂\n今天該怎麼練", "訓練狀態、五項能力、教練建議"),
        "ja": ("今日やるべきことが\n一目でわかる", "コンディション・5つの能力・コーチの提案"),
        "en-US": ("Know what to run\ntoday, at a glance", "Your status, five metrics, coach guidance"),
    },
    "02_plan": {
        "zh-Hant": ("為目標賽事\n排出的每一週", "從賽事日期倒推，一週七天都有理由"),
        "ja": ("目標レースへ向けて\n組まれた一週間", "レース日から逆算した七日間のプラン"),
        "en-US": ("Every week built\naround your race", "Planned backwards from race day"),
    },
    "03_records": {
        "zh-Hant": ("跑過的每一步\n都累積得見", "自動同步 Garmin、Strava、Apple 健康"),
        "ja": ("走った一歩ずつが\n積み上がっていく", "Garmin・Strava・ヘルスケアと自動同期"),
        "en-US": ("Every run\nadds up", "Auto-syncs Garmin, Strava and Apple Health"),
    },
    "04_achievements": {
        "zh-Hant": ("進步\n看得見", "能力變化、里程碑與個人紀錄"),
        "ja": ("進歩が\n目に見える", "能力の変化・マイルストーン・自己記録"),
        "en-US": ("Progress you\ncan actually see", "Ability trends, milestones and personal bests"),
    },
}

# 系統沒有可讀的 Hiragino Sans（JP），日文標題需要 Noto Sans JP——
# 缺了會用 PingFang TC 代替，但「歩」等字會變成中文字形。
FONT_CANDIDATES = {
    "zh-Hant": [
        (os.path.join(FONT_DIR, "NotoSansTC-Bold.ttf"), 0),
        ("/System/Library/AssetsV2/com_apple_MobileAsset_Font8/*/AssetData/PingFang.ttc", 10),
    ],
    "ja": [
        (os.path.join(FONT_DIR, "NotoSansJP-Bold.ttf"), 0),
        ("/System/Library/AssetsV2/com_apple_MobileAsset_Font8/*/AssetData/PingFang.ttc", 10),
    ],
    "en-US": [
        (os.path.join(os.path.dirname(ROOT), "Havital/Fonts/Onest-Bold.ttf"), 0),
    ],
}
SUB_CANDIDATES = {
    "zh-Hant": [
        (os.path.join(FONT_DIR, "NotoSansTC-Bold.ttf"), 0),
        ("/System/Library/AssetsV2/com_apple_MobileAsset_Font8/*/AssetData/PingFang.ttc", 6),
    ],
    "ja": [
        (os.path.join(FONT_DIR, "NotoSansJP-Bold.ttf"), 0),
        ("/System/Library/AssetsV2/com_apple_MobileAsset_Font8/*/AssetData/PingFang.ttc", 6),
    ],
    "en-US": [
        (os.path.join(os.path.dirname(ROOT), "Havital/Fonts/Onest-Medium.ttf"), 0),
    ],
}


def load_font(candidates, size):
    for pattern, index in candidates:
        for path in sorted(glob.glob(pattern)) or [pattern]:
            if not os.path.exists(path):
                continue
            try:
                return ImageFont.truetype(path, size, index=index)
            except OSError:
                continue
    raise SystemExit(f"找不到可用字型：{candidates}")


def background():
    grad = Image.new("RGB", (1, H))
    px = grad.load()
    for y in range(H):
        t = y / (H - 1)
        for i in range(len(GRAD) - 1):
            t0, c0 = GRAD[i]
            t1, c1 = GRAD[i + 1]
            if t0 <= t <= t1:
                k = (t - t0) / (t1 - t0)
                px[0, y] = tuple(round(c0[j] + (c1[j] - c0[j]) * k) for j in range(3))
                break
    return grad.resize((W, H))


def fit_font(candidates, text, size, max_w):
    """標題字級先給 size，太寬就往下縮到塞得進 max_w。"""
    while size > 40:
        font = load_font(candidates, size)
        if max(font.getbbox(line)[2] for line in text.split("\n")) <= max_w:
            return font
        size -= 3
    return load_font(candidates, size)


def compose(raw_path, locale, screen):
    head, sub = COPY[screen][locale]
    canvas = background()
    draw = ImageDraw.Draw(canvas)

    head_font = fit_font(FONT_CANDIDATES[locale], head, 86, W - SIDE * 2)
    sub_font = load_font(SUB_CANDIDATES[locale], 38)

    y = HEAD_TOP
    line_h = round(head_font.size * 1.26)
    for line in head.split("\n"):
        draw.text((W / 2, y), line, font=head_font, fill=HEAD_COLOR, anchor="ma")
        y += line_h
    draw.text((W / 2, y + 18), sub, font=sub_font, fill=SUB_COLOR, anchor="ma")

    shot = Image.open(raw_path).convert("RGB")
    dev_h = round(shot.height * DEVICE_W / shot.width)
    shot = shot.resize((DEVICE_W, dev_h), Image.LANCZOS)
    if DEVICE_TOP + dev_h > H:
        raise SystemExit(f"{raw_path}: 機身 {dev_h}px 放不進畫布，原始圖比例不對？")

    radius = 58
    mask = Image.new("L", (DEVICE_W, dev_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, DEVICE_W - 1, dev_h - 1], radius, fill=255)

    left = (W - DEVICE_W) // 2
    bez = [left - BEZEL, DEVICE_TOP - BEZEL,
           left + DEVICE_W + BEZEL - 1, DEVICE_TOP + dev_h + BEZEL - 1]

    # 投影：把機身輪廓模糊後壓在底下，機身才不會像貼紙浮在漸層上。
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).rounded_rectangle(
        [bez[0], bez[1] + 30, bez[2], bez[3] + 30], radius + BEZEL, fill=(0, 0, 0, 165),
    )
    canvas = Image.alpha_composite(
        canvas.convert("RGBA"), shadow.filter(ImageFilter.GaussianBlur(38))
    )

    # 機身邊框：不畫成純黑，留一圈亮邊當金屬反光，否則機身會糊進深色背景。
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(bez, radius + BEZEL, fill=(22, 26, 34, 255))
    draw.rounded_rectangle(bez, radius + BEZEL, outline=(255, 255, 255, 64), width=3)
    canvas.paste(shot, (left, DEVICE_TOP), mask)
    return canvas.convert("RGB")


def main():
    locales = sys.argv[1:] or ["zh-Hant", "ja", "en-US"]
    made = 0
    for locale in locales:
        for raw in sorted(glob.glob(os.path.join(RAW, locale, "*.png"))):
            screen = os.path.splitext(os.path.basename(raw))[0]
            if screen not in COPY:
                raise SystemExit(f"{raw}: COPY 沒有 {screen} 的文案")
            out_dir = os.path.join(OUT, locale)
            os.makedirs(out_dir, exist_ok=True)
            out = os.path.join(out_dir, os.path.basename(raw))
            compose(raw, locale, screen).save(out)
            print(f"{locale}/{screen} -> {out}")
            made += 1
    if not made:
        raise SystemExit(f"{RAW} 底下沒有原始圖")


if __name__ == "__main__":
    main()
