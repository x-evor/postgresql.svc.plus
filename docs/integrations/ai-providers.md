# AI 模型与向量能力

本项目不直接对接任何 AI 供应商，但通过 pgvector 提供向量存储与检索能力。

## 典型用法

- 使用 OpenAI/OSS 模型生成 embedding
- 将 embedding 写入 PostgreSQL
- 通过 pgvector 的距离函数进行相似度检索

## 注意

向量维度与索引策略应由业务侧决定，项目仅提供数据库与扩展能力。
