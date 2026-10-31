/* BEAT SHEET — 124 BPM music, 22-second faster cut.
0.00 everyday walks / shoe taps; 3.5 tracking / click; 6.7 points / chimes;
9.6 example offer / paper slide; 13.3 Wallet / voucher pop; 15.6 course reveal;
18.2 brand landing / three-note signature; 18.5–22 centred end-card hold.
All financial figures and the café offer are labelled illustrative demo content.
*/
const VIDEO = window.VIDEO = {w:1080,h:1920,duration:22,loop:false};
const C={cream:'#FEF8EC',surface:'#FFFBF3',sage:'#EBEEDD',green:'#4F6A4D',deep:'#264A3A',ink:'#3F352C',muted:'#6B6355',peach:'#F5DFC5',line:'#DEDCCA',gold:'#E3C889'};
const canvas=document.getElementById('stage'),ctx=canvas.getContext('2d',{alpha:false});
const render=new URLSearchParams(location.search).has('render');
if(render) document.body.classList.add('render');
const clamp=(x,a=0,b=1)=>Math.min(b,Math.max(a,x));
const lerp=(a,b,k)=>a+(b-a)*k;
const seg=(t,a,b)=>clamp((t-a)/(b-a));
const ease=x=>(x=clamp(x),x<.5?4*x*x*x:1-Math.pow(-2*x+2,3)/2);
function spring(t,w=14,z=.82){if(t<=0)return 0;if(z>=1)return 1-Math.exp(-w*t)*(1+w*t);const wd=w*Math.sqrt(1-z*z);return 1-Math.exp(-z*w*t)*(Math.cos(wd*t)+(z*w/wd)*Math.sin(wd*t));}
const track=(v0,keys)=>t=>{let v=v0,p=v0;for(const[tk,val,w,z]of keys){v+=(val-p)*spring(t-tk,w,z);p=val;}return v;};
const kf=keys=>t=>{if(t<=keys[0][0])return keys[0][1];for(let i=1;i<keys.length;i++){const[a,va]=keys[i-1],[b,vb,e=ease]=keys[i];if(t<=b)return lerp(va,vb,e((t-a)/(b-a)));}return keys.at(-1)[1];};
const rng=s=>()=>{s=(s+0x6D2B79F5)|0;let q=s;q=Math.imul(q^(q>>>15),1|q);q^=q+Math.imul(q^(q>>>7),61|q);return((q^(q>>>14))>>>0)/4294967296;};
const beat=60/112;
const stages=[{x:0,y:0},{x:1400,y:0},{x:1400,y:2200},{x:0,y:2200},{x:0,y:4400},{x:1400,y:4400}];
const number=n=>Math.round(n).toLocaleString('en-US');
const imgs={};let camera=[];
// Requested faster pacing: shorten travel while preserving the offer and end-card holds.
// Smooth monotone time remapping keeps all visual contacts deterministic.
const pacing=[[0,0],[2.5,3.55],[3.5,5.2],[5.8,7.95],[6.7,9.35],[8.8,11.95],[9.6,13.6],[11,14.9],[12.3,16.55],[13.3,18.4],[15.6,20.8],[16.6,22.5],[17.3,24.1],[18.2,25.65],[22,30]];
const slopes=pacing.slice(1).map((p,i)=>(p[1]-pacing[i][1])/(p[0]-pacing[i][0]));
const tangents=pacing.map((_,i)=>i===0?slopes[0]:i===pacing.length-1?slopes.at(-1):2*slopes[i-1]*slopes[i]/(slopes[i-1]+slopes[i]));
function retime(t){if(t<=0)return 0;if(t>=22)return 30;let i=0;while(pacing[i+1][0]<t)i++;const[a,va]=pacing[i],[b,vb]=pacing[i+1],d=b-a,u=(t-a)/d;return (2*u*u*u-3*u*u+1)*va+(u*u*u-2*u*u+u)*d*tangents[i]+(-2*u*u*u+3*u*u)*vb+(u*u*u-u*u)*d*tangents[i+1];}
function exportTime(base){let a=0,b=22;for(let i=0;i<30;i++){const m=(a+b)/2;if(retime(m)<base)a=m;else b=m;}return(a+b)/2;}

function rr(x,y,w,h,r=24,fill=C.surface,stroke=null){ctx.beginPath();ctx.roundRect(x,y,w,h,r);if(fill){ctx.fillStyle=fill;ctx.fill();}if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=2;ctx.stroke();}}
function text(s,x,y,size=40,weight=600,color=C.ink,align='left',maxWidth=920){ctx.fillStyle=color;ctx.textAlign=align;ctx.textBaseline='top';ctx.font=`${weight} ${size}px Nunito`;for(const[lineIndex,line]of s.split('\n').entries()){let fs=size;while(ctx.measureText(line).width>maxWidth&&fs>20){fs-=1;ctx.font=`${weight} ${fs}px Nunito`;}ctx.fillText(line,x,y+lineIndex*size*1.10);ctx.font=`${weight} ${size}px Nunito`;}}
function dot(x,y,r,color){ctx.beginPath();ctx.arc(x,y,r,0,Math.PI*2);ctx.fillStyle=color;ctx.fill();}
function line(x1,y1,x2,y2,color=C.line,width=3){ctx.beginPath();ctx.moveTo(x1,y1);ctx.lineTo(x2,y2);ctx.strokeStyle=color;ctx.lineWidth=width;ctx.lineCap='round';ctx.stroke();}
function shadowCard(x,y,w,h,r=38,fill=C.surface){ctx.save();ctx.shadowColor='#264A3A12';ctx.shadowBlur=20;ctx.shadowOffsetY=10;rr(x,y,w,h,r,fill,C.line);ctx.restore();}
function pill(s,x,y,w=240,fill=C.sage,fg=C.deep,size=27){rr(x,y,w,58,29,fill);text(s,x+w/2,y+13,size,800,fg,'center',w-20);}
function check(x,y,size=28,color=C.green){ctx.save();ctx.translate(x,y);ctx.beginPath();ctx.moveTo(-size*.4,0);ctx.lineTo(-size*.08,size*.3);ctx.lineTo(size*.48,-size*.4);ctx.strokeStyle=color;ctx.lineWidth=6;ctx.lineCap='round';ctx.lineJoin='round';ctx.stroke();ctx.restore();}
function logo(x,y,size=56,label=true){ctx.drawImage(imgs.logo,x,y,size,size);if(label)text('Stepsy',x+size+14,y-2,size*.93,900,C.deep);}
function label(index,s){logo(78,62,48);pill(`0${index}  ${s}`,650,60,350,C.surface,C.muted,24);}
function heading(a,b){text(a,78,180,92,900,C.deep);text(b,80,404,34,600,C.muted);}
function imageCover(img,x,y,w,h,r=24){ctx.save();ctx.beginPath();ctx.roundRect(x,y,w,h,r);ctx.clip();const iw=img.naturalWidth||img.width,ih=img.naturalHeight||img.height,scale=Math.max(w/iw,h/ih);ctx.drawImage(img,x+(w-iw*scale)/2,y+(h-ih*scale)/2,iw*scale,ih*scale);ctx.restore();}
function atlas(name,index,x,y,size){const im=imgs[name],i=clamp(Math.floor(index),0,59);ctx.drawImage(im,(i%6)*192,Math.floor(i/6)*192,192,192,x,y,size,size);}
function impact(t,at){return 1+.035*Math.exp(-Math.max(0,t-at)*10)*Math.sin(Math.max(0,t-at)*28);}
function button(s,x,y,w,t,at,enabled=true){const push=t>at&&t<at+.22?Math.sin((t-at)/.22*Math.PI)*7:0;rr(x,y+push,w,90,30,enabled?C.green:C.sage);text(s,x+w/2,y+push+23,32,800,enabled?C.surface:C.deep,'center',w-40);if(t>at&&t<at+.7){ctx.save();ctx.globalAlpha=(1-seg(t,at,at+.7))*.55;ctx.strokeStyle=C.gold;ctx.lineWidth=5;ctx.beginPath();ctx.roundRect(x-12*seg(t,at,at+.7),y-12*seg(t,at,at+.7),w+24*seg(t,at,at+.7),90+24*seg(t,at,at+.7),35);ctx.stroke();ctx.restore();}}

// One physical token, moving through a fixed course. Hops use a parabola.
const contacts=[
 [0,340,1580,0],[2.4,720,1580,0],[3.55,760,1580,0],
 [5.15,2209,1555,480],[5.65,2290,1655,130],[7.9,2290,1655,0],
 [9.35,1620,3130,20],[11.95,2235,3130,0],
 [13.6,850,3430,390],[14.9,540,3733,80],[16,540,3550,100],[16.35,850,3670,90],[16.55,850,3670,0],
 [18.4,540,5910,0],[18.9,820,5830,100],[20.5,820,5830,0],
 [25.65,1630,5739,2150],[30,1630,5739,0],
];
function hero(t){if(t<=0)return{x:340,y:1580};for(let i=1;i<contacts.length;i++){const[a,x0,y0]=contacts[i-1],[b,x1,y1,arc]=contacts[i];if(t<=b){let u=seg(t,a,b);if(i===contacts.length-2)u=u*u*(3-2*u);return{x:lerp(x0,x1,u),y:lerp(y0,y1,u)-4*arc*u*(1-u)};}}return{x:1630,y:5739};}
const ax=kf([[0,540],[3.7,540],[5.2,1940],[7.95,1940],[9.35,1940],[12,1940],[13.6,540],[16.5,540],[18.4,540],[20.8,540],[22.4,1240],[24.1,1240],[25.65,1940],[30,1940]]);
const ay=kf([[0,780],[3.7,780],[5.2,780],[7.95,780],[9.35,3100],[12,3100],[13.6,2980],[16.5,2980],[18.4,5180],[20.8,5180],[22.4,3100],[24.1,3100],[25.65,5200],[30,5200]]);
const zoom=kf([[0,1],[3.7,1],[4.3,.82],[5.2,1],[8,.94],[9.35,1],[12.3,.94],[13.6,1],[16.6,.96],[18.4,1],[20.8,.98],[22.5,.265],[24.1,.265],[25.65,1],[30,1]]);
function bakeCamera(){const dt=1/240;let x=500,y=940,vx=0,vy=0;camera=[];for(let i=0;i<=30*240+2;i++){const t=i*dt,future=hero(Math.min(t+.12,30));const weight=t<20.8?.8:lerp(.8,1,ease(seg(t,20.8,21.5)));const tx=lerp(future.x,ax(t),weight),ty=lerp(future.y,ay(t),weight);const w=12;vx+=((tx-x)*w*w-2*w*vx)*dt;vy+=((ty-y)*w*w-2*w*vy)*dt;x+=vx*dt;y+=vy*dt;camera.push({x,y,z:zoom(t)});}}

function stationWalk(t){label(1,'Your everyday walk');heading('Roz ke qadam.\nDiscount ki taraf.','Wohi routine. A little more to look forward to.');
 const f=Math.min(Math.floor(t*30),imgs.walkingFrames.length-1),g=Math.min(Math.floor(t*25),imgs.joggingFrames.length-1);
 shadowCard(78,510,924,526,34);imageCover(imgs.walkingFrames[f],82,514,916,518,30);
 pill('Walk your way',102,944,290,C.surface,C.deep,26);
 shadowCard(78,1090,924,430,34);imageCover(imgs.joggingFrames[g],82,1094,916,422,30);pill('A little movement',102,1424,335,C.surface,C.deep,26);
 line(235,1580,850,1580,C.sage,18);line(235,1580,lerp(340,760,ease(seg(t,0,3.55))),1580,C.green,18);
 text('Your phone stays with you.',540,1650,30,700,C.muted,'center');
}

function stationTracking(t){label(2,'Tracking');heading('Phone jeb mein.\nWalk apni.','Enable tracking. Then get on with your day.');
 const pocket=clamp(spring(t-6.15,12,1));ctx.save();ctx.translate(0,pocket*220);
 shadowCard(230,490,620,1000,60,C.deep);rr(246,508,588,960,48,C.cream);dot(540,530,8,'#25382e');
 logo(282,567,38);pill('71 pts',648,562,146,C.sage,C.deep,23);
 text('Today’s walk',282,655,34,800);const n=6240+Math.floor(8*seg(t,5.2,8.45));text(number(n),282,714,95,900,C.deep);text('steps today',284,827,27,600);
 ctx.beginPath();ctx.arc(741,777,49,-Math.PI/2,-Math.PI/2+Math.PI*2*.78);ctx.strokeStyle=C.green;ctx.lineWidth=9;ctx.stroke();text('78%',741,758,27,900,C.deep,'center');
 imageCover(imgs.trail,278,892,524,280,22);atlas(t<5.2?'wave':'walk',t<5.2?0:((t-5.2)/1.2%1)*60,532,902,240);
 rr(278,1167,524,13,7,C.sage);rr(278,1167,409,13,7,C.green);text('1,752 steps to your goal',540,1204,25,700,C.deep,'center');
 text('Live steps · Points after sync',540,1276,24,600,C.muted,'center');text('APP PREVIEW · SAMPLE DATA',540,1402,18,800,C.muted,'center');
 ctx.restore();if(pocket>0){ctx.save();ctx.globalAlpha=pocket;ctx.beginPath();ctx.moveTo(185,1112);ctx.quadraticCurveTo(540,1185,895,1112);ctx.lineTo(865,1735);ctx.quadraticCurveTo(540,1795,215,1735);ctx.closePath();ctx.fillStyle=C.sage;ctx.fill();ctx.strokeStyle=C.line;ctx.lineWidth=3;ctx.stroke();ctx.setLineDash([8,10]);ctx.beginPath();ctx.moveTo(215,1145);ctx.quadraticCurveTo(540,1210,865,1145);ctx.strokeStyle='#A7B292';ctx.stroke();ctx.restore();}
 const on=t>=5.15;shadowCard(110,1370,860,240,32,C.surface);logo(146,1410,53,false);text(on?'Background tracking on':'Tracking paused',225,1405,34,900,C.deep);text(on?'Motion access allowed':'Resume when you’re ready',225,1458,28,600,C.muted);
 button(on?'Stop tracking':'Resume tracking',690,1510,238,t,5.15);text('You stay in control.',145,1532,27,700,C.muted);
}

function stationPoints(t){label(3,'Points');heading('Walks se\npoints jama.','Your eligible steps count after syncing.');
 shadowCard(100,570,880,545,42,C.sage);text('Available points',148,615,36,700,C.deep);const n=71+Math.floor(62*ease(seg(t,9.35,11.5)));text(number(n),148,690,164,900,C.deep);text('points to enjoy',153,877,35,600);ctx.drawImage(imgs.welcome,615,620,300,300);
 pill(t>=9.35?'Steps synced':'Syncing…',147,974,300,C.surface,C.deep,28);if(t>=9.35)check(405,1003,20);
 shadowCard(100,1165,880,235,36);text('Today’s walk',150,1205,33,800);text('6,248 eligible steps',150,1263,28,600,C.muted);text('+62',912,1215,62,900,C.green,'right');text('Earlier walks',150,1331,28,700,C.muted);text('+71',910,1328,32,800,C.muted,'right');
 line(220,930,835,930,C.surface,18);line(220,930,lerp(220,835,ease(seg(t,9.35,11.95))),930,C.green,18);
 text('Across your everyday walks.',540,1530,33,700,C.muted,'center');text('Illustrative totals · Points are not cash',540,1630,25,600,C.muted,'center');
}

function coffee(x,y,s){ctx.save();ctx.translate(x,y);ctx.scale(s,s);rr(-130,-110,260,220,48,C.peach);ctx.strokeStyle=C.green;ctx.lineWidth=15;ctx.beginPath();ctx.arc(74,15,40,-Math.PI/2,Math.PI/2);ctx.stroke();rr(-77,-40,145,132,25,C.surface,C.green);ctx.fillStyle='#B77E50';ctx.beginPath();ctx.ellipse(-4,-28,59,17,0,0,Math.PI*2);ctx.fill();ctx.strokeStyle=C.surface;ctx.lineWidth=5;ctx.beginPath();ctx.ellipse(-5,-28,27,8,.05,0,Math.PI*2);ctx.stroke();for(let i=0;i<3;i++){ctx.beginPath();ctx.moveTo(-38+i*35,-68);ctx.bezierCurveTo(-58+i*35,-98,-20+i*35,-95,-38+i*35,-128);ctx.strokeStyle='#A4AF8F';ctx.lineWidth=5;ctx.stroke();}ctx.restore();}
function stationOffer(t){label(4,'Rewards');heading('Points se\npartner discounts.','Choose something you’ll actually enjoy.');
 const confirmed=t>=16;shadowCard(105,550,870,970,44);
 coffee(540,760,1.2);pill('EXAMPLE OFFER',150,1032,350,C.sage,C.deep,25);
 text('Sample café',150,1119,31,700,C.muted);text('20% off\nyour order',150,1175,73,900,C.ink);text('100 pts',150,1391,39,900,C.deep);pill('133 pts available',530,1380,390,C.peach,C.deep,26);
 if(t>=14.9){rr(128,884,824,635,38,C.surface,C.line);text('Make it yours.',170,941,64,900,C.deep);text('Example café offer',170,1031,35,700,C.muted);text('100 points',170,1113,70,900,C.deep);text(confirmed?'Saved in Wallet':'Balance after claim: 33 pts',170,1221,34,700,C.muted);button(confirmed?'Voucher ready':'Confirm & redeem',170,1305,740,t,16);}
 else button('View reward',170,1488,740,t,14.9);
 if(confirmed){pill('Claim confirmed',320,1562,440,C.sage,C.deep,30);check(703,1591,21);}
 text('Illustrative offer · Actual partner terms apply',540,1695,26,600,C.muted,'center');
}

const qrRand=rng(7351),qr=Array.from({length:29},()=>Array.from({length:29},()=>qrRand()>.52));
function drawQR(x,y,size){const n=29,k=size/n;ctx.fillStyle=C.deep;for(let r=0;r<n;r++)for(let c=0;c<n;c++){const finder=(c<8&&r<8)||(c>20&&r<8)||(c<8&&r>20);if(!finder&&qr[r][c])ctx.fillRect(x+c*k,y+r*k,k+.25,k+.25);}for(const[a,b]of[[0,0],[22,0],[0,22]]){rr(x+a*k,y+b*k,k*7,k*7,3,C.deep);rr(x+(a+1)*k,y+(b+1)*k,k*5,k*5,1,C.surface);rr(x+(a+2)*k,y+(b+2)*k,k*3,k*3,1,C.deep);}}
function stationWallet(t){label(5,'Wallet');heading('Voucher dikhao.\nFaida uthao.','Show your voucher at the partner store.');
 shadowCard(115,530,850,1050,44,C.surface);pill('Ready to use',165,575,320,C.sage,C.deep,29);text('Your little win.',165,682,64,900,C.deep);text('Sample café · 20% off',165,768,34,700,C.muted);
 if(t>=18.4){const p=clamp(spring(t-18.4,16,.95));ctx.save();ctx.translate(540,1107);ctx.scale(.85+.15*p,.85+.15*p);ctx.translate(-540,-1107);ctx.globalAlpha=p;rr(315,882,450,450,28,C.cream,C.line);drawQR(350,917,380);rr(371,1068,338,75,15,C.surface);text('DEMO ONLY',540,1083,36,900,C.deep,'center');ctx.restore();}else coffee(540,1107,1.6);
 text('Demo voucher · Not redeemable',540,1381,26,800,C.muted,'center');
 button(t>=18.4?'Show in store':'Show voucher',200,1465,680,t,18.4);
 if(t>=19.35){pill('Use your partner discount',150,1630,780,C.sage,C.deep,34);}
 text('Available balance after example claim: 33 pts',540,1730,27,600,C.muted,'center');
}

function stationClose(t){ctx.font='900 104.16px Nunito';const brandWidth=112+14+ctx.measureText('Stepsy').width;logo(540-brandWidth/2,190,112);text('Qadam aapke.\nFaida bhi aapka.',540,435,90,900,C.deep,'center',940);
 const i=clamp((t-25.65)/2.5)*59;atlas('wave',i,275,680,530);
 pill('Coming soon on Android',150,1310,780,C.green,C.surface,38);
 text('Walk. Collect points. Enjoy partner discounts.',540,1452,31,800,C.deep,'center',980);
 text('Tracking permissions required. Earning rules\nand partner offer terms apply.',540,1580,26,600,C.muted,'center',950);
 text('BY HANOVA DEVS',540,1720,24,900,C.muted,'center');
}

function drawHero(t,z){const h=hero(t),before=hero(Math.max(0,t-.015)),after=hero(Math.min(30,t+.015));let angle=Math.atan2(after.y-before.y,after.x-before.x)+Math.PI/2;if(Math.hypot(after.x-before.x,after.y-before.y)<.1)angle=0;
 const landing=[0,5.15,9.35,14.9,16,18.4,25.65].filter(a=>a<=t).at(-1)??0;const d=t-landing;const squash=1+.20*Math.exp(-d*14)*Math.cos(d*24);const wide=Math.max(1,.44/z);
 ctx.save();ctx.translate(h.x,h.y);ctx.rotate(angle*.25);ctx.scale(wide*squash,wide/squash);
 if(z<.6){dot(0,0,48,'#FEF8EC88');}dot(0,0,33,C.green);dot(-4,-8,11,C.surface);ctx.save();ctx.rotate(-.25);rr(-12,1,17,22,8,C.surface);ctx.restore();dot(15,-18,4,C.gold);ctx.restore();
}

window.seek=function(t){t=retime(clamp(t,0,VIDEO.duration));if(!window.READY)return;const cam=camera[Math.min(Math.round(t*240),camera.length-1)];ctx.setTransform(1,0,0,1,0,0);ctx.fillStyle=C.cream;ctx.fillRect(0,0,1080,1920);ctx.translate(540,960);ctx.scale(cam.z,cam.z);ctx.translate(-cam.x,-cam.y);
 ctx.save();ctx.globalAlpha=.17;ctx.fillStyle=grid;ctx.fillRect(cam.x-700/cam.z,cam.y-1100/cam.z,1400/cam.z,2200/cam.z);ctx.restore();
 // A fixed course, never a GPS map. Muted connectors make the reveal readable.
 ctx.save();ctx.globalAlpha=clamp((.75-cam.z)/.3);ctx.strokeStyle='#A4B48D66';ctx.lineWidth=8;ctx.setLineDash([4,22]);ctx.beginPath();const start=hero(0);ctx.moveTo(start.x,start.y);for(let s=.05;s<=20.5;s+=.05){const p=hero(s);ctx.lineTo(p.x,p.y);}ctx.stroke();ctx.restore();
 const paint=[stationWalk,stationTracking,stationPoints,stationOffer,stationWallet,stationClose];for(let i=0;i<6;i++){ctx.save();ctx.translate(stages[i].x,stages[i].y);paint[i](t);ctx.restore();}
 drawHero(t,cam.z);ctx.setTransform(1,0,0,1,0,0);
};
let grid;
async function loadImage(url){return new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>resolve(im);im.onerror=reject;im.src=url;});}
window.readyPromise=(async()=>{await document.fonts.load('900 90px Nunito');await document.fonts.ready;for(const[k,v]of Object.entries(ASSETS)){imgs[k]=Array.isArray(v)?await Promise.all(v.map(loadImage)):await loadImage(v);}const p=document.createElement('canvas');p.width=p.height=96;const pc=p.getContext('2d');pc.fillStyle='#62784d';pc.beginPath();pc.arc(3,3,1.3,0,Math.PI*2);pc.fill();grid=ctx.createPattern(p,'repeat');bakeCamera();window.READY=true;window.seek(0);})();

// Original deterministic 124-BPM music, with contact sounds retimed to the faster cut.
window.buildAudio=async function(ac){const master=ac.createGain();master.gain.value=.65;master.connect(ac.destination);const random=rng(9017);const noise=ac.createBuffer(1,ac.sampleRate*.3,ac.sampleRate),a=noise.getChannelData(0);for(let i=0;i<a.length;i++)a[i]=random()*2-1;
 function note(midi,at,dur=.35,level=.08,type='triangle'){const o=ac.createOscillator(),g=ac.createGain();o.type=type;o.frequency.value=440*Math.pow(2,(midi-69)/12);g.gain.setValueAtTime(0,at);g.gain.linearRampToValueAtTime(level,at+.009);g.gain.exponentialRampToValueAtTime(.0001,at+dur);o.connect(g);g.connect(master);o.start(at);o.stop(at+dur+.02);}
 function hiss(at,dur=.06,level=.018,hz=6000){const s=ac.createBufferSource(),f=ac.createBiquadFilter(),g=ac.createGain();s.buffer=noise;f.type='highpass';f.frequency.value=hz;g.gain.setValueAtTime(level,at);g.gain.exponentialRampToValueAtTime(.0001,at+dur);s.connect(f);f.connect(g);g.connect(master);s.start(at);s.stop(at+dur);}
 const chords=[[50,57,62,66],[55,59,62,67],[52,59,64,67],[57,61,64,69]];
 const audioBeat=60/124;
 for(let b=0;b*audioBeat<VIDEO.duration;b++){const at=b*audioBeat,bar=Math.floor(b/4),ch=chords[bar%4];if(b%4===0)for(const m of ch)note(m,at,1.6,.026,'sine');note(ch[0]-12,at,.23,b%2===0?.07:.035,'sine');if(b%2===0){const o=ac.createOscillator(),g=ac.createGain();o.frequency.setValueAtTime(110,at);o.frequency.exponentialRampToValueAtTime(42,at+.1);g.gain.setValueAtTime(.15,at);g.gain.exponentialRampToValueAtTime(.001,at+.16);o.connect(g);g.connect(master);o.start(at);o.stop(at+.17);}if(b>5){hiss(at,.05,.016);hiss(at+audioBeat/2,.04,.008);}if(b%4===2)hiss(at,.10,.036,1500);if(b>5&&at<19&&b%2===1)note(ch[2]+12,at+audioBeat/2,.22,.038);}
 for(const[base,m]of[[0,62],[.54,64],[1.07,66],[5.15,69],[9.35,74],[10.42,76],[11.49,78],[14.9,69],[16,74],[18.4,78],[25.65,74],[25.92,78],[26.19,81]]){const t=exportTime(base);note(m,t,.32,.13);hiss(t,.045,.023,2100);}
 const fade=master.gain;fade.setValueAtTime(.65,VIDEO.duration-1.2);fade.linearRampToValueAtTime(.0001,VIDEO.duration);
};
if(!render){const play=document.getElementById('play'),scrub=document.getElementById('scrub'),out=document.getElementById('time');scrub.max=VIDEO.duration;let ac,buffer,src,playing=false,offset=0,start=0;const now=()=>playing?Math.min(VIDEO.duration,offset+ac.currentTime-start):offset;
 async function pause(){if(playing){offset=now();src.stop();playing=false;play.textContent='Play';}}
 play.onclick=async()=>{await window.readyPromise;if(playing)return pause();ac??=new AudioContext();await ac.resume();if(!buffer){const off=new OfflineAudioContext(2,48000*VIDEO.duration,48000);await window.buildAudio(off);buffer=await off.startRendering();}if(offset>=VIDEO.duration)offset=0;src=ac.createBufferSource();src.buffer=buffer;src.connect(ac.destination);src.start(0,offset);start=ac.currentTime;playing=true;play.textContent='Pause';};scrub.oninput=async()=>{await pause();offset=+scrub.value;window.seek(offset);};
 (function loop(){if(window.READY){const t=now();window.seek(t);scrub.value=t;out.value=`0:${String(Math.floor(t)).padStart(2,'0')}`;if(t>=VIDEO.duration&&playing)pause();}requestAnimationFrame(loop);})();
}
