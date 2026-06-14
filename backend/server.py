"""
server.py - FastAPI Backend for AngoMovie IPTV
Serves channel data from M3U source with caching and filtering
"""
import logging
from contextlib import asynccontextmanager
from typing import List, Optional

from fastapi import FastAPI, HTTPException, Query
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from channels import fetch_channels, get_data_version, group_channels_by_category

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Pre-load channels on startup."""
    logger.info("AngoMovie IPTV Backend starting...")
    try:
        channels = await fetch_channels()
        logger.info(f"Pre-loaded {len(channels)} channels")
    except Exception as e:
        logger.warning(f"Pre-load failed: {e}. Will retry on first request.")
    yield
    logger.info("AngoMovie IPTV Backend shutting down...")


app = FastAPI(
    title="AngoMovie IPTV API",
    description="Backend API for AngoMovie IPTV app",
    version="1.2.0",
    lifespan=lifespan,
    docs_url=None,  # Disable docs in production
    redoc_url=None,
)

# CORS - restrict to app only
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict to app domain in production
    allow_credentials=False,
    allow_methods=["GET"],
    allow_headers=["*"],
)


@app.get("/api/channels", response_class=JSONResponse)
async def get_channels(
    category: Optional[str] = Query(None, description="Filter by category"),
    refresh: bool = Query(False, description="Force refresh from source"),
    limit: int = Query(0, description="Limit results (0 = all)"),
):
    """
    Get all live TV channels, optionally filtered by category.
    Channels are cached for 10 minutes and filtered to exclude VOD/movies.
    """
    try:
        channels = await fetch_channels(force_refresh=refresh)

        if category:
            channels = [
                ch for ch in channels
                if ch.get("group_title", "").upper() == category.upper()
            ]

        if limit > 0:
            channels = channels[:limit]

        # Format for Flutter app
        result = []
        for ch in channels:
            result.append({
                "id": ch.get("id", ""),
                "name": ch.get("tvg_name") or ch.get("name", ""),
                "stream_url": ch.get("stream_url", ""),
                "logo_url": ch.get("tvg_logo", ""),
                "group_title": ch.get("group_title", "Geral"),
                "tvg_id": ch.get("tvg_id", ""),
                "is_http": ch.get("is_http", False),
            })

        return result

    except Exception as e:
        logger.error(f"Error getting channels: {e}")
        raise HTTPException(status_code=503, detail="Serviço temporariamente indisponível")


@app.get("/api/categories", response_class=JSONResponse)
async def get_categories():
    """Get all available channel categories."""
    try:
        channels = await fetch_channels()
        grouped = group_channels_by_category(channels)
        categories = [
            {
                "name": cat,
                "count": len(ch_list)
            }
            for cat, ch_list in sorted(grouped.items())
        ]
        return categories
    except Exception as e:
        logger.error(f"Error getting categories: {e}")
        raise HTTPException(status_code=503, detail="Erro ao carregar categorias")


@app.get("/api/data-version", response_class=JSONResponse)
async def get_data_version_endpoint():
    """
    Returns the current version of the channel data.
    App uses this to determine if local cache needs updating.
    """
    return get_data_version()


@app.get("/api/health")
async def health_check():
    """Health check endpoint."""
    version_info = get_data_version()
    return {
        "status": "ok",
        "version": "1.2.0",
        "channels_cached": version_info["channel_count"],
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "server:app",
        host="0.0.0.0",
        port=8000,
        reload=False,
        log_level="info",
    )
