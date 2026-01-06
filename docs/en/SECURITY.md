# Security Policy

## Reporting Security Vulnerabilities

**DO NOT** open public issues for security vulnerabilities. Instead, please email: `security@astro1deep.com`

Please include:
1. Description of the vulnerability
2. Steps to reproduce
3. Potential impact
4. Suggested fix (if available)

We will:
- Acknowledge receipt within 48 hours
- Provide status updates weekly
- Credit you in the security advisory (unless you prefer anonymity)
- Work with you on a fix and release timeline

## Security Best Practices

### Safe Mode
Always run with `SAFE_MODE=1` (default):
- Prevents accidental file deletion
- Requires confirmation before destructive operations
- Maintains detailed logs of all changes

### Backups
The tool automatically:
- Creates timestamped backups before any modifications
- Preserves original files in quarantine for 30 days
- Maintains integrity checksums

### Permissions
- Never runs with `sudo` unless explicitly needed
- Respects file ownership and permissions
- Won't modify files you don't own

### Isolation
- ML features run in isolated Python virtual environment
- No network calls without user permission
- No data sent to external servers

## Supported Versions

| Version | Status | Until |
|---------|--------|-------|
| 1.0.0 | Supported | 2025-01-04 |
| 1.9.5 | Security fixes only | 2024-07-04 |
| < 1.9.5 | Unsupported | - |

## Disclosure Timeline

Our vulnerability disclosure policy:
- **Day 0**: Vulnerability reported
- **Day 1**: Initial acknowledgment
- **Day 7**: Patch development begins
- **Day 21**: Patch released (or timeline negotiated)
- **Day 30**: Public disclosure (if not fixed, disclosure timeline extended)

## Known Limitations

### File System
- Limited to macOS file systems (HFS+, APFS)
- Symlinks may not work as expected
- Network drives not recommended for performance

### Memory
- Large libraries (>100K files) may require optimization
- Recommend 8GB RAM minimum
- Increase available disk space for processing

## Dependencies

### Critical
- bash 4.0+ (included in macOS)
- Standard Unix utilities (grep, find, sed, awk)

### Security Considerations
- ffmpeg: Can process untrusted audio files (sandboxed via environment)
- Python: Local execution only, no network access
- jq: JSON parsing of potentially untrusted files

## Compliance

This tool:
- ✅ Does not collect telemetry
- ✅ Does not require account creation
- ✅ Does not access the internet by default
- ✅ Respects your file privacy
- ✅ Allows full offline operation

## Security Updates

Security updates are released as patch versions (e.g., 2.0.1) and applied to the latest and previous versions.

To check for updates:
```bash
# Check version
cat VERSION

# Or use the built-in updater (Option 3 in menu)
```

## Audit Trail

All operations create audit logs in:
```
_DJProducerTools/logs/audit_YYYY-MM-DD.txt
```

Enable comprehensive logging:
```bash
DEBUG_MODE=1 ./DJProducerTools_MultiScript_EN.sh
```

## Contributing Security Fixes

1. Email `security@astro1deep.com` first
2. Do not commit to public repository
3. Include test cases
4. Provide detailed explanation

Thank you for helping keep DJProducerTools secure! 🛡️
