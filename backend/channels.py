"""
channels.py - M3U Channel Parser and Filter
AngoMovie IPTV Backend
"""
import re
import time
import logging
from typing import List, Dict, Optional
import httpx

logger = logging.getLogger(__name__)

# M3U Source URL
M3U_URL = "http://nitidez.pro:80/get.php?username=Marcio&password=123456&type=m3u_plus"

# Keywords to EXCLUDE (filter out non-live content)
EXCLUDED_KEYWORDS = [
    "FILME", "SERIE", "VOD", "MOVIE", "EPISODIO",
    "TEMPORADA", "DESENHO", "ANIME", "SERIES",
    "FILMES", "MOVIES", "NOVELA", "DOCUMENTARY",
]

# Authorized domains for HTTP streams
AUTHORIZED_DOMAINS = ["nitidez.pro"]

# Cache
_channels_cache: List[Dict] = []
_cache_timestamp: float = 0
_cache_ttl: float = 600  # 10 minutes
_data_version: int = 1


def is_live_tv(group_title: str) -> bool:
    """Check if a channel group is live TV (not VOD/movies/series)."""
    upper = group_title.upper()
    return not any(kw in upper for kw in EXCLUDED_KEYWORDS)


def parse_m3u(content: str) -> List[Dict]:
    """Parse M3U+ content and return filtered list of channels."""
    channels = []
    lines = content.split("\n")
    current_extinf = None

    for line in lines:
        line = line.strip()

        if line.startswith("#EXTINF:"):
            current_extinf = line
        elif line and not line.startswith("#") and current_extinf:
            entry = _parse_extinf(current_extinf, line)
            if is_live_tv(entry.get("group_title", "")):
                channels.append(entry)
            current_extinf = None

    return channels


def _parse_extinf(extinf_line: str, url: str) -> Dict:
    """Extract metadata from #EXTINF line."""
    entry = {"stream_url": url.strip()}

    # Extract attributes
    attr_pattern = re.compile(r'(\S+)="([^"]*)"')
    for match in attr_pattern.finditer(extinf_line):
        key = match.group(1).lower().replace("-", "_")
        value = match.group(2)
        entry[key] = value

    # Extract name (after last comma)
    comma_idx = extinf_line.rfind(",")
    if comma_idx != -1:
        name = extinf_line[comma_idx + 1:].strip()
        entry["name"] = name
        if not entry.get("tvg_name"):
            entry["tvg_name"] = name

    # Normalize fields
    entry["group_title"] = entry.get("group_title", "Geral")
    entry["tvg_logo"] = entry.get("tvg_logo", "")
    entry["tvg_id"] = entry.get("tvg_id", "")
    entry["is_http"] = url.strip().startswith("http://")

    # Generate unique ID
    entry["id"] = entry.get("tvg_id") or str(hash(url))

    return entry


async def fetch_channels(force_refresh: bool = False) -> List[Dict]:
    """Fetch channels from M3U source with caching."""
    global _channels_cache, _cache_timestamp, _data_version

    now = time.time()

    # Return cache if valid
    if not force_refresh and _channels_cache and (now - _cache_timestamp) < _cache_ttl:
        logger.debug(f"Returning {len(_channels_cache)} channels from cache")
        return _channels_cache

    try:
        async with httpx.AsyncClient(timeout=30.0, follow_redirects=True) as client:
            # Try HTTPS first for security
            try:
                https_url = M3U_URL.replace("http://", "https://", 1)
                response = await client.get(
                    https_url,
                    headers={"User-Agent": "AngoMovie/1.2.0 Backend"}
                )
                content = response.text
            except Exception:
                # Fall back to HTTP
                response = await client.get(
                    M3U_URL,
                    headers={"User-Agent": "AngoMovie/1.2.0 Backend"}
                )
                content = response.text

            if response.status_code != 200:
                raise Exception(f"HTTP error: {response.status_code}")

            channels = parse_m3u(content)

            if channels:
                _channels_cache = channels
                _cache_timestamp = now
                _data_version += 1
                logger.info(f"Loaded {len(channels)} live TV channels")

            return channels

    except Exception as e:
        logger.error(f"Failed to fetch channels: {e}")
        if _channels_cache:
            logger.info("Returning stale cache due to fetch failure")
            return _channels_cache
        raise


def get_data_version() -> Dict:
    """Return current data version info."""
    return {
        "version": _data_version,
        "channel_count": len(_channels_cache),
        "cached_at": _cache_timestamp,
        "ttl_seconds": _cache_ttl,
    }


def group_channels_by_category(channels: List[Dict]) -> Dict[str, List[Dict]]:
    """Group channels by their group_title."""
    grouped = {}
    for channel in channels:
        key = channel.get("group_title", "GERAL").upper()
        if key not in grouped:
            grouped[key] = []
        grouped[key].append(channel)
    return grouped
