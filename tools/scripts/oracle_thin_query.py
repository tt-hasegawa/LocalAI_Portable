#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
LocalAI Portable - Oracle Database Query & Export Tool (Thin Mode)
Key Feature:
  Uses python-oracledb in THIN MODE.
  NO Oracle Instant Client or Oracle Client installation required!
  Direct TCP network connection to Oracle DB 12.1+.
"""

import sys
import os
import argparse
from pathlib import Path
import oracledb
import pandas as pd


def query_oracle(user, password, host, port, service_name, sql, output=None, limit=None):
    dsn = f"{host}:{port}/{service_name}"
    print(f"Connecting to Oracle (Thin Mode) at {dsn} as {user}...")

    # oracledb defaults to thin mode unless init_oracle_client is called.
    with oracledb.connect(user=user, password=password, dsn=dsn) as connection:
        print("Connected successfully.")
        effective_sql = sql
        if limit and "where" not in sql.lower() and "fetch" not in sql.lower():
            effective_sql = f"{sql.rstrip(';')} FETCH FIRST {limit} ROWS ONLY"

        print(f"Executing query: {effective_sql}")
        df = pd.read_sql_query(effective_sql, connection)
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


def main():
    parser = argparse.ArgumentParser(description="Oracle Query & Export Tool (Pure Python Thin Mode)")
    parser.add_argument("--host", default=os.getenv("ORACLE_HOST", "127.0.0.1"), help="Oracle DB Host")
    parser.add_argument("--port", type=int, default=int(os.getenv("ORACLE_PORT", "1521")), help="Oracle DB Port (Default: 1521)")
    parser.add_argument("--service", default=os.getenv("ORACLE_SERVICE", "ORCLPDB1"), help="Service Name / SID")
    parser.add_argument("--user", default=os.getenv("ORACLE_USER"), help="Username")
    parser.add_argument("--password", default=os.getenv("ORACLE_PASSWORD"), help="Password")
    parser.add_argument("--sql", default=None, help="SQL Query string or path to .sql file")
    parser.add_argument("--output", default=None, help="Export output path (.csv or .xlsx)")
    parser.add_argument("--limit", type=int, default=None, help="Row limit for testing")

    args = parser.parse_args()

    if not args.user or not args.password:
        print("Error: Username and Password must be provided via arguments or ORACLE_USER / ORACLE_PASSWORD environment variables.", file=sys.stderr)
        sys.exit(1)

    if not args.sql:
        print("Error: SQL query must be provided via --sql (e.g. --sql 'SELECT * FROM tab' or --sql myquery.sql)", file=sys.stderr)
        sys.exit(1)

    sql_str = args.sql
    if Path(sql_str).is_file():
        sql_str = Path(sql_str).read_text(encoding="utf-8")

    query_oracle(
        user=args.user,
        password=args.password,
        host=args.host,
        port=args.port,
        service_name=args.service,
        sql=sql_str,
        output=args.output,
        limit=args.limit
    )


if __name__ == "__main__":
    main()
