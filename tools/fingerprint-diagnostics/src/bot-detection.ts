import puppeteer from "puppeteer-core";

const LIGHTPANDA_WS = process.env.LIGHTPANDA_WS || "ws://127.0.0.1:9222";
const BOT_DETECTION_URL = "https://www.browserscan.net/bot-detection";

async function testBotDetection() {
  console.log("Connecting to LightPanda browser...");
  console.log(`WebSocket endpoint: ${LIGHTPANDA_WS}`);

  const browser = await puppeteer.connect({
    browserWSEndpoint: LIGHTPANDA_WS,
  });

  try {
    const context = await browser.createBrowserContext();
    const page = await context.newPage();

    console.log(`Navigating to ${BOT_DETECTION_URL}...`);
    await page.goto(BOT_DETECTION_URL, {
      waitUntil: "networkidle0",
      timeout: 30000,
    });

    console.log("Waiting for bot detection to complete...");
    await new Promise((resolve) => setTimeout(resolve, 5000));

    const results = await page.evaluate(() => {
      const items = document.querySelectorAll(
        '.detection-item, .result-item, [class*="detection"], [class*="result"]',
      );
      const detectionResults: string[] = [];

      items.forEach((item) => {
        detectionResults.push(item.textContent || "");
      });

      return {
        detectionItems: detectionResults,
        fullPageText: document.body.innerText,
        title: document.title,
        url: window.location.href,
      };
    });

    console.log("\n=== BOT DETECTION RESULTS ===\n");
    console.log("Page Title:", results.title);
    console.log("URL:", results.url);
    console.log("\n--- Full Page Content ---\n");
    console.log(results.fullPageText);

    const navigatorInfo = await page.evaluate(() => ({
      userAgent: navigator.userAgent,
      webdriver: navigator.webdriver,
      languages: navigator.languages,
      platform: navigator.platform,
      hardwareConcurrency: navigator.hardwareConcurrency,
      deviceMemory: (navigator as any).deviceMemory,
      plugins: Array.from(navigator.plugins || []).map((p) => p.name),
    }));

    console.log("\n--- Navigator Properties ---\n");
    console.log(JSON.stringify(navigatorInfo, null, 2));

    await page.close();
    await context.close();
  } catch (error) {
    console.error("Error:", (error as Error).message);
    process.exitCode = 1;
  } finally {
    await browser.disconnect();
  }
}

void testBotDetection();
