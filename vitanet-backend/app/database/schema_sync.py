# app/database/schema_sync.py
"""Additive schema upkeep for tables that predate Alembic tracking.

The portal and staff tables were first created with `create_all`, which never
adds columns to an existing table. `sync_schema` creates any missing table and
adds any missing nullable/defaulted column, so an existing database keeps
working after an upgrade. It never drops or changes data. Used at startup and
by the Alembic revision for the portal rebuild."""
from sqlalchemy import inspect, text
from sqlalchemy.engine import Connection

from app.database.base import Base

# Columns added after their table first shipped: table -> {column: SQL type + default}
ADDED_COLUMNS = {
    "portal_referrals": {
        "source": "VARCHAR(16) NOT NULL DEFAULT 'app'",
        "arrived_at": "TIMESTAMP NULL",
        "brief": "JSON NULL",
    },
    "portal_cases": {
        "arrived_at": "TIMESTAMP NULL",
        "outcome": "VARCHAR(20) NULL",
    },
}

LEGACY_TABLES = ("hospital_patient_records", "hospital_cases", "hospital_wards",
                 "hospital_equipment", "hospital_staff")


def sync_schema(conn: Connection, drop_legacy: bool = False) -> None:
    import app.models  # noqa: F401  (registers every model on Base)

    Base.metadata.create_all(bind=conn, checkfirst=True)
    insp = inspect(conn)
    for table, cols in ADDED_COLUMNS.items():
        if not insp.has_table(table):
            continue
        have = {c["name"] for c in insp.get_columns(table)}
        for name, ddl in cols.items():
            if name not in have:
                conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {name} {ddl}"))
    if drop_legacy:
        for table in LEGACY_TABLES:
            if insp.has_table(table):
                conn.execute(text(f"DROP TABLE {table}"))
