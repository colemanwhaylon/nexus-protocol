'use client';

import { useState, useCallback, useEffect } from 'react';
import { useAccount } from 'wagmi';

// API base URL
const API_BASE_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

// Types matching the backend repository types
export interface Pricing {
  id: string;
  service_code: string;
  service_name: string;
  description: string;
  cost_usd: number;
  cost_provider: string;
  price_usd: number;
  price_eth: number | null;
  price_nexus: number | null;
  markup_percent: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
  updated_by?: string;
}

export interface PricingUpdate {
  price_usd?: number;
  price_eth?: number;
  price_nexus?: number;
  markup_percent?: number;
  is_active?: boolean;
  operator: string;
  reason?: string;
}

export interface PaymentMethod {
  id: string;
  method_code: string;
  method_name: string;
  is_active: boolean;
  processor_config: Record<string, unknown>;
  min_amount_usd: number;
  max_amount_usd: number | null;
  fee_percent: number;
  display_order: number;
  created_at: string;
  updated_at: string;
}

export interface PaymentMethodUpdate {
  is_active?: boolean;
  min_amount_usd?: number;
  max_amount_usd?: number;
  fee_percent?: number;
  display_order?: number;
  operator: string;
}

export interface PricingHistoryEntry {
  id: string;
  pricing_id: string;
  old_price_usd: number | null;
  old_price_eth: number | null;
  old_price_nexus: number | null;
  old_markup_percent: number | null;
  new_price_usd: number | null;
  new_price_eth: number | null;
  new_price_nexus: number | null;
  new_markup_percent: number | null;
  changed_by: string;
  changed_at: string;
  change_reason: string;
}

interface ApiResponse<T> {
  success: boolean;
  data?: T;
  message?: string;
  error?: string;
}

interface UsePricingOptions {
  autoRefresh?: boolean;
  refreshInterval?: number;
}

export function usePricing(options: UsePricingOptions = {}) {
  const { autoRefresh = false, refreshInterval = 30000 } = options;
  const { address } = useAccount();

  // State
  const [pricingList, setPricingList] = useState<Pricing[]>([]);
  const [paymentMethods, setPaymentMethods] = useState<PaymentMethod[]>([]);
  const [pricingHistory, setPricingHistory] = useState<Record<string, PricingHistoryEntry[]>>({});
  const [isLoading, setIsLoading] = useState(false);
  const [isUpdating, setIsUpdating] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Clear error
  const clearError = useCallback(() => {
    setError(null);
  }, []);

  // Fetch all pricing
  const fetchPricing = useCallback(async (activeOnly = false) => {
    setIsLoading(true);
    setError(null);

    try {
      const response = await fetch(
        `${API_BASE_URL}/api/v1/pricing${activeOnly ? '?active_only=true' : ''}`
      );
      const data: ApiResponse<{ pricing: Pricing[]; total: number }> = await response.json();

      if (data.success && data.data) {
        setPricingList(data.data.pricing);
      } else {
        setError(data.error || 'Failed to fetch pricing');
      }
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Network error';
      setError(message);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Fetch single pricing
  const fetchPricingByCode = useCallback(async (serviceCode: string): Promise<Pricing | null> => {
    try {
      const response = await fetch(`${API_BASE_URL}/api/v1/pricing/${serviceCode}`);
      const data: ApiResponse<Pricing> = await response.json();

      if (data.success && data.data) {
        return data.data;
      }
      return null;
    } catch {
      return null;
    }
  }, []);

  // Update pricing
  const updatePricing = useCallback(
    async (serviceCode: string, update: Omit<PricingUpdate, 'operator'>): Promise<boolean> => {
      if (!address) {
        setError('Wallet not connected');
        return false;
      }

      setIsUpdating(true);
      setError(null);

      try {
        const response = await fetch(`${API_BASE_URL}/api/v1/pricing/${serviceCode}`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            ...update,
            operator: address,
          }),
        });

        const data: ApiResponse<Pricing> = await response.json();

        if (data.success) {
          // Update local state
          setPricingList((prev) =>
            prev.map((p) => (p.service_code === serviceCode && data.data ? data.data : p))
          );
          return true;
        } else {
          setError(data.error || 'Failed to update pricing');
          return false;
        }
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Network error';
        setError(message);
        return false;
      } finally {
        setIsUpdating(false);
      }
    },
    [address]
  );

  // Fetch pricing history
  const fetchPricingHistory = useCallback(
    async (serviceCode: string, limit = 20): Promise<PricingHistoryEntry[]> => {
      try {
        const response = await fetch(
          `${API_BASE_URL}/api/v1/pricing/${serviceCode}/history?limit=${limit}`
        );
        const data: ApiResponse<{ service_code: string; history: PricingHistoryEntry[]; total: number }> =
          await response.json();

        if (data.success && data.data) {
          setPricingHistory((prev) => ({
            ...prev,
            [serviceCode]: data.data!.history,
          }));
          return data.data.history;
        }
        return [];
      } catch {
        return [];
      }
    },
    []
  );

  // Fetch all payment methods
  const fetchPaymentMethods = useCallback(async (activeOnly = false) => {
    try {
      const response = await fetch(
        `${API_BASE_URL}/api/v1/payment-methods${activeOnly ? '?active_only=true' : '?active_only=false'}`
      );
      const data: ApiResponse<{ methods: PaymentMethod[]; total: number }> = await response.json();

      if (data.success && data.data) {
        setPaymentMethods(data.data.methods);
      }
    } catch (err) {
      console.error('Failed to fetch payment methods:', err);
    }
  }, []);

  // Update payment method
  const updatePaymentMethod = useCallback(
    async (methodCode: string, update: Omit<PaymentMethodUpdate, 'operator'>): Promise<boolean> => {
      if (!address) {
        setError('Wallet not connected');
        return false;
      }

      setIsUpdating(true);
      setError(null);

      try {
        const response = await fetch(`${API_BASE_URL}/api/v1/payment-methods/${methodCode}`, {
          method: 'PUT',
          headers: {
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            ...update,
            operator: address,
          }),
        });

        const data: ApiResponse<PaymentMethod> = await response.json();

        if (data.success) {
          // Update local state
          setPaymentMethods((prev) =>
            prev.map((m) => (m.method_code === methodCode && data.data ? data.data : m))
          );
          return true;
        } else {
          setError(data.error || 'Failed to update payment method');
          return false;
        }
      } catch (err) {
        const message = err instanceof Error ? err.message : 'Network error';
        setError(message);
        return false;
      } finally {
        setIsUpdating(false);
      }
    },
    [address]
  );

  // Toggle payment method active status
  const togglePaymentMethod = useCallback(
    async (methodCode: string, isActive: boolean): Promise<boolean> => {
      return updatePaymentMethod(methodCode, { is_active: isActive });
    },
    [updatePaymentMethod]
  );

  // Refresh all data
  const refresh = useCallback(async () => {
    await Promise.all([fetchPricing(), fetchPaymentMethods()]);
  }, [fetchPricing, fetchPaymentMethods]);

  // Initial fetch
  useEffect(() => {
    fetchPricing();
    fetchPaymentMethods();
  }, [fetchPricing, fetchPaymentMethods]);

  // Auto refresh
  useEffect(() => {
    if (!autoRefresh) return;

    const interval = setInterval(() => {
      refresh();
    }, refreshInterval);

    return () => clearInterval(interval);
  }, [autoRefresh, refreshInterval, refresh]);

  return {
    // Data
    pricingList,
    paymentMethods,
    pricingHistory,

    // Actions
    fetchPricing,
    fetchPricingByCode,
    updatePricing,
    fetchPricingHistory,
    fetchPaymentMethods,
    updatePaymentMethod,
    togglePaymentMethod,
    refresh,

    // State
    isLoading,
    isUpdating,
    error,
    clearError,
  };
}
