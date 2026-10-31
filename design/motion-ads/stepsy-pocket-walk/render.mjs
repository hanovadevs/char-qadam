// Adapted from Barty-Bart/motion-graphics explainer renderer.
// No source media is deleted; render intermediates stay in the explicit cache directory.
import { createRequire } from 'node:module';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { mkdirSync,writeFileSync,readFileSync } from 'node:fs';
import path from 'node:path';
import { pathToFileURL } from 'node:url';

const [html,out,...flags]=process.argv.slice(2);
if(!html||!out)throw new Error('render.mjs HTML OUTPUT --ffmpeg EXE --playwright MODULE --browser EXE [--fps 30 --subframes 1 --workers 4 | --stills 0,1,2]');
const opts={};for(let i=0;i<flags.length;i+=2)opts[flags[i].replace(/^--/,'')]=flags[i+1];
const ffmpeg=opts.ffmpeg||process.env.FFMPEG_PATH||'ffmpeg';
const require=createRequire(import.meta.url);
const {chromium}=opts.playwright?require(path.resolve(opts.playwright)):require('playwright');
const cache=path.resolve(opts.cache||'mobile/build/stepsy-ad-cache/render');mkdirSync(cache,{recursive:true});
mkdirSync(path.dirname(path.resolve(out)),{recursive:true});
const browser=await chromium.launch({headless:true,...(opts.browser?{executablePath:opts.browser}:{}),args:['--allow-file-access-from-files','--disable-background-timer-throttling']});
const url=pathToFileURL(path.resolve(html)).href+'?render';
const errors=[];
async function openPage(){const page=await browser.newPage({viewport:{width:1080,height:1920},deviceScaleFactor:1});page.on('pageerror',e=>errors.push(e.message));await page.goto(url,{waitUntil:'load',timeout:120000});await page.waitForFunction(()=>window.READY===true,{},{timeout:120000});return page;}
async function run(args){const p=spawn(ffmpeg,args,{windowsHide:true,stdio:['ignore','pipe','pipe']});let err='';p.stderr.on('data',d=>err+=d);p.stdout.on('data',()=>{});const[code]=await once(p,'close');if(code!==0)throw new Error(`FFmpeg ${code}: ${err.slice(-1600)}`);return err;}
async function frame(page,t){await page.evaluate(t=>window.seek(t),t);return page.screenshot({type:'jpeg',quality:95,animations:'disabled',timeout:120000});}

try{
 if(opts.stills){const page=await openPage();const times=opts.stills.split(',').map(Number);const dir=path.join(cache,'stills');mkdirSync(dir,{recursive:true});for(let i=0;i<times.length;i++){writeFileSync(path.join(dir,`${String(i).padStart(3,'0')}.jpg`),await frame(page,times[i]));}await page.close();const cols=Math.min(3,times.length),rows=Math.ceil(times.length/cols);await run(['-v','error','-y','-framerate','1','-i',path.join(dir,'%03d.jpg'),'-vf',`scale=360:640,tile=${cols}x${rows}:padding=8:color=0xDEDCCA`,'-frames:v','1',path.resolve(out)]);console.log(`Contact sheet: ${path.resolve(out)}`);
 }else{
  const probe=await openPage();const duration=await probe.evaluate(()=>window.VIDEO.duration);await probe.close();
  const fps=+(opts.fps||30),sub=+(opts.subframes||1),workers=+(opts.workers||4),N=Math.round(duration*fps);
  const start=Date.now();let done=0;const count=Math.ceil(N/workers),parts=[];
  await Promise.all(Array.from({length:workers},async(_,w)=>{const a=w*count,b=Math.min(N,a+count);if(a>=b)return;const file=path.join(cache,`part-${fps}-${sub}-${w}.mp4`);parts[w]=file;const page=await openPage();const vf=sub>1?['-vf',`tmix=frames=${sub},select='eq(mod(n\\,${sub})\\,${sub-1})',settb=expr=1/${fps},setpts=N,tpad=stop_mode=clone:stop_duration=${2/fps}`]:[];
   const p=spawn(ffmpeg,['-v','error','-y','-f','image2pipe','-framerate',String(fps*sub),'-i','-',...vf,'-r',String(fps),'-frames:v',String(b-a),'-c:v','libx264','-threads','2','-pix_fmt','yuv420p','-crf','17','-preset','fast','-movflags','+faststart',file],{windowsHide:true,stdio:['pipe','ignore','pipe']});let stderr='';p.stderr.on('data',d=>stderr+=d);p.stdin.on('error',()=>{});const closed=once(p,'close');
   for(let f=a;f<b;f++){if(p.exitCode!==null)throw new Error(stderr);for(let s=0;s<sub;s++){const buf=await frame(page,(f+(sub>1?(s/sub)*.5:0))/fps);if(!p.stdin.write(buf))await once(p.stdin,'drain');}done++;if(done%90===0)console.log(`${done}/${N} frames, ${Math.round((Date.now()-start)/1000)}s elapsed`);}p.stdin.end();const[code]=await closed;await page.close();if(code!==0)throw new Error(stderr);
  }));
  const concat=path.join(cache,`concat-${fps}-${sub}.txt`);writeFileSync(concat,parts.filter(Boolean).map(p=>`file '${p.replaceAll('\\','/')}'`).join('\n'));
  const silent=path.resolve(out).replace(/\.mp4$/,'_silent.mp4');await run(['-v','error','-y','-f','concat','-safe','0','-i',concat,'-c','copy','-movflags','+faststart',silent]);
  const page=await openPage();const pcm64=await page.evaluate(async()=>{const ac=new OfflineAudioContext(2,Math.ceil(48000*window.VIDEO.duration),48000);await window.buildAudio(ac);const b=await ac.startRendering(),L=b.getChannelData(0),R=b.getChannelData(1),i16=new Int16Array(L.length*2);for(let i=0;i<L.length;i++){i16[2*i]=Math.max(-1,Math.min(1,L[i]))*32767;i16[2*i+1]=Math.max(-1,Math.min(1,R[i]))*32767;}const bytes=new Uint8Array(i16.buffer);let str='';for(let i=0;i<bytes.length;i+=32768)str+=String.fromCharCode(...bytes.subarray(i,i+32768));return btoa(str);});await page.close();const pcm=path.join(cache,'soundtrack.pcm');writeFileSync(pcm,Buffer.from(pcm64,'base64'));
  await run(['-v','error','-y','-i',silent,'-f','s16le','-ar','48000','-ac','2','-i',pcm,'-af','loudnorm=I=-16:TP=-1.5:LRA=11','-ar','48000','-c:v','copy','-c:a','aac','-b:a','192k','-t',String(duration),'-movflags','+faststart',path.resolve(out)]);
  console.log(`Rendered ${path.resolve(out)} in ${Math.round((Date.now()-start)/1000)}s`);
 }
 if(errors.length)throw new Error(`Page errors: ${[...new Set(errors)].join('; ')}`);
}finally{await browser.close();}
