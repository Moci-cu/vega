#!/usr/bin/env python3

import ipaddress
import json
import os
import sqlite3
import threading
import time
from datetime import datetime

from http.server import BaseHTTPRequestHandler, HTTPServer
from socketserver import ThreadingMixIn
from urllib.parse import parse_qs, quote, unquote, urlparse

import requests


PORT = int(os.environ.get("UNIT4_MANGA_PORT", "5150"))
API_BASE = os.environ.get("UNIT4_MANGA_API_BASE", "https://api.shngm.io/v1")
ASSET_BASE = "https://assets.shngm.id"
PAGE_SIZE = 24
FILTER_SCAN_SIZE = 1000
DATA_HOME = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
DATA_DIR = os.path.join(DATA_HOME, "unit-4", "manga")
LIBRARY_FILE = os.path.join(DATA_DIR, "library.json")

HEADERS = {
    "Accept": "application/json",
    "Origin": "https://g.shinigami.asia",
    "Referer": "https://g.shinigami.asia/",
    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 Chrome/131 Safari/537.36",
}

SESSION = requests.Session()
CACHE = {}
CACHE_LOCK = threading.Lock()
LIBRARY_LOCK = threading.Lock()
IMAGE_CACHE = {}
IMAGE_CACHE_LOCK = threading.Lock()
IMAGE_SEMAPHORE = threading.Semaphore(8)
_chapter_progress = {"current": 0, "mangaId": ""}


DB_PATH = os.path.join(DATA_DIR, "cache.db")
_db_lock = threading.Lock()


def _get_db():
    os.makedirs(DATA_DIR, exist_ok=True)
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    conn.execute("CREATE TABLE IF NOT EXISTS cache (key TEXT PRIMARY KEY, value TEXT, expires_at REAL)")
    conn.execute("CREATE INDEX IF NOT EXISTS idx_expires ON cache(expires_at)")
    conn.commit()
    return conn


_db = _get_db()


def cached(key, ttl, callback, use_file=False):
    with CACHE_LOCK:
        entry = CACHE.get(key)
    if entry and (entry[1] is None or time.monotonic() < entry[1]):
        return entry[0]

    if use_file:
        try:
            with _db_lock:
                row = _db.execute("SELECT value, expires_at FROM cache WHERE key = ?", (key,)).fetchone()
            if row and (row[1] is None or time.time() < row[1]):
                value = json.loads(row[0])
                with CACHE_LOCK:
                    CACHE[key] = (value, None if ttl is None else time.monotonic() + ttl)
                return value
        except Exception:
            pass

    value = callback()
    with CACHE_LOCK:
        CACHE[key] = (value, None if ttl is None else time.monotonic() + ttl)

    if use_file and value is not None:
        try:
            with _db_lock:
                _db.execute(
                    "INSERT OR REPLACE INTO cache (key, value, expires_at) VALUES (?, ?, ?)",
                    (key, json.dumps(value, ensure_ascii=False), None if ttl is None else time.time() + ttl)
                )
                _db.commit()
        except Exception:
            pass

    return value


def api_get(path, params=None, timeout=30):
    response = SESSION.get(
        f"{API_BASE}{path}",
        params=params,
        headers=HEADERS,
        timeout=timeout,
    )
    response.raise_for_status()
    payload = response.json()
    return payload.get("data")


def proxy_url(url):
    if not url:
        return ""
    return f"http://127.0.0.1:{PORT}/image?url={quote(url, safe='')}"


def status_label(value):
    return {1: "Ongoing", 2: "Completed", 3: "Hiatus"}.get(value, "Unknown")


def country_label(value):
    code = str(value or "").upper()
    return {
        "JA": "Manga",
        "JP": "Manga",
        "KO": "Manhwa",
        "KR": "Manhwa",
        "ZH": "Manhua",
        "CN": "Manhua",
    }.get(code, "")


def country_id(value):
    return {"Manga": "JP", "Manhwa": "KR", "Manhua": "CN"}.get(value)


def taxonomy_names(taxonomy, key):
    if not isinstance(taxonomy, dict):
        return []
    values = taxonomy.get(key, [])
    return [
        value.get("name", "")
        for value in values
        if isinstance(value, dict) and value.get("name")
    ]


def normalize_list_item(item):
    return {
        "id": item.get("manga_id", ""),
        "title": item.get("title", ""),
        "image": proxy_url(item.get("cover_image_url", "")),
        "status": status_label(item.get("status")),
        "type": country_label(item.get("country_id", "")),
        "author": ", ".join(taxonomy_names(item.get("taxonomy"), "Author")),
    }


def manga_source(page=1, page_size=PAGE_SIZE, query=None, recommended=False, latest=False):
    params = {"page": str(page), "page_size": str(page_size)}
    if query:
        params["q"] = query
    if recommended:
        params["is_recommended"] = "true"
    if latest:
        params["is_update"] = "true"

    data = api_get("/manga/list", params)
    return data if isinstance(data, list) else data.get("data", []) if isinstance(data, dict) else []


def manga_list(page=1, query=None, recommended=False, latest=False):
    items = manga_source(
        page=page,
        query=query,
        recommended=recommended,
        latest=latest,
    )
    results = [normalize_list_item(item) for item in items]
    return {
        "results": results,
        "hasMore": len(results) == PAGE_SIZE,
        "nextOffset": page * PAGE_SIZE,
    }


def filtered_manga_list(manga_type, offset, query=None):
    wanted_country = country_id(manga_type)
    if not wanted_country:
        return {"results": [], "hasMore": False, "nextOffset": offset}

    required = offset + PAGE_SIZE + 1
    matches = []
    seen = set()
    source_page = 1

    while len(matches) < required:
        cache_key = f"filter-source:{query or ''}:{source_page}"
        items = cached(
            cache_key,
            300,
            lambda page=source_page: manga_source(
                page=page,
                page_size=FILTER_SCAN_SIZE,
                query=query,
            ),
        )
        if not items:
            break

        for item in items:
            manga_id = item.get("manga_id", "")
            if not manga_id or manga_id in seen:
                continue
            seen.add(manga_id)
            if str(item.get("country_id", "")).upper() == wanted_country:
                matches.append(normalize_list_item(item))

        if len(items) < FILTER_SCAN_SIZE:
            break
        source_page += 1

    results = matches[offset:offset + PAGE_SIZE]
    return {
        "results": results,
        "hasMore": len(matches) > offset + PAGE_SIZE,
        "nextOffset": offset + len(results),
    }


def hot():
    result = cached("hot", 300, lambda: manga_list(recommended=True))
    return {**result, "hasMore": False}


def latest(page):
    return cached(f"latest:{page}", 120, lambda: manga_list(page=page, latest=True))


def browse(manga_type, offset):
    key = f"browse:{manga_type}:{offset}"
    return cached(
        key,
        300,
        lambda: filtered_manga_list(manga_type, offset),
    )


def search(query, manga_type, offset):
    page = offset // PAGE_SIZE + 1
    key = f"search:{query}:{manga_type}:{offset}"
    return cached(
        key,
        600,
        lambda: filtered_manga_list(manga_type, offset, query)
        if manga_type
        else manga_list(page=page, query=query),
    )


def manga_info(manga_id):
    def fetch():
        data = api_get(f"/manga/detail/{manga_id}")
        if not data:
            return {"error": "Manga not found"}

        description = (data.get("description") or "").replace("\ufeff", "").replace("\r", "")
        description = "".join(
            char if char == "\n" or ord(char) >= 32 else " "
            for char in description
        ).strip()
        return {
            "id": data.get("manga_id", manga_id),
            "title": data.get("title", ""),
            "description": description,
            "status": status_label(data.get("status")),
            "image": proxy_url(data.get("cover_image_url", "")),
            "authors": taxonomy_names(data.get("taxonomy"), "Author"),
            "tags": taxonomy_names(data.get("taxonomy"), "Genre"),
            "chapters": [],
            "latestChapterId": data.get("latest_chapter_id", ""),
        }

    return cached(f"info:{manga_id}", 1800, fetch)


def _extract_chapter(data, fallback_id):
    return {
        "id": data.get("chapter_id", fallback_id),
        "title": data.get("chapter_title", ""),
        "chapter": str(data.get("chapter_number", "")),
        "publishAt": data.get("release_date", ""),
    }


def chapters(manga_id, latest_chapter_id):
    if not latest_chapter_id:
        return []

    def fetch():
        _chapter_progress["current"] = 0
        _chapter_progress["mangaId"] = manga_id
        raw = []
        seen = set()
        chapter_id = latest_chapter_id
        while chapter_id and chapter_id not in seen and len(raw) < 2000:
            seen.add(chapter_id)
            _chapter_progress["current"] = len(raw) + 1
            try:
                data = api_get(f"/chapter/detail/{chapter_id}", timeout=15)
            except requests.RequestException as error:
                print(f"[manga-server] chapter traversal stopped at {chapter_id}: {error}")
                break
            if not data:
                break
            raw.append(_extract_chapter(data, chapter_id))
            chapter_id = data.get("prev_chapter_id")
        raw.reverse()
        _chapter_progress["current"] = len(raw)
        return raw

    return cached(f"chapters:{manga_id}", None, fetch, use_file=True)


def pages(chapter_id):
    def fetch():
        data = api_get(f"/chapter/detail/{chapter_id}")
        if not data:
            return []
        chapter = data.get("chapter") or {}
        base_url = data.get("base_url") or ASSET_BASE
        path = chapter.get("path", "")
        return [
            {"page": index + 1, "img": proxy_url(f"{base_url}{path}{filename}")}
            for index, filename in enumerate(chapter.get("data") or [])
        ]

    return cached(f"pages:{chapter_id}", None, fetch, use_file=True)


def load_library():
    with LIBRARY_LOCK:
        try:
            with open(LIBRARY_FILE, encoding="utf-8") as handle:
                value = json.load(handle)
            return value if isinstance(value, list) else []
        except (FileNotFoundError, json.JSONDecodeError, OSError):
            return []


def save_library(entries):
    os.makedirs(DATA_DIR, exist_ok=True)
    temporary = f"{LIBRARY_FILE}.tmp"
    with LIBRARY_LOCK:
        with open(temporary, "w", encoding="utf-8") as handle:
            json.dump(entries, handle, indent=2, ensure_ascii=False)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, LIBRARY_FILE)
    return entries


def update_library(action, payload):
    entries = load_library()
    manga_id = str(payload.get("id", ""))
    if not manga_id:
        raise ValueError("missing id")

    if action == "add":
        if not any(entry.get("id") == manga_id for entry in entries):
            entries.insert(0, {
                "id": manga_id,
                "title": payload.get("title", ""),
                "coverUrl": payload.get("coverUrl", ""),
                "lastReadChapterId": "",
                "lastReadChapterNum": "",
                "lastReadPage": 0,
                "lastReadAt": "",
                "addedAt": payload.get("addedAt", ""),
            })
    elif action == "remove":
        entries = [entry for entry in entries if entry.get("id") != manga_id]
    elif action == "progress":
        for entry in entries:
            if entry.get("id") == manga_id:
                entry["lastReadChapterId"] = payload.get("chapterId", "")
                entry["lastReadChapterNum"] = payload.get("chapterNum", "")
                entry["lastReadPage"] = payload.get("lastReadPage", 0)
                entry["lastReadAt"] = datetime.now().isoformat()
                break
    else:
        raise ValueError("unsupported library action")
    return save_library(entries)


def validate_image_url(url):
    parsed = urlparse(url)
    if parsed.scheme not in ("http", "https") or not parsed.hostname:
        raise ValueError("invalid image URL")
    if parsed.hostname == "localhost":
        raise ValueError("local image URL is not allowed")
    try:
        address = ipaddress.ip_address(parsed.hostname)
    except ValueError:
        address = None
    if address is not None and not address.is_global:
        raise ValueError("private image URL is not allowed")


def fetch_image(url):
    validate_image_url(url)
    with IMAGE_CACHE_LOCK:
        cached_image = IMAGE_CACHE.get(url)
    if cached_image:
        return cached_image

    with IMAGE_SEMAPHORE:
        response = SESSION.get(
            url,
            headers={
                "User-Agent": HEADERS["User-Agent"],
                "Accept": "image/avif,image/webp,image/png,image/jpeg,*/*;q=0.8",
                "Referer": HEADERS["Referer"],
            },
            timeout=30,
        )
        response.raise_for_status()
        result = (response.content, response.headers.get("Content-Type", "image/jpeg"))

    with IMAGE_CACHE_LOCK:
        if len(IMAGE_CACHE) >= 300:
            IMAGE_CACHE.pop(next(iter(IMAGE_CACHE)))
        IMAGE_CACHE[url] = result
    return result


class ThreadingHTTPServer(ThreadingMixIn, HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        print(f"[manga-server] {fmt % args}")

    def send_json(self, value, status=200):
        body = json.dumps(value, ensure_ascii=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(body)

    def send_error_json(self, message, status=500):
        self.send_json({"error": message}, status)

    def do_GET(self):
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)

        def param(name, default=""):
            return (query.get(name) or [default])[0]

        try:
            if parsed.path == "/health":
                return self.send_json({"ok": True})
            if parsed.path == "/hot":
                return self.send_json(hot())
            if parsed.path == "/latest":
                return self.send_json(latest(int(param("page", "1"))))
            if parsed.path == "/browse":
                manga_type = param("type")
                if not country_id(manga_type):
                    return self.send_error_json("invalid type", 400)
                return self.send_json(
                    browse(manga_type, int(param("offset", "0")))
                )
            if parsed.path == "/search":
                text = param("q").strip()
                if not text:
                    return self.send_error_json("missing q", 400)
                return self.send_json(search(text, param("type") or None, int(param("offset", "0"))))
            if parsed.path == "/info":
                manga_id = param("id")
                if not manga_id:
                    return self.send_error_json("missing id", 400)
                return self.send_json(manga_info(manga_id))
            if parsed.path == "/chapters":
                manga_id = param("mangaId")
                if not manga_id:
                    return self.send_error_json("missing mangaId", 400)
                return self.send_json(chapters(manga_id, param("latestChapterId")))
            if parsed.path == "/chapters_progress":
                return self.send_json(_chapter_progress)
            if parsed.path == "/clear_cache":
                manga_id = param("mangaId")
                if not manga_id:
                    return self.send_error_json("missing mangaId", 400)
                with _db_lock:
                    _db.execute("DELETE FROM cache WHERE key LIKE ?", (f"chapters:{manga_id}%",))
                    _db.commit()
                with CACHE_LOCK:
                    to_remove = [k for k in CACHE if k.startswith(f"chapters:{manga_id}")]
                    for k in to_remove:
                        del CACHE[k]
                return self.send_json({"ok": True})
            if parsed.path == "/pages":
                chapter_id = param("chapterId")
                if not chapter_id:
                    return self.send_error_json("missing chapterId", 400)
                return self.send_json(pages(chapter_id))
            if parsed.path == "/library":
                return self.send_json(load_library())
            if parsed.path == "/image":
                image_url = unquote(param("url"))
                if not image_url:
                    return self.send_error_json("missing url", 400)
                body, content_type = fetch_image(image_url)
                self.send_response(200)
                self.send_header("Content-Type", content_type)
                self.send_header("Content-Length", str(len(body)))
                self.send_header("Cache-Control", "public, max-age=86400")
                self.end_headers()
                return self.wfile.write(body)
            return self.send_error_json("not found", 404)
        except (BrokenPipeError, ConnectionResetError):
            return
        except (ValueError, requests.RequestException) as error:
            return self.send_error_json(str(error), 502)
        except Exception as error:
            return self.send_error_json(str(error), 500)

    def do_POST(self):
        try:
            length = int(self.headers.get("Content-Length", "0"))
            payload = json.loads(self.rfile.read(length)) if length else {}
            if self.path == "/library/add":
                return self.send_json(update_library("add", payload))
            if self.path == "/library/remove":
                return self.send_json(update_library("remove", payload))
            if self.path == "/library/progress":
                return self.send_json(update_library("progress", payload))
            return self.send_error_json("not found", 404)
        except (json.JSONDecodeError, ValueError) as error:
            return self.send_error_json(str(error), 400)
        except (BrokenPipeError, ConnectionResetError):
            return
        except Exception as error:
            return self.send_error_json(str(error), 500)


def run():
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"[manga-server] listening on http://127.0.0.1:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    run()
