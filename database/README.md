# Personal Finance Manager - Database Structure

This directory contains all database-related scripts, organized for **clarity, modularity, and scalability**.

---

## Folder Structure

- `database/`  
  Root database folder. Contains the initialization entrypoint.

- `database/init.sql`  
  Master script that orchestrates the full database setup.

- `database/schema/`  
  Contains all schema definitions (tables, types, triggers, etc.).

  Current modules:

  - `functions.sql` → Shared database functions (e.g., timestamp triggers, JSON schema helpers)
  - `currencies.sql` → Currencies and exchange rates
  - `users.sql` → Users, sessions, and user settings
  - `accounts.sql` → Financial accounts, account types, and flexible metadata system

- `database/seeds/`  
  *(future)* Initial data population (e.g., default currencies, account types)

- `database/migrations/`  
  *(future)* Versioned schema evolution scripts

---

## Initialization Flow

The database is initialized through a **single entrypoint**:

```sql
\i /docker-entrypoint-initdb.d/schema/functions.sql
\i /docker-entrypoint-initdb.d/schema/currencies.sql
\i /docker-entrypoint-initdb.d/schema/users.sql
\i /docker-entrypoint-initdb.d/schema/accounts.sql
...
```

---

## Design Principles

**Modular schema**
  
  Each domain is isolated in its own file

---

**Single source of truth**
  
  `init.sql` controls execution order

---

**Database responsibility is minimal but strict**
  
  The database is responsible for:

  * Enforcing data integrity (constraints, foreign keys)
  * Handling timestamps and system-level automation
  * Ensuring structural consistency of stored data

  The database intentionally avoids:

  * Business logic
  * Financial calculations
  * Application workflows

---

**Backend-driven normalization**

  All business rules and interpretations are handled in the backend:

  * Financial operations
  * Validation of dynamic metadata
  * Account behavior logic
  * Data transformation and formatting

---

**Controlled flexibility (JSONB-based design)**
  
  The system uses a hybrid model:

  * Structured columns → critical financial data (balances, relations)
  * JSONB metadata → flexible, non-critical configuration

  Each account type defines a metadata contract used by the backend to interpret and validate account behavior.

  This allows:

  * Flexible account definitions
  * No schema migrations for new attributes
  * Extensible financial modeling

---

**Performance-aware design**
  * Indexes are aligned with query patterns, not just schema structure
  * JSONB fields use GIN indexes for flexible querying
  * Generated fields are used for frequently accessed attributes
  * User-scoped indexes optimize multi-tenant queries

---

**Extensible structure**
  
  New domains (e.g., transactions, investments, loans) can be added without modifying existing modules.
  
  The system evolves through:

  * New schema modules
  * Backend-driven behavior extensions
  * JSON-based metadata evolution

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

* All timestamps use TIMESTAMPTZ (UTC-based)
* Row Level Security (RLS) is enabled where applicable (policies defined in backend)
* Constraints are used strictly for data integrity, not business logic
* The accounts module introduces a flexible behavior model via:
    * account_types.metadata_definition
    * accounts.metadata

---
