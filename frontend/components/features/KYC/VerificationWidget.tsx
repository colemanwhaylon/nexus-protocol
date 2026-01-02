'use client';

import { useEffect, useRef, useState, useCallback } from 'react';
import { useKYC, type PaymentMethod } from '@/hooks/useKYC';
import { useNotifications } from '@/hooks/useNotifications';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Badge } from '@/components/ui/badge';
import { Loader2, CheckCircle, XCircle, Clock, CreditCard, Wallet, Coins } from 'lucide-react';
import { cn } from '@/lib/utils';

// Sumsub WebSDK types
declare global {
  interface Window {
    snsWebSdk?: {
      init: (
        accessToken: string,
        onMessage: (type: string, payload: Record<string, unknown>) => void,
        onError: (error: Error) => void
      ) => {
        withConf: (config: SumsubConfig) => {
          build: () => void;
          launch: (containerId: string) => void;
        };
      };
    };
  }
}

interface SumsubConfig {
  lang?: string;
  theme?: 'light' | 'dark';
  onMessage?: (type: string, payload: Record<string, unknown>) => void;
  onError?: (error: Error) => void;
}

interface VerificationWidgetProps {
  onComplete?: () => void;
  onError?: (error: string) => void;
  className?: string;
}

const PAYMENT_METHODS: { value: PaymentMethod; label: string; icon: React.ElementType; description: string }[] = [
  {
    value: 'nexus',
    label: 'NEXUS Token',
    icon: Coins,
    description: '10% discount applied',
  },
  {
    value: 'eth',
    label: 'Ethereum (ETH)',
    icon: Wallet,
    description: 'Pay with ETH',
  },
  {
    value: 'stripe',
    label: 'Credit Card',
    icon: CreditCard,
    description: 'Pay with card via Stripe',
  },
];

export function VerificationWidget({ onComplete, onError, className }: VerificationWidgetProps) {
  const containerRef = useRef<HTMLDivElement>(null);
  const [sdkLoaded, setSdkLoaded] = useState(false);
  const [widgetLaunched, setWidgetLaunched] = useState(false);

  const {
    status,
    isVerified,
    isInProgress,
    pricing,
    paymentMethods,
    selectedPaymentMethod,
    setSelectedPaymentMethod,
    calculateTotalPrice,
    sumsubAccessToken,
    startVerification,
    isLoading,
    error,
    clearError,
  } = useKYC();

  const { notifyKYCApproved, notifyKYCRejected } = useNotifications();

  // Load Sumsub SDK script
  useEffect(() => {
    if (typeof window !== 'undefined' && !window.snsWebSdk) {
      const script = document.createElement('script');
      script.src = 'https://static.sumsub.com/idensic/static/sns-websdk-builder.js';
      script.async = true;
      script.onload = () => setSdkLoaded(true);
      script.onerror = () => onError?.('Failed to load verification SDK');
      document.body.appendChild(script);

      return () => {
        document.body.removeChild(script);
      };
    } else if (window.snsWebSdk) {
      setSdkLoaded(true);
    }
  }, [onError]);

  // Handle Sumsub messages
  const handleMessage = useCallback((type: string, payload: Record<string, unknown>) => {
    console.log('[Sumsub]', type, payload);

    switch (type) {
      case 'idCheck.onApplicantStatusChanged':
        if (payload.reviewStatus === 'completed') {
          if (payload.reviewResult?.reviewAnswer === 'GREEN') {
            notifyKYCApproved();
            onComplete?.();
          } else {
            const rejectLabels = (payload.reviewResult?.rejectLabels as string[]) || [];
            notifyKYCRejected(rejectLabels.join(', ') || 'Verification failed');
            onError?.('Verification was not approved');
          }
        }
        break;

      case 'idCheck.onError':
        const errorMessage = (payload.error as { message?: string })?.message || 'Verification error occurred';
        onError?.(errorMessage);
        break;
    }
  }, [notifyKYCApproved, notifyKYCRejected, onComplete, onError]);

  // Handle Sumsub errors
  const handleError = useCallback((err: Error) => {
    console.error('[Sumsub Error]', err);
    onError?.(err.message);
  }, [onError]);

  // Launch Sumsub widget
  useEffect(() => {
    if (
      sdkLoaded &&
      sumsubAccessToken &&
      containerRef.current &&
      !widgetLaunched &&
      window.snsWebSdk
    ) {
      try {
        const snsWebSdk = window.snsWebSdk
          .init(sumsubAccessToken, handleMessage, handleError)
          .withConf({
            lang: 'en',
            theme: 'dark',
          })
          .build();

        snsWebSdk.launch('sumsub-container');
        setWidgetLaunched(true);
      } catch (err) {
        console.error('Failed to launch Sumsub SDK:', err);
        onError?.('Failed to launch verification widget');
      }
    }
  }, [sdkLoaded, sumsubAccessToken, widgetLaunched, handleMessage, handleError, onError]);

  // Handle payment method selection and start verification
  const handleStartVerification = async () => {
    clearError();
    await startVerification(selectedPaymentMethod);
  };

  // Render status badge
  const renderStatusBadge = () => {
    switch (status) {
      case 'approved':
        return (
          <Badge className="bg-green-500/10 text-green-500 border-green-500/20">
            <CheckCircle className="w-3 h-3 mr-1" />
            Verified
          </Badge>
        );
      case 'rejected':
        return (
          <Badge className="bg-red-500/10 text-red-500 border-red-500/20">
            <XCircle className="w-3 h-3 mr-1" />
            Rejected
          </Badge>
        );
      case 'verification_in_progress':
      case 'verification_pending':
        return (
          <Badge className="bg-yellow-500/10 text-yellow-500 border-yellow-500/20">
            <Clock className="w-3 h-3 mr-1" />
            In Progress
          </Badge>
        );
      case 'payment_pending':
        return (
          <Badge className="bg-blue-500/10 text-blue-500 border-blue-500/20">
            <Clock className="w-3 h-3 mr-1" />
            Payment Pending
          </Badge>
        );
      default:
        return (
          <Badge variant="outline">
            Not Started
          </Badge>
        );
    }
  };

  // If already verified, show success state
  if (isVerified) {
    return (
      <Card className={cn('border-green-500/20 bg-green-500/5', className)}>
        <CardContent className="flex items-center justify-center py-12">
          <div className="text-center">
            <CheckCircle className="w-16 h-16 text-green-500 mx-auto mb-4" />
            <h3 className="text-xl font-semibold text-green-500 mb-2">Identity Verified</h3>
            <p className="text-muted-foreground">
              Your identity has been verified. You have full access to the platform.
            </p>
          </div>
        </CardContent>
      </Card>
    );
  }

  // If verification is in progress, show the Sumsub widget
  if (status === 'verification_in_progress' && sumsubAccessToken) {
    return (
      <Card className={className}>
        <CardHeader>
          <div className="flex items-center justify-between">
            <CardTitle>Identity Verification</CardTitle>
            {renderStatusBadge()}
          </div>
          <CardDescription>
            Complete the verification steps below to verify your identity
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div
            ref={containerRef}
            id="sumsub-container"
            className="min-h-[600px] bg-background rounded-lg"
          />
        </CardContent>
      </Card>
    );
  }

  // Payment selection and start verification
  return (
    <Card className={className}>
      <CardHeader>
        <div className="flex items-center justify-between">
          <CardTitle>KYC Verification</CardTitle>
          {renderStatusBadge()}
        </div>
        <CardDescription>
          Complete identity verification to access all platform features. Choose your preferred payment method.
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-6">
        {/* Pricing info */}
        {pricing && (
          <div className="p-4 bg-muted rounded-lg">
            <div className="flex items-center justify-between">
              <span className="text-sm text-muted-foreground">Verification Fee</span>
              <span className="font-semibold">${pricing.priceUSD} USD</span>
            </div>
          </div>
        )}

        {/* Payment method selection */}
        <div className="space-y-3">
          <label className="text-sm font-medium">Select Payment Method</label>
          <div className="grid gap-3">
            {PAYMENT_METHODS.map((method) => {
              const priceInfo = calculateTotalPrice(method.value);
              const Icon = method.icon;
              const isDisabled = !paymentMethods.find(m => m.code === method.value);

              return (
                <button
                  key={method.value}
                  onClick={() => setSelectedPaymentMethod(method.value)}
                  disabled={isDisabled}
                  className={cn(
                    'flex items-center justify-between p-4 rounded-lg border transition-colors',
                    selectedPaymentMethod === method.value
                      ? 'border-primary bg-primary/5'
                      : 'border-border hover:border-primary/50',
                    isDisabled && 'opacity-50 cursor-not-allowed'
                  )}
                >
                  <div className="flex items-center gap-3">
                    <div className={cn(
                      'p-2 rounded-full',
                      selectedPaymentMethod === method.value
                        ? 'bg-primary/10 text-primary'
                        : 'bg-muted text-muted-foreground'
                    )}>
                      <Icon className="w-5 h-5" />
                    </div>
                    <div className="text-left">
                      <div className="font-medium">{method.label}</div>
                      <div className="text-xs text-muted-foreground">{method.description}</div>
                    </div>
                  </div>
                  {priceInfo && (
                    <div className="text-right">
                      <div className="font-semibold">
                        {priceInfo.total.toFixed(priceInfo.currency === 'USD' ? 2 : 6)} {priceInfo.currency}
                      </div>
                      {priceInfo.fee > 0 && (
                        <div className="text-xs text-muted-foreground">
                          +{priceInfo.feePercent}% fee
                        </div>
                      )}
                    </div>
                  )}
                </button>
              );
            })}
          </div>
        </div>

        {/* Error display */}
        {error && (
          <div className="p-3 bg-destructive/10 text-destructive rounded-lg text-sm">
            {error}
          </div>
        )}

        {/* Start verification button */}
        <Button
          onClick={handleStartVerification}
          disabled={isLoading || isInProgress}
          className="w-full"
          size="lg"
        >
          {isLoading ? (
            <>
              <Loader2 className="w-4 h-4 mr-2 animate-spin" />
              Processing...
            </>
          ) : status === 'payment_pending' ? (
            'Complete Payment'
          ) : (
            'Start Verification'
          )}
        </Button>

        {/* Info text */}
        <p className="text-xs text-muted-foreground text-center">
          Verification is powered by Sumsub. Your data is processed securely according to their privacy policy.
        </p>
      </CardContent>
    </Card>
  );
}

export default VerificationWidget;
