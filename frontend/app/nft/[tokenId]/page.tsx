'use client';

import { useState, useEffect } from 'react';
import { useParams, useRouter } from 'next/navigation';
import { useChainId, useReadContract, useWriteContract, useWaitForTransactionReceipt, useAccount } from 'wagmi';
import { isAddress } from 'viem';
import { getContractAddresses } from '@/lib/contracts/addresses';
import { NFTDetail } from '@/components/features/NFT';
import { useNotifications } from '@/hooks/useNotifications';
import { useTokenMetadata } from '@/hooks/useNFT';
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from '@/components/ui/dialog';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';

const nftAbi = [
  {
    name: 'ownerOf',
    type: 'function',
    stateMutability: 'view',
    inputs: [{ name: 'tokenId', type: 'uint256' }],
    outputs: [{ type: 'address' }],
  },
  {
    name: 'transferFrom',
    type: 'function',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'from', type: 'address' },
      { name: 'to', type: 'address' },
      { name: 'tokenId', type: 'uint256' },
    ],
    outputs: [],
  },
] as const;

export default function NFTDetailPage() {
  const params = useParams();
  const router = useRouter();
  const tokenId = params.tokenId as string;
  const chainId = useChainId();
  const addresses = getContractAddresses(chainId);
  const nftAddress = addresses.nexusNFT as `0x${string}`;
  const { address: userAddress } = useAccount();
  const { notifyNFTTransfer, notifyPending } = useNotifications();

  // Transfer modal state
  const [isTransferModalOpen, setIsTransferModalOpen] = useState(false);
  const [recipientAddress, setRecipientAddress] = useState('');
  const [addressError, setAddressError] = useState('');

  // Read owner
  const { data: owner, isLoading: isLoadingOwner, refetch: refetchOwner } = useReadContract({
    address: nftAddress,
    abi: nftAbi,
    functionName: 'ownerOf',
    args: [BigInt(tokenId)],
  });

  // Fetch token metadata
  const { metadata, isLoading: isLoadingMetadata } = useTokenMetadata(
    chainId,
    BigInt(tokenId)
  );

  // Write contract for transfer
  const { writeContract, data: transferHash, isPending: isTransferPending, error: transferError, reset: resetTransfer } = useWriteContract();
  const { isLoading: isConfirming, isSuccess: isTransferSuccess } = useWaitForTransactionReceipt({ hash: transferHash });

  // Handle transfer success
  useEffect(() => {
    if (isTransferSuccess && transferHash) {
      notifyNFTTransfer(tokenId, recipientAddress, transferHash, true);
      setIsTransferModalOpen(false);
      setRecipientAddress('');
      setAddressError('');
      resetTransfer();
      refetchOwner();
    }
  }, [isTransferSuccess, transferHash, tokenId, recipientAddress, notifyNFTTransfer, resetTransfer, refetchOwner]);

  // Handle transfer error
  useEffect(() => {
    if (transferError) {
      notifyNFTTransfer(tokenId, recipientAddress, undefined, false);
    }
  }, [transferError, tokenId, recipientAddress, notifyNFTTransfer]);

  const handleBack = () => {
    router.push('/nft/gallery');
  };

  const handleTransfer = () => {
    setIsTransferModalOpen(true);
  };

  const validateAddress = (address: string): boolean => {
    if (!address) {
      setAddressError('Recipient address is required');
      return false;
    }
    if (!isAddress(address)) {
      setAddressError('Invalid Ethereum address');
      return false;
    }
    if (address.toLowerCase() === userAddress?.toLowerCase()) {
      setAddressError('Cannot transfer to yourself');
      return false;
    }
    setAddressError('');
    return true;
  };

  const handleRecipientChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setRecipientAddress(value);
    if (value) {
      validateAddress(value);
    } else {
      setAddressError('');
    }
  };

  const handleConfirmTransfer = () => {
    if (!validateAddress(recipientAddress)) {
      return;
    }

    if (!userAddress) {
      setAddressError('Wallet not connected');
      return;
    }

    notifyPending('Transfer Initiated', `Transferring NFT #${tokenId}...`);

    writeContract({
      address: nftAddress,
      abi: nftAbi,
      functionName: 'transferFrom',
      args: [userAddress, recipientAddress as `0x${string}`, BigInt(tokenId)],
    });
  };

  const handleCloseModal = () => {
    if (!isTransferPending && !isConfirming) {
      setIsTransferModalOpen(false);
      setRecipientAddress('');
      setAddressError('');
      resetTransfer();
    }
  };

  const isTransferLoading = isTransferPending || isConfirming;

  // Use metadata attributes or fallback to defaults
  const attributes = metadata?.attributes?.map((attr) => ({
    trait_type: attr.trait_type,
    value: attr.value,
    rarity: attr.trait_type === 'Rarity'
      ? { Legendary: 0.5, Epic: 3, Rare: 10, Uncommon: 25, Common: 50 }[attr.value as string]
      : undefined,
  })) || [];

  // Get rarity from attributes for the detail component
  const rarityAttr = metadata?.attributes?.find((attr) => attr.trait_type === 'Rarity');
  const rarityValue = rarityAttr?.value as string | undefined;
  const rarityMap: Record<string, number> = {
    Legendary: 0.5,
    Epic: 3,
    Rare: 10,
    Uncommon: 25,
    Common: 50,
  };

  return (
    <div className="container mx-auto px-4 py-8">
      <NFTDetail
        tokenId={tokenId}
        name={metadata?.name || `Nexus NFT #${tokenId}`}
        description={metadata?.description || "A Nexus Genesis NFT providing exclusive benefits including staking boosts, enhanced governance voting power, and access to exclusive platform features."}
        image={metadata?.image}
        owner={owner}
        contractAddress={nftAddress}
        attributes={attributes}
        rarity={rarityValue ? rarityMap[rarityValue] : undefined}
        chainId={chainId}
        onBack={handleBack}
        onTransfer={handleTransfer}
        isLoading={isLoadingOwner || isLoadingMetadata}
      />

      {/* Transfer Modal */}
      <Dialog open={isTransferModalOpen} onOpenChange={handleCloseModal}>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Transfer NFT #{tokenId}</DialogTitle>
            <DialogDescription>
              Enter the recipient address to transfer this NFT. This action cannot be undone.
            </DialogDescription>
          </DialogHeader>

          <div className="space-y-4 py-4">
            <div className="space-y-2">
              <label htmlFor="recipient" className="text-sm font-medium">
                Recipient Address
              </label>
              <Input
                id="recipient"
                placeholder="0x..."
                value={recipientAddress}
                onChange={handleRecipientChange}
                disabled={isTransferLoading}
                aria-describedby={addressError ? 'recipient-error' : undefined}
                className={addressError ? 'border-destructive' : ''}
              />
              {addressError && (
                <p id="recipient-error" role="alert" className="text-sm text-destructive">
                  {addressError}
                </p>
              )}
            </div>
          </div>

          <DialogFooter>
            <Button
              variant="outline"
              onClick={handleCloseModal}
              disabled={isTransferLoading}
            >
              Cancel
            </Button>
            <Button
              onClick={handleConfirmTransfer}
              disabled={isTransferLoading || !!addressError || !recipientAddress}
              aria-busy={isTransferLoading}
            >
              {isTransferLoading ? (
                <>
                  <span className="mr-2 h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent" />
                  {isConfirming ? 'Confirming...' : 'Transferring...'}
                </>
              ) : (
                'Confirm Transfer'
              )}
            </Button>
          </DialogFooter>
        </DialogContent>
      </Dialog>
    </div>
  );
}
