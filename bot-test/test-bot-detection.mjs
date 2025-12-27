import puppeteer from 'puppeteer-core';

const LIGHTPANDA_WS = 'ws://127.0.0.1:9222';
const BOT_DETECTION_URL = 'https://www.browserscan.net/bot-detection';

async function testBotDetection() {
  console.log('Connecting to LightPanda browser...');
  
  const browser = await puppeteer.connect({
    browserWSEndpoint: LIGHTPANDA_WS,
  });

  try {
    const context = await browser.createBrowserContext();
    const page = await context.newPage();

    console.log(`Navigating to ${BOT_DETECTION_URL}...`);
    await page.goto(BOT_DETECTION_URL, { 
      waitUntil: 'networkidle0',
      timeout: 30000 
    });

    // Wait for the page to load and run detection scripts
    console.log('Waiting for bot detection to complete...');
    await new Promise(resolve => setTimeout(resolve, 5000));

    // Extract bot detection results from the page
    const results = await page.evaluate(() => {
      // Try to get all detection result items
      const items = document.querySelectorAll('.detection-item, .result-item, [class*="detection"], [class*="result"]');
      const results = [];
      
      items.forEach(item => {
        results.push(item.innerText);
      });

      // Also get the main content
      const mainContent = document.body.innerText;
      
      return {
        detectionItems: results,
        fullPageText: mainContent,
        title: document.title,
        url: window.location.href
      };
    });

    console.log('\n=== BOT DETECTION RESULTS ===\n');
    console.log('Page Title:', results.title);
    console.log('URL:', results.url);
    console.log('\n--- Full Page Content ---\n');
    console.log(results.fullPageText);

    // Get navigator properties that are commonly checked
    const navigatorInfo = await page.evaluate(() => {
      return {
        userAgent: navigator.userAgent,
        webdriver: navigator.webdriver,
        languages: navigator.languages,
        platform: navigator.platform,
        hardwareConcurrency: navigator.hardwareConcurrency,
        deviceMemory: navigator.deviceMemory,
        plugins: Array.from(navigator.plugins || []).map(p => p.name),
      };
    });

    console.log('\n--- Navigator Properties ---\n');
    console.log(JSON.stringify(navigatorInfo, null, 2));

    await page.close();
    await context.close();
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await browser.disconnect();
  }
}

testBotDetection().catch(console.error);
