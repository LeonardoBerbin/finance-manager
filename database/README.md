# Personal Finance Manager - Database Structure

This folder contains all database-related scripts for the backend, organized in a **modular and maintainable way**.

## Folder Structure

- `database/` → Contains `init.sql` and this README.
- `database/schema/` → SQL scripts for table creation (e.g., `010_currencies.sql`, `020_users.sql`, etc.).
- `database/seeds/` → SQL scripts for initial data insertion.
- `database/init.sql` → Master file that imports all schema scripts in the correct order.

## Execution Order

The master `init.sql` ensures that tables are created in the correct sequence to respect dependencies:

```sql
\i schema/010_currencies.sql
\i schema/020_users.sql
...