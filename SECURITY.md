# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public issue
2. Email security concerns to: security@codepros.dev
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)

We will acknowledge receipt within 48 hours and provide a detailed response within 7 days.

## Security Measures

This project implements the following security measures:

### CI/CD Security Scanning
- **SAST**: Static Application Security Testing via GitLab
- **Secret Detection**: Automated scanning for hardcoded secrets
- **License Scanning**: Compliance verification for dependencies
- **Gitleaks**: Enhanced secrets detection

### Code Security
- Memory-safe Zig implementation
- No external C dependencies; optional Zig dependency on [spice](https://gitlab.com/devnw/zig/spice) for parallelism (controlled by `-Dspice=true/false` build flag)
- Compile-time safety checks enabled

### Release Security
- All releases are tagged and signed
- SPDX license identifiers in all source files
- Apache-2.0 license

## Security Updates

Security updates will be released as patch versions. Subscribe to releases to be notified.

