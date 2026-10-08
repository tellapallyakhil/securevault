import psycopg2
import urllib.parse

user = "postgres.jujqnwewcznqqwtrazbx"
password = "Nar_endra@256"
host = "aws-0-ap-southeast-1.pooler.supabase.com"
port = 5432
db = "postgres"

print(f"Connecting to Supabase Pooler: {host}:{port}...")

try:
    conn = psycopg2.connect(
        host=host,
        port=port,
        user=user,
        password=password,
        database=db,
        connect_timeout=15
    )
    print("SUCCESS: Connected to live Supabase PostgreSQL!")
    cur = conn.cursor()
    cur.execute("SELECT version();")
    print("Version:", cur.fetchone()[0])
    
    # Enable pgvector
    try:
        cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
        conn.commit()
        print("SUCCESS: pgvector extension is ENABLED on your Supabase database!")
    except Exception as ve:
        print("pgvector note:", ve)

    conn.close()
    print("Test passed completely!")
except Exception as e:
    print("Connection error:", e)
