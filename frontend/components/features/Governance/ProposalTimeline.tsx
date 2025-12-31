'use client';

import { Card, CardContent, CardHeader, CardTitle } from '@/components/ui/card';
import { CheckCircle2, Circle, Clock, XCircle } from 'lucide-react';

type ProposalState = 'Pending' | 'Active' | 'Canceled' | 'Defeated' | 'Succeeded' | 'Queued' | 'Expired' | 'Executed';

interface ProposalTimelineProps {
  state: ProposalState;
  createdAt?: number;
  votingStartedAt?: number;
  votingEndedAt?: number;
  queuedAt?: number;
  executedAt?: number;
  canceledAt?: number;
}

export function ProposalTimeline({
  state,
  createdAt,
  votingStartedAt,
  votingEndedAt,
  queuedAt,
  executedAt,
  canceledAt,
}: ProposalTimelineProps) {
  const formatDate = (timestamp?: number) => {
    if (!timestamp) return null;
    return new Date(timestamp * 1000).toLocaleDateString('en-US', {
      month: 'short',
      day: 'numeric',
      hour: '2-digit',
      minute: '2-digit',
    });
  };

  const getStateOrder = () => {
    const order = ['Pending', 'Active'];
    if (state === 'Canceled') return [...order, 'Canceled'];
    if (state === 'Defeated' || state === 'Expired') return [...order, state];
    return [...order, 'Succeeded', 'Queued', 'Executed'];
  };

  const isCompleted = (step: string) => {
    const order = getStateOrder();
    const currentIndex = order.indexOf(state);
    const stepIndex = order.indexOf(step);
    return stepIndex < currentIndex;
  };

  const isCurrent = (step: string) => step === state;

  const isFailed = (step: string) => 
    ['Canceled', 'Defeated', 'Expired'].includes(step) && state === step;

  const getIcon = (step: string) => {
    if (isFailed(step)) return <XCircle className="h-5 w-5 text-destructive" />;
    if (isCompleted(step)) return <CheckCircle2 className="h-5 w-5 text-green-500" />;
    if (isCurrent(step)) return <Clock className="h-5 w-5 text-primary animate-pulse" />;
    return <Circle className="h-5 w-5 text-muted-foreground" />;
  };

  const getTimestamp = (step: string) => {
    switch (step) {
      case 'Pending':
        return formatDate(createdAt);
      case 'Active':
        return formatDate(votingStartedAt);
      case 'Succeeded':
      case 'Defeated':
      case 'Expired':
        return formatDate(votingEndedAt);
      case 'Queued':
        return formatDate(queuedAt);
      case 'Executed':
        return formatDate(executedAt);
      case 'Canceled':
        return formatDate(canceledAt);
      default:
        return null;
    }
  };

  const steps = getStateOrder();

  return (
    <Card>
      <CardHeader>
        <CardTitle className="text-base">Proposal Timeline</CardTitle>
      </CardHeader>
      <CardContent>
        <div className="relative">
          {steps.map((step, index) => (
            <div key={step} className="flex gap-4 pb-6 last:pb-0">
              <div className="flex flex-col items-center">
                {getIcon(step)}
                {index < steps.length - 1 && (
                  <div 
                    className={`w-0.5 flex-1 mt-2 ${
                      isCompleted(step) ? 'bg-green-500' : 'bg-muted'
                    }`}
                  />
                )}
              </div>
              <div className="flex-1 pt-0.5">
                <p className={`font-medium ${
                  isCurrent(step) ? 'text-primary' : 
                  isFailed(step) ? 'text-destructive' : ''
                }`}>
                  {step}
                </p>
                {getTimestamp(step) && (
                  <p className="text-sm text-muted-foreground">
                    {getTimestamp(step)}
                  </p>
                )}
              </div>
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
