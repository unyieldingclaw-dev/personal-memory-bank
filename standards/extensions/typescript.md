# TypeScript Extension for Code Quality Standard

TypeScript-specific code quality rules extending the generic standard.

## Formatting

### Tools
- **Formatter**: [Prettier](https://prettier.io/)
- **Linter**: [ESLint](https://eslint.org/) with TypeScript plugin

### Configuration

```json
// .prettierrc
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100
}
```

```json
// .eslintrc.json
{
  "extends": [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
    "prettier"
  ],
  "parser": "@typescript-eslint/parser",
  "plugins": ["@typescript-eslint"],
  "rules": {
    "@typescript-eslint/explicit-function-return-type": "error",
    "@typescript-eslint/no-explicit-any": "error",
    "@typescript-eslint/no-unused-vars": "error"
  }
}
```

### Rules
- Single quotes for strings
- Semicolons required
- 2-space indentation
- Trailing commas in multi-line

## Type Safety

### Compiler Configuration

```json
// tsconfig.json
{
  "compilerOptions": {
    "strict": true,
    "noImplicitAny": true,
    "strictNullChecks": true,
    "noImplicitReturns": true,
    "noFallthroughCasesInSwitch": true,
    "noUncheckedIndexedAccess": true
  }
}
```

### Rules

| Rule | Example |
|------|---------|
| Explicit return types | `function process(): Result {}` |
| No `any` type | Use `unknown` or specific types |
| Null checks | `if (value !== null)` |
| Exhaustive switch | Handle all enum cases |

```typescript
// ✅ GOOD - Fully typed
interface User {
  id: number;
  name: string;
  email: string | null;
}

function getUser(id: number): Promise<User | null> {
  // ...
}

// ❌ BAD - Using any
function processData(data: any): any {
  // ...
}
```

### Exhaustive Switch Pattern

```typescript
// ✅ GOOD - Exhaustive switch
type Status = 'pending' | 'active' | 'completed';

function getStatusColor(status: Status): string {
  switch (status) {
    case 'pending':
      return 'yellow';
    case 'active':
      return 'blue';
    case 'completed':
      return 'green';
    default:
      // This ensures all cases are handled
      const _exhaustive: never = status;
      throw new Error(`Unhandled status: ${_exhaustive}`);
  }
}
```

## Testing

### Framework
- **Test Runner**: [Vitest](https://vitest.dev/) or [Jest](https://jestjs.io/)
- **React Testing**: [@testing-library/react](https://testing-library.com/react)

### Configuration

```typescript
// vitest.config.ts
import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    globals: true,
    environment: 'jsdom',
    coverage: {
      reporter: ['text', 'html'],
      threshold: {
        lines: 80,
        branches: 80,
      },
    },
  },
});
```

### Rules

| Rule | Implementation |
|------|----------------|
| Test file naming | `*.test.ts` or `*.spec.ts` |
| Test function naming | `it('should <expected behavior>')` |
| Use describe blocks | Group related tests |
| Minimum coverage | 80% for new code |

```typescript
// ✅ GOOD - Clear test structure
describe('UserService', () => {
  describe('createUser', () => {
    it('should create a user with valid data', async () => {
      const result = await createUser({ name: 'Alice', email: 'alice@example.com' });
      
      expect(result.name).toBe('Alice');
      expect(result.id).toBeDefined();
    });

    it('should throw when email is duplicate', async () => {
      await createUser({ email: 'test@example.com' });
      
      await expect(
        createUser({ email: 'test@example.com' })
      ).rejects.toThrow('Email already exists');
    });
  });
});
```

## React Patterns

### Rules

| Rule | Rationale |
|------|-----------|
| Functional components only | Simpler, hooks-based |
| Custom hooks for logic | Reusable, testable |
| Props interface defined | Type safety |
| Memoization when needed | Performance |

```typescript
// ✅ GOOD - Typed functional component
interface UserCardProps {
  user: User;
  onSelect: (id: number) => void;
}

export function UserCard({ user, onSelect }: UserCardProps): JSX.Element {
  const handleClick = useCallback(() => {
    onSelect(user.id);
  }, [user.id, onSelect]);

  return (
    <div onClick={handleClick}>
      <h3>{user.name}</h3>
      <p>{user.email}</p>
    </div>
  );
}
```

### State Management

| Pattern | Use Case |
|---------|----------|
| `useState` | Simple local state |
| `useReducer` | Complex local state |
| Context | Shared state (small scope) |
| Zustand/Jotai | Global state (large apps) |

## Error Handling

### Rules

| Rule | Implementation |
|------|----------------|
| Type error responses | Custom error types |
| Boundaries for React | Error boundaries for UI |
| Async error handling | try/catch with types |

```typescript
// ✅ GOOD - Typed error handling
class ApiError extends Error {
  constructor(
    message: string,
    public statusCode: number,
    public code: string
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

async function fetchUser(id: number): Promise<User> {
  try {
    const response = await fetch(`/api/users/${id}`);
    if (!response.ok) {
      throw new ApiError('User not found', response.status, 'USER_NOT_FOUND');
    }
    return response.json();
  } catch (error) {
    if (error instanceof ApiError) {
      throw error;
    }
    throw new ApiError('Network error', 500, 'NETWORK_ERROR');
  }
}
```

## Anti-Patterns

### Avoid These

| Anti-Pattern | Better Approach |
|--------------|-----------------|
| `as any` type assertion | Proper typing or `unknown` |
| `!` non-null assertion | Null checks |
| `enum` (some cases) | Union types or const objects |
| `class` for data | Interface + functions |
| Default exports | Named exports |
| `var` keyword | `const` or `let` |

```typescript
// ❌ BAD - Using any and !
const data = response.data as any;
const name = user!.name;

// ✅ GOOD - Proper typing
interface ResponseData {
  user: User;
}
const data: ResponseData = response.data;
const name = user?.name ?? 'Unknown';
```

## Dependencies

### Rules

| Rule | Rationale |
|------|-----------|
| Lock versions | `package-lock.json` |
| Audit regularly | `npm audit` |
| Minimal dependencies | Reduce attack surface |
| Check bundle size | `bundlephobia.com` |

```json
// package.json
{
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0"
  },
  "devDependencies": {
    "@types/react": "^18.2.0",
    "typescript": "^5.2.0",
    "vitest": "^1.0.0"
  }
}
```

## IDE Integration

### Cursor

Add to `.cursor/rules/typescript.mdc`:

```yaml
---
globs: ["**/*.ts", "**/*.tsx"]
---

# TypeScript Code Quality

## Formatting
- Use Prettier for formatting
- Run: `npx prettier --write .`

## Type Safety
- Enable strict mode in tsconfig.json
- No `any` type - use `unknown` or specific types
- Explicit return types on functions
- Run: `npx tsc --noEmit`

## Testing
- Use Vitest or Jest
- Minimum 80% coverage for new code
- Run: `npm test`

## React
- Functional components only (no class components)
- Define Props interface for all components
- Use custom hooks for reusable logic
```

### Pre-commit

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: prettier
        name: prettier
        entry: npx prettier --write --ignore-unknown
        language: system
        types: [file]
        files: \.(ts|tsx|js|jsx|json|md)$
      - id: eslint
        name: eslint
        entry: npx eslint --fix
        language: system
        types: [file]
        files: \.(ts|tsx)$
      - id: typecheck
        name: typecheck
        entry: npx tsc --noEmit
        language: system
        pass_filenames: false
```

## Common AI Mistakes in TypeScript

| Mistake | Prevention |
|---------|------------|
| Using `any` to bypass types | Explicit "no any" rule |
| Missing null checks | Enable `strictNullChecks` |
| Not awaiting promises | TypeScript catches with `noImplicitReturns` |
| Class components in React | Specify functional only |
| Default exports | Specify named exports |
| Missing error boundaries | Include in React patterns |
