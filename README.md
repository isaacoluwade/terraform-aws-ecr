# terraform-aws-ecr

Provision a set of AWS ECR repositories with KMS-encrypted storage, image
scanning (Basic by default, Enhanced opt-in), lifecycle policies, optional
cross-account access via repository policies, and optional cross-region
replication. One module call creates N repositories.

This is module 5 of 10 in the [AWS MTKP Terraform Module Library](../projects/1-aws-mtkp-terraform-module-library/).

## Usage

```hcl
module "ecr" {
  source = "git::https://github.com/<org>/terraform-aws-ecr.git?ref=v1.0.0"

  providers = {
    aws    = aws
    aws.dr = aws.dr
  }

  project     = "mtkp"
  environment = "prod"
  region      = "us-east-1"
  kms_key_arn = module.platform_kms.key_arn

  repositories = {
    "api-service"   = {}
    "web-frontend"  = {}
    "data-pipeline" = {}
    "platform/base" = {
      name           = "platform/base"
      immutable_tags = false # base image uses :latest
    }
    "ml-model" = {
      enhanced_scan      = true
      cross_account_pull = ["123456789012"]
      replicate_to       = ["us-west-2"]
    }
  }

  tags = { Owner = "platform-team" }
}
```

The module always requires two provider configurations: the default `aws`
provider for the primary region and an `aws.dr` alias for cross-region
replication. When no repository sets `replicate_to`, point `aws.dr` at the
same region as the primary — its resources will not be materialized.

## Operational defaults

- Encryption: SSE-KMS with a consumer-provided customer-managed key. Always on.
- Image scanning: `scan_on_push = true` for every repository (Basic scan).
  Enhanced (Inspector-powered) scanning is opt-in per-repo via `enhanced_scan`.
- Image tag mutability: `IMMUTABLE` by default. Per-repo override via
  `immutable_tags = false` for `:latest`-style base images.
- Lifecycle: two rules per repo — untagged images expire after
  `expire_untagged_days` (default 7), and the most recent
  `expire_old_versions` (default 30) tagged images are retained.
- Repository policies are generated only when `cross_account_pull` or
  `cross_account_push` is non-empty for a given repo.
- Cross-region replication uses a single registry-wide
  `aws_ecr_replication_configuration` with one prefix-match rule per
  replicating repo.

## Inputs

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `project` | `string` | — | Required. 3-12 chars, lowercase letters/digits/hyphens. Drives `primary_name` and the Project tag. |
| `environment` | `string` | — | Required. Lowercase letters/digits/hyphens. Drives `primary_name` and the Environment tag. |
| `region` | `string` | — | Required. Primary AWS region (e.g. `us-east-1`). |
| `kms_key_arn` | `string` | — | Required. ARN of the KMS key used to encrypt repository data at rest. |
| `repositories` | `map(object)` | — | Required. Map of repository definitions. See below. |
| `tags` | `map(string)` | `{}` | Consumer-specific tags merged with the module's spine. |

### `repositories` object shape

| Field | Type | Default | Description |
|------|------|---------|-------------|
| `name` | `string` | `null` | Explicit repo name. When null, derived as `${primary_name}/${key}`. |
| `immutable_tags` | `bool` | `true` | When true, `IMMUTABLE`; when false, `MUTABLE`. |
| `scan_on_push` | `bool` | `true` | Trigger a Basic scan on every push. |
| `enhanced_scan` | `bool` | `false` | Enable Inspector-powered Enhanced scanning for this repo (paid). |
| `cross_account_pull` | `list(string)` | `[]` | 12-digit account IDs allowed to pull. |
| `cross_account_push` | `list(string)` | `[]` | 12-digit account IDs allowed to push. |
| `expire_untagged_days` | `number` | `7` | Days to retain untagged images. Range 1-365. |
| `expire_old_versions` | `number` | `30` | Number of tagged images to keep per repo. Range 1-100. |
| `replicate_to` | `list(string)` | `[]` | AWS regions to replicate this repo to. |

## Outputs

| Name | Description |
|------|-------------|
| `repository_arns` | Map of repo key → ARN. |
| `repository_urls` | Map of repo key → registry URL (push/pull target). |
| `repository_names` | Map of repo key → resolved repository name. |
| `registry_id` | AWS account ID hosting the registry. |
| `region` | Echo of the input region. |
| `replication_destinations` | Map of repo key → list of replication destination regions. Empty map when no repos replicate. |

## Examples

- [`examples/main`](./examples/main) — minimal two-repo usage.
- [`examples/complete`](./examples/complete) — multiple repos, Enhanced scanning, cross-account pull, cross-region replication, explicit name override.

## Testing

Three layers per the [testing pyramid](../projects/1-aws-mtkp-terraform-module-library/01-foundations/04-the-testing-pyramid.md):

```bash
# Layer 1 — static analysis (sub-second)
terraform fmt -check -recursive
tflint --config .tflint.hcl
checkov --config-file .checkov.yaml -d .

# Layer 2 — unit tests with mock_provider (<5s)
terraform test

# Layer 3 — integration tests against real AWS (post-merge only)
cd terratest/test && go test -v -timeout 30m ./...
```

## Versioning

See [CHANGELOG.md](./CHANGELOG.md). Tag `v<MAJOR>.<MINOR>.<PATCH>` is the
immutable artifact; the `VERSION` file mirrors the tag and CI enforces
agreement at release.
