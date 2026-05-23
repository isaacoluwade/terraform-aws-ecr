# `examples/main` — minimal ECR

Provisions a single-region ECR with two repositories (`app` defaults,
`base` with mutable tags for the `:latest` use case).

## Apply

```bash
terraform init
terraform apply
```

Outputs `push_command` — three commands you can paste to put your first
image into the `app` repo.

## Tear down

```bash
terraform destroy
```

> Note: ECR repos must be empty before destroy succeeds. If you've pushed
> images, delete them first via `aws ecr batch-delete-image` or the AWS
> console.
