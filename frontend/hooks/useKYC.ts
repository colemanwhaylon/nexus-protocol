'use client';

import { useState, useCallback, useEffect } from 'react';
import { useAccount } from 'wagmi';
import { useNotifications } from './useNotifications';

// Types
export type PaymentMethod = 'nexus' | 'eth' | 'stripe';

export type KYCStatus =
  | 'not_started'
  | 'payment_pending'
  | 'payment_completed'
  | 'verification_pending'
  | 'verification_in_progress'
  | 'approved'
  | 'rejected'
  | 'expired';

export interface KYCPricing {
  serviceCode: string;
  serviceName: string;
  description: string;
  priceUSD: number;
  priceETH: number;
  priceNEXUS: number;
  discountPercent?: number;
}

export interface PaymentMethodInfo {
  code: PaymentMethod;
  name: string;
  isActive: boolean;
  feePercent: number;
  displayOrder: number;
}

export interface KYCVerification {
  id: string;
  walletAddress: string;
  status: KYCStatus;
  paymentMethod?: PaymentMethod;
  paymentId?: string;
  sumsubApplicantId?: string;
  createdAt: string;
  updatedAt: string;
  expiresAt?: string;
}

interface UseKYCOptions {
  autoRefresh?: boolean;
  refreshInterval?: number; // milliseconds
}

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

export function useKYC(options: UseKYCOptions = {}) {
  const { autoRefresh = true, refreshInterval = 30000 } = options;

  const { address } = useAccount();
  const {
    notifyKYCStarted,
    notifyKYCApproved,
    notifyKYCRejected,
    notifyPaymentRequired,
    notifyPaymentPending,
    notifyPaymentCompleted,
    notifyPaymentFailed,
  } = useNotifications();

  // State
  const [status, setStatus] = useState<KYCStatus>('not_started');
  const [verification, setVerification] = useState<KYCVerification | null>(null);
  const [pricing, setPricing] = useState<KYCPricing | null>(null);
  const [paymentMethods, setPaymentMethods] = useState<PaymentMethodInfo[]>([]);
  const [selectedPaymentMethod, setSelectedPaymentMethod] = useState<PaymentMethod>('nexus');
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [sumsubAccessToken, setSumsubAccessToken] = useState<string | null>(null);

  // Fetch KYC pricing
  const fetchPricing = useCallback(async () => {
    try {
      const response = await fetch(`${API_BASE}/api/v1/pricing/kyc_verification`);
      if (!response.ok) throw new Error('Failed to fetch pricing');
      const data = await response.json();
      setPricing(data);
    } catch (err) {
      console.error('Error fetching KYC pricing:', err);
    }
  }, []);

  // Fetch available payment methods
  const fetchPaymentMethods = useCallback(async () => {
    try {
      const response = await fetch(`${API_BASE}/api/v1/pricing/payment-methods`);
      if (!response.ok) throw new Error('Failed to fetch payment methods');
      const data = await response.json();
      setPaymentMethods(data.filter((m: PaymentMethodInfo) => m.isActive));
    } catch (err) {
      console.error('Error fetching payment methods:', err);
    }
  }, []);

  // Fetch current verification status
  const fetchVerificationStatus = useCallback(async () => {
    if (!address) return;

    try {
      const response = await fetch(`${API_BASE}/api/v1/kyc/status/${address}`);
      if (response.status === 404) {
        setStatus('not_started');
        setVerification(null);
        return;
      }
      if (!response.ok) throw new Error('Failed to fetch verification status');

      const data: KYCVerification = await response.json();
      setVerification(data);
      setStatus(data.status);

      // Notify on status changes
      if (data.status === 'approved') {
        notifyKYCApproved();
      } else if (data.status === 'rejected') {
        notifyKYCRejected();
      }
    } catch (err) {
      console.error('Error fetching verification status:', err);
    }
  }, [address, notifyKYCApproved, notifyKYCRejected]);

  // Start KYC process
  const startVerification = useCallback(async (paymentMethod: PaymentMethod = selectedPaymentMethod) => {
    if (!address) {
      setError('Wallet not connected');
      return null;
    }

    setIsLoading(true);
    setError(null);

    try {
      // Step 1: Create payment session
      const paymentResponse = await fetch(`${API_BASE}/api/v1/payments/create`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          wallet_address: address,
          service_code: 'kyc_verification',
          payment_method: paymentMethod,
        }),
      });

      if (!paymentResponse.ok) {
        const errData = await paymentResponse.json();
        throw new Error(errData.error || 'Failed to create payment session');
      }

      const paymentData = await paymentResponse.json();

      if (paymentMethod === 'stripe' && paymentData.checkout_url) {
        // Redirect to Stripe checkout
        notifyPaymentPending('Credit Card', pricing?.priceUSD?.toString() || '15', 'USD');
        window.location.href = paymentData.checkout_url;
        return paymentData;
      }

      // For crypto payments, return payment details
      notifyPaymentRequired('KYC Verification',
        paymentMethod === 'nexus' ? pricing?.priceNEXUS?.toString() || '150' : pricing?.priceETH?.toString() || '0.005',
        paymentMethod === 'nexus' ? 'NEXUS' : 'ETH'
      );

      setStatus('payment_pending');
      return paymentData;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to start verification';
      setError(message);
      notifyPaymentFailed(paymentMethod, message);
      return null;
    } finally {
      setIsLoading(false);
    }
  }, [address, selectedPaymentMethod, pricing, notifyPaymentPending, notifyPaymentRequired, notifyPaymentFailed]);

  // Confirm crypto payment
  const confirmCryptoPayment = useCallback(async (paymentId: string, txHash: string) => {
    if (!address) return false;

    setIsLoading(true);
    try {
      const response = await fetch(`${API_BASE}/api/v1/payments/crypto/confirm`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          payment_id: paymentId,
          tx_hash: txHash,
        }),
      });

      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.error || 'Failed to confirm payment');
      }

      notifyPaymentCompleted(selectedPaymentMethod,
        selectedPaymentMethod === 'nexus' ? pricing?.priceNEXUS?.toString() || '150' : pricing?.priceETH?.toString() || '0.005',
        selectedPaymentMethod === 'nexus' ? 'NEXUS' : 'ETH',
        txHash
      );

      setStatus('payment_completed');

      // Automatically start Sumsub verification
      await startSumsubVerification();

      return true;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Payment confirmation failed';
      setError(message);
      notifyPaymentFailed(selectedPaymentMethod, message);
      return false;
    } finally {
      setIsLoading(false);
    }
  }, [address, selectedPaymentMethod, pricing, notifyPaymentCompleted, notifyPaymentFailed]);

  // Start Sumsub verification (after payment)
  const startSumsubVerification = useCallback(async () => {
    if (!address) return null;

    setIsLoading(true);
    try {
      // Create applicant
      const applicantResponse = await fetch(`${API_BASE}/api/v1/sumsub/applicant`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ wallet_address: address }),
      });

      if (!applicantResponse.ok) {
        throw new Error('Failed to create verification applicant');
      }

      const applicantData = await applicantResponse.json();

      // Get access token for SDK
      const tokenResponse = await fetch(`${API_BASE}/api/v1/sumsub/access-token/${applicantData.applicant_id}`);
      if (!tokenResponse.ok) {
        throw new Error('Failed to get verification access token');
      }

      const tokenData = await tokenResponse.json();
      setSumsubAccessToken(tokenData.token);

      notifyKYCStarted();
      setStatus('verification_in_progress');

      return {
        applicantId: applicantData.applicant_id,
        accessToken: tokenData.token,
      };
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to start verification';
      setError(message);
      return null;
    } finally {
      setIsLoading(false);
    }
  }, [address, notifyKYCStarted]);

  // Calculate price with payment method fees
  const calculateTotalPrice = useCallback((method: PaymentMethod) => {
    if (!pricing) return null;

    const paymentMethodInfo = paymentMethods.find(m => m.code === method);
    const feePercent = paymentMethodInfo?.feePercent || 0;

    let basePrice: number;
    let currency: string;

    switch (method) {
      case 'nexus':
        basePrice = pricing.priceNEXUS;
        currency = 'NEXUS';
        // NEXUS gets 10% discount
        basePrice = basePrice * 0.9;
        break;
      case 'eth':
        basePrice = pricing.priceETH;
        currency = 'ETH';
        break;
      case 'stripe':
        basePrice = pricing.priceUSD;
        currency = 'USD';
        break;
      default:
        return null;
    }

    const fee = basePrice * (feePercent / 100);
    const total = basePrice + fee;

    return {
      basePrice,
      fee,
      total,
      currency,
      feePercent,
    };
  }, [pricing, paymentMethods]);

  // Check if user is verified
  const isVerified = status === 'approved';

  // Check if verification is in progress
  const isInProgress = ['payment_pending', 'payment_completed', 'verification_pending', 'verification_in_progress'].includes(status);

  // Check if verification can be retried
  const canRetry = status === 'rejected' || status === 'expired';

  // Initial data fetch
  useEffect(() => {
    fetchPricing();
    fetchPaymentMethods();
  }, [fetchPricing, fetchPaymentMethods]);

  // Fetch status when address changes
  useEffect(() => {
    if (address) {
      fetchVerificationStatus();
    }
  }, [address, fetchVerificationStatus]);

  // Auto-refresh status
  useEffect(() => {
    if (!autoRefresh || !address || !isInProgress) return;

    const interval = setInterval(() => {
      fetchVerificationStatus();
    }, refreshInterval);

    return () => clearInterval(interval);
  }, [autoRefresh, address, isInProgress, refreshInterval, fetchVerificationStatus]);

  return {
    // Status
    status,
    isVerified,
    isInProgress,
    canRetry,
    verification,

    // Pricing
    pricing,
    paymentMethods,
    selectedPaymentMethod,
    setSelectedPaymentMethod,
    calculateTotalPrice,

    // Sumsub
    sumsubAccessToken,

    // Actions
    startVerification,
    confirmCryptoPayment,
    startSumsubVerification,
    refreshStatus: fetchVerificationStatus,

    // Loading/Error
    isLoading,
    error,
    clearError: () => setError(null),
  };
}

// Re-export types
export type { PaymentMethod, KYCStatus, KYCPricing, PaymentMethodInfo, KYCVerification };
