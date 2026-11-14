# Library Management System (Topic 22) - Queries

Course: IT079IU - Principles of Database Management, Semester 1, 2026-2027

This repository holds the five SQL queries that the Topic 22 database must answer.
The tables and sample data come from `database.sql` in the main project repository.

## Environment

- DBMS: MySQL 8.4.11
- Tool: DBeaver 26.2.
- Database: `library_management_db`

## Repository structure

```
Library-Management-System/
├── README.md
└── queries/
    ├── Topic22_Library_Queries_v1_original.sql
    └── Topic22_Library_Queries_v2_collation_fix.sql
```

## The two versions

| File | Description |
|------|-------------|
| `Topic22_Library_Queries_v1_original.sql` | First version of the five queries. |
| `Topic22_Library_Queries_v2_collation_fix.sql` | Same five queries, with one extra line at the top: `SET NAMES utf8mb4 COLLATE utf8mb4_unicode_ci;` |

**Why version 2 exists.** The database is created with `utf8mb4_unicode_ci`, but a MySQL 8
connection defaults to `utf8mb4_0900_ai_ci`. The queries use user variables
(`@title`, `@member_id`, `@author_name`), which take the connection collation. Comparing such
a variable with a column can then fail with
`Error 1267: Illegal mix of collations ... for operation '='`.
Version 2 makes the connection collation match the database, so the error does not occur.
The query logic is identical in both files.

## How to run

1. Run `database.sql` from the main project repository. It drops and recreates `library_management_db` and fills it with sample data.
2. Open one of the files in `queries/` and run the **whole script in one session** (Execute script).
   The `SET NAMES` line in version 2 only applies to the session it is run in.

## The five queries

| # | Question | Technique |
|---|----------|-----------|
| Q1 | The copies of a title currently available | Multi-table join |
| Q2 | The loans of one member that are overdue today | Join with view `Loan_Detail_Fine` |
| Q3 | The ten most borrowed titles this year | `GROUP BY`, `ORDER BY`, `LIMIT` |
| Q4 | Members who have borrowed every title by a given author | `NOT EXISTS` (relational division) |
| Q5 | Total fines outstanding per member category | Join with view, `GROUP BY` |

Q2 and Q5 use `CURRENT_DATE`, so their results change with the day the script is run.

Topic: 22 - Library Management# Library-Management-System
SQL queries for Topic 22 (Library Management System)
