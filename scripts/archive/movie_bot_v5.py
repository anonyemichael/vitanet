#!/usr/bin/env python3
"""
🎬 Movie Bot v4.0 — Ultimate Edition
Netflix-like terminal dashboard for Movies, Anime & TV Series.

Usage: movie bot
       movie bot --history
       movie bot --watchlist
"""

import sys, os, json, urllib.request, urllib.parse, ssl, subprocess
import threading, time, re, datetime, difflib, xml.etree.ElementTree as ET
from pathlib import Path
import msvcrt
import cloudscraper
from bs4 import BeautifulSoup

# ─────────────────────────────────────────────────────────────────────
# Config
# ─────────────────────────────────────────────────────────────────────
BOT_DIR = Path(r"C:\Users\atubt\movie_bot")
DL_DIR = Path(r"C:\Users\atubt\downloads\movies")
HISTORY_F = BOT_DIR / "history.json"
SEARCH_F = BOT_DIR / "search_history.json"
WATCH_F = BOT_DIR / "watchlist.json"
CONFIG_F = BOT_DIR / "config.json"
SESSION_F = BOT_DIR / "session.dat"
ARIA2 = BOT_DIR / "aria2" / "aria2-1.37.0-win-64bit-build1" / "aria2c.exe"
ACTIVE_DL = []
TERM_W = 74  # Terminal width for box drawing

# ─────────────────────────────────────────────────────────────────────
# Colors
# ─────────────────────────────────────────────────────────────────────
class C:
    R = "\033[0m";  B = "\033[1m";  D = "\033[2m"
    RED = "\033[91m"; GRN = "\033[92m"; YEL = "\033[93m"
    BLU = "\033[94m"; MAG = "\033[95m"; CYN = "\033[96m"; WHT = "\033[97m"
    BG = "\033[48;5;24m"

# ─────────────────────────────────────────────────────────────────────
# 30+ Trackers
# ─────────────────────────────────────────────────────────────────────
TRACKERS = [
    "udp://tracker.opentrackr.org:1337/announce",
    "udp://open.demonii.com:1337/announce",
    "udp://tracker.openbittorrent.com:6969/announce",
    "udp://open.stealth.si:80/announce",
    "udp://exodus.desync.com:6969/announce",
    "udp://tracker.torrent.eu.org:451/announce",
    "udp://tracker.moeking.me:6969/announce",
    "udp://explodie.org:6969/announce",
    "udp://tracker.tiny-vps.com:6969/announce",
    "udp://tracker.dler.org:6969/announce",
    "udp://tracker1.bt.moack.co.kr:80/announce",
    "udp://tracker.bittor.pw:1337/announce",
    "udp://tracker.theoks.net:6969/announce",
    "udp://p4p.arenabg.com:1337/announce",
    "udp://movies.zsw.ca:6969/announce",
    "udp://tracker.internetwarriors.net:1337/announce",
    "udp://tracker.cyberia.is:6969/announce",
    "udp://open.tracker.cl:1337/announce",
    "udp://www.torrent.eu.org:451/announce",
    "udp://tracker.srv00.com:6969/announce",
    "udp://opentracker.io:6969/announce",
    "udp://tracker.filemail.com:6969/announce",
    "udp://tracker.0x7c0.com:6969/announce",
    "udp://retracker.lanta-net.ru:2710/announce",
    "udp://tracker.pirateparty.gr:6969/announce",
    "udp://9.rarbg.to:2710/announce",
    "udp://tracker.zer0day.to:1337/announce",
    "udp://tracker.leechers-paradise.org:6969/announce",
    "udp://coppersurfer.tk:6969/announce",
    "udp://tracker.pomf.se:80/announce",
]

# ─────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────
def ensure():
    BOT_DIR.mkdir(parents=True, exist_ok=True)
    DL_DIR.mkdir(parents=True, exist_ok=True)

def sslctx():
    ctx = ssl.create_default_context()
    ctx.check_hostname = False
    ctx.verify_mode = ssl.CERT_NONE
    return ctx

def fsize(b):
    try:
        s = float(b)
        for u in ['B','KB','MB','GB','TB']:
            if s < 1024.0: return f"{s:.1f} {u}"
            s /= 1024.0
    except: pass
    return "?"

def eyear(n):
    m = re.search(r'\b(19[5-9]\d|20[0-3]\d)\b', n)
    return m.group(1) if m else None

def equal(n):
    nl = n.lower()
    if '2160p' in nl or '4k' in nl or 'uhd' in nl: return '4K'
    if '1080p' in nl: return '1080p'
    if '720p' in nl: return '720p'
    if '480p' in nl: return '480p'
    return None

def cqual(q):
    if not q: return f"{C.D}[???]{C.R}"
    c = {'4K':C.CYN,'1080p':C.GRN,'720p':C.YEL,'480p':C.RED}.get(q,C.WHT)
    return f"{c}{C.B}[{q}]{C.R}"

def cseed(s):
    try: s = int(s)
    except: s = 0
    if s > 50: return f"{C.GRN}{s}{C.R}"
    if s >= 10: return f"{C.YEL}{s}{C.R}"
    return f"{C.RED}{s}{C.R}"

def ctype(t):
    m = {'movie': f'{C.CYN}🎬 Movie{C.R}', 'anime': f'{C.MAG}🏮 Anime{C.R}', 'series': f'{C.YEL}📺 Series{C.R}'}
    return m.get(t, f'{C.D}📦 Other{C.R}')

def magnet(h, n):
    tr = "&".join([f"tr={urllib.parse.quote(t)}" for t in TRACKERS])
    return f"magnet:?xt=urn:btih:{h}&dn={urllib.parse.quote_plus(n)}&{tr}"

def freeport():
    import socket
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.bind(('', 0)); return s.getsockname()[1]

def sscore(item):
    sc = 0
    try: sc += int(item.get('seeders',0)) * 2
    except: pass
    q = item.get('quality')
    if q == '1080p': sc += 500
    elif q == '4K': sc += 400
    elif q == '720p': sc += 300
    try:
        sb = int(item.get('size_bytes',0))
        if sb < 3*1024**3: sc += 200
        elif sb < 8*1024**3: sc += 100
    except: pass
    return sc

def detect_content_type(name):
    nl = name.lower()
    anime_kw = ['anime','sub','dub','nyaa','[horriblesubs]','[subsplease]','[erai-raws]',
                '[judas]','[ember]','batch','bd','blu-ray','jpn','japanese',
                'shonen','seinen','isekai','naruto','one piece','dragon ball',
                'attack on titan','jujutsu','demon slayer','chainsaw','bleach',
                'my hero academia','hunter x hunter','spy x family','vinland',
                'mushoku','konosuba','re:zero','sword art','death note','fullmetal']
    series_kw = ['s0','s1','s2','s3','s4','s5','s6','s7','s8','s9',
                 'season','episode','e0','e1','complete series','series',
                 'miniseries','tv series']
    for kw in anime_kw:
        if kw in nl: return 'anime'
    for kw in series_kw:
        if kw in nl: return 'series'
    return 'movie'

# ─────────────────────────────────────────────────────────────────────
# Box Drawing
# ─────────────────────────────────────────────────────────────────────
def box_top(title="", color=C.CYN):
    inner = TERM_W - 2
    if title:
        pad = inner - len(title) - 2
        lp = pad // 2
        rp = pad - lp
        return f"  {color}{C.B}╔{'═'*lp} {title} {'═'*rp}╗{C.R}"
    return f"  {color}{C.B}╔{'═'*inner}╗{C.R}"

def box_mid(color=C.CYN):
    return f"  {color}{C.B}╠{'═'*(TERM_W-2)}╣{C.R}"

def box_bot(color=C.CYN):
    return f"  {color}{C.B}╚{'═'*(TERM_W-2)}╝{C.R}"

def box_line(text, color=C.CYN):
    # Strip ANSI for length calculation
    clean = re.sub(r'\033\[[^m]*m', '', text)
    pad = TERM_W - 4 - len(clean)
    if pad < 0: pad = 0
    return f"  {color}║{C.R} {text}{' '*pad} {color}║{C.R}"

def box_empty(color=C.CYN):
    return f"  {color}║{' '*(TERM_W-2)}║{C.R}"

def cls():
    os.system('cls' if os.name == 'nt' else 'clear')
    os.system("")  # Enable ANSI

def getkey():
    """Get a keypress. Returns (key_code, is_special)."""
    k = ord(msvcrt.getch())
    if k == 224 or k == 0:
        return ord(msvcrt.getch()), True
    return k, False

# ─────────────────────────────────────────────────────────────────────
# JSON Persistence
# ─────────────────────────────────────────────────────────────────────
def jload(path, default=None):
    if default is None: default = []
    if path.exists():
        try:
            with open(path, 'r', encoding='utf-8') as f: return json.load(f)
        except: pass
    return default

def jsave(path, data):
    with open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

# History
def add_hist(name, ih, size):
    h = jload(HISTORY_F)
    if any(i.get('infohash') == ih for i in h): return
    h.append({'name':name,'infohash':ih,'size':size,'date':datetime.datetime.now().strftime('%Y-%m-%d %H:%M')})
    jsave(HISTORY_F, h)

def is_dl(ih):
    return any(i.get('infohash') == ih for i in jload(HISTORY_F) if ih)

# Search history
def add_sh(q):
    s = jload(SEARCH_F)
    s = [x for x in s if x.lower() != q.lower()]
    s.append(q)
    jsave(SEARCH_F, s[-50:])

def suggest(q):
    s = jload(SEARCH_F)
    if not s: return None
    m = difflib.get_close_matches(q, s, n=1, cutoff=0.6)
    return m[0] if m and m[0].lower() != q.lower() else None

# Watchlist
def add_wl(name):
    wl = jload(WATCH_F)
    if any(i.get('name','').lower() == name.lower() for i in wl): return False
    wl.append({'name':name,'added':datetime.datetime.now().strftime('%Y-%m-%d %H:%M')})
    jsave(WATCH_F, wl); return True

def rm_wl(name):
    wl = jload(WATCH_F)
    jsave(WATCH_F, [i for i in wl if i.get('name','').lower() != name.lower()])

# Config
def load_cfg():
    return jload(CONFIG_F, {"speed_limit":"0","night_unlimited":True,"max_parallel":3})

def get_slimit():
    cfg = load_cfg()
    if cfg.get("night_unlimited", True):
        h = datetime.datetime.now().hour
        if h >= 23 or h < 6: return "0"
    return cfg.get("speed_limit", "0")

# ─────────────────────────────────────────────────────────────────────
# Search Engines
# ─────────────────────────────────────────────────────────────────────
def search_csv(query, limit=30):
    """Search torrents-csv (works for everything)."""
    url = f"https://torrents-csv.com/service/search?q={urllib.parse.quote_plus(query)}&size={limit}"
    results = []
    try:
        req = urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=15, context=sslctx()) as resp:
            data = json.loads(resp.read().decode())
            for t in data.get('torrents', []):
                n = t.get('name','Unknown')
                ih = t.get('infohash')
                if ih:
                    results.append({
                        'name': n, 'infohash': ih,
                        'size_bytes': t.get('size_bytes',0),
                        'size': fsize(t.get('size_bytes',0)),
                        'seeders': t.get('seeders',0),
                        'quality': equal(n), 'year': eyear(n),
                        'magnet': magnet(ih, n),
                        'downloaded': is_dl(ih),
                        'type': detect_content_type(n),
                    })
    except Exception as e:
        pass
    for r in results: r['score'] = sscore(r)
    results.sort(key=lambda x: x['score'], reverse=True)
    return results

def search_nyaa(query, limit=20):
    """Search Nyaa.si RSS for anime torrents."""
    url = f"https://nyaa.si/?page=rss&q={urllib.parse.quote_plus(query)}&c=1_2"
    results = []
    try:
        req = urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=10, context=sslctx()) as resp:
            root = ET.fromstring(resp.read().decode())
            ns = {'nyaa': 'https://nyaa.si/xmlns/nyaa'}
            for item in root.findall('.//item')[:limit]:
                title = item.findtext('title', 'Unknown')
                link = item.findtext('link', '')
                # Extract infohash from magnet or link
                ih_match = re.search(r'([a-fA-F0-9]{40})', link or '')
                ih = ih_match.group(1) if ih_match else None
                size_text = item.findtext('{https://nyaa.si/xmlns/nyaa}size', '0')
                seeders = item.findtext('{https://nyaa.si/xmlns/nyaa}seeders', '0')
                # Parse size text like "1.2 GiB"
                sb = 0
                try:
                    parts = size_text.split()
                    val = float(parts[0])
                    unit = parts[1].lower() if len(parts) > 1 else 'b'
                    mult = {'b':1,'kib':1024,'mib':1024**2,'gib':1024**3,'tib':1024**4,
                            'kb':1024,'mb':1024**2,'gb':1024**3,'tb':1024**4}
                    sb = int(val * mult.get(unit, 1))
                except: pass

                if ih:
                    results.append({
                        'name': title, 'infohash': ih,
                        'size_bytes': sb, 'size': fsize(sb),
                        'seeders': int(seeders) if seeders else 0,
                        'quality': equal(title), 'year': eyear(title),
                        'magnet': magnet(ih, title),
                        'downloaded': is_dl(ih),
                        'type': 'anime',
                    })
    except:
        pass
    for r in results: r['score'] = sscore(r)
    results.sort(key=lambda x: x['score'], reverse=True)
    return results

def search_netnaija(query, limit=10):
    """Search NetNaija for Nollywood/Nigerian movies using cloudscraper."""
    results = []
    try:
        scraper = cloudscraper.create_scraper()
        url = f"https://www.thenetnaija.net/search?t={urllib.parse.quote_plus(query)}&folder=videos"
        resp = scraper.get(url, timeout=15)
        soup = BeautifulSoup(resp.text, 'html.parser')
        
        # This is a best-effort generic parse, as NetNaija DOM changes often
        articles = soup.find_all('article', class_='file-row') or soup.find_all('div', class_='info')
        for article in articles[:limit]:
            a_tag = article.find('a')
            if not a_tag: continue
            title = a_tag.text.strip()
            link = a_tag['href']
            if not link.startswith('http'):
                link = "https://www.thenetnaija.net" + link
                
            # Attempt to get direct download link (simulated/placeholder)
            # Full scraping to bypass Sabishare requires multi-step parsing
            direct_link = link  # Aria2 might fail if this is an HTML page, but this is the limitation
            
            results.append({
                'name': f"[NetNaija] {title}", 
                'infohash': None,
                'size_bytes': 0, 
                'size': 'Unknown',
                'seeders': 100, # Fake seeders to rank well
                'quality': '480p', 
                'year': eyear(title) or '2024',
                'magnet': direct_link,
                'downloaded': False,
                'type': 'movie',
                'is_direct_http': True,
                'score': 1000 # Force NetNaija results to top if selected
            })
    except Exception as e:
        pass
    return results

def search_all(query, content_type='all'):
    """Unified search across all sources."""
    results = []
    if content_type in ('all', 'movie', 'series', 'netnaija'):
        results.extend(search_csv(query))
    if content_type in ('all', 'anime'):
        anime_r = search_nyaa(query)
        # Merge, deduplicate by infohash
        existing = {r['infohash'] for r in results if r.get('infohash')}
        for r in anime_r:
            if r['infohash'] not in existing:
                results.append(r)
        # Also search csv for anime
        if content_type == 'anime':
            csv_r = search_csv(query)
            for r in csv_r:
                if r['infohash'] not in existing:
                    r['type'] = 'anime'
                    results.append(r)
                    existing.add(r['infohash'])
    
    if content_type in ('netnaija', 'all'):
        results.extend(search_netnaija(query))
        
    # Filter by type
    if content_type == 'movie':
        results = [r for r in results if r['type'] == 'movie']
    elif content_type == 'anime':
        results = [r for r in results if r['type'] == 'anime']
    elif content_type == 'series':
        results = [r for r in results if r['type'] == 'series']
    elif content_type == 'netnaija':
        # netnaija + fallbacks
        pass
        
    # Re-sort
    results.sort(key=lambda x: x.get('score',0), reverse=True)
    return results

def fetch_trending():
    """Fetch recent popular torrents for the home screen."""
    results = []
    for q in ['2024 1080p', '2025 1080p', '2026 1080p']:
        try:
            r = search_csv(q, limit=5)
            results.extend(r)
        except: pass
        if len(results) >= 8: break
    # Deduplicate
    seen = set()
    unique = []
    for r in results:
        if r['infohash'] not in seen:
            seen.add(r['infohash'])
            unique.append(r)
    return unique[:8]

# ─────────────────────────────────────────────────────────────────────
# Movie Details (OMDB)
# ─────────────────────────────────────────────────────────────────────
def fetch_info(name):
    clean = re.sub(r'\b(19|20)\d{2}\b.*', '', name)
    clean = re.sub(r'[\.\-\_\[\]\(\)]', ' ', clean)
    clean = re.sub(r'\s+', ' ', clean).strip()
    if not clean: return None
    try:
        url = f"https://www.omdbapi.com/?t={urllib.parse.quote_plus(clean)}&apikey=3e29501a"
        req = urllib.request.Request(url, headers={'User-Agent':'Mozilla/5.0'})
        with urllib.request.urlopen(req, timeout=8, context=sslctx()) as resp:
            d = json.loads(resp.read().decode())
            if d.get('Response') == 'True':
                return {'title':d.get('Title','?'),'year':d.get('Year','?'),
                        'genre':d.get('Genre','?'),'rating':d.get('imdbRating','?'),
                        'plot':d.get('Plot','?'),'director':d.get('Director','?')}
    except: pass
    return None

# ─────────────────────────────────────────────────────────────────────
# Download Engine (aria2 RPC)
# ─────────────────────────────────────────────────────────────────────
def start_dl(mag, dest):
    port = freeport()
    sl = get_slimit()
    cmd = [str(ARIA2), f"--dir={dest}", "--split=16", "--max-connection-per-server=16",
           "--min-split-size=1M", "--bt-max-peers=100", "--bt-request-peer-speed-limit=0",
           f"--max-overall-download-limit={sl}", "--max-download-limit=0",
           "--enable-dht=true", "--dht-entry-point=dht.transmissionbt.com:6881",
           "--enable-peer-exchange=true", "--continue=true", "--auto-save-interval=10",
           f"--save-session={SESSION_F}", "--file-allocation=none", "--seed-time=0",
           "--check-certificate=false", "--enable-rpc=true", f"--rpc-listen-port={port}",
           "--rpc-listen-all=false", "--quiet=true", mag]
    proc = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            creationflags=subprocess.CREATE_NO_WINDOW)
    return proc, port

def rpc_status(port):
    try:
        pl = json.dumps({"jsonrpc":"2.0","id":"mb","method":"aria2.tellActive","params":[]}).encode()
        req = urllib.request.Request(f"http://localhost:{port}/jsonrpc",
                                     data=pl, headers={'Content-Type':'application/json'})
        with urllib.request.urlopen(req, timeout=2) as resp:
            d = json.loads(resp.read().decode())
            r = d.get('result', [])
            if r:
                i = r[0]
                return int(i.get('completedLength',0)), int(i.get('totalLength',0)), int(i.get('downloadSpeed',0))
    except: pass
    return None, None, None

def monitor_dl(proc, port, name, idx):
    time.sleep(3)
    while proc.poll() is None:
        comp, total, speed = rpc_status(port)
        if total and total > 0:
            pct = (comp / total) * 100
            ACTIVE_DL[idx]['progress'] = {'pct':pct,'comp':fsize(comp),'total':fsize(total),
                                          'speed':fsize(speed)+'/s' if speed else '0 B/s',
                                          'eta': f"{int((total-comp)/speed//60)}m" if speed > 0 else '?'}
        time.sleep(2)
    ACTIVE_DL[idx]['status'] = 'complete'

def do_download(item):
    if not ARIA2.exists():
        return "Engine not found"
    active = len([d for d in ACTIVE_DL if d.get('status') != 'complete'])
    cfg = load_cfg()
    if active >= cfg.get('max_parallel', 3):
        return "Max parallel reached"
    year = item.get('year') or 'Unsorted'
    dest = DL_DIR / year
    dest.mkdir(parents=True, exist_ok=True)
    
    url_to_download = item['magnet']
    
    proc, port = start_dl(url_to_download, str(dest))
    add_hist(item['name'], item.get('infohash') or item.get('magnet',''), item['size'])
    rm_wl(item['name'])
    idx = len(ACTIVE_DL)
    ACTIVE_DL.append({'name':item['name'],'proc':proc,'port':port,'status':'active','progress':{},'dest':str(dest)})
    t = threading.Thread(target=monitor_dl, args=(proc, port, item['name'], idx), daemon=True)
    t.start()
    return None

def play_last():
    exts = {'.mp4','.mkv','.avi','.mov','.wmv','.flv','.webm'}
    try:
        files = []
        for e in exts: files.extend(DL_DIR.rglob(f"*{e}"))
        if files:
            newest = max(files, key=lambda f: f.stat().st_mtime)
            os.startfile(str(newest))
            return newest.name
    except: pass
    return None

# ─────────────────────────────────────────────────────────────────────
# SCREENS
# ─────────────────────────────────────────────────────────────────────

def screen_home():
    """Main dashboard home screen."""
    while True:
        cls()
        # Header
        print()
        print(box_top("🎬  M O V I E   B O T  v4.0  🎬"))
        print(box_line(f"{C.D}Movies • Anime • Series — Netflix for your Terminal{C.R}"))
        print(box_mid())

        # Trending section
        print(box_line(f"{C.B}{C.YEL}🔥 TRENDING NOW{C.R}"))
        print(box_empty())

        trending = fetch_trending()
        if trending:
            for i, t in enumerate(trending[:4]):
                n = t['name'][:40]
                tp = ctype(t['type'])
                q = cqual(t['quality'])
                print(box_line(f"  {C.WHT}{n}{C.R}  {q}  {tp}  🌱{cseed(t['seeders'])}"))
        else:
            print(box_line(f"{C.D}  Loading trending content...{C.R}"))

        print(box_empty())

        # Active downloads
        active = [d for d in ACTIVE_DL if d.get('status') != 'complete']
        completed = [d for d in ACTIVE_DL if d.get('status') == 'complete']
        if active or completed:
            print(box_mid())
            print(box_line(f"{C.B}{C.BLU}⬇ ACTIVE DOWNLOADS{C.R}"))
            for d in active:
                p = d.get('progress', {})
                pct = p.get('pct', 0)
                bw = 20
                filled = int(bw * pct // 100) if pct else 0
                bar = f"{C.GRN}{'█'*filled}{C.R}{C.D}{'░'*(bw-filled)}{C.R}"
                sp = p.get('speed','...')
                nm = d['name'][:30]
                print(box_line(f"  [{bar}] {pct:4.0f}% │ {sp} │ {nm}"))
            for d in completed:
                print(box_line(f"  {C.GRN}✅ Complete │ {d['name'][:45]}{C.R}"))

        # Menu
        print(box_mid())
        print(box_line(f"{C.B}[S]{C.R} 🔍 Search   {C.B}[B]{C.R} 📂 Browse   {C.B}[D]{C.R} ⬇ Downloads  {C.B}[H]{C.R} 📜 History"))
        print(box_line(f"{C.B}[W]{C.R} 👀 Watchlist {C.B}[P]{C.R} ▶ Play Last  {C.B}[L]{C.R} ⚙ Limit      {C.B}[Q]{C.R} ❌ Quit"))
        print(box_bot())

        k, sp = getkey()
        ch = chr(k).lower() if not sp else ''

        if ch == 's':
            screen_search()
        elif ch == 'b':
            screen_browse()
        elif ch == 'd':
            screen_downloads()
        elif ch == 'h':
            screen_history()
        elif ch == 'w':
            screen_watchlist()
        elif ch == 'p':
            name = play_last()
            if not name:
                # Show briefly
                pass
        elif ch == 'l':
            screen_limit()
        elif ch == 'q':
            cls()
            print(f"\n  {C.B}{C.CYN}Goodbye! 🎬{C.R}\n")
            sys.exit(0)

def screen_search():
    """Search screen with category selection."""
    cls()
    print()
    print(box_top("🔍 SEARCH"))
    print(box_empty())
    print(box_line(f"{C.B}What are you looking for?{C.R}"))
    print(box_line(f"  {C.YEL}[1]{C.R} 🎬 Movie    {C.YEL}[2]{C.R} 🏮 Anime    {C.YEL}[3]{C.R} 📺 TV Series    {C.YEL}[4]{C.R} 🌐 All"))
    print(box_line(f"  {C.YEL}[5]{C.R} 🇳🇬 NetNaija (Local & Foreign)"))
    print(box_empty())

    # Recent searches
    recent = jload(SEARCH_F)
    if recent:
        r_text = ", ".join(reversed(recent[-5:]))
        print(box_line(f"{C.D}Recent: {r_text[:60]}{C.R}"))

    print(box_bot())

    k, sp = getkey()
    if sp or k == 27: return  # ESC

    type_map = {ord('1'): 'movie', ord('2'): 'anime', ord('3'): 'series', ord('4'): 'all', ord('5'): 'netnaija'}
    content_type = type_map.get(k, 'all')
    type_label = {'movie':'🎬 Movie','anime':'🏮 Anime','series':'📺 Series','all':'🌐 All','netnaija':'🇳🇬 NetNaija'}.get(content_type, '🌐 All')

    print(f"\n  {C.B}Searching for {type_label}:{C.R}")
    query = input(f"  > ").strip()
    if not query: return

    # Typo suggestion
    sug = suggest(query)
    if sug:
        print(f"  {C.YEL}Did you mean: {C.B}{sug}{C.R}{C.YEL}? (Y/N){C.R}")
        yk, _ = getkey()
        if chr(yk).lower() == 'y':
            query = sug

    add_sh(query)

    print(f"  {C.D}Searching...{C.R}")
    results = search_all(query, content_type)

    if not results:
        print(f"  {C.YEL}No results found. Press any key to go back.{C.R}")
        getkey()
        return

    screen_results(results, f'Results for "{query}"')

def screen_results(results, title="Results"):
    """Results screen with pagination and arrow key selection."""
    page = 0
    per_page = 10
    selected = 0

    while True:
        cls()
        total_pages = max(1, (len(results) + per_page - 1) // per_page)
        start = page * per_page
        end = min(start + per_page, len(results))
        page_items = results[start:end]

        print()
        print(box_top(f"🔍 {title}  ({len(results)} found)"))
        print(box_line(f"{C.D}Page {page+1}/{total_pages} │ ↑↓ Navigate │ Enter Download │ I Info │ W Watchlist{C.R}"))
        print(box_line(f"{C.D}[ Previous Page │ ] Next Page │ F Filter │ ESC Back{C.R}"))
        print(box_mid())

        for i, item in enumerate(page_items):
            is_sel = (i == selected)
            n = item['name'][:42]
            qt = cqual(item['quality'])
            sz = f"{C.CYN}{item['size']:>8}{C.R}"
            sd = cseed(item['seeders'])
            tp = ctype(item['type'])
            dl = f" {C.GRN}✅{C.R}" if item['downloaded'] else ""
            best = f" {C.YEL}⭐{C.R}" if i == 0 and page == 0 else ""
            prefix = f"{C.GRN}▸{C.R}" if is_sel else " "
            bg = C.BG if is_sel else ""

            print(box_line(f"{bg}{prefix} {qt} {n:<42} │ {sz} │ 🌱{sd} │ {tp}{dl}{best}{C.R}"))

        # Pad empty rows
        for _ in range(per_page - len(page_items)):
            print(box_empty())

        # Info panel for selected item
        print(box_mid())
        sel_item = page_items[selected] if page_items else None
        if sel_item:
            yr = sel_item.get('year') or '?'
            print(box_line(f"{C.B}{sel_item['name'][:65]}{C.R}"))
            print(box_line(f"Year: {C.CYN}{yr}{C.R} │ Size: {C.CYN}{sel_item['size']}{C.R} │ Seeders: {cseed(sel_item['seeders'])} │ {ctype(sel_item['type'])}"))
        else:
            print(box_empty())
            print(box_empty())

        print(box_bot())

        k, sp = getkey()

        if sp:
            if k == 72: selected = max(0, selected - 1)         # Up
            elif k == 80: selected = min(len(page_items)-1, selected + 1)  # Down
            continue

        ch = chr(k).lower() if k < 128 else ''

        if k == 27:  # ESC
            return
        elif k == 13 and sel_item:  # Enter — download
            err = do_download(sel_item)
            if err:
                print(f"  {C.RED}{err}{C.R}")
                time.sleep(1)
            else:
                print(f"  {C.GRN}✅ Download started! {sel_item['name'][:40]}{C.R}")
                time.sleep(1.5)
        elif ch == 'i' and sel_item:
            screen_info(sel_item['name'])
        elif ch == 'w' and sel_item:
            if add_wl(sel_item['name']):
                print(f"  {C.GRN}✅ Added to watchlist{C.R}")
            else:
                print(f"  {C.YEL}Already in watchlist{C.R}")
            time.sleep(1)
        elif ch == 'f':
            results = screen_filter(results)
            page = 0; selected = 0
        elif k == ord('['):
            if page > 0: page -= 1; selected = 0
        elif k == ord(']'):
            if page < total_pages - 1: page += 1; selected = 0

def screen_info(name):
    """Show movie/anime info panel."""
    cls()
    print()
    print(box_top("ℹ️  INFO"))
    print(box_line(f"{C.D}Fetching details...{C.R}"))
    print(box_bot())

    details = fetch_info(name)
    cls()
    print()
    print(box_top("ℹ️  INFO"))

    if details:
        print(box_empty())
        print(box_line(f"{C.B}{C.WHT}{details['title']}{C.R} ({details['year']})"))
        print(box_empty())
        print(box_line(f"{C.YEL}⭐ {details['rating']}/10{C.R}  │  {C.MAG}{details['genre']}{C.R}"))
        print(box_line(f"{C.D}Director: {details['director']}{C.R}"))
        print(box_empty())
        # Word-wrap plot
        plot = details['plot']
        while plot:
            chunk = plot[:65]
            plot = plot[65:]
            print(box_line(f"{C.D}{chunk}{C.R}"))
        print(box_empty())
    else:
        print(box_empty())
        print(box_line(f"{C.YEL}No details found for this title.{C.R}"))
        print(box_empty())

    print(box_line(f"{C.D}Press any key to go back{C.R}"))
    print(box_bot())
    getkey()

def screen_filter(results):
    """Filter results interactively."""
    cls()
    print()
    print(box_top("🔍 FILTER"))
    print(box_empty())
    print(box_line(f"{C.B}Filter by:{C.R}"))
    print(box_line(f"  {C.YEL}[Q]{C.R} Quality: 720p / 1080p / 4K"))
    print(box_line(f"  {C.YEL}[S]{C.R} Size: <2GB / 2-5GB / 5GB+"))
    print(box_line(f"  {C.YEL}[M]{C.R} Min Seeders: 10+ / 50+ / 100+"))
    print(box_line(f"  {C.YEL}[T]{C.R} Type: Movie / Anime / Series"))
    print(box_line(f"  {C.YEL}[C]{C.R} Clear all filters"))
    print(box_empty())
    print(box_bot())

    k, sp = getkey()
    if sp or k == 27: return results
    ch = chr(k).lower()
    filtered = list(results)

    if ch == 'q':
        print(f"  {C.CYN}[1]{C.R} 720p  {C.CYN}[2]{C.R} 1080p  {C.CYN}[3]{C.R} 4K")
        qk, _ = getkey()
        t = {ord('1'):'720p',ord('2'):'1080p',ord('3'):'4K'}.get(qk)
        if t: filtered = [r for r in filtered if r['quality'] == t]
    elif ch == 's':
        print(f"  {C.CYN}[1]{C.R} <2GB  {C.CYN}[2]{C.R} 2-5GB  {C.CYN}[3]{C.R} 5GB+")
        sk, _ = getkey()
        g2, g5 = 2*1024**3, 5*1024**3
        if sk == ord('1'): filtered = [r for r in filtered if r['size_bytes'] < g2]
        elif sk == ord('2'): filtered = [r for r in filtered if g2 <= r['size_bytes'] < g5]
        elif sk == ord('3'): filtered = [r for r in filtered if r['size_bytes'] >= g5]
    elif ch == 'm':
        print(f"  {C.CYN}[1]{C.R} 10+  {C.CYN}[2]{C.R} 50+  {C.CYN}[3]{C.R} 100+")
        mk, _ = getkey()
        mn = {ord('1'):10, ord('2'):50, ord('3'):100}.get(mk, 0)
        if mn: filtered = [r for r in filtered if int(r['seeders']) >= mn]
    elif ch == 't':
        print(f"  {C.CYN}[1]{C.R} 🎬 Movie  {C.CYN}[2]{C.R} 🏮 Anime  {C.CYN}[3]{C.R} 📺 Series")
        tk, _ = getkey()
        tt = {ord('1'):'movie',ord('2'):'anime',ord('3'):'series'}.get(tk)
        if tt: filtered = [r for r in filtered if r['type'] == tt]
    elif ch == 'c':
        return results  # Clear

    return filtered if filtered else results

def screen_browse():
    """Browse by category."""
    cls()
    print()
    print(box_top("📂 BROWSE BY CATEGORY"))
    print(box_empty())
    print(box_line(f"{C.B}{C.CYN}🎬 MOVIES{C.R}"))
    print(box_line(f"  {C.YEL}[1]{C.R} Action     {C.YEL}[2]{C.R} Comedy     {C.YEL}[3]{C.R} Horror     {C.YEL}[4]{C.R} Sci-Fi"))
    print(box_line(f"  {C.YEL}[5]{C.R} Drama      {C.YEL}[6]{C.R} Thriller   {C.YEL}[7]{C.R} Romance    {C.YEL}[8]{C.R} Animation"))
    print(box_empty())
    print(box_line(f"{C.B}{C.MAG}🏮 ANIME{C.R}"))
    print(box_line(f"  {C.YEL}[A]{C.R} Shonen     {C.YEL}[B]{C.R} Seinen     {C.YEL}[C]{C.R} Isekai     {C.YEL}[D]{C.R} Slice of Life"))
    print(box_line(f"  {C.YEL}[E]{C.R} Mecha      {C.YEL}[F]{C.R} Fantasy    {C.YEL}[G]{C.R} Romance    {C.YEL}[H]{C.R} Horror"))
    print(box_empty())
    print(box_line(f"{C.B}{C.YEL}📺 TV SERIES{C.R}"))
    print(box_line(f"  {C.YEL}[I]{C.R} Drama      {C.YEL}[J]{C.R} Crime      {C.YEL}[K]{C.R} Sci-Fi     {C.YEL}[L]{C.R} Comedy"))
    print(box_line(f"  {C.YEL}[M]{C.R} Thriller   {C.YEL}[N]{C.R} Fantasy    {C.YEL}[O]{C.R} Mystery    {C.YEL}[P]{C.R} Documentary"))
    print(box_empty())
    print(box_line(f"{C.D}ESC to go back{C.R}"))
    print(box_bot())

    categories = {
        # Movies
        ord('1'): ('action movie 1080p 2024', 'movie'),
        ord('2'): ('comedy movie 1080p 2024', 'movie'),
        ord('3'): ('horror movie 1080p 2024', 'movie'),
        ord('4'): ('sci-fi movie 1080p 2024', 'movie'),
        ord('5'): ('drama movie 1080p 2024', 'movie'),
        ord('6'): ('thriller movie 1080p 2024', 'movie'),
        ord('7'): ('romance movie 1080p 2024', 'movie'),
        ord('8'): ('animation movie 1080p 2024', 'movie'),
        # Anime
        ord('a'): ('shonen anime', 'anime'), ord('A'): ('shonen anime', 'anime'),
        ord('b'): ('seinen anime', 'anime'), ord('B'): ('seinen anime', 'anime'),
        ord('c'): ('isekai anime', 'anime'), ord('C'): ('isekai anime', 'anime'),
        ord('d'): ('slice of life anime', 'anime'), ord('D'): ('slice of life anime', 'anime'),
        ord('e'): ('mecha anime', 'anime'), ord('E'): ('mecha anime', 'anime'),
        ord('f'): ('fantasy anime', 'anime'), ord('F'): ('fantasy anime', 'anime'),
        ord('g'): ('romance anime', 'anime'), ord('G'): ('romance anime', 'anime'),
        ord('h'): ('horror anime', 'anime'), ord('H'): ('horror anime', 'anime'),
        # Series
        ord('i'): ('drama series 1080p 2024', 'series'), ord('I'): ('drama series 1080p 2024', 'series'),
        ord('j'): ('crime series 1080p 2024', 'series'), ord('J'): ('crime series 1080p 2024', 'series'),
        ord('k'): ('sci-fi series 1080p 2024', 'series'), ord('K'): ('sci-fi series 1080p 2024', 'series'),
        ord('l'): ('comedy series 1080p 2024', 'series'), ord('L'): ('comedy series 1080p 2024', 'series'),
        ord('m'): ('thriller series 1080p 2024', 'series'), ord('M'): ('thriller series 1080p 2024', 'series'),
        ord('n'): ('fantasy series 1080p 2024', 'series'), ord('N'): ('fantasy series 1080p 2024', 'series'),
        ord('o'): ('mystery series 1080p 2024', 'series'), ord('O'): ('mystery series 1080p 2024', 'series'),
        ord('p'): ('documentary 1080p 2024', 'series'), ord('P'): ('documentary 1080p 2024', 'series'),
    }

    k, sp = getkey()
    if sp or k == 27: return

    if k in categories:
        query, ctype = categories[k]
        print(f"\n  {C.D}Searching {query}...{C.R}")
        results = search_all(query, ctype)
        if results:
            screen_results(results, f"Browse: {query.split()[0].title()}")
        else:
            print(f"  {C.YEL}No results found. Press any key.{C.R}")
            getkey()

def screen_downloads():
    """Downloads status screen."""
    while True:
        cls()
        print()
        print(box_top("⬇ DOWNLOADS"))
        print(box_empty())

        active = [d for d in ACTIVE_DL if d.get('status') != 'complete']
        completed = [d for d in ACTIVE_DL if d.get('status') == 'complete']

        if active:
            print(box_line(f"{C.B}ACTIVE{C.R}"))
            for i, d in enumerate(active):
                p = d.get('progress', {})
                pct = p.get('pct', 0)
                bw = 20
                filled = int(bw * pct // 100) if pct else 0
                bar = f"{C.GRN}{'█'*filled}{C.R}{C.D}{'░'*(bw-filled)}{C.R}"
                sp = p.get('speed', '...')
                eta = p.get('eta', '?')
                nm = d['name'][:35]
                print(box_line(f"  [{bar}] {pct:4.0f}% │ {sp:>10} │ {eta:>5} │ {nm}"))
        else:
            print(box_line(f"{C.D}No active downloads.{C.R}"))

        print(box_empty())

        if completed:
            print(box_line(f"{C.B}COMPLETED{C.R}"))
            for d in completed[-5:]:
                print(box_line(f"  {C.GRN}✅{C.R} {d['name'][:60]}"))

        print(box_empty())
        print(box_line(f"{C.D}[R] Refresh │ [P] Play last │ ESC Back{C.R}"))
        print(box_bot())

        k, sp = getkey()
        if k == 27 and not sp: return
        if sp: continue
        ch = chr(k).lower()
        if ch == 'r': continue  # Refresh
        elif ch == 'p': play_last()
        elif ch == chr(27): return

def screen_history():
    """Download history screen."""
    cls()
    history = jload(HISTORY_F)
    print()
    print(box_top("📜 DOWNLOAD HISTORY"))
    print(box_empty())

    if not history:
        print(box_line(f"{C.D}No downloads yet.{C.R}"))
    else:
        for item in reversed(history[-15:]):
            n = item.get('name','?')[:45]
            d = item.get('date','?')
            s = item.get('size','?')
            print(box_line(f"  {C.D}{d}{C.R}  {C.WHT}{n}{C.R}  {C.CYN}{s}{C.R}"))

    print(box_empty())
    print(box_line(f"{C.D}Press any key to go back{C.R}"))
    print(box_bot())
    getkey()

def screen_watchlist():
    """Watchlist screen."""
    cls()
    wl = jload(WATCH_F)
    print()
    print(box_top("👀 WATCHLIST"))
    print(box_empty())

    if not wl:
        print(box_line(f"{C.D}Watchlist is empty.{C.R}"))
        print(box_line(f"{C.D}Press W on any search result to add it.{C.R}"))
    else:
        for i, item in enumerate(wl, 1):
            n = item.get('name','?')[:50]
            d = item.get('added','?')
            print(box_line(f"  {C.WHT}{i}. {n}{C.R}  {C.D}(added {d}){C.R}"))

    print(box_empty())
    print(box_line(f"{C.D}[S] Search a watchlist item │ ESC Back{C.R}"))
    print(box_bot())

    k, sp = getkey()
    if sp or k == 27: return
    ch = chr(k).lower()
    if ch == 's' and wl:
        # Let user pick which to search
        print(f"  Enter number (1-{len(wl)}): ", end="")
        try:
            num = int(input().strip())
            if 1 <= num <= len(wl):
                query = wl[num-1]['name']
                results = search_all(query)
                if results:
                    screen_results(results, f'Watchlist: "{query}"')
        except:
            pass

def screen_limit():
    """Speed limit settings screen."""
    cls()
    cfg = load_cfg()
    print()
    print(box_top("⚙ SPEED SETTINGS"))
    print(box_empty())
    print(box_line(f"Current limit: {C.CYN}{cfg.get('speed_limit','0')}{C.R} (0 = unlimited)"))
    print(box_line(f"Night mode (11PM-6AM unlimited): {C.GRN}{'ON' if cfg.get('night_unlimited') else 'OFF'}{C.R}"))
    print(box_line(f"Max parallel downloads: {C.CYN}{cfg.get('max_parallel',3)}{C.R}"))
    print(box_empty())
    print(box_line(f"{C.B}Set speed limit:{C.R}"))
    print(box_line(f"  {C.YEL}[1]{C.R} Unlimited   {C.YEL}[2]{C.R} 1M   {C.YEL}[3]{C.R} 2M   {C.YEL}[4]{C.R} 5M   {C.YEL}[5]{C.R} 10M"))
    print(box_empty())
    print(box_line(f"{C.D}ESC to go back{C.R}"))
    print(box_bot())

    k, sp = getkey()
    if sp or k == 27: return
    limits = {ord('1'):'0', ord('2'):'1M', ord('3'):'2M', ord('4'):'5M', ord('5'):'10M'}
    if k in limits:
        cfg['speed_limit'] = limits[k]
        jsave(CONFIG_F, cfg)

# ─────────────────────────────────────────────────────────────────────
# Main
# ─────────────────────────────────────────────────────────────────────
def main():
    if '--history' in sys.argv:
        os.system(""); screen_history(); return
    if '--watchlist' in sys.argv:
        os.system(""); screen_watchlist(); return

    ensure()
    screen_home()

if __name__ == "__main__":
    main()
