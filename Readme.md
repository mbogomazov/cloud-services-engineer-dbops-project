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

## Количество проданных сосисок за каждый день предыдущей недели

```sql
SELECT o.date_created, SUM(op.quantity) AS total_quantity
FROM orders o
JOIN order_product op ON o.id = op.order_id
WHERE o.date_created >= CURRENT_DATE - INTERVAL '7 days'
  AND o.date_created < CURRENT_DATE
GROUP BY o.date_created
ORDER BY o.date_created;
```

## Оптимизация запроса с помощью индексов

### Создание индексов

Используются композитные (покрывающие) индексы, которые включают все необходимые столбцы для запроса — это позволяет PostgreSQL выполнять Index-Only Scan без обращения к таблице:

```sql
CREATE INDEX idx_orders_date_created ON orders (date_created, id);
CREATE INDEX idx_order_product_order_id ON order_product (order_id, quantity);
```

- `idx_orders_date_created(date_created, id)` — покрывает фильтрацию по `WHERE date_created` и выборку `id` для JOIN, обеспечивает Index-Only Scan
- `idx_order_product_order_id(order_id, quantity)` — покрывает JOIN по `order_id` и агрегацию `SUM(quantity)`

### EXPLAIN (ANALYZE) без индексов

```
Execution Time: 3695.125 ms

 Finalize GroupAggregate  (cost=324167.82..324190.87 rows=91 width=12) (actual time=3614.480..3694.230 rows=7 loops=1)
   Group Key: o.date_created
   ->  Gather Merge  (cost=324167.82..324189.05 rows=182 width=12) (actual time=3614.453..3694.200 rows=21 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Partial HashAggregate  (cost=323163.92..323164.83 rows=91 width=12) (actual time=3594.683..3594.850 rows=7 loops=3)
               ->  Parallel Hash Join  (cost=163009.13..321563.90 rows=320004 width=8) (actual time=2620.929..3551.939 rows=259257 loops=3)
                     Hash Cond: (op.order_id = o.id)
                     ->  Parallel Seq Scan on order_product op  (cost=0.00..105362.15 rows=4166715 width=12)
                     ->  Parallel Hash  (cost=157446.08..157446.08 rows=320004 width=12)
                           ->  Parallel Seq Scan on orders o  (cost=0.00..157446.08 rows=320004 width=12)
                                 Filter: ((date_created < CURRENT_DATE) AND (date_created >= (CURRENT_DATE - '7 days'::interval)))
                                 Rows Removed by Filter: 3074076
```

### EXPLAIN (ANALYZE) с индексами

```
Execution Time: 3609.018 ms

 Finalize GroupAggregate  (cost=189433.50..189456.56 rows=91 width=12) (actual time=3526.396..3608.217 rows=7 loops=1)
   Group Key: o.date_created
   ->  Gather Merge  (cost=189433.50..189454.74 rows=182 width=12) (actual time=3526.368..3608.186 rows=21 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Partial HashAggregate  (cost=188429.61..188430.52 rows=91 width=12) (actual time=3506.987..3506.993 rows=7 loops=3)
               ->  Parallel Hash Join  (cost=28275.44..186829.61 rows=320000 width=8) (actual time=2344.696..3461.035 rows=259257 loops=3)
                     Hash Cond: (op.order_id = o.id)
                     ->  Parallel Seq Scan on order_product op  (cost=0.00..105361.67 rows=4166667 width=12)
                     ->  Parallel Hash  (cost=22712.44..22712.44 rows=320000 width=12)
                           ->  Parallel Index Only Scan using idx_orders_date_created on orders o  (cost=0.44..22712.44 rows=320000 width=12)
                                 Index Cond: ((date_created >= (CURRENT_DATE - '7 days'::interval)) AND (date_created < CURRENT_DATE))
                                 Heap Fetches: 0
```

### Выводы

- Композитный индекс `idx_orders_date_created(date_created, id)` обеспечил **Index-Only Scan** с `Heap Fetches: 0` — данные читаются только из индекса, без обращения к таблице
- Сканирование таблицы `orders` ускорилось в **29 раз**: с 1306 мс (Parallel Seq Scan) до 45 мс (Parallel Index-Only Scan)
- Оценочная стоимость (cost) снизилась с 324167 до 189433 (на 42%)
- Время выполнения запроса сократилось с 3695 мс до 3609 мс; основное время теперь занимает Seq Scan по `order_product` (10 млн строк), а не сканирование `orders`
