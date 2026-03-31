# 使用示例

> 如未启用扩展，请先执行 `CREATE EXTENSION IF NOT EXISTS ...;`（例如 `vector`/`pg_jieba`/`pgmq`）。

## pgvector：向量检索

```sql
CREATE TABLE documents (
  id SERIAL PRIMARY KEY,
  content TEXT,
  embedding vector(3)
);

INSERT INTO documents (content, embedding) VALUES
  ('Hello world', '[1,2,3]'),
  ('PostgreSQL rocks', '[4,5,6]'),
  ('Vector search', '[7,8,9]');

SELECT content, embedding <-> '[2,3,4]' AS distance
FROM documents
ORDER BY distance
LIMIT 3;
```

## pg_jieba：中文分词

```sql
CREATE TABLE articles (
  id SERIAL PRIMARY KEY,
  title TEXT,
  content TEXT
);

INSERT INTO articles (title, content) VALUES
  ('测试文章', '我爱北京天安门，天安门上太阳升'),
  ('技术文档', 'PostgreSQL是世界上最先进的开源数据库');

SELECT title, content
FROM articles
WHERE to_tsvector('jiebacfg', content) @@ to_tsquery('jiebacfg', '北京');
```

## pgmq：消息队列

```sql
SELECT pgmq.create('tasks');
SELECT pgmq.send('tasks', '{"task": "process_order", "order_id": 123}');
SELECT * FROM pgmq.read('tasks', 30, 1);
SELECT pgmq.archive('tasks', 1);
```

## JSONB + GIN：文档存储

```sql
CREATE TABLE products (
  id SERIAL PRIMARY KEY,
  data JSONB
);

CREATE INDEX idx_products_data ON products USING gin(data);

INSERT INTO products (data) VALUES
  ('{"name": "Laptop", "price": 999, "tags": ["electronics", "computers"]}'),
  ('{"name": "Mouse", "price": 29, "tags": ["electronics", "accessories"]}');

SELECT data->>'name' AS name, data->>'price' AS price
FROM products
WHERE data @> '{"tags": ["electronics"]}';
```
