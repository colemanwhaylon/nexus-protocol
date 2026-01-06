"use client";

import { useState, useEffect } from "react";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Switch } from "@/components/ui/switch";
import { Label } from "@/components/ui/label";
import { Cookie, Settings, X } from "lucide-react";
import Link from "next/link";

interface CookiePreferences {
  essential: boolean; // Always true
  functional: boolean;
  analytics: boolean;
  marketing: boolean;
  timestamp: number;
}

const COOKIE_CONSENT_KEY = "nexus_cookie_consent";

export function CookieConsentBanner() {
  const [isVisible, setIsVisible] = useState(false);
  const [showSettings, setShowSettings] = useState(false);
  const [preferences, setPreferences] = useState<CookiePreferences>({
    essential: true,
    functional: true,
    analytics: false,
    marketing: false,
    timestamp: 0,
  });

  useEffect(() => {
    // Check if consent has been given
    const savedConsent = localStorage.getItem(COOKIE_CONSENT_KEY);
    if (!savedConsent) {
      // Show banner after a short delay for better UX
      const timer = setTimeout(() => setIsVisible(true), 1000);
      return () => clearTimeout(timer);
    } else {
      try {
        const parsed = JSON.parse(savedConsent) as CookiePreferences;
        setPreferences(parsed);
      } catch {
        // Invalid consent data, show banner
        setIsVisible(true);
      }
    }
  }, []);

  const savePreferences = (prefs: CookiePreferences) => {
    const prefsWithTimestamp = { ...prefs, timestamp: Date.now() };
    localStorage.setItem(COOKIE_CONSENT_KEY, JSON.stringify(prefsWithTimestamp));
    setPreferences(prefsWithTimestamp);
    setIsVisible(false);
    setShowSettings(false);
  };

  const acceptAll = () => {
    savePreferences({
      essential: true,
      functional: true,
      analytics: true,
      marketing: true,
      timestamp: Date.now(),
    });
  };

  const acceptEssential = () => {
    savePreferences({
      essential: true,
      functional: false,
      analytics: false,
      marketing: false,
      timestamp: Date.now(),
    });
  };

  const saveCustomPreferences = () => {
    savePreferences(preferences);
  };

  if (!isVisible) return null;

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50 p-4 md:p-6">
      <Card className="mx-auto max-w-4xl border-primary/20 shadow-lg">
        <CardContent className="p-4 md:p-6">
          {!showSettings ? (
            // Main Banner
            <div className="space-y-4">
              <div className="flex items-start gap-4">
                <Cookie className="h-8 w-8 text-primary shrink-0 mt-1" />
                <div className="flex-1">
                  <h3 className="font-semibold text-lg mb-2">Cookie Settings</h3>
                  <p className="text-sm text-muted-foreground">
                    We use cookies to enhance your browsing experience, analyze site traffic,
                    and personalize content. By clicking &quot;Accept All&quot;, you consent to our use
                    of cookies. You can customize your preferences or learn more in our{" "}
                    <Link href="/cookies" className="text-primary hover:underline">
                      Cookie Policy
                    </Link>
                    .
                  </p>
                </div>
              </div>
              <div className="flex flex-wrap gap-3 justify-end">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={() => setShowSettings(true)}
                  className="gap-2"
                >
                  <Settings className="h-4 w-4" />
                  Customize
                </Button>
                <Button variant="outline" size="sm" onClick={acceptEssential}>
                  Essential Only
                </Button>
                <Button size="sm" onClick={acceptAll}>
                  Accept All
                </Button>
              </div>
            </div>
          ) : (
            // Settings Panel
            <div className="space-y-6">
              <div className="flex items-center justify-between">
                <h3 className="font-semibold text-lg">Cookie Preferences</h3>
                <Button
                  variant="ghost"
                  size="icon"
                  onClick={() => setShowSettings(false)}
                >
                  <X className="h-4 w-4" />
                </Button>
              </div>

              <div className="space-y-4">
                {/* Essential Cookies */}
                <div className="flex items-center justify-between py-3 border-b">
                  <div className="space-y-1">
                    <Label className="text-sm font-medium">Essential Cookies</Label>
                    <p className="text-xs text-muted-foreground">
                      Required for the website to function. Cannot be disabled.
                    </p>
                  </div>
                  <Switch checked disabled />
                </div>

                {/* Functional Cookies */}
                <div className="flex items-center justify-between py-3 border-b">
                  <div className="space-y-1">
                    <Label className="text-sm font-medium">Functional Cookies</Label>
                    <p className="text-xs text-muted-foreground">
                      Remember your preferences like theme and wallet.
                    </p>
                  </div>
                  <Switch
                    checked={preferences.functional}
                    onCheckedChange={(checked) =>
                      setPreferences({ ...preferences, functional: checked })
                    }
                  />
                </div>

                {/* Analytics Cookies */}
                <div className="flex items-center justify-between py-3 border-b">
                  <div className="space-y-1">
                    <Label className="text-sm font-medium">Analytics Cookies</Label>
                    <p className="text-xs text-muted-foreground">
                      Help us understand how visitors use our site.
                    </p>
                  </div>
                  <Switch
                    checked={preferences.analytics}
                    onCheckedChange={(checked) =>
                      setPreferences({ ...preferences, analytics: checked })
                    }
                  />
                </div>

                {/* Marketing Cookies */}
                <div className="flex items-center justify-between py-3">
                  <div className="space-y-1">
                    <Label className="text-sm font-medium">Marketing Cookies</Label>
                    <p className="text-xs text-muted-foreground">
                      Used to show relevant advertisements. Currently not in use.
                    </p>
                  </div>
                  <Switch
                    checked={preferences.marketing}
                    onCheckedChange={(checked) =>
                      setPreferences({ ...preferences, marketing: checked })
                    }
                    disabled
                  />
                </div>
              </div>

              <div className="flex justify-between items-center pt-2">
                <Link href="/cookies" className="text-sm text-primary hover:underline">
                  View Cookie Policy
                </Link>
                <div className="flex gap-3">
                  <Button variant="outline" size="sm" onClick={acceptEssential}>
                    Reject All
                  </Button>
                  <Button size="sm" onClick={saveCustomPreferences}>
                    Save Preferences
                  </Button>
                </div>
              </div>
            </div>
          )}
        </CardContent>
      </Card>
    </div>
  );
}

// Hook to check cookie consent preferences
export function useCookieConsent() {
  const [consent, setConsent] = useState<CookiePreferences | null>(null);

  useEffect(() => {
    const savedConsent = localStorage.getItem(COOKIE_CONSENT_KEY);
    if (savedConsent) {
      try {
        setConsent(JSON.parse(savedConsent));
      } catch {
        setConsent(null);
      }
    }
  }, []);

  return {
    hasConsent: consent !== null,
    allowFunctional: consent?.functional ?? false,
    allowAnalytics: consent?.analytics ?? false,
    allowMarketing: consent?.marketing ?? false,
    resetConsent: () => {
      localStorage.removeItem(COOKIE_CONSENT_KEY);
      window.location.reload();
    },
  };
}
