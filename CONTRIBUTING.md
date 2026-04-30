# Contributing to Memory Bank Standard

Thank you for your interest in improving the Memory Bank Standard! This guide will help you contribute effectively.

## How to Contribute

### Reporting Issues

If you find a bug or have a suggestion:

1. Check [existing issues](https://gitlab.com/tmobile/ere/memory-bank/-/issues) to avoid duplicates
2. Create a new issue with:
   - Clear title describing the problem or suggestion
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Your environment (OS, IDE, versions)

### Proposing Changes

For code changes, documentation improvements, or new features:

1. **Fork the repository** or create a feature branch
2. **Make your changes** following our standards
3. **Test thoroughly** - verify scripts work on target platforms
4. **Update documentation** if you change behavior
5. **Submit a merge request** with a clear description

## Contribution Guidelines

### Code Standards

This project follows its own standards:

- **Memory Bank**: Keep context files focused and scannable
- **Security**: Follow the 3-tier guardrail system
- **Code Quality**: Add WHY comments, not WHAT comments

### Script Contributions

When modifying scripts:

- **Cross-platform**: Test on both Windows (PowerShell) and macOS/Linux (Bash)
- **Help text**: Update documentation in script headers
- **Error handling**: Check for missing files/directories
- **Colored output**: Use consistent color scheme (Green=success, Yellow=warning, Red=error)

### Template Contributions

Templates must be:

- **Generic**: No project-specific examples or values
- **Fillable**: Use `[placeholder]` markers for user input
- **Complete**: Include all necessary sections
- **Consistent**: Match the structure of existing templates

### Documentation Contributions

When writing documentation:

- **Explain WHY**: Don't just describe what, explain why it matters
- **Use tables**: For structured data (comparisons, options, metrics)
- **Provide examples**: Show both good and bad patterns
- **Keep scannable**: Use headers, bullets, and short paragraphs

## Language Extensions

To add a new language extension (e.g., Go, Java, C#):

1. Copy `standards/extensions/_template.md`
2. Fill in language-specific patterns
3. Add linting/formatting tool recommendations
4. Provide code examples showing good/bad patterns
5. Create corresponding `.mdc` rule file for Cursor

## Testing Your Changes

Before submitting:

### For Script Changes

```powershell
# Windows - Test init script
.\scripts\init-memory-bank.ps1 -ProjectPath "C:\temp\test-project"

# Windows - Test mb utility
.\scripts\mb.ps1 status
```

```bash
# macOS/Linux - Test init script
./scripts/init-memory-bank.sh --force /tmp/test-project

# Verify templates were copied
ls -la /tmp/test-project/memory-bank/
```

### For Template Changes

1. Run init script to copy templates to test project
2. Verify all placeholders are present
3. Fill in templates to ensure they're usable
4. Have AI read templates to verify they work

### For Documentation Changes

1. Read through the entire document
2. Check all links work
3. Verify code examples are correct
4. Ensure formatting renders properly

## Merge Request Process

1. **Title**: Use conventional commits format
   - `feat: Add Go language extension`
   - `fix: Correct PowerShell script path handling`
   - `docs: Update setup guide with GitLab instructions`
   - `chore: Update dependencies`

2. **Description**: Include:
   - What changed and why
   - Testing performed
   - Breaking changes (if any)
   - Related issues

3. **Review**: Address feedback promptly and professionally

4. **Merge**: Maintainers will merge after approval

## Questions?

- **Teams**: [RE - SkyNet Support - AI Discussion](https://teams.microsoft.com/l/channel/19%3A7130c6f6eb354efda1d4b3fa89546215%40thread.tacv2/RE%20-%20SkyNet%20Support%20-%20AI%20Discussion?groupId=4f72c46d-e46e-43b9-a3d6-1de811294cf8&tenantId=be0f980b-dd99-4b19-bd7b-bc71a09b026c)
- **GitLab Issues**: For bugs and feature requests
- **Email**: Contact the Release Engineering/AERO team

## Code of Conduct

- Be respectful and professional
- Focus on constructive feedback
- Help others learn and improve
- Assume good intentions

Thank you for contributing to making AI-assisted development better for everyone!
