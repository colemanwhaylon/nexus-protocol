# Frontend - Claude Code Instructions

> **Purpose**: This document defines React/Next.js conventions, component patterns, and state management rules for the frontend. Claude MUST read and apply these rules before writing any frontend code.

---

## Tech Stack

- **Framework**: Next.js 14 (App Router)
- **Language**: TypeScript (strict mode)
- **Styling**: Tailwind CSS + shadcn/ui components
- **State**: Zustand (global), React Query (server state)
- **Web3**: wagmi v2 + viem + RainbowKit
- **Forms**: React Hook Form + Zod validation

---

## SOLID Principles in React

### S - Single Responsibility

Each component should do ONE thing:

```
WRONG:
┌─────────────────────────────────────────────────────────────┐
│ function StakingPage() {                                    │
│   // Fetches data                                           │
│   // Validates input                                        │
│   // Handles form submission                                │
│   // Formats numbers                                        │
│   // Shows notifications                                    │
│   // Manages local state                                    │
│   // Manages global state                                   │
│   return <div>...</div>                                     │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘

RIGHT:
┌─────────────────────────────────────────────────────────────┐
│ // page.tsx - Orchestration only                            │
│ function StakingPage() {                                    │
│   return (                                                  │
│     <StakingProvider>                                       │
│       <StakingOverview />                                   │
│       <StakeForm />                                         │
│       <StakingPosition />                                   │
│     </StakingProvider>                                      │
│   )                                                         │
│ }                                                           │
│                                                             │
│ // StakeForm.tsx - Form handling only                       │
│ // StakingPosition.tsx - Display only                       │
│ // useStaking.ts - Contract interactions only               │
│ // stakingStore.ts - Global state only                      │
└─────────────────────────────────────────────────────────────┘
```

### O - Open/Closed Principle

Components should be extendable without modification:

```typescript
// WRONG: Adding a new card type requires modifying the component
function Card({ type }: { type: 'stake' | 'reward' }) {
  if (type === 'stake') return <StakeCard />
  if (type === 'reward') return <RewardCard />
  // Must modify to add new types
}

// RIGHT: Use composition
function Card({ children, header, footer }: CardProps) {
  return (
    <div className="rounded-lg border p-4">
      {header && <div className="mb-4">{header}</div>}
      {children}
      {footer && <div className="mt-4">{footer}</div>}
    </div>
  )
}
```

### D - Dependency Inversion

Components depend on abstractions (hooks), not implementations:

```typescript
// WRONG: Component calls contract directly
function StakeButton() {
  const { writeContract } = useWriteContract()

  const handleStake = () => {
    writeContract({
      address: '0x...',  // Hardcoded
      abi: stakingAbi,
      functionName: 'stake',
    })
  }
}

// RIGHT: Component uses hook abstraction
function StakeButton() {
  const { stake, isLoading } = useStaking()

  const handleStake = () => {
    stake({ amount: parseEther('100') })
  }
}

// Hook encapsulates all contract details
function useStaking() {
  const chainId = useChainId()
  const addresses = getContractAddresses(chainId)
  // All contract logic here
}
```

---

## Directory Structure

```
frontend/
├── app/                          # Next.js App Router pages
│   ├── (routes)/                 # Grouped routes
│   │   ├── staking/
│   │   │   ├── page.tsx          # Page component
│   │   │   └── loading.tsx       # Loading state
│   │   ├── governance/
│   │   └── admin/
│   ├── layout.tsx                # Root layout
│   └── providers.tsx             # Context providers
├── components/
│   ├── ui/                       # Base UI components (shadcn)
│   │   ├── button.tsx
│   │   ├── card.tsx
│   │   └── input.tsx
│   ├── features/                 # Feature-specific components
│   │   ├── Staking/
│   │   │   ├── StakeForm.tsx
│   │   │   ├── StakingPosition.tsx
│   │   │   └── index.ts          # Barrel export
│   │   ├── Governance/
│   │   ├── NFT/
│   │   └── Admin/
│   ├── layout/                   # Layout components
│   │   ├── Header.tsx
│   │   ├── Sidebar.tsx
│   │   └── Footer.tsx
│   └── guards/                   # Access control components
│       ├── ConnectedGuard.tsx
│       └── RoleGuard.tsx
├── hooks/                        # Custom React hooks
│   ├── useStaking.ts             # Staking contract hook
│   ├── useGovernance.ts          # Governance contract hook
│   ├── useNFT.ts                 # NFT contract hook
│   ├── useAdmin.ts               # Admin operations hook
│   └── useNotifications.ts       # Toast notifications hook
├── stores/                       # Zustand stores
│   ├── notificationStore.ts
│   └── uiStore.ts
├── lib/
│   ├── contracts/                # Contract ABIs and addresses
│   │   ├── abis/
│   │   └── addresses.ts
│   ├── utils/                    # Utility functions
│   │   ├── format.ts             # Number/date formatting
│   │   └── validation.ts         # Zod schemas
│   └── config/                   # App configuration
│       └── wagmi.ts
└── types/                        # TypeScript types
    ├── contracts.ts
    └── api.ts
```

---

## Component Patterns

### Page Components

Pages are thin orchestration layers:

```typescript
// app/staking/page.tsx
'use client'

import { StakingOverview, StakeForm, StakingPosition } from '@/components/features/Staking'
import { ConnectedGuard } from '@/components/guards/ConnectedGuard'

export default function StakingPage() {
  return (
    <ConnectedGuard>
      <div className="container mx-auto px-4 py-8">
        <h1 className="text-3xl font-bold mb-8">Staking</h1>
        <div className="grid gap-6 lg:grid-cols-2">
          <StakingOverview />
          <StakeForm />
        </div>
        <StakingPosition />
      </div>
    </ConnectedGuard>
  )
}
```

### Feature Components

Feature components handle their specific domain:

```typescript
// components/features/Staking/StakeForm.tsx
'use client'

import { useState } from 'react'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { parseEther } from 'viem'
import { useStaking } from '@/hooks/useStaking'
import { useNotifications } from '@/hooks/useNotifications'
import { stakeSchema, type StakeFormData } from '@/lib/utils/validation'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'

export function StakeForm() {
  const { stake, isLoading, balance } = useStaking()
  const { notifyStakeSuccess, notifyError } = useNotifications()

  const form = useForm<StakeFormData>({
    resolver: zodResolver(stakeSchema),
    defaultValues: { amount: '' },
  })

  const onSubmit = async (data: StakeFormData) => {
    try {
      const hash = await stake({ amount: parseEther(data.amount) })
      notifyStakeSuccess(data.amount, hash)
      form.reset()
    } catch (error) {
      notifyError('Stake failed', error)
    }
  }

  return (
    <form onSubmit={form.handleSubmit(onSubmit)} className="space-y-4">
      <Input
        {...form.register('amount')}
        placeholder="Amount to stake"
        error={form.formState.errors.amount?.message}
      />
      <Button type="submit" disabled={isLoading}>
        {isLoading ? 'Staking...' : 'Stake'}
      </Button>
    </form>
  )
}
```

---

## Hook Patterns

### Contract Hooks

Each contract domain has ONE hook:

```typescript
// hooks/useStaking.ts
import { useReadContract, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { useChainId, useAccount } from 'wagmi'
import { parseEther, formatEther } from 'viem'
import { getContractAddresses } from '@/lib/contracts/addresses'
import { nexusStakingAbi } from '@/lib/contracts/abis/nexusStaking'

export function useStaking() {
  const chainId = useChainId()
  const { address: userAddress } = useAccount()
  const addresses = getContractAddresses(chainId)

  // Read: User's staked balance
  const { data: stakedBalance, refetch: refetchBalance } = useReadContract({
    address: addresses.nexusStaking,
    abi: nexusStakingAbi,
    functionName: 'balanceOf',
    args: userAddress ? [userAddress] : undefined,
    enabled: !!userAddress,
  })

  // Read: Total staked
  const { data: totalStaked } = useReadContract({
    address: addresses.nexusStaking,
    abi: nexusStakingAbi,
    functionName: 'totalStaked',
  })

  // Write: Stake tokens
  const { writeContractAsync, isPending: isStaking } = useWriteContract()

  const stake = async ({ amount }: { amount: bigint }) => {
    const hash = await writeContractAsync({
      address: addresses.nexusStaking,
      abi: nexusStakingAbi,
      functionName: 'stake',
      args: [amount],
    })
    await refetchBalance()
    return hash
  }

  const unstake = async ({ amount }: { amount: bigint }) => {
    const hash = await writeContractAsync({
      address: addresses.nexusStaking,
      abi: nexusStakingAbi,
      functionName: 'requestUnstake',
      args: [amount],
    })
    await refetchBalance()
    return hash
  }

  return {
    // Data
    stakedBalance: stakedBalance ? formatEther(stakedBalance) : '0',
    totalStaked: totalStaked ? formatEther(totalStaked) : '0',

    // Actions
    stake,
    unstake,

    // Loading states
    isStaking,

    // Refetch
    refetchBalance,
  }
}
```

---

## State Management

### Global State (Zustand)

For UI state that persists across pages:

```typescript
// stores/notificationStore.ts
import { create } from 'zustand'

export type NotificationCategory =
  | 'transaction' | 'approval' | 'stake' | 'unstake'
  | 'delegate' | 'mint' | 'governance' | 'system'
  | 'kyc' | 'admin' | 'emergency' | 'nft'

interface Notification {
  id: string
  type: 'info' | 'success' | 'warning' | 'error'
  title: string
  message: string
  category: NotificationCategory
  txHash?: string
  timestamp: number
}

interface NotificationStore {
  notifications: Notification[]
  addNotification: (notification: Omit<Notification, 'id' | 'timestamp'>) => void
  removeNotification: (id: string) => void
  clearAll: () => void
}

export const useNotificationStore = create<NotificationStore>((set) => ({
  notifications: [],

  addNotification: (notification) => set((state) => ({
    notifications: [
      ...state.notifications,
      {
        ...notification,
        id: crypto.randomUUID(),
        timestamp: Date.now(),
      },
    ],
  })),

  removeNotification: (id) => set((state) => ({
    notifications: state.notifications.filter((n) => n.id !== id),
  })),

  clearAll: () => set({ notifications: [] }),
}))
```

### Server State (React Query)

For data fetched from APIs:

```typescript
// Use React Query for server state
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query'

function useProposals() {
  return useQuery({
    queryKey: ['proposals'],
    queryFn: fetchProposals,
    staleTime: 30_000, // 30 seconds
  })
}
```

---

## Form Validation

Use Zod schemas for all forms:

```typescript
// lib/utils/validation.ts
import { z } from 'zod'
import { isAddress } from 'viem'

export const stakeSchema = z.object({
  amount: z.string()
    .min(1, 'Amount is required')
    .refine((val) => !isNaN(Number(val)), 'Must be a number')
    .refine((val) => Number(val) > 0, 'Must be greater than 0'),
})

export const transferSchema = z.object({
  recipient: z.string()
    .min(1, 'Recipient is required')
    .refine((val) => isAddress(val), 'Invalid address'),
  amount: z.string()
    .min(1, 'Amount is required')
    .refine((val) => Number(val) > 0, 'Must be greater than 0'),
})

export type StakeFormData = z.infer<typeof stakeSchema>
export type TransferFormData = z.infer<typeof transferSchema>
```

---

## Naming Conventions

### Files

| Type | Pattern | Example |
|------|---------|---------|
| Page | `page.tsx` | `app/staking/page.tsx` |
| Layout | `layout.tsx` | `app/layout.tsx` |
| Loading | `loading.tsx` | `app/staking/loading.tsx` |
| Component | `PascalCase.tsx` | `StakeForm.tsx` |
| Hook | `useCamelCase.ts` | `useStaking.ts` |
| Store | `camelCaseStore.ts` | `notificationStore.ts` |
| Utility | `camelCase.ts` | `format.ts` |
| Type | `camelCase.ts` | `contracts.ts` |

### Components

| Type | Prefix/Suffix | Example |
|------|---------------|---------|
| Page component | None | `StakingPage` |
| Feature component | None | `StakeForm` |
| UI component | None | `Button` |
| Guard component | `*Guard` | `ConnectedGuard` |
| Provider | `*Provider` | `WagmiProvider` |

### Hooks

| Purpose | Pattern | Example |
|---------|---------|---------|
| Contract interaction | `use{Domain}` | `useStaking` |
| Notification | `useNotifications` | - |
| Form state | `useForm` (from react-hook-form) | - |
| Local state | `useState` (React) | - |
| Global state | `use{Store}Store` | `useNotificationStore` |

---

## Error Handling

### In Components

```typescript
function StakeForm() {
  const { notifyError } = useNotifications()

  const onSubmit = async (data: StakeFormData) => {
    try {
      await stake({ amount: parseEther(data.amount) })
    } catch (error) {
      // User-friendly error message
      if (error instanceof ContractError) {
        notifyError('Transaction Failed', error.shortMessage)
      } else {
        notifyError('Stake Failed', 'Please try again')
      }
      // Log for debugging
      console.error('Stake error:', error)
    }
  }
}
```

### Error Boundaries

Wrap feature sections in error boundaries:

```typescript
// components/ErrorBoundary.tsx
'use client'

import { Component, type ReactNode } from 'react'

interface Props {
  children: ReactNode
  fallback?: ReactNode
}

interface State {
  hasError: boolean
}

export class ErrorBoundary extends Component<Props, State> {
  state = { hasError: false }

  static getDerivedStateFromError() {
    return { hasError: true }
  }

  render() {
    if (this.state.hasError) {
      return this.props.fallback || (
        <div className="p-4 border border-destructive rounded-lg">
          <p>Something went wrong. Please refresh the page.</p>
        </div>
      )
    }
    return this.props.children
  }
}
```

---

## Loading States

### Page Loading

Use Next.js loading.tsx:

```typescript
// app/staking/loading.tsx
import { Skeleton } from '@/components/ui/skeleton'

export default function StakingLoading() {
  return (
    <div className="container mx-auto px-4 py-8">
      <Skeleton className="h-10 w-48 mb-8" />
      <div className="grid gap-6 lg:grid-cols-2">
        <Skeleton className="h-64" />
        <Skeleton className="h-64" />
      </div>
    </div>
  )
}
```

### Component Loading

Use loading props:

```typescript
function StakeForm({ isLoading }: { isLoading?: boolean }) {
  if (isLoading) {
    return <Skeleton className="h-32" />
  }

  return <form>...</form>
}
```

---

## Forbidden Patterns

**NEVER do these:**

1. `console.log()` for user-facing feedback (use notifications)
2. `setTimeout()` to fake async operations
3. Hardcoded contract addresses in components
4. Direct contract calls in components (use hooks)
5. Mock data in production pages (use feature flags)
6. `any` type (use proper TypeScript types)
7. Inline styles (use Tailwind classes)
8. `useEffect` for data fetching (use React Query or wagmi hooks)
9. Global variables for state (use Zustand stores)
10. Ignoring form validation errors

---

## Code Review Checklist

Before submitting frontend code:

- [ ] Component has single responsibility
- [ ] Contract logic in hooks, not components
- [ ] Form uses Zod validation
- [ ] Loading states handled
- [ ] Error states handled with notifications
- [ ] TypeScript types defined (no `any`)
- [ ] Tailwind for styling (no inline styles)
- [ ] Page uses `'use client'` if needed
- [ ] Exports via barrel file (`index.ts`)
- [ ] Hook follows naming convention (`use*`)

---

## Accessibility

All components must be accessible:

```typescript
// Button with proper accessibility
<Button
  onClick={handleStake}
  disabled={isLoading}
  aria-busy={isLoading}
  aria-label="Stake tokens"
>
  {isLoading ? 'Staking...' : 'Stake'}
</Button>

// Form with proper labels
<label htmlFor="amount" className="sr-only">
  Amount to stake
</label>
<Input
  id="amount"
  name="amount"
  aria-describedby="amount-error"
/>
{error && <p id="amount-error" role="alert">{error}</p>}
```

---

## Performance

### Memoization

Use memo for expensive renders:

```typescript
import { memo } from 'react'

export const NFTCard = memo(function NFTCard({ tokenId, metadata }: NFTCardProps) {
  // Expensive render
})
```

### Code Splitting

Use dynamic imports for large components:

```typescript
import dynamic from 'next/dynamic'

const ProposalDetail = dynamic(
  () => import('@/components/features/Governance/ProposalDetail'),
  { loading: () => <Skeleton className="h-64" /> }
)
```

---

## When In Doubt

1. **Logic**: Put it in a hook
2. **State**: Use Zustand (UI) or React Query (server)
3. **Styling**: Use Tailwind classes
4. **Types**: Define explicit TypeScript interfaces
5. **Errors**: Show user-friendly notifications
