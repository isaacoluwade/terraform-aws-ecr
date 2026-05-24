# Changelog

All notable changes to this module are documented here. Format based on
[Keep a Changelog](https://keepachangelog.com/), versioning follows
[SemVer](https://semver.org/).

## [2.0.0] - 2026-05-24

### Breaking changes

- **Region short-code derivation rewritten** (S-1 fix). The `region_code`
  local previously derived its value from a substring formula that produced
  non-canonical codes (`us-east-1` → `useast1`, `eu-west-2` → `euwest2`,
  `ap-southeast-1` → `apsoutheast1`). v2.0.0 replaces it with an explicit
  `region_code_map` lookup, giving the canonical short codes
  (`use1`, `euw2`, `apse1`, ...). **Every resource name and every `Name`
  tag in this module shifts as a result.** Consumers upgrading from
  v1.x will see destroy+recreate on first apply.

  See [`UPGRADE_GUIDE.md`](../UPGRADE_GUIDE.md) at the workspace root for
  the recommended per-environment cutover sequence.
- **`configuration_aliases = [aws.dr]` removed** (S-2 fix). Consumers
  no longer need to wire `aws.dr` in their `providers = {}` block. ECR
  replication runs against the source-region provider; the destination
  region is named in the rule.

  Migration: drop `aws.dr = aws.dr` from the `providers` block when
  calling this module.

- **Registry-wide writers gated by explicit ownership flags** (EC-C2 fix).
  Two new boolean inputs (defaults `false`):
  - `manage_registry_replication` — must be `true` for this module
    instance to write the account/region-wide `aws_ecr_replication_configuration`.
  - `manage_registry_scanning` — must be `true` for this module instance
    to write the account/region-wide `aws_ecr_registry_scanning_configuration`.

  Both resources are singletons; without these flags two module instances
  in the same account silently overwrote each other. Plan-time `check`
  blocks now fail loudly if any repo opts into `enhanced_scan = true` or
  `replicate_to = [...]` without the corresponding writer flag set.

  Migration: pick exactly one module instance per account+region to own
  the registry-wide config and set both flags to `true`. All other
  instances leave them at the default.

## [1.0.0] - 2026-05-22

### Added

- Initial release of `terraform-aws-ecr`.
- Map-of-repositories input model — one module call provisions N repos.
- KMS-encrypted repository storage (KMS key consumer-provided).
- Image scanning (Basic by default; Enhanced opt-in per repo via
  `enhanced_scan`, wired through a registry-level
  `aws_ecr_registry_scanning_configuration` with a wildcard filter per
  opted-in repo).
- Per-repository lifecycle policies with untagged-expiry (default 7 days)
  and old-version-expiry (default 30 versions kept), in priority order so
  untagged images expire before the count-based rule runs.
- Per-repository policies for cross-account pull/push, generated only when
  `cross_account_pull` or `cross_account_push` is non-empty.
- Optional cross-region replication via per-repo `replicate_to` list,
  assembled into a single registry-wide replication configuration with
  prefix-match filters.
- Image tag immutability defaulted to true; per-repo override via
  `immutable_tags` for base-image / `:latest` use cases.
- Native `terraform test` suite covering encryption, mutability defaults,
  scan-on-push, lifecycle two-rule shape, conditional policy/replication
  resources, naming derivation, tag spine, and validation negatives.
- Terratest suite verifying repo creation via AWS API and an optional
  push/pull roundtrip exercising `scan_on_push`.

### Module contract

- Required inputs: `project`, `environment`, `region`, `kms_key_arn`,
  `repositories`.
- Optional inputs: `tags`.
- Outputs: `repository_arns`, `repository_urls`, `repository_names`,
  `registry_id`, `region`, `replication_destinations`.

[1.0.0]: https://github.com/example/terraform-aws-ecr/releases/tag/v1.0.0
