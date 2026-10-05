#!/usr/bin/env python3
# -*- coding: utf-8 -*-
import sys
import json
import requests

MASS_API = "http://localhost:3000"
HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                  "AppleWebKit/537.36 (KHTML, like Gecko) "
                  "Chrome/120.0.0.0 Safari/537.36",
    "Referer": "https://music.163.com/",
    "Cookie": "appver=8.9.70; os=pc;",
}

# 从命令行参数取 cid，或交互输入
if len(sys.argv) > 1:
    song_cid = sys.argv[1]
else:
    song_cid = input("输入歌曲 cid: ").strip()

print(f"\n{'='*60}")
print(f"诊断歌曲 cid = {song_cid}")
print(f"{'='*60}\n")

# ------------------------------------------------------------
# 1. Mass API
# ------------------------------------------------------------
print(f"[1] GET {MASS_API}/song/{song_cid}")
try:
    r = requests.get(f"{MASS_API}/song/{song_cid}", timeout=10)
    print(f"    HTTP {r.status_code}")
    data = r.json()
    print(f"    返回内容（前 1500 字符）:")
    print(json.dumps(data, ensure_ascii=False, indent=2)[:1500])

    inner = data.get("data", {})
    lyric_url = inner.get("lyricUrl") or inner.get("lyric_url", "")
    source_url = inner.get("sourceUrl") or inner.get("url", "")
    print(f"\n    lyricUrl  = {lyric_url!r}")
    print(f"    sourceUrl = {source_url!r}")

except Exception as e:
    print(f"    ERROR: {e}")
    lyric_url = ""

# ------------------------------------------------------------
# 2. 下载歌词
# ------------------------------------------------------------
if lyric_url:
    print(f"\n[2] GET {lyric_url}")
    try:
        r2 = requests.get(lyric_url, headers=HEADERS, timeout=10)
        print(f"    HTTP {r2.status_code}")
        print(f"    内容长度 = {len(r2.text)} 字符")
        print(f"    前 500 字符:")
        print("    " + repr(r2.text[:500]))
    except Exception as e:
        print(f"    ERROR: {e}")
else:
    print("\n[2] 跳过：lyricUrl 为空")

# ------------------------------------------------------------
# 3. 本地缓存检查
# ------------------------------------------------------------
print(f"\n[3] 本地 translation-cache.json")
import os
cache_path = os.path.join(
    os.environ.get("LOCALAPPDATA", ""),
    "Mass", "translation-cache.json"
)
print(f"    路径: {cache_path}")

if os.path.exists(cache_path):
    with open(cache_path, "r", encoding="utf-8") as f:
        cache = json.load(f)
    entries = cache.get("entries", {})
    print(f"    总条目数: {len(entries)}")

    if song_cid in entries:
        e = entries[song_cid]
        src = e.get("source", [])
        trs = e.get("translated", [])
        print(f"    ✓ 命中！")
        print(f"      source 行数: {len(src)}")
        print(f"      translated 行数: {len(trs)}")
        print(f"      前 3 行 source:")
        for i, line in enumerate(src[:3]):
            print(f"        [{i}] {line!r}")
        print(f"      前 3 行 translated:")
        for i, line in enumerate(trs[:3]):
            print(f"        [{i}] {line!r}")
    else:
        print(f"    ✗ 未命中")
else:
    print(f"    文件不存在")

# ------------------------------------------------------------
# 4. 网易云搜索和歌词
# ------------------------------------------------------------
print(f"\n[4] 网易云搜索")

# 从缓存或 API 获取歌曲名
song_name = ""
artist_name = ""

if os.path.exists(cache_path):
    with open(cache_path, "r", encoding="utf-8") as f:
        cache = json.load(f)
    e = cache.get("entries", {}).get(song_cid, {})
    song_name = e.get("song_name", "")
    artist_name = e.get("artist", "")

if not song_name:
    song_name = input("    请输入歌曲名: ").strip()
if not artist_name:
    artist_name = input("    请输入歌手名: ").strip()

if song_name:
    query = (song_name + " " + artist_name).strip()
    print(f"    搜索关键词: {query!r}")

    try:
        r3 = requests.get(
            "http://music.163.com/api/search/get",
            params={"s": query, "type": 1, "limit": 5, "offset": 0},
            headers=HEADERS, timeout=10
        )
        data3 = r3.json()
        songs = data3.get("result", {}).get("songs", [])
        print(f"    找到 {len(songs)} 首")

        if songs:
            nid = songs[0]["id"]
            nname = songs[0]["name"]
            nart = " / ".join(a.get("name", "") for a in songs[0].get("artists", []))
            print(f"    取第一首: id={nid}, {nname} - {nart}")

            print(f"\n[5] 网易云歌词")
            r4 = requests.get(
                "http://music.163.com/api/song/lyric",
                params={"id": nid, "lv": -1, "tv": -1, "os": "pc"},
                headers=HEADERS, timeout=10
            )
            data4 = r4.json()
            orig = data4.get("lrc", {}).get("lyric", "")
            trans = data4.get("tlyric", {}).get("lyric", "")
            print(f"    原文长度: {len(orig)}")
            print(f"    译文长度: {len(trans)}")
            print(f"    原文前 300 字符:")
            print("    " + repr(orig[:300]))
            print(f"    译文前 300 字符:")
            print("    " + repr(trans[:300]))
        else:
            print("    ✗ 网易云搜索无结果")
    except Exception as e:
        print(f"    ERROR: {e}")

print()