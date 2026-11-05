#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LocalAI Portable - PostgreSQL Query & Export Tool
Uses psycopg2-binary to connect to PostgreSQL without external client drivers.
"""

import sys
import os
import argparse
from pathlib import Path
import psycopg2
import pandas as pd


def query_postgres(user, password, host, port, dbname, sql, output=None, limit=None):
    print(f"Connecting to PostgreSQL at {host}:{port}/{dbname} as {user}...")

    conn = psycopg2.connect(
        host=host,
        port=port,
        dbname=dbname,
        user=user,
        password=password
    )

    try:
        print("Connected successfully.")
        effective_sql = sql
        if limit and "where" not in sql.lower() and "limit" not in sql.lower():
            effective_sql = f"{sql.rstrip(';')} LIMIT {limit}"

        print(f"Executing query: {effective_sql}")
        df = pd.read_sql_query(effective_sql, conn)
        print(f"Fetched {len(df)} rows.")

        if output:
            out_path = Path(output)
            suffix = out_path.suffix.lower()
            if suffix == ".xlsx":
                df.to_excel(out_path, index=False, engine="openpyxl")
                print(f"Exported to Excel: {out_path}")
            else:
                df.to_csv(out_path, index=False, encoding="utf-8-sig")
                print(f"Exported to CSV: {out_path}")
        else:
            print("\n--- Query Results ---")
            print(df.head(20))
            if len(df) > 20:
                print(f"... and {len(df) - 20} more rows.")
    finally:
        conn.close()


def main():
    parser = argparse.ArgumentParser(description="PostgreSQL Query & Export Tool")
    parser.add_argument("--host", default=os.getenv("PGHOST", "127.0.0.1"), help="Postgres Host")
    parser.add_argument("--port", type=int, default=int(os.getenv("PGPORT", "5432")), help="Postgres Port (Default: 5432)")
    parser.add_argument("--dbname", default=os.getenv("PGDATABASE", "postgres"), help="Database Name")
    parser.add_argument("--user", default=os.getenv("PGUSER", "postgres"), help="Username")
    parser.add_argument("--password", default=os.getenv("PGPASSWORD"), help="Password")
    parser.add_argument("--sql", default=None, help="SQL Query string or path to .sql file")
    parser.add_argument("--output", default=None, help="Export output path (.csv or .xlsx)")
    parser.add_argument("--limit", type=int, default=None, help="Row limit for preview")

    args = parser.parse_args()

    if not args.password and not os.getenv("PGPASSWORD"):
        print("Error: Password must be provided via --password or PGPASSWORD environment variable.", file=sys.stderr)
        sys.exit(1)

    if not args.sql:
        print("Error: SQL query must be provided via --sql (e.g. --sql 'SELECT * FROM users' or --sql query.sql)", file=sys.stderr)
        sys.exit(1)

    sql_str = args.sql
    if Path(sql_str).is_file():
        sql_str = Path(sql_str).read_text(encoding="utf-8")

    query_postgres(
        user=args.user,
        password=args.password,
        host=args.host,
        port=args.port,
        dbname=args.dbname,
        sql=sql_str,
        output=args.output,
        limit=args.limit
    )


if __name__ == "__main__":
    main()
