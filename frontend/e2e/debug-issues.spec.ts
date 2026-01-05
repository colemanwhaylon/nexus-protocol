import { test, expect } from "@playwright/test";

/**
 * Debug test to capture screenshots and verify NFT gallery and governance pages
 * Run with: BASE_URL=https://nexus.dapp.academy pnpm test e2e/debug-issues.spec.ts --headed
 */

test.describe("Debug Production Issues", () => {
  test.beforeEach(async ({ page }) => {
    // Set a longer timeout for production site
    page.setDefaultTimeout(30000);
  });

  test("capture NFT gallery page", async ({ page }) => {
    // Navigate to NFT gallery
    await page.goto("/nft/gallery");

    // Wait for page to load
    await page.waitForLoadState("networkidle");

    // Take full page screenshot
    await page.screenshot({
      path: "e2e/screenshots/nft-gallery-initial.png",
      fullPage: true,
    });

    // Log page content for debugging
    const pageTitle = await page.title();
    console.log("Page title:", pageTitle);

    // Check for specific elements
    const totalSupplyText = await page.locator("text=Total Supply").first().textContent();
    console.log("Total Supply section:", totalSupplyText);

    // Check if "Your NFTs" shows 0
    const yourNftsCard = page.locator("text=Your NFTs").first();
    if (await yourNftsCard.isVisible()) {
      const parentCard = yourNftsCard.locator("../..");
      const nftCount = await parentCard.locator("p.text-2xl").textContent();
      console.log("Your NFTs count:", nftCount);
    }

    // Check for error messages or loading states
    const errorMessages = await page.locator('[class*="destructive"], [class*="error"]').count();
    console.log("Error message count:", errorMessages);

    // Check console for errors
    page.on("console", (msg) => {
      if (msg.type() === "error") {
        console.log("Console error:", msg.text());
      }
    });

    // Wait a bit for any NFT cards to render
    await page.waitForTimeout(3000);

    // Take another screenshot after waiting
    await page.screenshot({
      path: "e2e/screenshots/nft-gallery-after-wait.png",
      fullPage: true,
    });

    // Check for NFT cards or "no NFTs" message
    const noNftsMessage = page.locator("text=You don't own any Nexus NFTs");
    const nftCards = page.locator('[class*="NFTCard"], [data-testid="nft-card"]');

    console.log("'No NFTs' message visible:", await noNftsMessage.isVisible());
    console.log("NFT cards count:", await nftCards.count());
  });

  test("capture NFT mint page", async ({ page }) => {
    // Navigate to NFT mint page
    await page.goto("/nft/mint");

    await page.waitForLoadState("networkidle");

    await page.screenshot({
      path: "e2e/screenshots/nft-mint.png",
      fullPage: true,
    });

    // Check mint status
    const mintStatus = page.locator("text=Mint Status");
    if (await mintStatus.isVisible()) {
      console.log("Mint Status section found");
    }

    // Check mint price
    const mintPriceSection = page.locator("text=Mint Price").first();
    if (await mintPriceSection.isVisible()) {
      const parent = mintPriceSection.locator("../..");
      const price = await parent.locator("p.text-2xl").textContent();
      console.log("Mint price:", price);
    }

    // Check if mint is active
    const activeStatus = page.locator("text=Active");
    const notActiveStatus = page.locator("text=Not Active");
    console.log("Active badge visible:", await activeStatus.isVisible());
    console.log("Not Active badge visible:", await notActiveStatus.isVisible());
  });

  test("capture governance page", async ({ page }) => {
    // Navigate to governance page
    await page.goto("/governance");

    await page.waitForLoadState("networkidle");

    // Take initial screenshot
    await page.screenshot({
      path: "e2e/screenshots/governance-initial.png",
      fullPage: true,
    });

    // Check for refresh button
    const refreshButton = page.locator('button[title="Refresh proposals"]');
    const refreshButtonExists = await refreshButton.count() > 0;
    console.log("Refresh button exists:", refreshButtonExists);

    // Check proposals count
    const totalProposals = page.locator("text=Total Proposals").first();
    if (await totalProposals.isVisible()) {
      const parent = totalProposals.locator("../..");
      const count = await parent.locator("p.text-2xl").textContent();
      console.log("Total proposals count:", count);
    }

    // Check for proposal list
    const proposalItems = page.locator('[class*="proposal"], [data-testid="proposal-item"]');
    console.log("Proposal items found:", await proposalItems.count());

    // Wait for any async loading
    await page.waitForTimeout(3000);

    await page.screenshot({
      path: "e2e/screenshots/governance-after-wait.png",
      fullPage: true,
    });

    // If refresh button exists, click it and take another screenshot
    if (refreshButtonExists) {
      await refreshButton.click();
      await page.waitForTimeout(2000);
      await page.screenshot({
        path: "e2e/screenshots/governance-after-refresh.png",
        fullPage: true,
      });
      console.log("Clicked refresh button and captured screenshot");
    }
  });

  test("check browser console for errors", async ({ page }) => {
    const consoleErrors: string[] = [];
    const consoleWarnings: string[] = [];
    const networkErrors: string[] = [];

    // Listen to console messages
    page.on("console", (msg) => {
      if (msg.type() === "error") {
        consoleErrors.push(msg.text());
      } else if (msg.type() === "warning") {
        consoleWarnings.push(msg.text());
      }
    });

    // Listen to network failures
    page.on("requestfailed", (request) => {
      networkErrors.push(`${request.method()} ${request.url()} - ${request.failure()?.errorText}`);
    });

    // Visit NFT gallery
    await page.goto("/nft/gallery");
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(5000);

    // Visit governance
    await page.goto("/governance");
    await page.waitForLoadState("networkidle");
    await page.waitForTimeout(3000);

    console.log("\n=== CONSOLE ERRORS ===");
    consoleErrors.forEach((err) => console.log(err));

    console.log("\n=== CONSOLE WARNINGS ===");
    consoleWarnings.slice(0, 10).forEach((warn) => console.log(warn));

    console.log("\n=== NETWORK ERRORS ===");
    networkErrors.forEach((err) => console.log(err));

    // Write errors to a file for analysis
    const errorReport = {
      consoleErrors,
      consoleWarnings: consoleWarnings.slice(0, 20),
      networkErrors,
      timestamp: new Date().toISOString(),
    };

    // Log to console as JSON
    console.log("\n=== ERROR REPORT JSON ===");
    console.log(JSON.stringify(errorReport, null, 2));
  });
});
