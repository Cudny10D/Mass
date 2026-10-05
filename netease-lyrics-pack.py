#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Netease Lyrics Pack Generator for Mass Music Player

从网易云音乐 API 获取翻译歌词，生成 Mass 可直接导入的歌词包。

用法：
    1. 先启动 Mass（或至少启动 dist/server 的 API 服务，端口 3000）
    2. python netease-lyrics-pack.py
    3. 生成的 lyrics-pack-netease.json 可在 Mass 设置 → 存储 → 导入
"""

import os
import re
import sys
import json
import time
from datetime import datetime

try:
    import requests
except ImportError:
    print("请先安装 requests:  pip install requests")
    sys.exit(1)


# ============================================================
# 配置
# ============================================================
MASS_API             = "http://localhost:3000"
NETEASE_LYRIC_API    = "http://music.163.com/api/song/lyric"
NETEASE_SEARCH_API   = "http://music.163.com/api/search/get"

OUTPUT_FILE          = "lyrics-pack-netease.json"
REQUEST_DELAY        = 0.8
RETRY_DELAY          = 3.0
MAX_RETRIES          = 3

HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                  "AppleWebKit/537.36 (KHTML, like Gecko) "
                  "Chrome/120.0.0.0 Safari/537.36",
    "Referer": "https://music.163.com/",
    "Cookie": "appver=8.9.70; os=pc;",
    "Accept": "application/json, text/plain, */*",
}

LRC_RE = re.compile(r"\[(\d+):(\d+)(?:[.:](\d+))?\](.*)")


# ============================================================
# 通用响应解包
# ============================================================
def unwrap(data):
    """{code,msg,data:...} → 内层 data；否则原样返回"""
    if isinstance(data, dict) and "data" in data:
        return data["data"]
    return data


def extract_list(data, keys):
    """从 data 里找一个数组"""
    if isinstance(data, list):
        return data
    if isinstance(data, dict):
        for k in keys:
            if isinstance(data.get(k), list):
                return data[k]
        for v in data.values():
            if isinstance(v, list):
                return v
    return []


def extract_str(data, keys):
    """从 data 里找一个字符串"""
    if isinstance(data, dict):
        for k in keys:
            v = data.get(k)
            if isinstance(v, str) and v:
                return v
    return ""


# ============================================================
# 歌词文本提取（兼容 JSON 包裹）
# ============================================================
def extract_lyric_text(raw_text):
    """
    从任意响应里提取 LRC 文本。

    - 纯 LRC：直接返回
    - JSON 包裹：尝试从 lyric / lrc / content / text 字段提取
    - 嵌套 data：递归一层
    """
    if not raw_text:
        return ""

    stripped = raw_text.strip()

    # 纯 LRC 或普通文本
    if not (stripped.startswith("{") or stripped.startswith("[")):
        return raw_text

    # JSON
    try:
        j = json.loads(stripped)
    except Exception:
        return raw_text

    candidates = []

    def pick_from(d):
        if not isinstance(d, dict):
            return
        for k in ("lyric", "lrc", "content", "text", "lyrics"):
            v = d.get(k)
            if isinstance(v, str) and v:
                candidates.append(v)

    pick_from(j)

    inner = j.get("data")
    if isinstance(inner, dict):
        pick_from(inner)
    elif isinstance(inner, str) and inner:
        candidates.append(inner)

    if not candidates:
        return raw_text

    # 优先选最像 LRC 的（含 [mm:ss）
    for c in candidates:
        if LRC_RE.search(c):
            return c

    # 否则返回最长的
    return max(candidates, key=len)


# ============================================================
# LRC 解析
# ============================================================
def parse_lrc(lrc_text):
    result = {}
    if not lrc_text:
        return result

    for line in lrc_text.split("\n"):
        line = line.strip()
        if not line:
            continue
        m = LRC_RE.match(line)
        if not m:
            continue
        mm, ss, xx, text = m.groups()
        ms = int(mm) * 60000 + int(ss) * 1000
        if xx:
            ms += int((xx + "000")[:3])
        text = text.strip()
        if text:
            result.setdefault(ms, []).append(text)
    return result


def find_translation(trans_dict, ms):
    if ms in trans_dict:
        return " ".join(trans_dict[ms])
    for offset in (50, -50, 100, -100, 150, -150, 200, -200):
        if (ms + offset) in trans_dict:
            return " ".join(trans_dict[ms + offset])
    return ""


# ============================================================
# HTTP
# ============================================================
def http_get(url, params=None, retries=MAX_RETRIES):
    for attempt in range(retries):
        try:
            r = requests.get(url, params=params, headers=HEADERS, timeout=15)
            r.raise_for_status()
            return r
        except Exception as e:
            if attempt < retries - 1:
                print(f"    [retry {attempt+1}/{retries-1}] {e}")
                time.sleep(RETRY_DELAY)
            else:
                raise
    return None


# ============================================================
# 网易云
# ============================================================
def search_netease(song_name, artist_name=""):
    """搜索网易云，返回最匹配的 song_id"""

    queries = [song_name]
    if artist_name:
        queries.append(song_name + " " + artist_name)

    for query in queries:
        try:
            r = http_get(NETEASE_SEARCH_API, params={
                "s": query,
                "type": 1,
                "limit": 10,
                "offset": 0,
            })
            data = r.json()
            songs = data.get("result", {}).get("songs", [])
            if not songs:
                continue

            artist_lower = artist_name.lower()
            if artist_lower:
                for s in songs:
                    s_artists = " ".join(
                        a.get("name", "") for a in s.get("artists", []))
                    if artist_lower in s_artists.lower():
                        return s["id"]

            return songs[0]["id"]

        except Exception as e:
            print(f"    [search error] {e}")
            continue

    return None


def get_netease_lyric(song_id):
    """获取网易云歌词 → (原文 LRC, 翻译 LRC)"""
    try:
        r = http_get(NETEASE_LYRIC_API, params={
            "id": song_id,
            "lv": -1,
            "tv": -1,
            "os": "pc",
        })
        data = r.json()
        original   = data.get("lrc",    {}).get("lyric", "")
        translated = data.get("tlyric", {}).get("lyric", "")
        return original, translated
    except Exception as e:
        print(f"    [lyric error] {e}")
        return "", ""


# ============================================================
# Mass API
# ============================================================
def fetch_mass_albums():
    r = http_get(f"{MASS_API}/albums")
    data = unwrap(r.json())
    return extract_list(data, ["list", "albums", "items"])


def fetch_mass_album_songs(album_cid):
    r = http_get(f"{MASS_API}/album/{album_cid}/detail")
    data = unwrap(r.json())
    return extract_list(data, ["songs", "list", "items"])


def fetch_mass_song_lyric(song_cid):
    """
    获取 Mass 视角下的原始歌词文本。
    兼容纯 LRC 和 JSON 包裹两种返回。
    """
    try:
        r = http_get(f"{MASS_API}/song/{song_cid}")
        data = unwrap(r.json())
        url = extract_str(data, ["lyricUrl", "lyric_url"])
        if not url:
            return ""

        r2 = requests.get(url, headers=HEADERS, timeout=10)
        if r2.status_code != 200:
            return ""

        return extract_lyric_text(r2.text)

    except Exception as e:
        print(f"    [mass lyric error] {e}")
        return ""


def parse_artist(song):
    artists = song.get("artistes") or song.get("artists") or []
    if isinstance(artists, list):
        names = []
        for a in artists:
            if isinstance(a, dict):
                names.append(a.get("name", ""))
            elif isinstance(a, str):
                names.append(a)
        return " / ".join(n for n in names if n)
    elif isinstance(artists, str):
        return artists
    return ""


# ============================================================
# 构建条目
# ============================================================
def build_entry(mass_cid, song_name, artist_name):
    netease_id = search_netease(song_name, artist_name)
    if not netease_id:
        return None, "not found on netease"

    time.sleep(REQUEST_DELAY)

    netease_orig_lrc, translated_lrc = get_netease_lyric(netease_id)
    if not translated_lrc:
        return None, "no translation"

    time.sleep(REQUEST_DELAY)

    mass_lrc = fetch_mass_song_lyric(mass_cid)
    if not mass_lrc:
        # 回退用网易云原文
        mass_lrc = netease_orig_lrc

    orig_dict  = parse_lrc(mass_lrc)
    trans_dict = parse_lrc(translated_lrc)

    if not orig_dict:
        return None, "empty original"

    source_lines = []
    trans_lines  = []

    for ms in sorted(orig_dict.keys()):
        for text in orig_dict[ms]:
            source_lines.append(text)
            trans_lines.append(find_translation(trans_dict, ms))

    if not source_lines:
        return None, "no lines"

    return {
        "source":     source_lines,
        "translated": trans_lines,
        "netease_id": netease_id,
        "song_name":  song_name,
        "artist":     artist_name,
    }, None


# ============================================================
# 诊断
# ============================================================
def debug_album_detail(album_cid):
    print(f"\n=== DEBUG: /album/{album_cid}/detail ===")
    try:
        r = http_get(f"{MASS_API}/album/{album_cid}/detail")
        data = r.json()
        inner = unwrap(data)
        if isinstance(inner, dict):
            print("内层 keys:", list(inner.keys()))
        elif isinstance(inner, list):
            print(f"数组长度: {len(inner)}")
    except Exception as e:
        print("ERROR:", e)
    print()


# ============================================================
# 主流程
# ============================================================
def main():
    print("=" * 64)
    print("  Netease Lyrics Pack Generator for Mass")
    print("=" * 64)
    print()

    cache = {"version": 1, "entries": {}}
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, "r", encoding="utf-8") as f:
                cache = json.load(f)
            print(f"✓ 已加载现有歌词包：{len(cache.get('entries', {}))} 首")
        except Exception as e:
            print(f"! 读取现有包失败，将新建：{e}")

    print("\n正在从 Mass API 获取专辑列表...")
    try:
        albums = fetch_mass_albums()
    except Exception as e:
        print(f"✗ 无法连接 Mass API ({MASS_API})：{e}")
        print("  请先启动 Mass 应用")
        sys.exit(1)

    if not albums:
        print("✗ API 返回空专辑列表")
        sys.exit(1)

    print(f"✓ 共 {len(albums)} 张专辑")

    debug_album_detail(albums[0]["cid"])

    print("\n开始处理...\n")

    total    = 0
    success  = 0
    skipped  = 0
    failed   = 0
    fail_reasons = {}

    for i, album in enumerate(albums):
        album_cid  = album.get("cid")
        album_name = album.get("name", "?")

        if not album_cid:
            continue

        print(f"[{i+1}/{len(albums)}] {album_name}")

        try:
            songs = fetch_mass_album_songs(album_cid)
        except Exception as e:
            print(f"  ! 专辑加载失败：{e}")
            continue

        if not songs:
            print("  (无歌曲)")
            continue

        for song in songs:
            song_cid  = song.get("cid")
            song_name = song.get("name", "?")
            artist    = parse_artist(song)

            if not song_cid:
                continue

            total += 1

            if song_cid in cache["entries"]:
                print(f"  · 跳过（已存在）: {song_name}")
                skipped += 1
                continue

            print(f"  → {song_name} - {artist}")

            try:
                entry, err = build_entry(song_cid, song_name, artist)
            except Exception as e:
                print(f"    ✗ 异常：{e}")
                failed += 1
                fail_reasons["exception"] = fail_reasons.get("exception", 0) + 1
                time.sleep(REQUEST_DELAY)
                continue

            if entry is None:
                print(f"    ✗ {err}")
                failed += 1
                fail_reasons[err] = fail_reasons.get(err, 0) + 1
            else:
                cache["entries"][song_cid] = entry
                n = len(entry["source"])
                print(f"    ✓ 已翻译 {n} 行")
                success += 1

            time.sleep(REQUEST_DELAY)

        cache["count"]        = len(cache["entries"])
        cache["generated_at"] = datetime.now().isoformat()
        cache["backend"]      = "Netease"
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(cache, f, ensure_ascii=False, indent=2)

    cache["count"]        = len(cache["entries"])
    cache["generated_at"] = datetime.now().isoformat()
    cache["backend"]      = "Netease"

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(cache, f, ensure_ascii=False, indent=2)

    size_kb = os.path.getsize(OUTPUT_FILE) / 1024

    print()
    print("=" * 64)
    print("  完成！")
    print(f"  总计处理:   {total}")
    print(f"  成功:       {success}")
    print(f"  跳过:       {skipped}")
    print(f"  失败:       {failed}")
    print(f"  包内共:     {len(cache['entries'])} 首")
    print(f"  输出文件:   {OUTPUT_FILE}  ({size_kb:.1f} KB)")

    if fail_reasons:
        print()
        print("  失败原因统计：")
        for reason, cnt in sorted(fail_reasons.items(),
                                   key=lambda x: -x[1]):
            print(f"    {reason}: {cnt}")

    print("=" * 64)
    print()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n用户中断。已保存进度到", OUTPUT_FILE)
        sys.exit(0)