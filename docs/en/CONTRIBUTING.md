# Contributing to DJProducerTools

## Overview
DJProducerTools is an open-source project dedicated to helping DJs and producers manage their music libraries efficiently and safely.

## Getting Started

### Prerequisites
- macOS 10.15+
- bash 4.0+
- git

### Development Setup
```bash
git clone https://github.com/Astro1Deep/DjProducerTool.git
cd DjProducerTool
```

## Code Standards

### Bash Script Guidelines
1. **Shebang**: Always use `#!/usr/bin/env bash`
2. **Error Handling**: Use `set -u` to catch undefined variables
3. **Color Codes**: Use the defined color constants (C_RED, C_GRN, etc.)
4. **Comments**: Keep comments brief and only for complex logic
5. **Variable Naming**: Use UPPERCASE for constants, lowercase for locals
6. **Function Naming**: Use snake_case, prefix with underscore if internal

### Python Guidelines
1. **Style**: Follow PEP 8
2. **Linting**: Use `pylint` or `black`
3. **Testing**: Write unit tests for new functions
4. **Documentation**: Include docstrings for all functions

## Testing

Run the test suite before submitting:
```bash
bash tests/test_runner_fixed.sh
```

## Localization

- English: `DJProducerTools_MultiScript_EN.sh`
- Spanish: `DJProducerTools_MultiScript_ES.sh`

Keep both files synchronized when making changes.

## Reporting Issues

Include:
- macOS version
- bash version
- Exact error message
- Steps to reproduce
- Expected behavior

## Pull Request Process

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Test thoroughly
4. Commit with clear messages
5. Push and create Pull Request
6. Respond to reviews promptly

## License
By contributing, you agree to license your contributions under the DJProducerTools License.

Thank you for improving DJProducerTools! 🎵
