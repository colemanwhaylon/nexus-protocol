# Nexus Protocol Frontend Style Guide

> A comprehensive style guide for the Next.js/React/TypeScript frontend, synthesized from industry-leading sources: [Vercel Style Guide](https://github.com/vercel/style-guide), [Airbnb React/JSX Style Guide](https://github.com/airbnb/javascript/tree/master/react), and [TypeScript Style Guide](https://mkosir.github.io/typescript-style-guide/).

---

## Table of Contents

1. [Technology Stack](#technology-stack)
2. [Project Structure](#project-structure)
3. [TypeScript Conventions](#typescript-conventions)
4. [React Component Guidelines](#react-component-guidelines)
5. [Naming Conventions](#naming-conventions)
6. [State Management](#state-management)
7. [Data Fetching](#data-fetching)
8. [Styling](#styling)
9. [Testing](#testing)
10. [Accessibility](#accessibility)
11. [Performance](#performance)
12. [Linting & Formatting](#linting--formatting)
13. [Git Conventions](#git-conventions)

---

## Technology Stack

| Category | Technology | Version |
|----------|------------|---------|
| Framework | Next.js (App Router) | 14.x |
| Language | TypeScript | 5.x |
| UI Library | React | 18.x |
| Styling | Tailwind CSS | 3.x |
| State | Zustand / React Context | Latest |
| Data Fetching | TanStack Query | 5.x |
| Web3 | wagmi + viem | Latest |
| Testing | Vitest + React Testing Library | Latest |
| Linting | ESLint + Prettier | Latest |

---

## Project Structure

Organize by **feature**, collocating related code together:

```
frontend/
├── app/                    # Next.js App Router
│   ├── (auth)/            # Route groups
│   │   ├── login/
│   │   └── register/
│   ├── dashboard/
│   │   ├── page.tsx
│   │   ├── layout.tsx
│   │   └── loading.tsx
│   ├── staking/
│   ├── governance/
│   └── layout.tsx
├── components/
│   ├── ui/                # Reusable UI primitives
│   │   ├── Button/
│   │   │   ├── Button.tsx
│   │   │   ├── Button.test.tsx
│   │   │   └── index.ts
│   │   ├── Card/
│   │   └── Modal/
│   └── features/          # Feature-specific components
│       ├── Staking/
│       ├── Governance/
│       └── Wallet/
├── hooks/                 # Custom React hooks
│   ├── useStaking.ts
│   ├── useGovernance.ts
│   └── useWallet.ts
├── lib/                   # Utilities & configurations
│   ├── api/              # API client functions
│   ├── contracts/        # Contract ABIs & addresses
│   ├── utils/            # Helper functions
│   └── constants.ts
├── types/                 # Global TypeScript types
│   ├── api.ts
│   ├── contracts.ts
│   └── index.ts
├── styles/               # Global styles
│   └── globals.css
└── public/               # Static assets
    └── images/
```

### Import Organization

```typescript
// 1. External packages
import { useState, useEffect } from 'react';
import { useQuery } from '@tanstack/react-query';

// 2. Internal absolute imports
import { Button } from '@/components/ui/Button';
import { useStaking } from '@/hooks/useStaking';
import type { StakingPosition } from '@/types';

// 3. Relative imports (same feature)
import { StakingCard } from './StakingCard';
import { formatAmount } from './utils';
```

**Rules:**
- Use **relative imports** (`./`, `../`) within the same feature
- Use **absolute imports** (`@/`) across features
- Separate **type imports** with `import type`

---

## TypeScript Conventions

### Type vs Interface

**Use `type` aliases over `interface`** for consistency:

```typescript
// Preferred
type User = {
  id: string;
  address: string;
  balance: bigint;
};

// Avoid
interface User {
  id: string;
  address: string;
  balance: bigint;
}
```

### Discriminated Unions

Prefer discriminated unions over optional properties:

```typescript
// Bad: Too many optionals
type TransactionState = {
  status?: 'idle' | 'pending' | 'success' | 'error';
  hash?: string;
  error?: Error;
};

// Good: Discriminated union
type TransactionState =
  | { status: 'idle' }
  | { status: 'pending' }
  | { status: 'success'; hash: string }
  | { status: 'error'; error: Error };
```

### Immutability

Use `Readonly` and `ReadonlyArray` throughout:

```typescript
type StakingConfig = Readonly<{
  minStake: bigint;
  lockPeriod: number;
  rewards: ReadonlyArray<RewardTier>;
}>;
```

### Avoid `any`

Use `unknown` with type guards instead:

```typescript
// Bad
function parseResponse(data: any) {
  return data.value;
}

// Good
function parseResponse(data: unknown): string {
  if (typeof data === 'object' && data !== null && 'value' in data) {
    return String(data.value);
  }
  throw new Error('Invalid response');
}
```

### Named Exports Only

Never use default exports:

```typescript
// Good
export const StakingCard = () => { ... };
export type StakingCardProps = { ... };

// Bad
export default StakingCard;
```

---

## React Component Guidelines

### Functional Components Only

Always use functional components with hooks:

```typescript
// Good
export const StakingCard = ({ position, onUnstake }: StakingCardProps) => {
  const [isLoading, setIsLoading] = useState(false);
  // ...
};

// Avoid class components
```

### Props Conventions

```typescript
// Props type naming: [ComponentName]Props
type StakingCardProps = {
  // Required props first
  position: StakingPosition;
  onUnstake: (amount: bigint) => void;

  // Optional props with sensible defaults
  showRewards?: boolean;
  className?: string;
};

// Component with defaults
export const StakingCard = ({
  position,
  onUnstake,
  showRewards = true,
  className,
}: StakingCardProps) => {
  // ...
};
```

### Event Handlers

```typescript
// Props: prefix with `on`
type ButtonProps = {
  onClick: () => void;
  onHover?: () => void;
};

// Implementation: prefix with `handle`
export const StakingForm = () => {
  const handleStake = () => {
    // ...
  };

  const handleAmountChange = (value: string) => {
    // ...
  };

  return (
    <form>
      <Input onChange={handleAmountChange} />
      <Button onClick={handleStake}>Stake</Button>
    </form>
  );
};
```

### One Component Per File

```typescript
// StakingCard.tsx - Single exported component
export const StakingCard = () => { ... };

// Exception: Small, tightly-coupled helper components
const StakingCardHeader = () => { ... };
const StakingCardBody = () => { ... };

export const StakingCard = () => (
  <Card>
    <StakingCardHeader />
    <StakingCardBody />
  </Card>
);
```

### JSX Formatting

```tsx
// Multi-line props: one per line, closing on new line
<StakingCard
  position={position}
  onUnstake={handleUnstake}
  showRewards={true}
  className="mt-4"
/>

// Single-line for few props
<Button onClick={handleClick}>Stake</Button>

// Self-close empty elements
<Divider />

// Wrap multi-line JSX in parentheses
return (
  <div>
    <StakingCard position={position} />
  </div>
);
```

---

## Naming Conventions

| Category | Convention | Example |
|----------|------------|---------|
| **Files** | PascalCase for components | `StakingCard.tsx` |
| **Files** | camelCase for utilities | `formatAmount.ts` |
| **Components** | PascalCase | `StakingCard`, `WalletConnect` |
| **Props Types** | `[Component]Props` | `StakingCardProps` |
| **Hooks** | `use` prefix, camelCase | `useStaking`, `useWallet` |
| **Variables** | camelCase | `stakingPosition`, `totalRewards` |
| **Constants** | UPPER_SNAKE_CASE | `MAX_STAKE_AMOUNT`, `API_URL` |
| **Booleans** | `is`, `has`, `should` prefix | `isLoading`, `hasError`, `shouldRefetch` |
| **Event Props** | `on` prefix | `onClick`, `onStake`, `onError` |
| **Event Handlers** | `handle` prefix | `handleClick`, `handleStake` |
| **Types** | PascalCase | `StakingPosition`, `UserBalance` |
| **Generics** | `T` prefix | `TData`, `TError`, `TResponse` |

### Acronyms

Treat acronyms as words:

```typescript
// Good
type NftMetadata = { ... };
const generateUserUrl = () => { ... };

// Bad
type NFTMetadata = { ... };
const generateUserURL = () => { ... };
```

---

## State Management

### State Hierarchy

1. **Local state** (`useState`) - Component-specific UI state
2. **Server state** (TanStack Query) - Data from API/blockchain
3. **Global state** (Zustand/Context) - Shared app state

### Local State

```typescript
// Simple state
const [isOpen, setIsOpen] = useState(false);

// Complex state with reducer
const [state, dispatch] = useReducer(stakingReducer, initialState);
```

### Server State with TanStack Query

```typescript
// hooks/useStakingPosition.ts
export const useStakingPosition = (address: string) => {
  return useQuery({
    queryKey: ['staking', 'position', address],
    queryFn: () => fetchStakingPosition(address),
    staleTime: 30_000, // 30 seconds
  });
};

// Usage
const { data: position, isLoading, error } = useStakingPosition(address);
```

### Global State with Zustand

```typescript
// stores/useWalletStore.ts
import { create } from 'zustand';

type WalletStore = {
  address: string | null;
  chainId: number | null;
  setAddress: (address: string | null) => void;
  setChainId: (chainId: number | null) => void;
  disconnect: () => void;
};

export const useWalletStore = create<WalletStore>((set) => ({
  address: null,
  chainId: null,
  setAddress: (address) => set({ address }),
  setChainId: (chainId) => set({ chainId }),
  disconnect: () => set({ address: null, chainId: null }),
}));
```

### State Colocation

Keep state close to where it's used:

```typescript
// Bad: State in parent when only child needs it
const Parent = () => {
  const [searchQuery, setSearchQuery] = useState('');
  return <SearchComponent query={searchQuery} setQuery={setSearchQuery} />;
};

// Good: State in component that uses it
const SearchComponent = () => {
  const [searchQuery, setSearchQuery] = useState('');
  // ...
};
```

---

## Data Fetching

### Next.js App Router Patterns

```typescript
// app/staking/page.tsx - Server Component (default)
export default async function StakingPage() {
  const positions = await fetchStakingPositions();

  return (
    <div>
      <StakingOverview positions={positions} />
      <Suspense fallback={<Loading />}>
        <StakingActions />
      </Suspense>
    </div>
  );
}
```

### Client Components

```typescript
// components/StakingActions.tsx
'use client';

import { useStaking } from '@/hooks/useStaking';

export const StakingActions = () => {
  const { stake, unstake, isLoading } = useStaking();
  // Client-side interactivity
};
```

### Server Actions

```typescript
// app/actions/staking.ts
'use server';

export async function createStakingPosition(formData: FormData) {
  const amount = formData.get('amount');
  // Server-side validation and processing
  revalidatePath('/staking');
}
```

### Rendering Strategy

| Content Type | Strategy | Example |
|--------------|----------|---------|
| Static content | SSG | Marketing pages |
| User-specific data | SSR | Dashboard |
| Real-time data | CSR | Live prices |
| Semi-dynamic | ISR (60s) | Governance proposals |

---

## Styling

### Tailwind CSS Conventions

```tsx
// Component with Tailwind classes
export const Card = ({ children, className }: CardProps) => {
  return (
    <div
      className={cn(
        // Base styles
        'rounded-lg border bg-card p-6 shadow-sm',
        // Hover/focus states
        'hover:shadow-md transition-shadow',
        // Custom classes
        className
      )}
    >
      {children}
    </div>
  );
};
```

### Class Merging Utility

```typescript
// lib/utils.ts
import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

export const cn = (...inputs: ClassValue[]) => {
  return twMerge(clsx(inputs));
};
```

### Design Tokens

```typescript
// tailwind.config.ts
export default {
  theme: {
    extend: {
      colors: {
        primary: {
          DEFAULT: 'hsl(var(--primary))',
          foreground: 'hsl(var(--primary-foreground))',
        },
        destructive: {
          DEFAULT: 'hsl(var(--destructive))',
          foreground: 'hsl(var(--destructive-foreground))',
        },
      },
    },
  },
};
```

---

## Testing

### Test File Structure

```
components/
└── StakingCard/
    ├── StakingCard.tsx
    ├── StakingCard.test.tsx    # Unit tests
    └── index.ts
```

### Testing Conventions

Follow the **AAA pattern**: Arrange, Act, Assert

```typescript
// StakingCard.test.tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { StakingCard } from './StakingCard';

describe('StakingCard', () => {
  it('should display staking position amount', () => {
    // Arrange
    const position = { amount: 1000n, rewards: 50n };

    // Act
    render(<StakingCard position={position} onUnstake={vi.fn()} />);

    // Assert
    expect(screen.getByText('1,000')).toBeInTheDocument();
  });

  it('should call onUnstake when unstake button is clicked', async () => {
    // Arrange
    const onUnstake = vi.fn();
    const position = { amount: 1000n, rewards: 50n };

    // Act
    render(<StakingCard position={position} onUnstake={onUnstake} />);
    fireEvent.click(screen.getByRole('button', { name: /unstake/i }));

    // Assert
    expect(onUnstake).toHaveBeenCalledWith(1000n);
  });
});
```

### Query Priority (Testing Library)

1. `getByRole` - Accessible queries (preferred)
2. `getByLabelText` - Form fields
3. `getByPlaceholderText` - Inputs
4. `getByText` - Non-interactive elements
5. `getByTestId` - Last resort

### Coverage Goals

- **80%+ overall coverage**
- Unit tests for utilities and hooks
- Integration tests for features
- E2E tests for critical user flows

---

## Accessibility

### Semantic HTML

```tsx
// Good: Semantic elements
<nav>
  <ul>
    <li><a href="/staking">Staking</a></li>
  </ul>
</nav>

<main>
  <article>
    <h1>Staking Dashboard</h1>
    <section>...</section>
  </article>
</main>

// Bad: Div soup
<div className="nav">
  <div className="nav-item">...</div>
</div>
```

### ARIA Attributes

```tsx
// Button with loading state
<button
  onClick={handleStake}
  disabled={isLoading}
  aria-busy={isLoading}
  aria-label={isLoading ? 'Staking in progress' : 'Stake tokens'}
>
  {isLoading ? <Spinner /> : 'Stake'}
</button>

// Form with error
<input
  id="amount"
  aria-invalid={!!error}
  aria-describedby={error ? 'amount-error' : undefined}
/>
{error && <span id="amount-error" role="alert">{error}</span>}
```

### Image Alt Text

```tsx
// Good: Descriptive alt text
<Image src="/logo.png" alt="Nexus Protocol logo" />

// Good: Decorative image
<Image src="/decoration.png" alt="" aria-hidden="true" />

// Bad: Redundant
<Image src="/logo.png" alt="Image of Nexus Protocol logo image" />
```

### Keyboard Navigation

- All interactive elements must be focusable
- Visible focus indicators
- Logical tab order
- Escape key closes modals

---

## Performance

### Image Optimization

```tsx
import Image from 'next/image';

// Always use Next.js Image component
<Image
  src="/hero.png"
  alt="Hero image"
  width={1200}
  height={600}
  priority // Above-the-fold images
/>

// Lazy load below-fold images (default)
<Image
  src="/feature.png"
  alt="Feature image"
  width={400}
  height={300}
  loading="lazy"
/>
```

### Code Splitting

```typescript
// Dynamic imports for heavy components
import dynamic from 'next/dynamic';

const Chart = dynamic(() => import('@/components/Chart'), {
  loading: () => <ChartSkeleton />,
  ssr: false, // Client-only component
});
```

### Memoization

Use sparingly, only after measuring:

```typescript
// Only memoize expensive computations
const sortedPositions = useMemo(
  () => positions.sort((a, b) => Number(b.amount - a.amount)),
  [positions]
);

// Only memoize callbacks passed to optimized children
const handleStake = useCallback(
  (amount: bigint) => stake(amount),
  [stake]
);
```

### Bundle Analysis

```bash
# Analyze bundle size
pnpm build
pnpm analyze
```

---

## Linting & Formatting

### ESLint Configuration

```javascript
// .eslintrc.js
module.exports = {
  extends: [
    'next/core-web-vitals',
    'plugin:@typescript-eslint/recommended',
    'plugin:react-hooks/recommended',
    'prettier',
  ],
  rules: {
    '@typescript-eslint/no-unused-vars': 'error',
    '@typescript-eslint/no-explicit-any': 'error',
    'react/prop-types': 'off',
    'react/react-in-jsx-scope': 'off',
    'import/order': [
      'error',
      {
        groups: ['builtin', 'external', 'internal', 'parent', 'sibling'],
        'newlines-between': 'always',
      },
    ],
  },
};
```

### Prettier Configuration

```json
// .prettierrc
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5",
  "printWidth": 100,
  "plugins": ["prettier-plugin-tailwindcss"]
}
```

### Pre-commit Hooks

```json
// package.json
{
  "scripts": {
    "lint": "eslint . --ext .ts,.tsx",
    "format": "prettier --write .",
    "type-check": "tsc --noEmit"
  },
  "lint-staged": {
    "*.{ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.{json,md}": ["prettier --write"]
  }
}
```

---

## Git Conventions

### Branch Naming

```
feature/add-staking-dashboard
fix/wallet-connection-error
refactor/reorganize-components
docs/update-readme
```

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(staking): add unstake functionality
fix(wallet): resolve connection timeout issue
refactor(components): extract shared card component
docs(readme): add setup instructions
test(staking): add unit tests for stake hook
chore(deps): update dependencies
```

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] E2E tests pass
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guide
- [ ] Self-reviewed
- [ ] No console.log statements
- [ ] Types are properly defined
```

---

## References

- [Vercel Style Guide](https://github.com/vercel/style-guide) - Official Next.js creator guidelines
- [Airbnb React/JSX Style Guide](https://github.com/airbnb/javascript/tree/master/react) - Industry standard React conventions
- [TypeScript Style Guide](https://mkosir.github.io/typescript-style-guide/) - Comprehensive TypeScript conventions
- [Next.js Documentation](https://nextjs.org/docs) - Official framework docs
- [React Documentation](https://react.dev) - Official React docs
- [TanStack Query](https://tanstack.com/query) - Server state management
- [Zustand](https://github.com/pmndrs/zustand) - Client state management
- [Testing Library](https://testing-library.com) - Testing utilities

---

*Last Updated: December 2024*
*Nexus Protocol Frontend Team*
