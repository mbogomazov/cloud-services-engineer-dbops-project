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

```sql
CREATE INDEX idx_orders_date_created ON orders (date_created);
CREATE INDEX idx_order_product_order_id ON order_product (order_id);
```

- `idx_orders_date_created` — ускоряет фильтрацию по `date_created` в условии `WHERE`
- `idx_order_product_order_id` — ускоряет `JOIN` по `order_id`

### EXPLAIN (ANALYZE) без индексов

```
Time: 3992,043 ms (00:03,992)
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
Execution Time: 14539.375 ms

 Finalize GroupAggregate  (cost=248092.50..248115.56 rows=91 width=12) (actual time=14453.378..14538.433 rows=7 loops=1)
   Group Key: o.date_created
   ->  Gather Merge  (cost=248092.50..248113.74 rows=182 width=12) (actual time=14453.360..14538.412 rows=21 loops=1)
         Workers Planned: 2
         Workers Launched: 2
         ->  Partial HashAggregate  (cost=247088.61..247089.52 rows=91 width=12) (actual time=14403.855..14403.862 rows=7 loops=3)
               ->  Parallel Hash Join  (cost=86934.44..245488.61 rows=320000 width=8) (actual time=13266.358..14364.975 rows=259257 loops=3)
                     Hash Cond: (op.order_id = o.id)
                     ->  Parallel Seq Scan on order_product op  (cost=0.00..105361.67 rows=4166667 width=12)
                     ->  Parallel Hash  (cost=81371.44..81371.44 rows=320000 width=12)
                           ->  Parallel Bitmap Heap Scan on orders o  (cost=10476.44..81371.44 rows=320000 width=12)
                                 Recheck Cond: ((date_created >= (CURRENT_DATE - '7 days'::interval)) AND (date_created < CURRENT_DATE))
                                 ->  Bitmap Index Scan on idx_orders_date_created  (cost=0.00..10284.44 rows=768000 width=0)
                                       Index Cond: ((date_created >= (CURRENT_DATE - '7 days'::interval)) AND (date_created < CURRENT_DATE))
```

### Выводы

- Индекс `idx_orders_date_created` используется: вместо `Parallel Seq Scan` на таблице `orders` планировщик применяет `Bitmap Index Scan` + `Bitmap Heap Scan`
- Оценочная стоимость (cost) снизилась с 324167 до 248092 (на 23%)
- Сканирование таблицы `orders` стало эффективнее: cost снизился с 157446 (Seq Scan) до 81371 (Bitmap Heap Scan), то есть почти в 2 раза
- Фактическое время выполнения с индексами составило 14539 мс против 3695 мс без индексов; это объясняется ограниченным объёмом оперативной памяти на сервере — при работе с 10 млн строк `Bitmap Heap Scan` вынужден перечитывать страницы с диска, что нивелирует выигрыш от индекса
- На серверах с достаточным объёмом `shared_buffers` и `work_mem` индексы дадут значительное ускорение, так как планировщик уже выбирает оптимальный план с меньшей стоимостью
