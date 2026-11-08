"""Artifact search endpoint. Fixed form used on main for DSAI-07 CI."""

from fastapi import FastAPI, Query
import os
import sqlite3

app = FastAPI(title="artifact-search")

ARTIFACT_API_KEY = os.environ["ARTIFACT_API_KEY"]


@app.get("/artifacts/search")
def search_artifacts(q: str = Query(..., min_length=1)) -> dict:
    """Search build artifacts by name. Returns matching rows from a local sqlite DB."""
    conn = sqlite3.connect("artifacts.db")
    cur = conn.cursor()
    cur.execute(
        "SELECT id, name, path FROM artifacts WHERE name LIKE ?",
        (f"%{q}%",),
    )
    rows = cur.fetchall()
    conn.close()
    return {
        "key_prefix": ARTIFACT_API_KEY[:8],
        "results": [{"id": r[0], "name": r[1], "path": r[2]} for r in rows],
    }
