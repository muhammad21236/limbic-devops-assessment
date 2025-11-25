# Contributing Guidelines

Thank you for considering contributing to this project! This document outlines the guidelines for contributing.

## 🤝 How to Contribute

### Reporting Issues

If you find a bug or have a suggestion:

1. Check if the issue already exists
2. Create a new issue with:
   - Clear title and description
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Environment details (OS, versions, etc.)

### Submitting Changes

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/your-feature`
3. Make your changes
4. Test your changes thoroughly
5. Commit with clear messages: `git commit -m "Add: feature description"`
6. Push to your fork: `git push origin feature/your-feature`
7. Submit a pull request

## 📝 Code Standards

### Shell Scripts

- Use `#!/bin/bash` shebang
- Include error handling: `set -e`
- Add comments for complex operations
- Use meaningful variable names in UPPERCASE
- Test scripts before committing

### Docker

- Use multi-stage builds
- Run as non-root user
- Include health checks
- Pin specific versions
- Minimize layer count

### Documentation

- Update README.md for major changes
- Add inline comments for complex code
- Keep documentation current
- Use clear, concise language

## 🧪 Testing

Before submitting:

- [ ] Test all scripts
- [ ] Verify Docker builds work
- [ ] Check applications run correctly
- [ ] Validate documentation accuracy
- [ ] Ensure no secrets are committed

## 📋 Commit Messages

Format: `Type: Brief description`

Types:
- `Add:` New feature or file
- `Fix:` Bug fix
- `Update:` Modify existing feature
- `Docs:` Documentation changes
- `Refactor:` Code restructuring
- `Test:` Add or update tests

Examples:
```
Add: Cloudflare tunnel health check script
Fix: Docker compose network configuration
Update: README with additional troubleshooting steps
Docs: Add architecture diagram explanation
```

## 🔒 Security

- Never commit secrets or credentials
- Use `.env.example` for environment templates
- Redact sensitive information in logs
- Report security issues privately

## 📄 License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

**Questions?** Open an issue or reach out to the maintainers.
