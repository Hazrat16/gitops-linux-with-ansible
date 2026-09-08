"""Homelab platform API — notes service with a /health endpoint."""

from __future__ import annotations

import os
import socket
from datetime import datetime, timezone
from typing import Generator

from fastapi import Depends, FastAPI, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel, Field
from sqlalchemy import DateTime, Integer, String, create_engine, select, text
from sqlalchemy.orm import DeclarativeBase, Mapped, Session, mapped_column, sessionmaker

DATABASE_URL = os.environ.get(
    "DATABASE_URL",
    "postgresql+psycopg2://homelab:homelab@127.0.0.1:5432/homelab",
)

engine = create_engine(DATABASE_URL, pool_pre_ping=True, future=True)
SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False, future=True)


class Base(DeclarativeBase):
    pass


class Note(Base):
    __tablename__ = "notes"

    id: Mapped[int] = mapped_column(Integer, primary_key=True)
    title: Mapped[str] = mapped_column(String(200), nullable=False)
    body: Mapped[str] = mapped_column(String(4000), default="")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )


class NoteIn(BaseModel):
    title: str = Field(min_length=1, max_length=200)
    body: str = Field(default="", max_length=4000)


class NoteOut(BaseModel):
    id: int
    title: str
    body: str
    created_at: datetime

    model_config = {"from_attributes": True}


app = FastAPI(
    title="Homelab Platform API",
    version="1.0.0",
    description="Small production-like notes API used by the GitOps Linux platform.",
)


def get_db() -> Generator[Session, None, None]:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


@app.on_event("startup")
def on_startup() -> None:
    Base.metadata.create_all(bind=engine)


@app.get("/health")
def health() -> JSONResponse:
    db_ok = False
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
        db_ok = True
    except Exception:
        db_ok = False

    payload = {
        "status": "ok" if db_ok else "degraded",
        "service": os.environ.get("APP_NAME", "homelab-api"),
        "hostname": socket.gethostname(),
        "database": "up" if db_ok else "down",
    }
    return JSONResponse(status_code=200 if db_ok else 503, content=payload)


@app.get("/")
def root() -> dict[str, str]:
    return {
        "service": "homelab-api",
        "docs": "/docs",
        "health": "/health",
        "notes": "/api/notes",
    }


@app.get("/api/info")
def info() -> dict[str, str]:
    return {
        "hostname": socket.gethostname(),
        "version": app.version,
    }


@app.get("/api/notes", response_model=list[NoteOut])
def list_notes(db: Session = Depends(get_db)) -> list[Note]:
    return list(db.scalars(select(Note).order_by(Note.id.desc())).all())


@app.post("/api/notes", response_model=NoteOut, status_code=201)
def create_note(payload: NoteIn, db: Session = Depends(get_db)) -> Note:
    note = Note(title=payload.title, body=payload.body)
    db.add(note)
    db.commit()
    db.refresh(note)
    return note


@app.get("/api/notes/{note_id}", response_model=NoteOut)
def get_note(note_id: int, db: Session = Depends(get_db)) -> Note:
    note = db.get(Note, note_id)
    if note is None:
        raise HTTPException(status_code=404, detail="note not found")
    return note
