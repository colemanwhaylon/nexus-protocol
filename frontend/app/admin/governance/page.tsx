'use client';

import { useState, useCallback } from 'react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
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
import {
  useGovernanceConfig,
  type GovernanceConfig,
  type GovernanceConfigHistoryEntry,
} from '@/hooks/useGovernanceConfig';
import { useNotifications } from '@/hooks/useNotifications';
import { useAccount } from 'wagmi';
import {
  RefreshCw,
  Settings,
  Edit2,
  History,
  AlertCircle,
  CheckCircle,
  XCircle,
  Upload,
  Clock,
  Hash,
  Percent,
  Coins,
  ExternalLink,
} from 'lucide-react';

// Format date for display
function formatDate(dateString: string | null): string {
  if (!dateString) return 'Never';
  return new Date(dateString).toLocaleString('en-US', {
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
  });
}

// Shorten address for display
function shortenAddress(address: string | null): string {
  if (!address || address.length < 10) return address || '-';
  return `${address.slice(0, 6)}...${address.slice(-4)}`;
}

// Shorten tx hash
function shortenTxHash(hash: string | null): string {
  if (!hash || hash.length < 10) return hash || '-';
  return `${hash.slice(0, 10)}...${hash.slice(-6)}`;
}

// Get icon for config type
function getConfigIcon(configKey: string) {
  switch (configKey) {
    case 'proposal_threshold':
      return <Coins className="h-4 w-4" />;
    case 'voting_delay':
    case 'voting_period':
    case 'timelock_delay':
      return <Clock className="h-4 w-4" />;
    case 'quorum_percent':
      return <Percent className="h-4 w-4" />;
    default:
      return <Settings className="h-4 w-4" />;
  }
}

// Get display value for config
function getDisplayValue(config: GovernanceConfig): string {
  if (config.value_wei) {
    // Convert wei to token amount
    const tokenAmount = Number(BigInt(config.value_wei) / BigInt(10 ** 18));
    return `${tokenAmount.toLocaleString()} ${config.value_unit}`;
  }
  if (config.value_number !== null) {
    return `${config.value_number} ${config.value_unit}`;
  }
  if (config.value_percent !== null) {
    return `${config.value_percent}%`;
  }
  if (config.value_string !== null) {
    return config.value_string;
  }
  return '-';
}

interface EditConfigDialogProps {
  config: GovernanceConfig | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSave: (update: {
    value_wei?: string;
    value_number?: number;
    value_percent?: number;
  }) => Promise<boolean>;
  isUpdating: boolean;
}

function EditConfigDialog({ config, open, onOpenChange, onSave, isUpdating }: EditConfigDialogProps) {
  const [inputValue, setInputValue] = useState('');
  const [error, setError] = useState<string | null>(null);

  // Reset form when config changes
  const resetForm = useCallback(() => {
    if (config) {
      if (config.value_wei) {
        const tokenAmount = Number(BigInt(config.value_wei) / BigInt(10 ** 18));
        setInputValue(tokenAmount.toString());
      } else if (config.value_number !== null) {
        setInputValue(config.value_number.toString());
      } else if (config.value_percent !== null) {
        setInputValue(config.value_percent.toString());
      } else {
        setInputValue('');
      }
      setError(null);
    }
  }, [config]);

  // Reset form when dialog opens with new config
  if (open && config && inputValue === '') {
    resetForm();
  }

  const handleSave = async () => {
    if (!config) return;
    setError(null);

    const numValue = parseFloat(inputValue);
    if (isNaN(numValue) || numValue < 0) {
      setError('Please enter a valid positive number');
      return;
    }

    const update: {
      value_wei?: string;
      value_number?: number;
      value_percent?: number;
    } = {};

    // Determine which field to update based on config type
    if (config.value_wei !== null || config.config_key === 'proposal_threshold') {
      // Convert token amount to wei
      const weiValue = BigInt(Math.floor(numValue)) * BigInt(10 ** 18);
      update.value_wei = weiValue.toString();
    } else if (config.value_percent !== null || config.config_key === 'quorum_percent') {
      update.value_percent = numValue;
    } else {
      update.value_number = Math.floor(numValue);
    }

    const success = await onSave(update);
    if (success) {
      onOpenChange(false);
      setInputValue('');
    }
  };

  const handleClose = () => {
    onOpenChange(false);
    setInputValue('');
    setError(null);
  };

  const getInputLabel = (): string => {
    if (!config) return 'Value';
    if (config.value_wei !== null || config.config_key === 'proposal_threshold') {
      return `Value (${config.value_unit || 'tokens'})`;
    }
    if (config.value_percent !== null || config.config_key === 'quorum_percent') {
      return 'Value (%)';
    }
    return `Value (${config.value_unit || 'blocks'})`;
  };

  return (
    <Dialog open={open} onOpenChange={handleClose}>
      <DialogContent className="sm:max-w-[450px]">
        <DialogHeader>
          <DialogTitle>Edit: {config?.display_name}</DialogTitle>
          <DialogDescription>
            {config?.description}
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-4 py-4">
          <div className="space-y-2">
            <Label htmlFor="config_value">{getInputLabel()}</Label>
            <Input
              id="config_value"
              type="number"
              step={config?.value_percent !== null ? '0.01' : '1'}
              min="0"
              value={inputValue}
              onChange={(e) => setInputValue(e.target.value)}
              placeholder="Enter new value"
            />
            {error && (
              <p className="text-sm text-destructive">{error}</p>
            )}
          </div>

          <div className="rounded-md bg-muted p-3">
            <p className="text-sm text-muted-foreground">
              <strong>Current value:</strong> {config ? getDisplayValue(config) : '-'}
            </p>
            <p className="text-sm text-muted-foreground mt-1">
              <strong>Note:</strong> After updating in the database, you&apos;ll need to sync to the smart contract.
            </p>
          </div>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={handleClose}>
            Cancel
          </Button>
          <Button onClick={handleSave} disabled={isUpdating}>
            {isUpdating ? 'Saving...' : 'Save to Database'}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

interface ConfigHistoryDialogProps {
  configKey: string | null;
  displayName: string | null;
  history: GovernanceConfigHistoryEntry[];
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

function ConfigHistoryDialog({ configKey, displayName, history, open, onOpenChange }: ConfigHistoryDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[700px]">
        <DialogHeader>
          <DialogTitle>History: {displayName || configKey}</DialogTitle>
          <DialogDescription>View historical changes and who made them.</DialogDescription>
        </DialogHeader>

        <div className="max-h-[400px] overflow-y-auto">
          {history.length === 0 ? (
            <div className="text-center py-8 text-muted-foreground">
              No history available for this config.
            </div>
          ) : (
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>Date</TableHead>
                  <TableHead>Old Value</TableHead>
                  <TableHead>New Value</TableHead>
                  <TableHead>Changed By</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {history.map((entry) => (
                  <TableRow key={entry.id}>
                    <TableCell className="text-sm">
                      {formatDate(entry.changed_at)}
                    </TableCell>
                    <TableCell>
                      {entry.old_value_wei
                        ? `${Number(BigInt(entry.old_value_wei) / BigInt(10 ** 18))} tokens`
                        : entry.old_value_number !== null
                        ? entry.old_value_number
                        : entry.old_value_percent !== null
                        ? `${entry.old_value_percent}%`
                        : '-'}
                    </TableCell>
                    <TableCell>
                      {entry.new_value_wei
                        ? `${Number(BigInt(entry.new_value_wei) / BigInt(10 ** 18))} tokens`
                        : entry.new_value_number !== null
                        ? entry.new_value_number
                        : entry.new_value_percent !== null
                        ? `${entry.new_value_percent}%`
                        : '-'}
                    </TableCell>
                    <TableCell className="font-mono text-sm">
                      {shortenAddress(entry.changed_by)}
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

interface SyncDialogProps {
  config: GovernanceConfig | null;
  open: boolean;
  onOpenChange: (open: boolean) => void;
  onSync: () => Promise<void>;
  isSyncing: boolean;
  isConfirming: boolean;
  writeHash: `0x${string}` | undefined;
}

function SyncDialog({
  config,
  open,
  onOpenChange,
  onSync,
  isSyncing,
  isConfirming,
  writeHash,
}: SyncDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="sm:max-w-[500px]">
        <DialogHeader>
          <DialogTitle>Sync to Smart Contract</DialogTitle>
          <DialogDescription>
            Update {config?.display_name} on the blockchain
          </DialogDescription>
        </DialogHeader>

        <div className="grid gap-4 py-4">
          <div className="rounded-md bg-muted p-4">
            <div className="flex items-center gap-2 mb-2">
              {getConfigIcon(config?.config_key || '')}
              <span className="font-medium">{config?.display_name}</span>
            </div>
            <p className="text-lg font-bold">
              {config ? getDisplayValue(config) : '-'}
            </p>
          </div>

          {writeHash && (
            <div className="flex items-center gap-2 text-sm">
              <Hash className="h-4 w-4" />
              <span className="text-muted-foreground">Transaction:</span>
              <a
                href={`https://sepolia.etherscan.io/tx/${writeHash}`}
                target="_blank"
                rel="noopener noreferrer"
                className="font-mono text-primary hover:underline flex items-center gap-1"
              >
                {shortenTxHash(writeHash)}
                <ExternalLink className="h-3 w-3" />
              </a>
            </div>
          )}

          {isConfirming && (
            <Alert>
              <Clock className="h-4 w-4 animate-spin" />
              <AlertTitle>Confirming Transaction</AlertTitle>
              <AlertDescription>
                Waiting for blockchain confirmation...
              </AlertDescription>
            </Alert>
          )}

          <Alert variant="default">
            <AlertCircle className="h-4 w-4" />
            <AlertTitle>Admin Override</AlertTitle>
            <AlertDescription>
              This function is only available on testnet and requires admin privileges.
              The transaction will call the admin override function on NexusGovernor.
            </AlertDescription>
          </Alert>
        </div>

        <DialogFooter>
          <Button variant="outline" onClick={() => onOpenChange(false)} disabled={isSyncing || isConfirming}>
            Cancel
          </Button>
          <Button onClick={onSync} disabled={isSyncing || isConfirming}>
            {isSyncing || isConfirming ? (
              <>
                <RefreshCw className="h-4 w-4 mr-2 animate-spin" />
                {isConfirming ? 'Confirming...' : 'Syncing...'}
              </>
            ) : (
              <>
                <Upload className="h-4 w-4 mr-2" />
                Sync to Contract
              </>
            )}
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}

interface ConfigCardProps {
  config: GovernanceConfig;
  onEdit: (config: GovernanceConfig) => void;
  onViewHistory: (config: GovernanceConfig) => void;
  onSync: (config: GovernanceConfig) => void;
}

function ConfigCard({ config, onEdit, onViewHistory, onSync }: ConfigCardProps) {
  return (
    <Card>
      <CardHeader className="pb-3">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            {getConfigIcon(config.config_key)}
            <CardTitle className="text-lg">{config.display_name}</CardTitle>
          </div>
          <div className="flex items-center gap-2">
            {config.is_synced_to_contract ? (
              <Badge variant="default" className="flex items-center gap-1">
                <CheckCircle className="h-3 w-3" />
                Synced
              </Badge>
            ) : (
              <Badge variant="secondary" className="flex items-center gap-1">
                <XCircle className="h-3 w-3" />
                Out of Sync
              </Badge>
            )}
          </div>
        </div>
        <CardDescription>{config.description}</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          <div>
            <span className="text-3xl font-bold">{getDisplayValue(config)}</span>
          </div>

          <div className="grid grid-cols-2 gap-2 text-sm">
            <div>
              <span className="text-muted-foreground">Config Key:</span>
              <span className="ml-1 font-mono text-xs">{config.config_key}</span>
            </div>
            <div>
              <span className="text-muted-foreground">Chain ID:</span>
              <span className="ml-1 font-medium">{config.chain_id}</span>
            </div>
          </div>

          {config.last_synced_at && (
            <div className="text-xs text-muted-foreground">
              Last synced: {formatDate(config.last_synced_at)}
            </div>
          )}

          <div className="flex gap-2 pt-2">
            <Button
              variant="outline"
              size="sm"
              className="flex-1"
              onClick={() => onEdit(config)}
            >
              <Edit2 className="h-4 w-4 mr-1" />
              Edit
            </Button>
            <Button
              variant={config.is_synced_to_contract ? 'ghost' : 'default'}
              size="sm"
              className="flex-1"
              onClick={() => onSync(config)}
              disabled={config.is_synced_to_contract}
            >
              <Upload className="h-4 w-4 mr-1" />
              Sync
            </Button>
            <Button
              variant="ghost"
              size="sm"
              onClick={() => onViewHistory(config)}
            >
              <History className="h-4 w-4" />
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}

export default function GovernanceConfigPage() {
  const { isConnected } = useAccount();
  const {
    configs,
    configHistory,
    governorAddress,
    updateConfig,
    fetchConfigHistory,
    markConfigSynced,
    syncProposalThreshold,
    syncVotingDelay,
    syncVotingPeriod,
    refresh,
    isLoading,
    isUpdating,
    isSyncing,
    isConfirming,
    writeHash,
    isWriteSuccess,
    error,
    clearError,
  } = useGovernanceConfig({ autoRefresh: true, refreshInterval: 60000 });

  const { notifySuccess, notifyError } = useNotifications();

  // Dialog states
  const [editDialogOpen, setEditDialogOpen] = useState(false);
  const [historyDialogOpen, setHistoryDialogOpen] = useState(false);
  const [syncDialogOpen, setSyncDialogOpen] = useState(false);
  const [selectedConfig, setSelectedConfig] = useState<GovernanceConfig | null>(null);

  // Handle edit config
  const handleEditConfig = (config: GovernanceConfig) => {
    setSelectedConfig(config);
    setEditDialogOpen(true);
  };

  // Handle save config to database
  const handleSaveConfig = async (update: {
    value_wei?: string;
    value_number?: number;
    value_percent?: number;
  }): Promise<boolean> => {
    if (!selectedConfig) return false;

    const success = await updateConfig(selectedConfig.config_key, update);
    if (success) {
      notifySuccess(
        'Config Updated',
        `${selectedConfig.display_name} has been updated in the database.`,
        'admin'
      );
    } else {
      notifyError('Update Failed', 'Failed to update config. Please try again.', 'admin');
    }
    return success;
  };

  // Handle view history
  const handleViewHistory = async (config: GovernanceConfig) => {
    setSelectedConfig(config);
    await fetchConfigHistory(config.config_key);
    setHistoryDialogOpen(true);
  };

  // Handle open sync dialog
  const handleOpenSyncDialog = (config: GovernanceConfig) => {
    setSelectedConfig(config);
    setSyncDialogOpen(true);
  };

  // Handle sync to contract
  const handleSyncToContract = async () => {
    if (!selectedConfig) return;

    let result: string | null = null;

    switch (selectedConfig.config_key) {
      case 'proposal_threshold':
        if (selectedConfig.value_wei) {
          result = await syncProposalThreshold(BigInt(selectedConfig.value_wei));
        }
        break;
      case 'voting_delay':
        if (selectedConfig.value_number !== null) {
          result = await syncVotingDelay(selectedConfig.value_number);
        }
        break;
      case 'voting_period':
        if (selectedConfig.value_number !== null) {
          result = await syncVotingPeriod(selectedConfig.value_number);
        }
        break;
      default:
        notifyError('Not Supported', `Syncing ${selectedConfig.config_key} is not yet supported.`, 'admin');
        return;
    }

    if (result === 'pending') {
      notifySuccess('Transaction Submitted', 'Waiting for confirmation...', 'admin');
    }
  };

  // Handle write success - mark config as synced
  const handleWriteSuccess = useCallback(async () => {
    if (isWriteSuccess && writeHash && selectedConfig) {
      const success = await markConfigSynced(selectedConfig.config_key, writeHash);
      if (success) {
        notifySuccess(
          'Sync Complete',
          `${selectedConfig.display_name} has been synced to the smart contract.`,
          'admin'
        );
        await refresh();
        setSyncDialogOpen(false);
      }
    }
  }, [isWriteSuccess, writeHash, selectedConfig, markConfigSynced, notifySuccess, refresh]);

  // Watch for write success
  if (isWriteSuccess && writeHash && selectedConfig && !isConfirming) {
    handleWriteSuccess();
  }

  // Show connect wallet message if not connected
  if (!isConnected) {
    return (
      <div className="container mx-auto px-4 py-8">
        <Alert>
          <AlertCircle className="h-4 w-4" />
          <AlertTitle>Wallet Not Connected</AlertTitle>
          <AlertDescription>
            Please connect your wallet to manage governance configuration. Admin privileges are required.
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
          <h1 className="text-3xl font-bold">Governance Configuration</h1>
          <p className="text-muted-foreground">
            Manage governance parameters with database-driven configuration
          </p>
        </div>
        <Button variant="outline" size="sm" onClick={refresh} disabled={isLoading}>
          <RefreshCw className={`h-4 w-4 mr-2 ${isLoading ? 'animate-spin' : ''}`} />
          Refresh
        </Button>
      </div>

      {/* Governor Address Info */}
      {governorAddress && (
        <Alert className="mb-6">
          <Settings className="h-4 w-4" />
          <AlertTitle>NexusGovernor Contract</AlertTitle>
          <AlertDescription className="flex items-center gap-2">
            <span className="font-mono text-sm">{governorAddress}</span>
            <a
              href={`https://sepolia.etherscan.io/address/${governorAddress}`}
              target="_blank"
              rel="noopener noreferrer"
              className="text-primary hover:underline"
            >
              <ExternalLink className="h-4 w-4" />
            </a>
          </AlertDescription>
        </Alert>
      )}

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

      {/* Config Cards */}
      {isLoading && configs.length === 0 ? (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {[1, 2, 3, 4, 5].map((i) => (
            <Card key={i} className="animate-pulse">
              <CardHeader>
                <div className="h-6 bg-muted rounded w-1/2 mb-2" />
                <div className="h-4 bg-muted rounded w-3/4" />
              </CardHeader>
              <CardContent>
                <div className="h-10 bg-muted rounded w-1/3 mb-4" />
                <div className="h-8 bg-muted rounded" />
              </CardContent>
            </Card>
          ))}
        </div>
      ) : configs.length === 0 ? (
        <Card>
          <CardContent className="py-8 text-center text-muted-foreground">
            No governance configs found. Please check API connectivity and ensure the database is seeded.
          </CardContent>
        </Card>
      ) : (
        <div className="grid gap-4 md:grid-cols-2 lg:grid-cols-3">
          {configs.map((config) => (
            <ConfigCard
              key={config.config_key}
              config={config}
              onEdit={handleEditConfig}
              onViewHistory={handleViewHistory}
              onSync={handleOpenSyncDialog}
            />
          ))}
        </div>
      )}

      {/* Edit Config Dialog */}
      <EditConfigDialog
        config={selectedConfig}
        open={editDialogOpen}
        onOpenChange={setEditDialogOpen}
        onSave={handleSaveConfig}
        isUpdating={isUpdating}
      />

      {/* Config History Dialog */}
      <ConfigHistoryDialog
        configKey={selectedConfig?.config_key || null}
        displayName={selectedConfig?.display_name || null}
        history={selectedConfig ? configHistory[selectedConfig.config_key] || [] : []}
        open={historyDialogOpen}
        onOpenChange={setHistoryDialogOpen}
      />

      {/* Sync to Contract Dialog */}
      <SyncDialog
        config={selectedConfig}
        open={syncDialogOpen}
        onOpenChange={setSyncDialogOpen}
        onSync={handleSyncToContract}
        isSyncing={isSyncing}
        isConfirming={isConfirming}
        writeHash={writeHash}
      />
    </div>
  );
}
