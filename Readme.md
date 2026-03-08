# dbops-project
Исходный репозиторий для выполнения проекта дисциплины "DBOps"

## Шаг 1. Создание базы данных store

```sql
CREATE DATABASE store;
```

## Шаг 2. Создание пользователя и выдача прав

```sql
CREATE USER store_user WITH PASSWORD 'store_password';
GRANT ALL PRIVILEGES ON DATABASE store TO store_user;
\c store
GRANT ALL ON SCHEMA public TO store_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO store_user;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO store_user;
```
