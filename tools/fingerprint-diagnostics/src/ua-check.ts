import puppeteer from "puppeteer-core";

const LIGHTPANDA_WS = process.env.LIGHTPANDA_WS || "ws://127.0.0.1:9222";

async function testUA() {
  console.log("Connecting to LightPanda browser...");
  console.log(`WebSocket endpoint: ${LIGHTPANDA_WS}`);

  const browser = await puppeteer.connect({
    browserWSEndpoint: LIGHTPANDA_WS,
  });

  try {
    const context = await browser.createBrowserContext();
    const page = await context.newPage();

    console.log("\n=== Navigator Properties ===\n");
    const navigatorInfo = await page.evaluate(() => ({
      userAgent: navigator.userAgent,
      platform: navigator.platform,
      vendor: navigator.vendor,
      appVersion: navigator.appVersion,
      appCodeName: navigator.appCodeName,
      appName: navigator.appName,
      product: navigator.product,
      productSub: navigator.productSub,
      language: navigator.language,
      online: navigator.onLine,
      cookieEnabled: navigator.cookieEnabled,
      webdriver: navigator.webdriver,
      hardwareConcurrency: navigator.hardwareConcurrency,
      deviceMemory: (navigator as any).deviceMemory,
      maxTouchPoints: navigator.maxTouchPoints,
      pdfViewerEnabled: navigator.pdfViewerEnabled,
    }));
    console.log(JSON.stringify(navigatorInfo, null, 2));

    console.log("\n=== ifconfig.co/json Response ===\n");
    await page.goto("https://ifconfig.co/json", {
      waitUntil: "networkidle0",
      timeout: 30000,
    });

    const pageContent = await page.evaluate(() => document.body.innerText);
    console.log(pageContent);

    await page.close();
    await context.close();
  } catch (error) {
    console.error("Error:", (error as Error).message);
    process.exitCode = 1;
  } finally {
    await browser.disconnect();
  }
}

void testUA();
