# `examples/complete` — full-featured ECR

Provisions four ECR repositories that exercise every optional knob:

- `api-service` — Enhanced (Inspector-powered) scanning, optional
  cross-account pull grant.
- `web-frontend` — Enhanced scanning only.
- `ml-model` — Enhanced scanning, cross-region replication to the DR region,
  loosened lifecycle thresholds.
- `platform/base` — explicit name override (no `${primary_name}/` prefix),
  mutable tags for a `:latest`-style base image.

## Apply

```bash
terraform init
terraform apply
```

To exercise the cross-account pull on `api-service`:

```bash
terraform apply -var consumer_account_id=123456789012
```

## Tear down

```bash
terraform destroy
```

> Note: cross-region replication can take 30+ seconds to fully apply.
> ECR repos must be empty before destroy succeeds — delete any pushed
> images first.
