import puppeteer from 'puppeteer-core';

const LIGHTPANDA_WS = 'ws://127.0.0.1:9222';

async function testUA() {
  console.log('Connecting to LightPanda browser...');
  
  const browser = await puppeteer.connect({
    browserWSEndpoint: LIGHTPANDA_WS,
  });

  try {
    const context = await browser.createBrowserContext();
    const page = await context.newPage();

    // Test 1: Check navigator properties directly
    console.log('\n=== Navigator Properties ===\n');
    const navigatorInfo = await page.evaluate(() => {
      return {
        userAgent: navigator.userAgent,
        platform: navigator.platform,
        vendor: navigator.vendor,
        appVersion: navigator.appVersion,
        appCodeName: navigator.appCodeName,
        appName: navigator.appName,
        product: navigator.product,
        productSub: navigator.productSub,
        language: navigator.language,
        online: navigator.online,
        cookieEnabled: navigator.cookieEnabled,
        webdriver: navigator.webdriver,
        hardwareConcurrency: navigator.hardwareConcurrency,
        deviceMemory: navigator.deviceMemory,
        maxTouchPoints: navigator.maxTouchPoints,
        pdfViewerEnabled: navigator.pdfViewerEnabled,
      };
    });
    console.log(JSON.stringify(navigatorInfo, null, 2));

    // Test 2: Navigate to ifconfig.co to see what UA the server sees
    console.log('\n=== ifconfig.co/json Response ===\n');
    await page.goto('https://ifconfig.co/json', { 
      waitUntil: 'networkidle0',
      timeout: 30000 
    });
    
    const pageContent = await page.evaluate(() => document.body.innerText);
    console.log(pageContent);

    await page.close();
    await context.close();
  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await browser.disconnect();
  }
}

testUA().catch(console.error);
