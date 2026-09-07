# backend.tf —— 放在 main.tf 同目录,让 state 搬进 S3(段④用)
# terraform 允许多个 terraform {} 块:main.tf 里已有 required_providers,这里的 backend 块会自动合并
terraform {
  backend "s3" {
    bucket         = "lab-tfstate-544340288157" # 桶名全局唯一,用账号 ID 兜底
    key            = "step13/terraform.tfstate" # state 对象在桶里的路径
    region         = "us-east-1"
    dynamodb_table = "lab-tfstate-lock" # 锁表:防两人/两流水线同时 apply
    encrypt        = true               # state 落盘加密(state 可能含敏感值)
  }
}
