# Terraform 状态漂移（State Drift）处理

小团队在业务初期为了赶进度，通常直接在云控制台（如 AWS Console）或通过 CLI 手动拉起基础设施。随着团队扩张和规范化需求，引入 Terraform 进行 IaC（基础设施即代码）管理时，必然会面临**云端实际状态与本地代码不一致**的问题。

核心原则：**绝对不能推倒重来（避免业务中断），而是通过状态文件（`tfstate`）对齐，逐步将资源接管。**

---

## 常见不一致场景与处理方案

### 0. 存量资源太多，不想纯手工写代码
如果早期手动创建的资源有几十上百个，一个个手写 `.tf` 再导入效率太低：
* **批量导出工具**：可以使用开源工具如 [Terraformer](https://github.com) 或 [Former2](https://former2.com)（AWS 专用），扫描现有云环境并反向生成 `.tf` 文件和 `tfstate`。
* **划清边界**：不要试图一次性把所有历史遗留资源全塞进 Terraform。优先纳管核心资源（VPC、RDS、S3、核心 EC2/EKS）；即将下线的老旧业务维持现状，等自然淘汰即可。

### 1. 云端有资源，但 TF 代码里没有（幽灵资源）
早期手动或通过脚本创建的资源，需要纳入 Terraform 统一管理。

* **方式 A：声明式导入（Terraform 1.5+ 推荐）**
  在代码中直接写 `import` 块，配合命令自动生成资源配置代码，省去手写大量参数的麻烦：
  ```hcl
  import {
    to = aws_instance.web_server
    id = "i-0123456789abcdef0"
  }
  ```
  执行生成命令，核对无误后 `apply` 即可：
  ```bash
  terraform plan -generate-config-out=generated.tf
  terraform apply
  ```

* **方式 B：命令行导入（传统方式）**
  先在 `.tf` 文件中手动写出对应的 `resource` 代码块（注意与云端配置保持一致），再执行绑定：
  ```bash
  terraform import aws_instance.web_server i-0123456789abcdef0
  ```

### 2. TF 代码创建了资源，但云端被手动删除了
有人直接在控制台把资源删掉了，导致 `tfstate` 里还有记录，但云端已不存在。

* **确认业务不再需要该资源**：
  从状态文件中移除记录，**同时删除 `.tf` 文件中的对应代码块**（否则下次 `apply` 又会重新创建）：
  ```bash
  terraform state rm aws_instance.web_server
  ```
* **属于线上误删，需要恢复**：
  无需操作 `state`，直接运行 `terraform apply`，Terraform 会根据代码自动重建该资源。

### 3. 资源在云端被手动修改了配置或名字
线下有人直接登控制台改资源名称，导致下次跑 `terraform plan` 出现差异。

> **⚠️ 警告**：操作前务必看清 `plan` 的输出标记。如果是 `~`（update in-place）通常安全；如果出现 `-/+`（forces replacement，先销毁再重建），**绝不能直接 `apply`**，否则会导致线上服务中断。

* **修改的是普通属性（如 Tag 标签、安全组规则）**：
  * **想保留线上修改**：手动修改本地 `.tf` 代码，使其与云端最新配置对齐，跑 `plan` 确认显示 `No changes` 即可。
  * **想回滚线上修改**：直接执行 `terraform apply`，用代码配置强制覆盖云端。
* **修改的是不可变主名称（如 S3 Bucket 名称或触发重建的标识）**：
  * 此时不能用 `state mv`（它只管代码层面的重命名）。
  * **安全做法**：先用 `terraform state rm <原资源地址>` 解除绑定 -> 修改 `.tf` 代码为新名字 -> 用 `terraform import <新资源地址> <云端新ID>` 重新导入绑定。

### 4. 团队重构代码，修改了 `.tf` 里的资源变量名，但是建议一开始就做好规范，后期move看起来太别扭了。

云端资源本身没动，只是为了代码规范，把 `aws_s3_bucket.test` 改成了 `aws_s3_bucket.prod_logs`。如果直接改名，Terraform 会认为你要“删掉旧的、建个新的”。

* **推荐做法（Terraform 1.1+）**：在代码中使用 `moved` 块声明迁移，支持 Git Code Review 且不易出错：
  ```hcl
  moved {
    from = aws_s3_bucket.test
    to   = aws_s3_bucket.prod_logs
  }
  ```
* **命令行方式**：
  ```bash
  terraform state mv aws_s3_bucket.test aws_s3_bucket.prod_logs
  ```

---

## 团队落地避坑建议

1. **改 State 前先开版本控制**：在执行任何 `state rm`、`state mv` 或 `import` 前，务必确保远程后端（如 S3 Bucket）开启了 **Versioning（版本控制）**，万一操作失误改坏了状态文件，随时可以回滚。
2. **收紧控制台写权限**：核心基础设施纳管完成后，建议在 IAM 中将日常开发/运维账号的控制台权限收紧为 `ReadOnlyAccess`。所有线上变更强制走 `Git PR -> CI 跑 Plan -> 审批后 Apply` 的流程，从根源上杜绝“手痒改配置”。
3. **配置定时漂移检测**：在 CI/CD（如 GitHub Actions）中配置每天定时跑一次 `terraform plan -detailed-exitcode`，一旦返回状态码 `2`（代表存在未同步的变更），直接向运维群发送告警。
