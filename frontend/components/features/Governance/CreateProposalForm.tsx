"use client";

import { useState } from "react";
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Loader2, FileText, Plus, Trash2 } from "lucide-react";
import { formatUnits } from "viem";

interface CreateProposalFormProps {
  votingPower?: bigint;
  proposalThreshold?: bigint;
  onSubmit?: (title: string, description: string, actions: ProposalAction[]) => Promise<void>;
  disabled?: boolean;
}

interface ProposalAction {
  target: string;
  value: string;
  calldata: string;
}

export function CreateProposalForm({
  votingPower = 0n,
  proposalThreshold = 0n,
  onSubmit,
  disabled,
}: CreateProposalFormProps) {
  const [title, setTitle] = useState("");
  const [description, setDescription] = useState("");
  const [actions, setActions] = useState<ProposalAction[]>([
    { target: "", value: "0", calldata: "" },
  ]);
  const [isSubmitting, setIsSubmitting] = useState(false);

  const hasEnoughPower = votingPower >= proposalThreshold;
  const formattedPower = formatUnits(votingPower, 18);
  const formattedThreshold = formatUnits(proposalThreshold, 18);

  const addAction = () => {
    setActions([...actions, { target: "", value: "0", calldata: "" }]);
  };

  const removeAction = (index: number) => {
    if (actions.length > 1) {
      setActions(actions.filter((_, i) => i !== index));
    }
  };

  const updateAction = (index: number, field: keyof ProposalAction, value: string) => {
    const newActions = [...actions];
    newActions[index][field] = value;
    setActions(newActions);
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!onSubmit || !hasEnoughPower || !title) return;

    setIsSubmitting(true);
    try {
      await onSubmit(title, description, actions);
      setTitle("");
      setDescription("");
      setActions([{ target: "", value: "0", calldata: "" }]);
    } catch (error) {
      console.error("Proposal creation failed:", error);
    } finally {
      setIsSubmitting(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <FileText className="h-5 w-5" />
          Create Proposal
        </CardTitle>
        <CardDescription>
          Submit a new governance proposal for the community to vote on
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={handleSubmit} className="space-y-6">
          {/* Voting Power Check */}
          <div className="p-4 bg-muted rounded-lg">
            <div className="flex items-center justify-between">
              <div>
                <p className="text-sm font-medium">Your Voting Power</p>
                <p className="text-2xl font-bold">{parseFloat(formattedPower).toLocaleString()}</p>
              </div>
              <Badge variant={hasEnoughPower ? "default" : "destructive"}>
                {hasEnoughPower ? "Eligible" : `Need ${parseFloat(formattedThreshold).toLocaleString()}`}
              </Badge>
            </div>
          </div>

          {/* Title */}
          <div className="space-y-2">
            <Label htmlFor="title">Proposal Title</Label>
            <Input
              id="title"
              placeholder="Enter a clear, descriptive title"
              value={title}
              onChange={(e) => setTitle(e.target.value)}
              disabled={!hasEnoughPower || disabled}
              required
            />
          </div>

          {/* Description */}
          <div className="space-y-2">
            <Label htmlFor="description">Description</Label>
            <textarea
              id="description"
              className="w-full min-h-[120px] p-3 rounded-md border bg-background"
              placeholder="Describe your proposal in detail..."
              value={description}
              onChange={(e) => setDescription(e.target.value)}
              disabled={!hasEnoughPower || disabled}
            />
          </div>

          {/* Actions */}
          <div className="space-y-4">
            <div className="flex items-center justify-between">
              <Label>Proposal Actions</Label>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={addAction}
                disabled={!hasEnoughPower || disabled}
              >
                <Plus className="mr-1 h-4 w-4" />
                Add Action
              </Button>
            </div>

            {actions.map((action, index) => (
              <div key={index} className="p-4 border rounded-lg space-y-3">
                <div className="flex items-center justify-between">
                  <span className="text-sm font-medium">Action {index + 1}</span>
                  {actions.length > 1 && (
                    <Button
                      type="button"
                      variant="ghost"
                      size="sm"
                      onClick={() => removeAction(index)}
                    >
                      <Trash2 className="h-4 w-4 text-destructive" />
                    </Button>
                  )}
                </div>
                <Input
                  placeholder="Target contract address (0x...)"
                  value={action.target}
                  onChange={(e) => updateAction(index, "target", e.target.value)}
                  disabled={!hasEnoughPower || disabled}
                />
                <Input
                  placeholder="ETH value (0)"
                  value={action.value}
                  onChange={(e) => updateAction(index, "value", e.target.value)}
                  disabled={!hasEnoughPower || disabled}
                />
                <Input
                  placeholder="Calldata (0x...)"
                  value={action.calldata}
                  onChange={(e) => updateAction(index, "calldata", e.target.value)}
                  disabled={!hasEnoughPower || disabled}
                />
              </div>
            ))}
          </div>

          <Button
            type="submit"
            className="w-full"
            disabled={!hasEnoughPower || !title || disabled || isSubmitting}
          >
            {isSubmitting ? (
              <>
                <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                Creating Proposal...
              </>
            ) : (
              "Create Proposal"
            )}
          </Button>
        </form>
      </CardContent>
    </Card>
  );
}
