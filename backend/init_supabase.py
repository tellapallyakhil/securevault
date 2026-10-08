import asyncio
from app.models.models import init_db, engine
from sqlalchemy import text

async def main():
    print("Connecting to Supabase PostgreSQL and creating tables...")
    await init_db()
    async with engine.begin() as conn:
        await conn.execute(text("ALTER TABLE documents ADD COLUMN IF NOT EXISTS content_hash VARCHAR(64);"))
    print("SUCCESS: Tables 'users', 'documents', 'audit_logs', 'anomaly_alerts', and 'share_links' are updated on live Supabase DB!")

if __name__ == "__main__":
    asyncio.run(main())
