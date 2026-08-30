#!/usr/bin/env python3
"""Paceriz iOS i18n lint — 確保多國語言正確顯示 + 用字統一不飄移。

兩層檢查:
  [A] .strings 完整性 (恆擋):  zh-Hant / en / ja 三語
      - key parity (缺 key → fallback 顯示錯語言)
      - 重複 key (未來飄移破口)
      - 空值
      - 佔位符 (%@ %d ...) 數量一致
      - zh-TW 用字飄移 / zh-CN 污染 (可設定詞表)
  [B] 新增寫死 CJK (擋 staged 新增行):  僅檢查 git staged *.swift 的「新增行」,
      不掃既有 721 處技術債,只杜絕「新長出來」的漏譯。

用法:
  python3 Scripts/i18n_lint.py              # A + B(staged) — pre-commit 用
  python3 Scripts/i18n_lint.py --strings    # 只跑 A
  python3 Scripts/i18n_lint.py --scan-all   # B 改為全庫掃描(報告用,不擋)
退出碼: 0 = 通過; 1 = 有阻擋級問題。
"""
import json, re, sys, os, subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)  # apps/ios/Havital
RES = os.path.join(ROOT, "Havital", "Resources")
LANGS = ["zh-Hant", "en", "ja"]

LINE_RE = re.compile(r'^\s*"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;\s*$')
# 不含 space-flag：避免把「5-10% grade」這類字面文字誤判成佔位符
PLACEHOLDER_RE = re.compile(r'%(?:\d+\$)?[-+0-9.]*[@dDiufFeEgGsxX]')

# zh-TW 用字規範: 禁用詞 -> 建議詞 (僅作用於 zh-Hant)
ZH_TW_FORBIDDEN = {
    "計劃": "計畫",
    "設置": "設定",
    # zh-CN 滲入用語
    "視頻": "影片",
    "屏幕": "螢幕",
    "網絡": "網路",
    "信息": "資訊",
    "質量": "品質",
    "缺省": "預設",
    "默認": "預設",
    "登錄": "登入",
    "登陸": "登入",
}

CJK_RE = re.compile(r'[一-鿿぀-ヿ]')
STRLIT_RE = re.compile(r'"((?:[^"\\]|\\.)*)"')
SKIP_CALLS_RE = re.compile(r'(Logger\.|print\(|debugPrint|os_log|NSLog|assert\(|assertionFailure|precondition|fatalError|#warning|#error)')


def parse_strings(path):
    d, dups = {}, []
    with open(path, encoding="utf-8") as f:
        for ln, raw in enumerate(f, 1):
            s = raw.rstrip("\n")
            t = s.strip()
            if not t or t.startswith("//") or t.startswith("/*") or t.startswith("*"):
                continue
            m = LINE_RE.match(s)
            if not m:
                continue
            k, v = m.group(1), m.group(2)
            if k in d:
                dups.append((k, ln))
            d[k] = v
    return d, dups


def placeholders(v):
    return sorted(PLACEHOLDER_RE.findall(v))


def check_strings():
    errors = []
    data, dups = {}, {}
    for lang in LANGS:
        p = os.path.join(RES, f"{lang}.lproj", "Localizable.strings")
        if not os.path.exists(p):
            errors.append(f"[strings] missing file: {p}")
            return errors
        data[lang], dups[lang] = parse_strings(p)

        # 「檔案裡有」不等於「App 裡讀得到」。上面是逐行 regex，對不上的行**默默跳過**；
        # `.strings` 在 App 裡走 plist 剖析，一行壞掉後面整段就沒了。兩者的差就是會在
        # 執行期消失的字串。2026-08-30 在 zh-Hant 抓到的正是這個：一行 mojibake 殘骸
        # （`2000599d` 改 `app2.session.heat_adjusted` 留下的、沒有開頭引號的尾巴）讓
        # `app2.session.effort_title` 到檔尾共 521 條在 App 裡不存在，而本 lint 全綠。
        # 用 App 用的那個剖析器再讀一次就擋得住。plutil 不在（非 macOS）就跳過。
        try:
            parsed = subprocess.run(
                ["plutil", "-convert", "json", "-o", "-", p],
                capture_output=True, check=True,
            ).stdout
            visible = set(json.loads(parsed))
        except (OSError, subprocess.CalledProcessError, ValueError):
            visible = None
        if visible is not None:
            lost = sorted(set(data[lang]) - visible)
            if lost:
                errors.append(
                    f"[unparsable] {lang} 有 {len(lost)} 條字串 plist 剖析不到"
                    f"（App 執行期會消失）——通常是壞掉的一行讓它後面整段被吃掉。"
                    f"第一條：'{lost[0]}'，最後一條：'{lost[-1]}'"
                )

    all_keys = set().union(*[set(d) for d in data.values()])

    # parity
    for lang in LANGS:
        miss = all_keys - set(data[lang])
        for k in sorted(miss):
            errors.append(f"[parity] '{k}' missing in {lang}")
    # duplicates
    for lang in LANGS:
        for k, ln in dups[lang]:
            errors.append(f"[dup] '{k}' duplicated in {lang} (line {ln})")
    # empty
    for lang in LANGS:
        for k, v in data[lang].items():
            if v.strip() == "":
                errors.append(f"[empty] '{k}' empty in {lang}")
    # placeholder consistency (vs en)
    en = data["en"]
    for lang in ["zh-Hant", "ja"]:
        for k in sorted(set(data[lang]) & set(en)):
            pl, pe = placeholders(data[lang][k]), placeholders(en[k])
            if pl != pe:
                errors.append(f"[placeholder] '{k}' {lang}={pl} vs en={pe}")
    # zh-TW terminology drift
    for k, v in data["zh-Hant"].items():
        for bad, good in ZH_TW_FORBIDDEN.items():
            if bad in v:
                errors.append(f"[term] '{k}' zh-Hant 用「{bad}」應為「{good}」: \"{v[:40]}\"")
    return errors


def _staged_swift_added_lines():
    """回傳 {path: [(lineno_in_new_file, text), ...]} 僅新增行。"""
    try:
        files = subprocess.check_output(
            ["git", "diff", "--cached", "--name-only", "--diff-filter=ACM", "--", "*.swift"],
            cwd=ROOT, text=True).splitlines()
    except subprocess.CalledProcessError:
        return {}
    out = {}
    for f in files:
        if not f.endswith(".swift"):
            continue
        # `/Debug/`（不是 `/Features/Debug/`）：DEBUG-only 開發面板的落點慣例是
        # `Features/<Feature>/Debug/`（`Subscription/Debug/IAPTestHarness.swift`、
        # `App2/Debug/App2PlanEndDevView.swift`…），repo 裡 7 個 Debug 目錄只有 1 個
        # 真的叫 `Features/Debug/`，所以原本那條規則只豁免得到其中一個。
        # 這些檔整份包在 `#if DEBUG` 裡、Release build 不存在，讀者是我們自己 ——
        # 走查用的標籤與 fixture 翻三語只會讓 .strings 多出沒有人會看到的 key。
        if any(x in f for x in ("/build/", "/.worktrees/", "/Tests/", "/PreviewHelpers/", "/Debug/")):
            continue
        # 測試碼不受 i18n 約束：wire payload fixture 與 XCTAssert 訊息本來就是寫死字面值，
        # 沒有「顯示給用戶」這回事。上面那條 "/Tests/" 只擋得到巢狀的測試目錄，
        # 抓不到 target 根目錄（`HavitalTests/`、`HavitalUITests/`、`HavitalWatchTests/`）。
        if re.match(r'^[^/]*Tests/', f):
            continue
        # 跳過純 Preview 檔(PreviewProvider 範例 mock)
        try:
            head = subprocess.check_output(["git", "show", ":%s" % f], cwd=ROOT, text=True)
            if "PreviewProvider" in head and "struct " in head and head.count("var body") == 0:
                continue
        except subprocess.CalledProcessError:
            pass
        diff = subprocess.check_output(["git", "diff", "--cached", "-U0", "--", f], cwd=ROOT, text=True)
        added = []
        newln = 0
        for line in diff.splitlines():
            m = re.match(r'^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@', line)
            if m:
                newln = int(m.group(1)); continue
            if line.startswith("+") and not line.startswith("+++"):
                added.append((newln, line[1:])); newln += 1
            elif not line.startswith("-"):
                newln += 1
        if added:
            out[f] = added
    return out


def _is_new_hardcoded_cjk(text):
    """判斷一行新增 swift 是否含「會顯示、寫死、不翻譯」的 CJK 字面值。粗略但保守。"""
    work = text
    # 去行註解(粗略)
    if "//" in work:
        # 不在字串內的第一個 //
        in_str = False; esc = False; cut = None
        for i, ch in enumerate(work):
            if esc: esc = False; continue
            if ch == "\\": esc = True; continue
            if ch == '"': in_str = not in_str; continue
            if not in_str and ch == "/" and i+1 < len(work) and work[i+1] == "/":
                cut = i; break
        if cut is not None:
            work = work[:cut]
    if SKIP_CALLS_RE.search(work):
        return None
    if not CJK_RE.search(work):
        return None
    for m in STRLIT_RE.finditer(work):
        val = m.group(1)
        if not CJK_RE.search(val):
            continue
        pre = work[:m.start()]
        if re.search(r'(comment|value|defaultValue)\s*:\s*$', pre):  # NSLocalizedString comment 參數
            continue
        if re.search(r'(accessibilityIdentifier|identifier|forKey|key:|name:)\s*\(?\s*$', pre):
            continue
        return val
    return None


def check_staged_swift():
    errors = []
    for f, added in _staged_swift_added_lines().items():
        for ln, text in added:
            val = _is_new_hardcoded_cjk(text)
            if val:
                v = val if len(val) < 50 else val[:50] + "…"
                errors.append(f"[hardcoded-cjk] {f}:{ln} 新增寫死 CJK \"{v}\" → 請走 NSLocalizedString")
    return errors


def main(argv):
    mode_strings_only = "--strings" in argv
    scan_all = "--scan-all" in argv

    print("🌐 i18n lint")
    errs = check_strings()
    if errs:
        print(f"\n❌ .strings 完整性: {len(errs)} 個問題")
        for e in errs:
            print(f"   {e}")
    else:
        print("✅ .strings 完整性: parity/重複/空值/佔位符/用字 全數通過")

    swift_errs = []
    if not mode_strings_only:
        if scan_all:
            print("\n(--scan-all: 全庫掃描為報告模式,不納入阻擋)")
        else:
            swift_errs = check_staged_swift()
            if swift_errs:
                print(f"\n❌ staged Swift 新增寫死 CJK: {len(swift_errs)} 處")
                for e in swift_errs:
                    print(f"   {e}")
            else:
                print("✅ staged Swift: 無新增寫死 CJK")

    total = len(errs) + len(swift_errs)
    if total:
        print(f"\n阻擋級問題 {total} 個。修正後再 commit (緊急可 --no-verify,不推薦)。")
        return 1
    print("\n✅ i18n lint 通過")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
