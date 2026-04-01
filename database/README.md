# Personal Finance Manager - Database Structure

This directory contains all database-related scripts, organized for **clarity, modularity, and scalability**.

---

## Folder Structure

* `database/`
  Root database folder. Contains the initialization entrypoint.

* `database/init.sql`
  Master script that orchestrates the full database setup.

* `database/schema/`
  Contains all schema definitions (tables, types, triggers, etc.).

  Current modules:

  * `functions.sql` → Shared database functions (e.g., timestamp triggers)
  * `currencies.sql` → Currencies and exchange rates
  * `users.sql` → Users, sessions, and user settings

* `database/seeds/`
  ...

* `database/migrations`
  ...

---

## Initialization Flow

The database is initialized through a **single entrypoint**:

```sql
\i /docker-entrypoint-initdb.d/schema/functions.sql
\i /docker-entrypoint-initdb.d/schema/currencies.sql
\i /docker-entrypoint-initdb.d/schema/users.sql
...
```

---

## Design Principles

* **Modular schema**
  Each domain is isolated in its own file

* **Single source of truth**
  `init.sql` controls execution order

* **Database responsibility is minimal**

  * Enforces integrity (constraints, relations)
  * Handles timestamps and critical rules
  * Avoids business logic duplication

* **Backend-driven normalization**
  Formatting (e.g., casing, trimming) is handled in the application layer

* **Extensible structure**
  New modules can be added without modifying existing ones

---

## Adding New Tables

1. Create a new file in `schema/`
   Example:

   ```
   schema/transactions.sql
   ```

2. Define tables, constraints, indexes, and triggers

3. Register it in `init.sql` in the correct order:

   ```sql
    \i /docker-entrypoint-initdb.d/schema/transactions.sql
   ```

---

## Notes

* All timestamps use `TIMESTAMPTZ` (UTC-based)
* Row Level Security (RLS) is enabled where applicable
* Constraints are used for **data integrity**, not business logic

---
