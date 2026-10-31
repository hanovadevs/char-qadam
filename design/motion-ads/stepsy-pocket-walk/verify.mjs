// Check random-access rendering and the closing camera's centre, without touching app data.
import {createRequire} from 'node:module';
import {createHash} from 'node:crypto';
import {writeFileSync} from 'node:fs';
import {pathToFileURL} from 'node:url';
import path from 'node:path';
const [html,modulePath,browserPath,reportPath]=process.argv.slice(2);
const {chromium}=createRequire(import.meta.url)(path.resolve(modulePath));
const browser=await chromium.launch({executablePath:browserPath,headless:true});
try {
 const page=await browser.newPage({viewport:{width:1080,height:1920}}),errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 await page.goto(pathToFileURL(path.resolve(html)).href+'?render');
 await page.waitForFunction(()=>window.READY===true);
 const info=await page.evaluate(()=>({video:window.VIDEO,fonts:[...document.fonts].map(f=>({family:f.family,status:f.status})),centres:[.92,.96,.999].map(u=>{const t=u*VIDEO.duration;if(typeof camera!=='undefined'){const cam=camera[Math.round(retime(t)*240)];return{t,x:540+(1940-cam.x)*cam.z};}window.seek(t);const row=document.getElementById('stage').getContext('2d').getImageData(0,1500,1080,1).data,x=[];for(let i=0;i<1080;i++)if(row[i*4]===79&&row[i*4+1]===106&&row[i*4+2]===77)x.push(i);return{t,x:(x[0]+x.at(-1))/2};})}));
 const hash=async(t)=>{await page.evaluate(t=>window.seek(t),t);return createHash('sha256').update(await page.screenshot()).digest('hex');};
 const times=[0,4.1,7.8,11.8,14.3,17,20.2],first=new Map();
 for(const t of times)first.set(t,await hash(t));
 const checks=[];for(const t of [...times].reverse())checks.push({t,identical:first.get(t)===await hash(t)});
 if(errors.length||checks.some(c=>!c.identical)||info.fonts.some(f=>f.status!=='loaded')||info.centres.some(c=>!Number.isFinite(c.x)||Math.abs(c.x-540)>1)||info.video.duration<=0)throw new Error(JSON.stringify({errors,checks,info}));
 const report={...info,randomAccess:checks,pageErrors:errors};
 if(reportPath)writeFileSync(reportPath,JSON.stringify(report,null,2));
 console.log(JSON.stringify(report));
}finally{await browser.close();}
