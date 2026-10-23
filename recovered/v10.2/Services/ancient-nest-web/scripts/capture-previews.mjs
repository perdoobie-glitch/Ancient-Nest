import {chromium} from '@playwright/test';
import {existsSync} from 'node:fs';
import fs from 'node:fs/promises';
const browser=await chromium.launch({executablePath:process.env.PLAYWRIGHT_CHROMIUM_EXECUTABLE||(existsSync('/usr/bin/chromium')?'/usr/bin/chromium':undefined),args:['--no-sandbox','--disable-dev-shm-usage']});
const base=process.env.TEST_BASE_URL||'http://127.0.0.1:3100';await fs.mkdir('verification',{recursive:true});
try{for(const width of [375,1440]){
 const context=await browser.newContext({viewport:{width,height:900},reducedMotion:'reduce'});const page=await context.newPage();await page.goto(base,{waitUntil:'networkidle'});
 const height=await page.evaluate(()=>document.documentElement.scrollHeight);
 for(let y=0;y<height;y+=700){await page.evaluate(y=>window.scrollTo(0,y),y);await page.waitForTimeout(90);}
 await page.waitForLoadState('networkidle');
 const broken=await page.locator('img').evaluateAll(async imgs=>{await Promise.all(imgs.map(img=>img.decode().catch(()=>{})));return imgs.filter(img=>!img.naturalWidth).map(img=>img.src);});
 if(broken.length)throw Error('Unloaded/broken image: '+broken.join(', '));
 await page.evaluate(()=>scrollTo(0,0));await page.screenshot({path:`verification/home-${width}.png`,fullPage:true});await page.screenshot({path:`verification/hero-${width}.png`});await context.close();console.log('Preview captured, all images decoded:',width);
}}finally{await browser.close();}
