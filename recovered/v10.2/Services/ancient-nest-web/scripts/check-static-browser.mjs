import {chromium} from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';
import assert from 'node:assert/strict';
import {existsSync} from 'node:fs';
const base=process.env.TEST_BASE_URL||'http://127.0.0.1:3101';
const executable=process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE||(existsSync('/usr/bin/chromium')?'/usr/bin/chromium':undefined);
const browser=await chromium.launch({executablePath:executable,args:['--no-sandbox','--disable-dev-shm-usage']});let checks=0;
try{for(const width of [375,1440]){
const context=await browser.newContext({viewport:{width,height:900}});const page=await context.newPage();const errors=[];page.on('pageerror',e=>errors.push(e.message));await page.goto(base,{waitUntil:'networkidle'});
assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);checks++;
const axe=await new AxeBuilder({page}).withTags(['wcag2a','wcag2aa','wcag21a','wcag21aa']).analyze();assert.equal(axe.violations.length,0);checks++;
if(width===375){await page.getByRole('button',{name:'Open navigation'}).click();await page.getByRole('navigation',{name:'Mobile navigation'}).getByRole('link',{name:'Game',exact:true}).click();await page.waitForURL('**/game/');assert.equal(await page.getByRole('heading',{level:1}).textContent(),'Ancient world. New warfare.');checks++;}
await page.goto(base+'/news/',{waitUntil:'networkidle'});await page.getByRole('link',{name:'Read update: Development Update'}).click();await page.waitForURL('**/news/development-update/');assert.equal(await page.getByRole('heading',{level:1}).textContent(),'Development Update');checks++;
assert.deepEqual(errors,[]);checks++;await context.close();console.log('PASS static export width',width);
}console.log('STATIC BROWSER CHECKS:',checks,'passed');}finally{await browser.close();}
