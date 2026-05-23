# Changelog

All notable changes to this module are documented here. Format based on
[Keep a Changelog](https://keepachangelog.com/), versioning follows
[SemVer](https://semver.org/).

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
