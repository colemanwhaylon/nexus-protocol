'use client';

import { useState, useCallback, useEffect } from 'react';
import { useAccount } from 'wagmi';
import { useNotifications } from './useNotifications';

// Types matching backend
export type KYCStatusType = 'pending' | 'approved' | 'rejected' | 'expired' | 'suspended';
export type RiskLevel = 'low' | 'medium' | 'high';

export interface KYCRegistration {
  address: string;
  status: KYCStatusType;
  level: number;
  jurisdiction: string;
  verified_at?: string;
  expires_at?: string;
  rejection_reason?: string;
  suspension_reason?: string;
  document_hash?: string;
  risk_score: number;
  accredited_investor: boolean;
  created_at: string;
  updated_at: string;
  reviewed_by?: string;
}

export interface KYCListResponse {
  success: boolean;
  registrations: KYCRegistration[];
  total: number;
  page: number;
  page_size: number;
}

interface UseAdminKYCOptions {
  autoRefresh?: boolean;
  refreshInterval?: number; // milliseconds
}

const API_BASE = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8080';

// Map risk score to risk level
function getRiskLevel(riskScore: number): RiskLevel {
  if (riskScore >= 70) return 'high';
  if (riskScore >= 40) return 'medium';
  return 'low';
}

// Map backend registration to frontend format
interface FormattedKYCRequest {
  id: string;
  address: string;
  submittedAt: number;
  status: 'pending' | 'approved' | 'rejected';
  riskLevel: RiskLevel;
  jurisdiction?: string;
  level?: number;
  rejectionReason?: string;
}

function formatRegistration(reg: KYCRegistration): FormattedKYCRequest {
  // Map backend status to frontend status
  let frontendStatus: 'pending' | 'approved' | 'rejected' = 'pending';
  if (reg.status === 'approved') frontendStatus = 'approved';
  if (reg.status === 'rejected' || reg.status === 'suspended' || reg.status === 'expired') {
    frontendStatus = 'rejected';
  }

  return {
    id: reg.address, // Use address as ID since backend doesn't provide separate ID
    address: reg.address,
    submittedAt: Math.floor(new Date(reg.created_at).getTime() / 1000),
    status: frontendStatus,
    riskLevel: getRiskLevel(reg.risk_score),
    jurisdiction: reg.jurisdiction,
    level: reg.level,
    rejectionReason: reg.rejection_reason || reg.suspension_reason,
  };
}

export function useAdminKYC(options: UseAdminKYCOptions = {}) {
  const { autoRefresh = true, refreshInterval = 30000 } = options;

  const { address: userAddress } = useAccount();
  const { notifySuccess, notifyError } = useNotifications();

  // State
  const [registrations, setRegistrations] = useState<KYCRegistration[]>([]);
  const [formattedRequests, setFormattedRequests] = useState<FormattedKYCRequest[]>([]);
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [isApproving, setIsApproving] = useState(false);
  const [isRejecting, setIsRejecting] = useState(false);

  // Fetch all registrations (using pending endpoint as base, then add more)
  const fetchRegistrations = useCallback(async () => {
    setIsLoading(true);
    setError(null);

    try {
      // Fetch pending registrations
      const pendingResponse = await fetch(`${API_BASE}/api/v1/kyc/pending?page=1&page_size=100`);

      if (!pendingResponse.ok) {
        throw new Error('Failed to fetch pending registrations');
      }

      const pendingData: KYCListResponse = await pendingResponse.json();

      // For now, we primarily work with pending registrations for the admin page
      // In a production scenario, you'd have a separate endpoint for all registrations
      const allRegistrations = pendingData.registrations || [];

      setRegistrations(allRegistrations);
      setFormattedRequests(allRegistrations.map(formatRegistration));
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to fetch KYC registrations';
      setError(message);
      console.error('Error fetching KYC registrations:', err);
    } finally {
      setIsLoading(false);
    }
  }, []);

  // Approve KYC
  const approveKYC = useCallback(async (address: string, reviewerAddress?: string) => {
    const reviewer = reviewerAddress || userAddress;
    if (!reviewer) {
      notifyError('Approval Failed', 'Wallet not connected');
      return false;
    }

    setIsApproving(true);
    try {
      const response = await fetch(`${API_BASE}/api/v1/kyc/update`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          address,
          status: 'approved',
          level: 2, // Standard verification level
          reviewer,
        }),
      });

      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.message || 'Failed to approve KYC');
      }

      notifySuccess('KYC Approved', `Successfully approved KYC for ${address.slice(0, 6)}...${address.slice(-4)}`, 'admin');

      // Refresh the list
      await fetchRegistrations();
      return true;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to approve KYC';
      notifyError('Approval Failed', message);
      return false;
    } finally {
      setIsApproving(false);
    }
  }, [userAddress, fetchRegistrations, notifySuccess, notifyError]);

  // Reject KYC
  const rejectKYC = useCallback(async (address: string, reason?: string, reviewerAddress?: string) => {
    const reviewer = reviewerAddress || userAddress;
    if (!reviewer) {
      notifyError('Rejection Failed', 'Wallet not connected');
      return false;
    }

    setIsRejecting(true);
    try {
      const response = await fetch(`${API_BASE}/api/v1/kyc/update`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          address,
          status: 'rejected',
          rejection_reason: reason || 'Verification requirements not met',
          reviewer,
        }),
      });

      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.message || 'Failed to reject KYC');
      }

      notifySuccess('KYC Rejected', `KYC rejected for ${address.slice(0, 6)}...${address.slice(-4)}`, 'admin');

      // Refresh the list
      await fetchRegistrations();
      return true;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to reject KYC';
      notifyError('Rejection Failed', message);
      return false;
    } finally {
      setIsRejecting(false);
    }
  }, [userAddress, fetchRegistrations, notifySuccess, notifyError]);

  // Add to whitelist
  const addToWhitelist = useCallback(async (address: string, reason?: string) => {
    if (!userAddress) {
      notifyError('Operation Failed', 'Wallet not connected');
      return false;
    }

    try {
      const response = await fetch(`${API_BASE}/api/v1/kyc/whitelist`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          address,
          operator: userAddress,
          reason: reason || 'Manual whitelist addition',
        }),
      });

      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.message || 'Failed to add to whitelist');
      }

      notifySuccess('Whitelist Updated', `Added ${address.slice(0, 6)}...${address.slice(-4)} to whitelist`, 'admin');
      return true;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to add to whitelist';
      notifyError('Whitelist Failed', message);
      return false;
    }
  }, [userAddress, notifySuccess, notifyError]);

  // Add to blacklist
  const addToBlacklist = useCallback(async (address: string, reason?: string) => {
    if (!userAddress) {
      notifyError('Operation Failed', 'Wallet not connected');
      return false;
    }

    try {
      const response = await fetch(`${API_BASE}/api/v1/kyc/blacklist`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          address,
          operator: userAddress,
          reason: reason || 'Manual blacklist addition',
        }),
      });

      if (!response.ok) {
        const errData = await response.json();
        throw new Error(errData.message || 'Failed to add to blacklist');
      }

      notifySuccess('Blacklist Updated', `Added ${address.slice(0, 6)}...${address.slice(-4)} to blacklist`, 'admin');
      await fetchRegistrations();
      return true;
    } catch (err) {
      const message = err instanceof Error ? err.message : 'Failed to add to blacklist';
      notifyError('Blacklist Failed', message);
      return false;
    }
  }, [userAddress, fetchRegistrations, notifySuccess, notifyError]);

  // Check compliance status for an address
  const checkCompliance = useCallback(async (address: string) => {
    try {
      const response = await fetch(`${API_BASE}/api/v1/kyc/check/${address}`);
      if (!response.ok) {
        throw new Error('Failed to check compliance');
      }
      return await response.json();
    } catch (err) {
      console.error('Error checking compliance:', err);
      return null;
    }
  }, []);

  // Calculate stats
  const stats = {
    total: formattedRequests.length,
    pending: formattedRequests.filter(r => r.status === 'pending').length,
    approved: formattedRequests.filter(r => r.status === 'approved').length,
    rejected: formattedRequests.filter(r => r.status === 'rejected').length,
  };

  // Initial fetch
  useEffect(() => {
    fetchRegistrations();
  }, [fetchRegistrations]);

  // Auto-refresh
  useEffect(() => {
    if (!autoRefresh) return;

    const interval = setInterval(() => {
      fetchRegistrations();
    }, refreshInterval);

    return () => clearInterval(interval);
  }, [autoRefresh, refreshInterval, fetchRegistrations]);

  return {
    // Data
    registrations,
    formattedRequests,
    stats,

    // Actions
    approveKYC,
    rejectKYC,
    addToWhitelist,
    addToBlacklist,
    checkCompliance,
    refresh: fetchRegistrations,

    // Loading states
    isLoading,
    isApproving,
    isRejecting,
    isProcessing: isApproving || isRejecting,

    // Error
    error,
    clearError: () => setError(null),
  };
}
