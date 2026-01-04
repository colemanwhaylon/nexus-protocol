'use client';

import { useState, useCallback } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Switch } from '@/components/ui/switch';
import { Badge } from '@/components/ui/badge';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '@/components/ui/table';
import { Alert, AlertDescription, AlertTitle } from '@/components/ui/alert';
import { usePricing, type Pricing, type PaymentMethod, type PricingHistoryEntry } from '@/hooks/usePricing';
import { useNotifications } from '@/hooks/useNotifications';
import { useAccount } from 'wagmi';
import {
  RefreshCw,
  DollarSign,
  Edit2,
  History,
  CreditCard,
  AlertCircle,
  CheckCircle,
  XCircle,
  Coins,
  Wallet,
} from 'lucide-react';

// Format currency for display
function formatCurrency(value: number | null | undefined, currency = 'USD'): string {
  if (value === null || value === undefined) return '-';
  return new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: currency === 'USD' ? 'USD' : 'USD',
    minimumFractionDigits: 2,
    maximumFractionDigits: currency === 'ETH' || currency === 'NEXUS' ? 6 : 2,
  }).format(value);
}

// Format date for display
function formatDate(dateString: string): string {
  return new Date(dateString).toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

// Shorten address for display
function shortenAddress(address: string): string {
  if (!address || address.length < 10) return address || '-';
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

// Get icon for payment method
function getPaymentMethodIcon(methodCode: string) {
  switch (methodCode) {
    case 'nexus':
      return <Coins className="h-4 w-4" />;
    case 'eth':
      return <Wallet className="h-4 w-4" />;
    case 'stripe':
      return <CreditCard className="h-4 w-4" />;
    default:
      return <DollarSign className="h-4 w-4" />;
  }
}

interface EditPricingDialogProps {
  pricing: Pricing | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSave: (update: {
    price_usd?: number;
    price_eth?: number;
    price_nexus?: number;
    markup_percent?: number;
    is_active?: boolean;
    reason?: string;
  }) => Promise<boolean>;
  isUpdating: boolean;
}

function EditPricingDialog({ pricing, open, onOpenChange, onSave, isUpdating }: EditPricingDialogProps) {
  const [priceUsd, setPriceUsd] = useState('');
  const [priceEth, setPriceEth] = useState('');
  const [priceNexus, setPriceNexus] = useState('');
  const [markupPercent, setMarkupPercent] = useState('');
  const [isActive, setIsActive] = useState(true);
  const [reason, setReason] = useState('');

  // Reset form when pricing changes
  const resetForm = useCallback(() => {
    if (pricing) {
      setPriceUsd(pricing.price_usd?.toString() || '');
      setPriceEth(pricing.price_eth?.toString() || '');
      setPriceNexus(pricing.price_nexus?.toString() || '');
      setMarkupPercent(pricing.markup_percent?.toString() || '');
      setIsActive(pricing.is_active);
      setReason('');
    }
  }, [pricing]);

  // Reset form when dialog opens with new pricing
  if (open && pricing && priceUsd === '') {
    resetForm();
  }

  const handleSave = async () => {
    const update: {
      price_usd?: number;
      price_eth?: number;
      price_nexus?: number;
      markup_percent?: number;
      is_active?: boolean;
      reason?: string;
    } = {};

    if (priceUsd && !isNaN(parseFloat(priceUsd))) {
      update.price_usd = parseFloat(priceUsd);
    }
    if (priceEth && !isNaN(parseFloat(priceEth))) {
      update.price_eth = parseFloat(priceEth);
    }
    if (priceNexus && !isNaN(parseFloat(priceNexus))) {
      update.price_nexus = parseFloat(priceNexus);
    }
    if (markupPercent && !isNaN(parseFloat(markupPercent))) {
      update.markup_percent = parseFloat(markupPercent);
    }
    update.is_active = isActive;
    if (reason) {
      update.reason = reason;
    }

    const success = await onSave(update);
    if (success) {
      onOpenChange(false);
      // Reset form state
      setPriceUsd('');
      setPriceEth('');
      setPriceNexus('');
      setMarkupPercent('');
      setReason('');
    }
  };

  const handleClose = () => {
    onOpenChange(false);
    setPriceUsd('');
    setPriceEth('');
    setPriceNexus('');
    setMarkupPercent('');
    setReason('');
  };

  return (
    <Dialog open={open} onOpenChange={handleClose}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle>Edit Pricing: {pricing?.service_name}</DialogTitle>
          <DialogDescription>
            Update pricing for {pricing?.service_code}. Changes will be logged with audit trail.
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-4 py-4">
          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="price_usd">Price (USD)</Label>
              <Input
                id="price_usd"
                type="number"
                step="0.01"
                value={priceUsd}
                onChange={(e) => setPriceUsd(e.target.value)}
                placeholder="15.00"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="markup_percent">Markup (%)</Label>
              <Input
                id="markup_percent"
                type="number"
                step="0.1"
                value={markupPercent}
                onChange={(e) => setMarkupPercent(e.target.value)}
                placeholder="20"
              />
            </div>
          </div>

          <div className="grid grid-cols-2 gap-4">
            <div className="space-y-2">
              <Label htmlFor="price_eth">Price (ETH)</Label>
              <Input
                id="price_eth"
                type="number"
                step="0.000001"
                value={priceEth}
                onChange={(e) => setPriceEth(e.target.value)}
                placeholder="0.005"
              />
            </div>
            <div className="space-y-2">
              <Label htmlFor="price_nexus">Price (NEXUS)</Label>
              <Input
                id="price_nexus"
                type="number"
                step="0.01"
                value={priceNexus}
                onChange={(e) => setPriceNexus(e.target.value)}
                placeholder="100"
              />
            </div>
          </div>

          <div className="flex items-center space-x-2">
            <Switch id="is_active" checked={isActive} onCheckedChange={setIsActive} />
            <Label htmlFor="is_active">Active</Label>
          </div>

          <div className="space-y-2">
            <Label htmlFor="reason">Reason for Change (optional)</Label>
            <Input
              id="reason"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              placeholder="e.g., Market adjustment, cost increase"
            />
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={handleClose}>
            Cancel
          </Button>
          <Button onClick={handleSave} disabled={isUpdating}>
            {isUpdating ? 'Saving...' : 'Save Changes'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

interface PricingHistoryDialogProps {
  serviceCode: string | null;
  history: PricingHistoryEntry[];
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

function PricingHistoryDialog({ serviceCode, history, open, onOpenChange }: PricingHistoryDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[700px]">
        <DialogHeader>
          <DialogTitle>Pricing History: {serviceCode}</DialogTitle>
          <DialogDescription>View historical price changes and who made them.</DialogDescription>
        </DialogHeader>

        <div className="max-h-[400px] overflow-y-auto">
          {history.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              No pricing history available.
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Date</TableHead>
                  <TableHead>Old USD</TableHead>
                  <TableHead>New USD</TableHead>
                  <TableHead>Changed By</TableHead>
                  <TableHead>Reason</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {history.map((entry) => (
                  <TableRow key={entry.id}>
                    <TableCell className="text-sm">
                      {formatDate(entry.changed_at)}
                    </TableCell>
                    <TableCell>
                      {formatCurrency(entry.old_price_usd)}
                    </TableCell>
                    <TableCell>
                      {formatCurrency(entry.new_price_usd)}
                    </TableCell>
                    <TableCell className="font-mono text-sm">
                      {shortenAddress(entry.changed_by)}
                    </TableCell>
                    <TableCell className="text-sm text-muted-foreground max-w-[150px] truncate">
                      {entry.change_reason || '-'}
                    </TableCell>
                  </TableRow>
                ))}
              </TableBody>
            </Table>
          )}
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)}>
            Close
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

interface PaymentMethodCardProps {
  method: PaymentMethod;
  onToggle: (methodCode: string, isActive: boolean) => Promise<boolean>;
  onUpdateFee: (methodCode: string, feePercent: number) => Promise<boolean>;
  isUpdating: boolean;
}

function PaymentMethodCard({ method, onToggle, onUpdateFee, isUpdating }: PaymentMethodCardProps) {
  const [editingFee, setEditingFee] = useState(false);
  const [newFee, setNewFee] = useState(method.fee_percent.toString());

  const handleToggle = async () => {
    await onToggle(method.method_code, !method.is_active);
  };

  const handleSaveFee = async () => {
    const fee = parseFloat(newFee);
    if (!isNaN(fee) && fee >= 0) {
      const success = await onUpdateFee(method.method_code, fee);
      if (success) {
        setEditingFee(false);
      }
    }
  };

  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            {getPaymentMethodIcon(method.method_code)}
            <CardTitle className="text-lg">{method.method_name}</CardTitle>
          </div>
          <div className="flex items-center gap-2">
            <Badge variant={method.is_active ? 'default' : 'secondary'}>
              {method.is_active ? 'Active' : 'Inactive'}
            </Badge>
            <Switch
              checked={method.is_active}
              onCheckedChange={handleToggle}
              disabled={isUpdating}
              aria-label={`Toggle ${method.method_name}`}
            />
          </div>
        </div>
        <CardDescription>Method code: {method.method_code}</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span className="text-muted-foreground">Min Amount:</span>
            <span className="ml-2 font-medium">{formatCurrency(method.min_amount_usd)}</span>
          </div>
          <div>
            <span className="text-muted-foreground">Max Amount:</span>
            <span className="ml-2 font-medium">
              {method.max_amount_usd ? formatCurrency(method.max_amount_usd) : 'No limit'}
            </span>
          </div>
          <div className="col-span-2">
            <div className="flex items-center gap-2">
              <span className="text-muted-foreground">Fee:</span>
              {editingFee ? (
                <div className="flex items-center gap-2">
                  <Input
                    type="number"
                    step="0.1"
                    value={newFee}
                    onChange={(e) => setNewFee(e.target.value)}
                    className="w-20 h-8"
                  />
                  <span>%</span>
                  <Button size="sm" variant="ghost" onClick={handleSaveFee} disabled={isUpdating}>
                    <CheckCircle className="h-4 w-4 text-green-500" />
                  </Button>
                  <Button size="sm" variant="ghost" onClick={() => setEditingFee(false)}>
                    <XCircle className="h-4 w-4 text-red-500" />
                  </Button>
                </div>
              ) : (
                <div className="flex items-center gap-2">
                  <span className="font-medium">{method.fee_percent}%</span>
                  <Button size="sm" variant="ghost" onClick={() => setEditingFee(true)}>
                    <Edit2 className="h-3 w-3" />
                  </Button>
                </div>
              )}
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

export default function PricingPage() {
  const { isConnected } = useAccount();
  const {
    pricingList,
    paymentMethods,
    pricingHistory,
    updatePricing,
    updatePaymentMethod,
    togglePaymentMethod,
    fetchPricingHistory,
    refresh,
    isLoading,
    isUpdating,
    error,
    clearError,
  } = usePricing({ autoRefresh: true, refreshInterval: 60000 });

  const { notifySuccess, notifyError } = useNotifications();

  // Dialog states
  const [editDialogOpen, setEditDialogOpen] = useState(false);
  const [historyDialogOpen, setHistoryDialogOpen] = useState(false);
  const [selectedPricing, setSelectedPricing] = useState<Pricing | null>(null);
  const [selectedHistoryCode, setSelectedHistoryCode] = useState<string | null>(null);

  // Handle edit pricing
  const handleEditPricing = (pricing: Pricing) => {
    setSelectedPricing(pricing);
    setEditDialogOpen(true);
  };

  // Handle save pricing
  const handleSavePricing = async (update: {
    price_usd?: number;
    price_eth?: number;
    price_nexus?: number;
    markup_percent?: number;
    is_active?: boolean;
    reason?: string;
  }): Promise<boolean> => {
    if (!selectedPricing) return false;

    const success = await updatePricing(selectedPricing.service_code, update);
    if (success) {
      notifySuccess('Pricing Updated', `${selectedPricing.service_name} pricing has been updated.`, 'admin');
    } else {
      notifyError('Update Failed', 'Failed to update pricing. Please try again.', 'admin');
    }
    return success;
  };

  // Handle view history
  const handleViewHistory = async (pricing: Pricing) => {
    setSelectedHistoryCode(pricing.service_code);
    await fetchPricingHistory(pricing.service_code);
    setHistoryDialogOpen(true);
  };

  // Handle toggle payment method
  const handleTogglePaymentMethod = async (methodCode: string, isActive: boolean): Promise<boolean> => {
    const success = await togglePaymentMethod(methodCode, isActive);
    if (success) {
      notifySuccess(
        'Payment Method Updated',
        `${methodCode} has been ${isActive ? 'enabled' : 'disabled'}.`,
        'admin'
      );
    }
    return success;
  };

  // Handle update payment method fee
  const handleUpdatePaymentMethodFee = async (methodCode: string, feePercent: number): Promise<boolean> => {
    const success = await updatePaymentMethod(methodCode, { fee_percent: feePercent });
    if (success) {
      notifySuccess('Fee Updated', `${methodCode} fee has been updated to ${feePercent}%.`, 'admin');
    }
    return success;
  };

  // Show connect wallet message if not connected
  if (!isConnected) {
    return (
      <div className="container mx-auto px-4 py-8">
        <Alert>
          <AlertCircle className="h-4 w-4" />
          <AlertTitle>Wallet Not Connected</AlertTitle>
          <AlertDescription>
            Please connect your wallet to manage pricing. Admin privileges are required.
          </AlertDescription>
        </Alert>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      {/* Header */}
      <div className="mb-8 flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Pricing Management</h1>
          <p className="text-muted-foreground">
            Manage service pricing and payment methods
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={refresh} disabled={isLoading}>
          <RefreshCw className={`h-4 w-4 mr-2 ${isLoading ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

      {/* Error Alert */}
      {error && (
        <Alert variant="destructive" className="mb-6">
          <AlertCircle className="h-4 w-4" />
          <AlertTitle>Error</AlertTitle>
          <AlertDescription className="flex items-center justify-between">
            <span>{error}</span>
            <Button variant="ghost" size="sm" onClick={clearError}>
              Dismiss
            </Button>
          </AlertDescription>
        </Alert>
      )}

      {/* Service Pricing Section */}
      <div className="mb-8">
        <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
          <DollarSign className="h-5 w-5" />
          Service Pricing
        </h2>

        {isLoading && pricingList.length === 0 ? (
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {[1, 2, 3, 4].map((i) => (
              <Card key={i} className="animate-pulse">
                <CardHeader>
                  <div className="h-6 bg-muted rounded w-1/2 mb-2" />
                  <div className="h-4 bg-muted rounded w-3/4" />
                </CardHeader>
                <CardContent>
                  <div className="h-8 bg-muted rounded w-1/3" />
                </CardContent>
              </Card>
            ))}
          </div>
        ) : pricingList.length === 0 ? (
          <Card>
            <CardContent className="py-8 text-center text-muted-foreground">
              No pricing configured. Please check API connectivity.
            </CardContent>
          </Card>
        ) : (
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {pricingList.map((pricing) => (
              <Card key={pricing.id}>
                <CardHeader className="pb-3">
                  <div className="flex items-center justify-between">
                    <CardTitle className="text-lg">{pricing.service_name}</CardTitle>
                    <Badge variant={pricing.is_active ? 'default' : 'secondary'}>
                      {pricing.is_active ? 'Active' : 'Inactive'}
                    </Badge>
                  </div>
                  <CardDescription>{pricing.description}</CardDescription>
                </CardHeader>
                <CardContent>
                  <div className="space-y-3">
                    <div className="flex items-center justify-between">
                      <span className="text-2xl font-bold">{formatCurrency(pricing.price_usd)}</span>
                      <span className="text-sm text-muted-foreground">
                        {pricing.markup_percent}% markup
                      </span>
                    </div>

                    <div className="grid grid-cols-2 gap-2 text-sm">
                      <div>
                        <span className="text-muted-foreground">ETH:</span>
                        <span className="ml-1 font-medium">
                          {pricing.price_eth !== null ? `${pricing.price_eth} ETH` : '-'}
                        </span>
                      </div>
                      <div>
                        <span className="text-muted-foreground">NEXUS:</span>
                        <span className="ml-1 font-medium">
                          {pricing.price_nexus !== null ? `${pricing.price_nexus}` : '-'}
                        </span>
                      </div>
                    </div>

                    <div className="text-xs text-muted-foreground">
                      Code: {pricing.service_code}
                    </div>

                    <div className="flex gap-2 pt-2">
                      <Button
                        variant="outline"
                        size="sm"
                        className="flex-1"
                        onClick={() => handleEditPricing(pricing)}
                      >
                        <Edit2 className="h-4 w-4 mr-1" />
                        Edit
                      </Button>
                      <Button
                        variant="ghost"
                        size="sm"
                        onClick={() => handleViewHistory(pricing)}
                      >
                        <History className="h-4 w-4 mr-1" />
                        History
                      </Button>
                    </div>
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>

      {/* Payment Methods Section */}
      <div>
        <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
          <CreditCard className="h-5 w-5" />
          Payment Methods
        </h2>

        {isLoading && paymentMethods.length === 0 ? (
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {[1, 2, 3].map((i) => (
              <Card key={i} className="animate-pulse">
                <CardHeader>
                  <div className="h-6 bg-muted rounded w-1/2 mb-2" />
                  <div className="h-4 bg-muted rounded w-1/4" />
                </CardHeader>
                <CardContent>
                  <div className="h-12 bg-muted rounded" />
                </CardContent>
              </Card>
            ))}
          </div>
        ) : paymentMethods.length === 0 ? (
          <Card>
            <CardContent className="py-8 text-center text-muted-foreground">
              No payment methods configured. Please check API connectivity.
            </CardContent>
          </Card>
        ) : (
          <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
            {paymentMethods
              .sort((a, b) => a.display_order - b.display_order)
              .map((method) => (
                <PaymentMethodCard
                  key={method.id}
                  method={method}
                  onToggle={handleTogglePaymentMethod}
                  onUpdateFee={handleUpdatePaymentMethodFee}
                  isUpdating={isUpdating}
                />
              ))}
          </div>
        )}
      </div>

      {/* Edit Pricing Dialog */}
      <EditPricingDialog
        pricing={selectedPricing}
        open={editDialogOpen}
        onOpenChange={setEditDialogOpen}
        onSave={handleSavePricing}
        isUpdating={isUpdating}
      />

      {/* Pricing History Dialog */}
      <PricingHistoryDialog
        serviceCode={selectedHistoryCode}
        history={selectedHistoryCode ? pricingHistory[selectedHistoryCode] || [] : []}
        open={historyDialogOpen}
        onOpenChange={setHistoryDialogOpen}
      />
    </div>
  );
}
