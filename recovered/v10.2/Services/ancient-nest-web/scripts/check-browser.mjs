import { chromium } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import { existsSync } from 'node:fs';
const base=process.env.TEST_BASE_URL||'http://127.0.0.1:3100';
const executable=process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE||(existsSync('/usr/bin/chromium')?'/usr/bin/chromium':undefined);
const browser=await chromium.launch({executablePath:executable,headless:true,args:['--no-sandbox','--disable-dev-shm-usage']});
const routes=['/','/game','/play','/community','/news','/profile','/profile/demo','/account','/status','/privacy','/terms','/news/development-update','/news/networking-update','/news/website-launch'];
const results=[];const failures=[];let checks=0;const errors=[];const internal=new Set();
await fs.mkdir('verification',{recursive:true});
try{
 for(const width of [375,768,1024,1440]){
  const context=await browser.newContext({viewport:{width,height:900},reducedMotion:'reduce'});
  const page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));page.on('console',msg=>{if(msg.type()==='error')errors.push(msg.text());});
  for(const route of routes){
   await page.goto(base+route,{waitUntil:'networkidle'});await page.evaluate(()=>document.fonts.ready);
   const overflow=await page.evaluate(()=>({window:innerWidth,page:document.documentElement.scrollWidth,offenders:[...document.querySelectorAll('main *')].filter(e=>e.getBoundingClientRect().right>innerWidth+1).slice(0,6).map(e=>e.className)}));
   checks++;if(overflow.page>width+1)failures.push({route,width,type:'overflow',...overflow});
   const images=await page.locator('img').evaluateAll(images=>images.filter(i=>i.complete&&i.naturalWidth===0).map(i=>i.src));checks++;if(images.length)failures.push({route,width,type:'broken images',images});
   const links=await page.locator('a[href]').evaluateAll(links=>links.map(l=>l.getAttribute('href')).filter(h=>h?.startsWith('/')));links.forEach(h=>internal.add(h));
   const axe=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa']).analyze();
   checks++;if(axe.violations.length)failures.push({route,width,type:'accessibility',violations:axe.violations.map(v=>({id:v.id,impact:v.impact,nodes:v.nodes.map(n=>({target:n.target,summary:n.failureSummary}))}))});
   results.push({route,width,overflow:overflow.page,axeViolations:axe.violations.length});
   if(route==='/'&&(width===375||width===1440)){
    await page.screenshot({path:`verification/home-${width}.png`,fullPage:true});
    await page.screenshot({path:`verification/hero-${width}.png`});
   }
  }
  if(width<1024){
   await page.goto(base,{waitUntil:'networkidle'});const button=page.locator('.menu-toggle');
   await button.click();assert.equal(await button.getAttribute('aria-expanded'),'true');checks++;
   await page.keyboard.press('Escape');assert.equal(await button.getAttribute('aria-expanded'),'false');assert.equal(await button.evaluate(el=>el===document.activeElement),true);checks+=2;
   await button.click();await page.getByRole('navigation',{name:'Mobile navigation'}).getByRole('link',{name:'Game',exact:true}).click();await page.waitForURL(base+'/game');assert.equal(await page.getByRole('button',{name:'Open navigation'}).getAttribute('aria-expanded'),'false');checks++;
  }
  await page.goto(base+'/account',{waitUntil:'networkidle'});const login=page.getByRole('link',{name:'Sign in with Steam',exact:true});if(await login.count())assert.equal(await login.getAttribute('href'),'/api/auth/steam');else assert.equal(await page.getByRole('button',{name:'Sign in with Steam',exact:true}).isDisabled(),true);checks++;
  const requests=[];page.on('request',req=>{if(!req.url().startsWith(base))requests.push(req.url());});await page.reload({waitUntil:'networkidle'});assert.deepEqual(requests,[]);checks++;
  await context.close();console.log('CHECKED viewport',width);
 }
 const context=await browser.newContext();const page=await context.newPage();
 for(const href of internal){const [path,hash]=href.split('#');const response=await page.goto(base+path,{waitUntil:'domcontentloaded'});checks++;if(response.status()!==200)failures.push({href,type:'internal link',status:response.status()});if(hash){checks++;if(!await page.locator(`[id="${hash}"]`).count())failures.push({href,type:'missing anchor'});}}
 await page.goto(base,{waitUntil:'networkidle'});await page.keyboard.press('Tab');assert.equal(await page.evaluate(()=>document.activeElement?.textContent),'Skip to content');checks++;
 await page.keyboard.press('Enter');assert.equal(await page.evaluate(()=>document.activeElement?.id),'main-content');checks++;
 await context.close();
 if(errors.length)failures.push({type:'browser console/page errors',errors});
 await fs.writeFile('verification/browser-results.json',JSON.stringify({engine:'System Chromium via Playwright',viewports:[375,768,1024,1440],checks,results,failures},null,2));
 console.log(`BROWSER CHECKS: ${checks}; failures: ${failures.length}`);
 if(failures.length){console.log(JSON.stringify(failures,null,2));process.exitCode=1;}
}finally{await browser.close();}
