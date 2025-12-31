'use client';

import { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Loader2, Plus, Minus, Sparkles } from 'lucide-react';
import { formatEther } from 'viem';

interface MintCardProps {
  mintPrice?: bigint;
  maxPerTx?: number;
  totalMinted?: bigint;
  maxSupply?: bigint;
  isMintActive?: boolean;
  onMint?: (quantity: number) => Promise<void>;
  isLoading?: boolean;
  disabled?: boolean;
}

export function MintCard({
  mintPrice = 0n,
  maxPerTx = 5,
  totalMinted = 0n,
  maxSupply = 10000n,
  isMintActive = true,
  onMint,
  isLoading: _isLoading,
  disabled,
}: MintCardProps) {
  const [quantity, setQuantity] = useState(1);
  const [isMinting, setIsMinting] = useState(false);

  const totalCost = mintPrice * BigInt(quantity);
  const remaining = maxSupply - totalMinted;
  const canMint = isMintActive && remaining > 0n && !disabled && !isMinting;

  const handleIncrement = () => {
    if (quantity < maxPerTx && BigInt(quantity) < remaining) {
      setQuantity(q => q + 1);
    }
  };

  const handleDecrement = () => {
    if (quantity > 1) {
      setQuantity(q => q - 1);
    }
  };

  const handleMint = async () => {
    if (!onMint || !canMint) return;

    setIsMinting(true);
    try {
      await onMint(quantity);
      setQuantity(1);
    } catch (error) {
      console.error('Mint failed:', error);
    } finally {
      setIsMinting(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Sparkles className="h-5 w-5" />
          Mint NFT
        </CardTitle>
        <CardDescription>
          {isMintActive ? 'Mint is live!' : 'Minting not active'}
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="text-center space-y-1">
          <p className="text-sm text-muted-foreground">
            {totalMinted.toString()} / {maxSupply.toString()} minted
          </p>
          <p className="text-lg font-medium">
            Price: {parseFloat(formatEther(mintPrice)).toFixed(4)} ETH each
          </p>
        </div>

        <div className="flex items-center justify-center gap-4">
          <Button
            variant="outline"
            size="icon"
            onClick={handleDecrement}
            disabled={quantity <= 1 || disabled}
          >
            <Minus className="h-4 w-4" />
          </Button>
          
          <Input
            type="number"
            value={quantity}
            onChange={(e) => {
              const val = parseInt(e.target.value) || 1;
              setQuantity(Math.min(Math.max(1, val), maxPerTx));
            }}
            className="w-20 text-center"
            min={1}
            max={maxPerTx}
            disabled={disabled}
          />
          
          <Button
            variant="outline"
            size="icon"
            onClick={handleIncrement}
            disabled={quantity >= maxPerTx || disabled}
          >
            <Plus className="h-4 w-4" />
          </Button>
        </div>

        <div className="p-3 bg-muted rounded-lg text-center">
          <p className="text-sm text-muted-foreground">Total Cost</p>
          <p className="text-xl font-bold">
            {parseFloat(formatEther(totalCost)).toFixed(4)} ETH
          </p>
        </div>

        <Button
          className="w-full"
          size="lg"
          disabled={!canMint}
          onClick={handleMint}
        >
          {isMinting ? (
            <>
              <Loader2 className="mr-2 h-4 w-4 animate-spin" />
              Minting...
            </>
          ) : (
            <>
              <Sparkles className="mr-2 h-4 w-4" />
              Mint {quantity} NFT{quantity > 1 ? 's' : ''}
            </>
          )}
        </Button>

        <p className="text-xs text-center text-muted-foreground">
          Max {maxPerTx} per transaction
        </p>
      </CardContent>
    </Card>
  );
}
