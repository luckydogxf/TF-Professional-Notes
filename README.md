# Terraform-professinal-Notes
Master Terraform in a few weeks.

* 太多关于terraform的书都是入门介绍，实际工作中发现，理论和实践还是有很大差距，这里分享一些terraform企业级的做法，同时也是工作笔记，如果你用过`terraform`(TF),应该比较容易理解和上手。

# Terraform 编码与模块化规范

## 1. 总体原则

Terraform 项目遵循：

> **根模块负责编排，子模块负责实现，模块之间通过 Input / Output 传递数据。**

禁止把业务资源实现全部堆在 environment 根目录。

推荐结构：

```text
terraform/
├── config/
│   ├── dev.yaml
│   ├── test.yaml
│   └── prod.yaml
│
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── providers.tf
│   │   ├── locals.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── prod/
│
└── modules/
    ├── networking/
    ├── security-groups/
    ├── elasticache-redis/
    ├── aurora-postgresql/
    ├── documentdb/
    ├── kafka/
    ├── iam/
    └── ...
```

---

# 2. `environments/*/main.tf` 只负责模块调用

这是最重要的一条。

例如：

```
module "networking" {
  source = "../../modules/networking"

  config = local.config
  tags   = module.common_tags.tags
}

```

根模块应该回答：

> “哪些模块需要被创建，以及它们之间的数据怎么连接？”

而不是回答：

> “Redis 里面具体创建什么资源？”

---

# 3. 根 `main.tf` 尽量不要直接创建 AWS Resource

不推荐：

```
resource "aws_cloudwatch_event_rule" "xxx" {
  ...
}

resource "aws_cloudwatch_event_target" "xxx" {
  ...
}
```

如果这部分属于一个完整功能，应拆成模块：

```text
modules/
└── codecommit-backup/
    ├── main.tf
    ├── variables.tf
    ├── locals.tf
    ├── outputs.tf
    └── providers.tf
```

然后根模块：

```
module "codecommit_backup" {
  source = "../../modules/codecommit-backup"

  config = local.config
  tags   = module.common_tags.tags
}
```

这样根目录始终保持“编排层”的角色。

---

# 4. 一个模块只负责一个明确领域

模块边界按照**业务/基础设施职责**划分。

例如：

```text
networking
    → VPC / Subnet / NAT / Endpoint

security-groups
    → Security Group / SG Rules

elasticache-redis
    → Redis
```

不要创建这种“大杂烩模块”：

```text
database/
    ├── redis
    ├── aurora
    ├── documentdb
    └── kafka
```

除非这些资源确实具有非常强的生命周期和配置耦合。

---

# 5. 模块之间必须通过 Output 传递数据

推荐：

```
module "networking" {
  ...
}

module "redis" {
  subnet_ids = module.networking.subnet_ids_map["private_ec2"]
}
```

不推荐：

```
subnet_ids = [
  "subnet-xxx",
  "subnet-yyy",
]
```

更不允许 module A 直接引用 module B 的内部 resource：

```
# ❌ 不允许
aws_subnet.xxx.id
```

应该：

```
# ✅
module.networking.subnet_ids_map["private_ec2"]
```

原则：

> **Module 只知道其他 Module 的 Output，不知道其他 Module 的内部 Resource。**

---

# 6. Output 要表达“接口”，而不是暴露内部实现

例如 networking：

```
output "vpc_ids" {
  value = {
    primary = aws_vpc.this["primary"].id
  }
}

output "subnet_ids_map" {
  value = {
    private_ec2 = ...
    private_eks = ...
    public      = ...
  }
}
```

上层使用：

```
module.networking.vpc_ids["primary"]
```

而不是要求调用方知道：

```
module.networking.aws_vpc.this["primary"].id
```

Output 就是 Module 的 API。

---

# 7. Input 只传模块真正需要的数据

例如 Redis：

```
variable "config" {
  type = any
}

variable "subnet_ids" {
  type = list(string)
}
```

不要为了方便把整个系统的所有东西传进去：

```
# ❌
variable "everything" {
  type = any
}
```

---

# 8. 配置和资源实现分离

环境差异尽量放在：

```text
config/dev.yaml
config/test.yaml
config/prod.yaml
```

例如：

```yaml
elasticache:
  redis:
    engine_version: "7.1"
    node_type: "cache.t4g.medium"
    subnet_type: "private_ec2"
    security_group_key: "redis"
```

Terraform module 负责把配置变成 AWS Resource：

```
engine_version = local.redis_cfg.engine_version
node_type      = local.redis_cfg.node_type
```

不要把 Dev/Prod 判断写进资源：

```
# ❌
node_type = var.environment == "prod"
  ? "cache.r7g.large"
  : "cache.t4g.medium"
```

应该：

```yaml
# dev.yaml
node_type: "cache.t4g.medium"

# prod.yaml
node_type: "cache.r7g.large"
```

---

# 9. `locals.tf` 只做数据整理

推荐：

```
locals {
  redis_cfg = var.config.elasticache.redis
  env       = lower(var.config.environment)
  app       = var.config.application
}
```

然后 `main.tf` 使用：

```
engine_version = local.redis_cfg.engine_version
```

不要把大量业务逻辑塞进 `locals.tf`。

`locals.tf` 的主要职责：

> **把 Input 整理成 Module 内部易于使用的变量。**

---

# 10. 所有模块都应该有标准文件结构

普通模块：

```text
modules/example/
├── main.tf
├── variables.tf
├── locals.tf
├── outputs.tf
└── versions.tf
```

职责：

```text
main.tf
    Resource 定义

variables.tf
    Module Input

locals.tf
    Module 内部数据整理

outputs.tf
    Module Output / API

versions.tf
    Terraform / Provider requirements
```

---


# 11. 模块不要偷偷创建其他模块负责的资源

例如 Redis Module：

```text
✅ 创建 Redis
✅ 创建 Redis subnet group
✅ 创建 Redis parameter group
```

但不应该：

```text
❌ 创建 VPC
❌ 创建 Subnet
❌ 创建 Redis Security Group
❌ 创建 IAM Role
```

因为这些都有自己的模块。

原则：

> **谁拥有资源生命周期，谁负责创建它。**

---

# 12. 不要跨模块复制逻辑

例如多个数据库都需要：

```
subnet_ids = module.networking.subnet_ids_map["private_ec2"]
```

这是正常的。

但是不要每个 module 都自己重新计算 subnet：

```
# ❌
data "aws_subnet" ...
```

如果 networking module 已经拥有这些信息，就直接使用 Output。

---

# 13. Tags 统一由公共模块提供

调用：

```
tags = module.common_tags.tags
```

资源内部：

```
tags = merge(
  var.tags,
  {
    Name = "${local.env}-${local.app}-redis"
  }
)
```

这样公共 Tag 和资源专属 Tag 分开。

---


# 14. 最核心的规范


> **Terraform 项目必须遵循模块化设计。Environment Root Module 负责资源编排，不负责具体 AWS Resource 实现。具体资源必须封装在独立 Module 中。Module 之间不得直接访问彼此内部 Resource，只能通过 Input / Output 进行数据传递。环境差异通过 `config/<environment>.yaml` 管理，Module 不应硬编码环境条件。每个 Module 应至少包含 `main.tf`、`variables.tf`、`outputs.tf`、`locals.tf` 和 `providers.tf`，并保持单一职责。


