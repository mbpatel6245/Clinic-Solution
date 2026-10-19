const assert = require('node:assert/strict');
const fs = require('node:fs');
const http = require('node:http');
const path = require('node:path');
const { chromium } = require('playwright');

(async () => {
  const browser = await chromium.launch({headless:true, ...(process.env.CLINIC_BROWSER_CHANNEL ? {channel:process.env.CLINIC_BROWSER_CHANNEL} : {})});
  const root = path.resolve(process.argv[2] || 'web');
  const realApp = process.argv.includes('--real-app');
  const types = {'.html':'text/html; charset=utf-8','.css':'text/css','.js':'text/javascript','.svg':'image/svg+xml','.png':'image/png','.json':'application/json','.wasm':'application/wasm','.mjs':'text/javascript','.woff2':'font/woff2'};
  let bootstrapRequests = 0;
  const server = http.createServer((req, res) => {
    let pathname = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
    if (pathname === '/flutter_bootstrap.js' && !realApp) {
      bootstrapRequests++;
      res.writeHead(200, {'Content-Type':'text/javascript'});
      res.end('window.testBootstrapCount=(window.testBootstrapCount||0)+1');
      return;
    }
    let file = path.resolve(root, '.' + pathname);
    if (!file.startsWith(root + path.sep) && file !== root) {res.writeHead(403);res.end();return;}
    if (!fs.existsSync(file) || fs.statSync(file).isDirectory()) file = path.join(root, 'index.html');
    res.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
    let data = fs.readFileSync(file);
    if (path.extname(file) === '.html') data = data.toString().replace('$FLUTTER_BASE_HREF', '/');
    res.end(data);
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const origin = `http://127.0.0.1:${server.address().port}`;

  try {
    const page = await browser.newPage();
    if (realApp) {
      await page.goto(origin);
      assert.equal(await page.locator('#marketing').isVisible(), true);
      await page.getByRole('link', {name:'Log in', exact:true}).first().click();
      await page.waitForSelector('#loading', {state:'detached', timeout:90000});
      await page.waitForSelector('flutter-view', {timeout:30000});
      await page.waitForTimeout(1500);
      const semantics = page.locator('flt-semantics-placeholder');
      if (await semantics.count()) await semantics.dispatchEvent('click');
      await page.getByText('WELCOME BACK', {exact:true}).waitFor({timeout:30000});
      await page.screenshot({path:'build/marketing-preview/existing-login.png'});
      await page.goBack();
      await page.waitForSelector('#marketing', {state:'visible', timeout:30000});
      await page.goto(origin);
      await page.getByRole('link', {name:'Get started', exact:false}).click();
      await page.waitForSelector('#loading', {state:'detached', timeout:90000});
      await page.waitForSelector('flutter-view', {timeout:30000});
      await page.waitForTimeout(1000);
      await page.screenshot({path:'build/marketing-preview/existing-register.png'});
      assert.equal(new URL(page.url()).pathname, '/register');
      const registerSemantics = page.locator('flt-semantics-placeholder');
      if (await registerSemantics.count()) await registerSemantics.dispatchEvent('click');
      await page.getByText('GET STARTED', {exact:true}).waitFor({timeout:30000});
      console.log('PASS: actual Flutter login screen, browser Back to public homepage, and registration entry.');
      return;
    }
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(origin);
    assert.equal(bootstrapRequests, 0, 'marketing must not start Firebase/Flutter');
    assert.equal(await page.getByRole('heading', {level:1}).textContent(), 'Less admin.More timefor care.');
    await page.getByRole('button', {name:'Clinic teams', exact:true}).click();
    assert.equal(await page.getByRole('button', {name:'Clinic teams', exact:true}).getAttribute('aria-pressed'), 'true');
    assert.equal(await page.locator('#audience-copy h3').textContent(), 'Make the handoff feel effortless.');
    await page.getByRole('button', {name:'Clinic owners', exact:true}).click();
    assert.equal(await page.locator('#audience-copy h3').textContent(), 'A clearer view of your growing practice.');
    await page.getByText('Can I use it for more than one clinic?', {exact:true}).click();
    assert.equal(await page.locator('details[open]').count(), 1);
    fs.mkdirSync('build/marketing-preview', {recursive:true});
    for (const width of [1440, 1024, 768, 390, 320]) {
      await page.setViewportSize({width,height:1000});
      await page.goto(origin);
      assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, `horizontal overflow at ${width}`);
      assert.equal(await page.getByRole('link', {name:'Log in', exact:true}).first().isVisible(), true);
      await page.screenshot({path:`build/marketing-preview/home-${width}.png`,fullPage:true});
    }
    await page.setViewportSize({width:390,height:900});
    await page.evaluate(() => { document.body.style.zoom = '1.25'; });
    assert.equal(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), true, 'zoom overflow');
    await page.evaluate(() => { document.body.style.zoom = ''; });
    await page.getByRole('link', {name:'Log in', exact:true}).first().click();
    await page.waitForFunction(() => window.testBootstrapCount === 1);
    assert.equal(new URL(page.url()).pathname, '/login');
    assert.equal(await page.locator('#marketing').isVisible(), false);
    await page.goBack();
    await page.waitForSelector('#marketing', {state:'visible'});
    await page.getByRole('link', {name:'Get started', exact:false}).click();
    await page.waitForFunction(() => window.testBootstrapCount === 1);
    assert.equal(new URL(page.url()).pathname, '/register');
    for (const route of ['/#/forgot','/#/home','/login','/register']) {
      await page.goto(origin + route);
      await page.waitForFunction(() => window.testBootstrapCount === 1);
    }
    await page.goto(origin + '/#features');
    assert.equal(await page.locator('#marketing').isVisible(), true);
    assert.equal(await page.evaluate(() => window.testBootstrapCount || 0), 0);
    assert.deepEqual(errors, []);
    console.log('PASS: responsive widths, role switch, FAQ, login/register, back navigation and direct app links.');
  } finally {
    await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(error => {console.error(error);process.exitCode=1;});
