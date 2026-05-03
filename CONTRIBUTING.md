# Contributing to TierSpec

Thank you for your interest in contributing to TierSpec! This document provides guidelines and instructions for contributing.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [How to Contribute](#how-to-contribute)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Commit Messages](#commit-messages)

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment. Please be considerate of others and follow standard open-source community guidelines.

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/TierSpec.git
   cd TierSpec
   ```
3. Create a branch for your changes:
   ```bash
   git checkout -b feature/your-feature-name
   ```

## Development Setup

### Prerequisites

- Node.js 18+
- Xcode 15+ (for Mac client development)
- OpenAI API key (for AI features testing)

### MCP Server Setup

```bash
cd mcp-server
npm install
npm run build
npm run test
```

### Mac Client Setup

1. Open `TierSpec/TierSpec.xcodeproj` in Xcode
2. Wait for Swift Package Manager to resolve dependencies
3. Build the project (⌘B)
4. Run tests (⌘U)

## How to Contribute

### Reporting Bugs

1. Check existing issues to avoid duplicates
2. Use the [Bug Report template](.github/ISSUE_TEMPLATE/bug_report.md)
3. Include as much detail as possible:
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details
   - Logs and screenshots

### Requesting Features

1. Use the [Feature Request template](.github/ISSUE_TEMPLATE/feature_request.md)
2. Describe the problem you're trying to solve
3. Explain your proposed solution
4. Consider alternative approaches

### Submitting Code

1. Create a feature branch from `main`
2. Make your changes
3. Add/update tests
4. Update documentation if needed
5. Submit a Pull Request

## Pull Request Process

1. **Ensure all tests pass**:
   ```bash
   cd mcp-server
   npm run test
   npm run typecheck
   ```

2. **Update documentation** for any new features or changed behavior

3. **Add tests** for new functionality

4. **Follow the PR template** and fill in all sections

5. **Request review** from maintainers

6. **Address review feedback** promptly

### PR Checklist

- [ ] Code compiles without errors
- [ ] All tests pass
- [ ] New tests added for new functionality
- [ ] Documentation updated
- [ ] Commit messages follow conventions
- [ ] Branch is up-to-date with `main`

## Coding Standards

### TypeScript (MCP Server)

- Use strict mode
- Follow existing code style
- Use meaningful variable names
- Add JSDoc comments for public APIs
- Keep functions small and focused

```typescript
// Good
/**
 * Parses a natural language requirement into a hierarchy suggestion.
 * @param requirement - The natural language requirement text
 * @returns A hierarchy suggestion with confidence scores
 */
export async function parseRequirement(requirement: string): Promise<HierarchySuggestion> {
  // Implementation
}
```

### Swift (Mac Client)

- Follow Swift naming conventions
- Use meaningful variable names
- Add documentation comments for public APIs
- Prefer SwiftUI patterns

```swift
// Good
/// Manages the MCP client connection and tool invocations.
@MainActor
final class MCPClientManager: ObservableObject {
    // Implementation
}
```

## Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

### Types

- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

### Examples

```
feat(ai): add dependency detection for user stories
fix(hierarchy): correct parent-child validation for test cases
docs(readme): update installation instructions
test(sprint): add tests for sprint capacity calculation
```

## Project Structure

```
TierSpec/
├── mcp-server/           # TypeScript MCP Server
│   ├── src/
│   │   ├── index.ts      # Main entry point
│   │   ├── tools/        # MCP tool implementations
│   │   ├── ai/           # AI integration
│   │   └── db/           # Database layer
│   └── tests/            # Vitest tests
├── TierSpec/             # Swift Mac Client
│   └── TierSpec/
│       ├── Models/       # Data models
│       ├── Views/        # SwiftUI views
│       ├── ViewModels/   # View models
│       └── Services/     # MCP client, etc.
└── .github/              # GitHub templates
```

## Questions?

Feel free to open an issue with the "question" label or start a discussion in GitHub Discussions.

---

Thank you for contributing to TierSpec! 🎉