"""FastAPI voice runtime: telephony /answer webhook + /agent WebSocket (port 7860)."""

from __future__ import annotations

import os
import sys
from pathlib import Path

_ROOT_DIR = Path(__file__).resolve().parent.parent.parent
if str(_ROOT_DIR) not in sys.path:
    sys.path.insert(0, str(_ROOT_DIR))

try:
    import nltk
    _NLTK_DIR = Path(__file__).resolve().parent / "nltk_data"
    if _NLTK_DIR.exists():
        nltk.data.path.insert(0, str(_NLTK_DIR))
except Exception:
    pass

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# pyrefly: ignore [missing-import]
from apps.runtime.routes import agent, health, telephony

app = FastAPI(
    title="Voicera Runtime",
    description="Telephony answer webhook + Pipecat WebSocket pipeline",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(telephony.router)
app.include_router(agent.router)


def main() -> None:
    import uvicorn

    host = os.getenv("RUNTIME_HOST", "0.0.0.0")
    port = int(os.getenv("RUNTIME_PORT", "7860"))
    uvicorn.run(
        "apps.runtime.app:app",
        host=host,
        port=port,
        reload=False,
    )


if __name__ == "__main__":
    main()
