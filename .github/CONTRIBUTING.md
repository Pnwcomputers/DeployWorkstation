cat > .github/CONTRIBUTING.md << 'EOF'
# Contributing to DeployWorkstation

Thank you for your interest in contributing to DeployWorkstation! This document provides guidelines and information for contributors.

## 🎯 Ways to Contribute

### 🐛 Bug Reports
- Use the bug report template
- Include system information and logs
- Provide clear reproduction steps

### 💡 Feature Requests
- Use the feature request template
- Explain the use case and business value
- Consider implementation complexity

### 🔧 Code Contributions
- Fork the repository
- Create a feature branch
- Follow PowerShell best practices
- Add tests for new functionality
- Update documentation

### 📖 Documentation
- Improve README clarity
- Add configuration examples
- Create troubleshooting guides
- Fix typos and formatting

## 🔄 Development Process

### Setting Up Development Environment
1. Fork the repository
2. Clone your fork locally
3. Create a feature branch: `git checkout -b feature/your-feature-name`
4. Make your changes
5. Test thoroughly on multiple Windows versions
6. Commit with clear messages
7. Push to your fork
8. Create a pull request

### PowerShell Style Guidelines
- Use approved verbs for function names
- Follow PascalCase for functions and variables
- Use meaningful variable names
- Include comment-based help for functions
- Handle errors gracefully
- Use Write-Log for consistent logging

### Testing Requirements
- Test on Windows 10 and 11
- Test both domain and workgroup environments
- Verify offline functionality
- Check with different hardware configurations

## 📋 Code Review Process

1. **Automated Checks**: PR must pass all automated tests
2. **Manual Review**: Maintainer reviews code and functionality
3. **Testing**: Changes tested in real deployment scenarios
4. **Documentation**: Ensure documentation is updated
5. **Approval**: Maintainer approves and merges PR

## 🏷️ Commit Message Format

Use conventional commits format:
