# Changelog

All notable changes to this module are listed here. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the module uses [semantic versioning](https://semver.org/): a new major version means callers must change their code.

## [Unreleased]

## [1.0.1] - 2026-10-06

### Changed

- The copyright year in `NOTICE` and the file headers is now 2026, the year the module was rebuilt and released as 1.0.0.
- `CLAUDE.md`, the working rules shared by every Automate the Cloud module, adds the lessons learned while rebuilding the modules.

## [1.0.0] - 2026-10-05

Initial release.

### Added

- A security group in a VPC that allows no traffic, in either direction, until you add rules.
- Inbound and outbound rules, keyed by names you choose, each for one protocol and port range from or to an IPv4 range, an IPv6 range, a managed prefix list, another security group (including one in a peered VPC in another account), or the group itself.
- TCP, UDP, ICMP, ICMPv6, all protocols, and other IP protocol numbers.
- Checks at plan time for rules AWS would refuse or save in another form: duplicates, ranges that do not start at their first address, protocol numbers that have names, and descriptions with unsupported characters.
- `region`, to create the group in a Region other than the provider's.
- A `metadata` output with everything the module created.
- Offline tests, and examples for one group and for three tiers that allow only the traffic between them.

[Unreleased]: https://github.com/AutomateTheCloud/terraform-aws-security_group/compare/v1.0.1...HEAD
[1.0.1]: https://github.com/AutomateTheCloud/terraform-aws-security_group/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/AutomateTheCloud/terraform-aws-security_group/releases/tag/v1.0.0
