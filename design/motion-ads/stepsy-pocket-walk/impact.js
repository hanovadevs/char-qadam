/* STEPSY / IMPACT CUT — 128 BPM, 44 beats, 20.625 seconds.
   0.000 masked giant brand; 0.234 footprint slam, shake, expanding film iris
   2.344 phone reveal, live steps, pocket / sweep + step contacts
   5.625 step-to-point transfer, balance punch-in / rising plucks
   8.438 reward ticket, 100-point claim / paper sweep, click, success
  12.188 Wallet catch, QR close-up / fold, pop
  15.469 three-part recap becomes brand / sweep, signature
  17.000–20.625 centred brand hold / resolved chord, fade
   Brand adaptation of Barty-Bart high-energy: cozy palette, no technical HUD.
   All balances, café offer and QR are illustrative, never a partner claim.
*/
const VIDEO=window.VIDEO={w:1080,h:1920,duration:20.625,loop:false};
const C={cream:'#FEF8EC',surface:'#FFFBF3',sage:'#E5EBD6',green:'#4F6A4D',deep:'#264A3A',ink:'#3F352C',muted:'#6B6355',peach:'#F5DFC5',line:'#DEDCCA',gold:'#E3C889'};
const canvas=document.getElementById('stage'),ctx=canvas.getContext('2d',{alpha:false});
const render=new URLSearchParams(location.search).has('render');if(render)document.body.classList.add('render');
const clamp=(x,a=0,b=1)=>Math.min(b,Math.max(a,x)),lerp=(a,b,k)=>a+(b-a)*k;
const seg=(t,a,b)=>clamp((t-a)/(b-a));
const ease=x=>(x=clamp(x),x<.5?4*x*x*x:1-Math.pow(-2*x+2,3)/2);
const out=x=>1-Math.pow(1-clamp(x),3);
function spring(t,w=15,z=.76){if(t<=0)return 0;const wd=w*Math.sqrt(1-z*z);return 1-Math.exp(-z*w*t)*(Math.cos(wd*t)+z*w/wd*Math.sin(wd*t));}
const rng=s=>()=>{s=(s+0x6D2B79F5)|0;let q=s;q=Math.imul(q^(q>>>15),1|q);q^=q+Math.imul(q^(q>>>7),61|q);return((q^(q>>>14))>>>0)/4294967296;};
const imgs={},B=60/128,starts=[0,5*B,12*B,18*B,26*B,33*B];let sceneBg=C.cream;
window.CUES=[{t:B/2,type:'reveal',desc:'Footprint slam / camera shake'},{t:B,type:'movement',desc:'Film portal opens'},{t:5*B,type:'scene_cut',desc:'Phone reveal'},{t:8*B,type:'click',desc:'Live steps focus'},{t:10*B,type:'movement',desc:'Phone enters pocket'},{t:12*B,type:'scene_cut',desc:'Steps become points'},{t:14*B,type:'appear',desc:'Points arrive'},{t:17*B,type:'success',desc:'Balance lands at 133'},{t:18*B,type:'scene_cut',desc:'Offer ticket reveal'},{t:23*B,type:'click',desc:'Redeem press'},{t:24*B,type:'success',desc:'Reward claimed'},{t:26*B,type:'scene_cut',desc:'Wallet catches voucher'},{t:29*B,type:'movement',desc:'QR focus'},{t:31*B,type:'success',desc:'Ready to show'},{t:33*B,type:'scene_cut',desc:'Workflow recap'},{t:36*B,type:'reveal',desc:'Stepsy brand reveal'}];
function rect(x,y,w,h,r=30,fill=C.surface,stroke=null){ctx.beginPath();ctx.roundRect(x,y,w,h,r);if(fill){ctx.fillStyle=fill;ctx.fill();}if(stroke){ctx.lineWidth=2;ctx.strokeStyle=stroke;ctx.stroke();}}
function circle(x,y,r,fill,stroke=null,lw=3){ctx.beginPath();ctx.arc(x,y,Math.max(0,r),0,Math.PI*2);if(fill){ctx.fillStyle=fill;ctx.fill();}if(stroke){ctx.strokeStyle=stroke;ctx.lineWidth=lw;ctx.stroke();}}
function line(x,y,a,b,color=C.green,width=5){ctx.beginPath();ctx.moveTo(x,y);ctx.lineTo(a,b);ctx.strokeStyle=color;ctx.lineWidth=width;ctx.lineCap='round';ctx.stroke();}
function text(s,x,y,size=60,weight=900,color=C.deep,align='center',width=960){ctx.fillStyle=color;ctx.textAlign=align;ctx.textBaseline='top';ctx.font=`${weight} ${size}px Nunito`;for(const[i,l]of s.split('\n').entries()){let fs=size;while(ctx.measureText(l).width>width&&fs>18){fs--;ctx.font=`${weight} ${fs}px Nunito`;}ctx.fillText(l,x,y+i*size*1.08);ctx.font=`${weight} ${size}px Nunito`;}}
function pill(s,x,y,w=500,h=68,fill=C.sage,fg=C.deep,size=29){rect(x,y,w,h,h/2,fill);text(s,x+w/2,y+(h-size*1.1)/2,size,800,fg,'center',w-30);}
function card(x,y,w,h,r=40,fill=C.surface){ctx.save();ctx.shadowColor='#264A3A1A';ctx.shadowBlur=32;ctx.shadowOffsetY=16;rect(x,y,w,h,r,fill,C.line);ctx.restore();}
function check(x,y,s=35,color=C.surface){ctx.beginPath();ctx.moveTo(x-s*.45,y);ctx.lineTo(x-s*.08,y+s*.32);ctx.lineTo(x+s*.5,y-s*.38);ctx.strokeStyle=color;ctx.lineWidth=s*.15;ctx.lineCap='round';ctx.lineJoin='round';ctx.stroke();}
function brand(cx,y,size=74,color=C.deep){ctx.font=`900 ${size}px Nunito`;const tw=ctx.measureText('Stepsy').width,iconW=size*.98*LOGO_BOUNDS[2]/LOGO_BOUNDS[3],gap=size*.17,total=iconW+gap+tw,x=cx-total/2;ctx.drawImage(imgs.logo,...LOGO_BOUNDS,x,y-size*.02,iconW,size*.98);text('Stepsy',x+iconW+gap,y,size,900,color,'left');}
function cover(img,x,y,w,h,r=0){ctx.save();ctx.beginPath();ctx.roundRect(x,y,w,h,r);ctx.clip();const k=Math.max(w/img.width,h/img.height);ctx.drawImage(img,x+(w-img.width*k)/2,y+(h-img.height*k)/2,img.width*k,img.height*k);ctx.restore();}
function atlas(name,index,x,y,size){const i=clamp(Math.floor(index),0,59);ctx.drawImage(imgs[name],i%6*192,Math.floor(i/6)*192,192,192,x,y,size,size);}
function footprint(x,y,size=80,angle=0,color=C.green,reverse=false){ctx.save();ctx.translate(x,y);ctx.rotate(angle);ctx.scale(reverse?-1:1,1);ctx.fillStyle=color;ctx.beginPath();ctx.ellipse(-size*.04,-size*.23,size*.23,size*.34,-.22,0,Math.PI*2);ctx.fill();ctx.beginPath();ctx.ellipse(size*.07,size*.30,size*.19,size*.21,-.10,0,Math.PI*2);ctx.fill();ctx.restore();}
function coin(x,y,r=62,rot=0){ctx.save();ctx.translate(x,y);ctx.scale(Math.max(.15,Math.abs(Math.cos(rot))),1);circle(7,5,r,C.green);circle(0,0,r,C.gold);circle(0,0,r*.80,null,'#B29E66',3);text('S',0,-r*.58,r*1.1,900,C.deep);ctx.restore();}
function ticketIcon(x,y,s,color=C.surface){rect(x-s*.6,y-s*.38,s*1.2,s*.76,s*.12,color);circle(x-s*.6,y,s*.12,C.green);circle(x+s*.6,y,s*.12,C.green);ctx.save();ctx.setLineDash([4,6]);line(x+s*.22,y-s*.3,x+s*.22,y+s*.3,C.green,3);ctx.restore();}
function coffee(x,y,s=1){ctx.save();ctx.translate(x,y);ctx.scale(s,s);circle(0,15,124,C.peach);ctx.strokeStyle=C.green;ctx.lineWidth=13;ctx.beginPath();ctx.arc(63,17,36,-Math.PI/2,Math.PI/2);ctx.stroke();rect(-75,-38,140,122,24,C.surface,C.green);ctx.fillStyle='#A67D56';ctx.beginPath();ctx.ellipse(-5,-29,56,15,0,0,Math.PI*2);ctx.fill();for(let i=0;i<3;i++){ctx.beginPath();ctx.moveTo(-37+i*32,-65);ctx.bezierCurveTo(-60+i*32,-96,-14+i*32,-91,-37+i*32,-119);ctx.strokeStyle=C.green;ctx.lineWidth=4;ctx.stroke();}ctx.restore();}
function qr(x,y,size){const n=25,k=size/n,random=rng(67291);ctx.fillStyle=C.deep;for(let r=0;r<n;r++)for(let c=0;c<n;c++){const v=random();if(((c<8&&r<8)||(c>16&&r<8)||(c<8&&r>16)))continue;if(v>.51)ctx.fillRect(x+c*k,y+r*k,k+.4,k+.4);}for(const[a,b]of[[0,0],[18,0],[0,18]]){rect(x+a*k,y+b*k,7*k,7*k,2,C.deep);rect(x+(a+1)*k,y+(b+1)*k,5*k,5*k,1,C.surface);rect(x+(a+2)*k,y+(b+2)*k,3*k,3*k,1,C.deep);}rect(x+size*.12,y+size*.42,size*.76,size*.17,12,C.surface);text('DEMO ONLY',x+size/2,y+size*.451,size*.077,900,C.deep);}
function particles(t,at,cx,cy,count=26){const random=rng(441);for(let i=0;i<count;i++){const angle=random()*Math.PI*2,speed=120+random()*390,delay=random()*.12,u=t-at-delay;if(u<0||u>1)continue;ctx.save();ctx.globalAlpha=Math.sin(Math.PI*clamp(u))*Math.min(1,6*(1-u));ctx.translate(cx+Math.cos(angle)*speed*u,cy+Math.sin(angle)*speed*u+130*u*u);ctx.rotate(angle+u*5);rect(-6,-12,12,24,6,[C.green,C.gold,C.peach][i%3]);ctx.restore();}}
function burst(t,at,x,y,color=C.green){const u=seg(t,at,at+.65);if(u<=0||u>=1)return;ctx.save();ctx.globalAlpha=1-u;circle(x,y,30+u*200,null,color,7*(1-u));ctx.restore();}
function background(color=C.cream){sceneBg=color;ctx.fillStyle=color;ctx.fillRect(0,0,1080,1920);ctx.save();ctx.globalAlpha=.11;for(let i=0;i<8;i++)circle((i*271)%1180-50,(i*417)%2050,80+(i%3)*46,color===C.deep?C.sage:C.peach);ctx.restore();}
function heading(s,t,color=C.deep,size=92){const p=out(seg(t,.1,.55));ctx.save();ctx.translate(0,35*(1-p));ctx.globalAlpha=p;text(s,540,230,size,900,color);ctx.restore();}
function objectCam(x,y,z,draw){ctx.save();ctx.beginPath();ctx.rect(0,515,1080,1120);ctx.clip();ctx.translate(540,1050);ctx.scale(z,z);ctx.translate(-x,-y);draw();ctx.restore();const top=ctx.createLinearGradient(0,515,0,620);top.addColorStop(0,sceneBg);top.addColorStop(1,sceneBg+'00');ctx.fillStyle=top;ctx.fillRect(0,515,1080,105);const bottom=ctx.createLinearGradient(0,1535,0,1635);bottom.addColorStop(0,sceneBg+'00');bottom.addColorStop(1,sceneBg);ctx.fillStyle=bottom;ctx.fillRect(0,1535,1080,100);}
function phone(t){card(260,575,560,915,58,C.deep);rect(275,590,530,881,45,C.cream);circle(540,613,7,C.deep);brand(420,657,33);pill('71 pts',650,650,115,45,C.sage,C.deep,20);text('Today’s walk',320,749,28,800,C.ink,'left');text((6240+Math.floor(8*seg(t,.25,2.5))).toLocaleString('en-US'),320,802,96,900,C.deep,'left');text('steps today',321,910,26,600,C.muted,'left');circle(718,856,41,null,C.sage,8);ctx.beginPath();ctx.arc(718,856,41,-Math.PI/2,Math.PI*1.06);ctx.strokeStyle=C.green;ctx.lineWidth=8;ctx.stroke();cover(imgs.trail,307,986,466,275,20);atlas('walk',(t/1.25%1)*60,445,1012,240);rect(309,1260,464,13,6,C.sage);rect(309,1260,360,13,6,C.green);pill('Live steps',380,1325,320,60,C.sage,C.deep,27);}

function sceneOpen(t){background(C.deep);const hit=B/2,d=t-hit,shake=d<0?0:Math.exp(-d*13)*13;ctx.save();ctx.translate(Math.sin(d*91)*shake,Math.cos(d*77)*shake*.55);
 const move=ease(seg(t,.30,.82)),reveal=out(seg(t,0,.22));ctx.save();ctx.beginPath();ctx.rect(540-540*reveal,lerp(580,135,move)-20,1080*reveal,lerp(220,100,move));ctx.clip();brand(540,lerp(580,135,move),lerp(168,66,move),C.surface);ctx.restore();
 const iris=out(seg(t,.40,1.10)),r=iris*570;
 if(r>0){ctx.save();ctx.beginPath();ctx.arc(540,1090,r,0,Math.PI*2);ctx.clip();const im=imgs.walkingFrames[Math.min(imgs.walkingFrames.length-1,Math.floor(t*32))],push=1+.14*(1-iris);ctx.translate(540,1090);ctx.scale(push,push);ctx.translate(-540,-1090);cover(im,0,500,1080,1150);const g=ctx.createLinearGradient(0,1150,0,1650);g.addColorStop(0,'#264A3A00');g.addColorStop(1,C.deep);ctx.fillStyle=g;ctx.fillRect(0,1100,1080,600);ctx.restore();circle(540,1090,r,null,'#E3C88999',4);}
 for(let i=0;i<4;i++){const u=seg(t,hit+i*.065,1.05+i*.11);if(u>0&&u<1){ctx.save();ctx.globalAlpha=(1-u)*.8;circle(540,1090,90+u*(800+i*70),null,i%2?C.sage:C.gold,12*(1-u));ctx.restore();}}
 const descent=seg(t,0,hit),landing=d<0?1:1+.24*Math.exp(-d*15)*Math.cos(d*27),size=lerp(2.1,1,out(descent))*(1-.20*ease(seg(t,.65,1.05)));
 ctx.save();ctx.translate(540,lerp(270,1090,descent*descent));ctx.rotate(lerp(-.7,-.2,out(descent)));ctx.scale(size*landing,size/landing);circle(0,0,122,C.sage);footprint(0,0,164,0,C.deep);ctx.restore();
 const a=out(seg(t,.66,.96)),b=out(seg(t,.88,1.20));ctx.save();ctx.globalAlpha=a;ctx.beginPath();ctx.rect(40,285,1000,245);ctx.clip();text('Qadam wahi.',540-210*(1-a),302+70*(1-a),104,900,C.surface);ctx.globalAlpha=b;text('Faida naya.',540+210*(1-b),425+70*(1-b),104,900,C.gold);ctx.restore();
 const pop=spring(t-1.2,18,.7);ctx.save();ctx.translate(760+280*(1-out(seg(t,1.2,1.55))),1350);ctx.rotate(-.08);ctx.scale(Math.max(0,pop),Math.max(0,pop));pill('DISCOUNTS',-240,-48,480,96,C.gold,C.deep,48);ctx.restore();
 for(let i=0;i<4;i++){const q=out(seg(t,1.05+i*.15,1.4+i*.15));ctx.save();ctx.globalAlpha=q;footprint(240+i*130,1590-i*57,54,-.35,C.sage,i%2);ctx.restore();}
 particles(t,hit,540,1090,32);ctx.restore();
}
function sceneTracking(t){background();brand(540,110,52);heading('Phone jeb mein.\nWalk apni.',t, C.deep,88);
 const focus=ease(seg(t,.7,1.25))*(1-ease(seg(t,1.55,2.15))),drop=ease(seg(t,1.95,2.75));
 objectCam(540,lerp(1030,870,focus),1+.30*focus,()=>{ctx.save();ctx.translate(0,lerp(190,0,out(seg(t,0,.5)))+210*drop);ctx.rotate(-.025*(1-out(seg(t,0,.5))));phone(t);ctx.restore();
 if(drop>0){ctx.save();ctx.globalAlpha=drop;ctx.beginPath();ctx.moveTo(190,1130);ctx.quadraticCurveTo(540,1215,890,1130);ctx.lineTo(860,1680);ctx.quadraticCurveTo(540,1760,220,1680);ctx.closePath();ctx.fillStyle=C.sage;ctx.fill();ctx.strokeStyle='#A4B18E';ctx.lineWidth=3;ctx.stroke();ctx.setLineDash([9,11]);ctx.beginPath();ctx.moveTo(220,1170);ctx.quadraticCurveTo(540,1250,860,1170);ctx.stroke();ctx.restore();}
 });
 const on=spring(t-2.1);ctx.save();ctx.translate(540,1490+60*(1-on));ctx.scale(on,on);card(-365,-72,730,144,36);circle(-285,0,32,C.green);check(-285,0,28);text('Background tracking on',-220,-24,35,900,C.deep,'left');ctx.restore();
 text('Permissions on. Phone with you.',540,1685,31,700,C.muted);
}
function scenePoints(t){background(C.sage);brand(540,110,52);heading('Qadam se\npoints.',t);
 const p=ease(seg(t,1.05,2.35));objectCam(540,lerp(980,1240,p),lerp(1.02,1.34,p),()=>{
 card(230,610,620,235);text('6,248',540,638,100,900);text('eligible steps',540,756,30,700,C.muted);
 ctx.save();ctx.setLineDash([4,19]);line(540,855,540,1055,'#A9B997',5);ctx.restore();
 card(155,1075,770,370,48,C.deep);text('Available points',540,1120,35,800,C.sage);const n=71+Math.round(62*ease(seg(t,.65,2.45)));text(String(n),540,1175,155,900,C.surface);text('pts',540,1348,32,800,C.gold);
 for(let i=0;i<9;i++){const u=seg(t,.55+i*.15,1.28+i*.15);if(u<=0||u>=1)continue;const x=540+Math.sin(Math.PI*u)*(i%2?1:-1)*(160+(i%3)*65),y=lerp(840,1150,u)-90*Math.sin(Math.PI*u);coin(x,y,43,Math.PI*3*u);}
 burst(t,2.45,540,1260,C.gold);particles(t,2.45,540,1240,19);
 });
 const ready=t>2.1;pill(ready?'Synced ✓':'Syncing your walk',290,1554,500,72,C.surface,C.deep,32);text('Eligible steps earn points after sync.',540,1694,28,700,C.muted);
}
function sceneReward(t){background();brand(540,110,52);heading('Points lagao.\nDiscount pao.',t,C.deep,87);
 const punch=ease(seg(t,.55,1.05))*(1-ease(seg(t,1.35,1.8))),tap=ease(seg(t,2,2.25))*(1-ease(seg(t,2.65,3.0))),claimed=t>=2.8125;
 objectCam(540,1040+60*punch+230*tap,1+.35*punch+.16*tap,()=>{const rise=spring(t,15,.8);ctx.save();ctx.translate(540,1020+300*(1-rise));ctx.rotate(-.07*(1-ease(seg(t,0,.65))));ctx.translate(-540,-1020);
 card(185,570,710,920,45);pill('EXAMPLE OFFER',375,605,330,52,C.sage,C.deep,23);coffee(540,842,.95);text('Sample café',540,995,30,700,C.muted);text('20% off',540,1043,107,900,C.deep);text('your order',540,1160,40,800,C.ink);
 const press=seg(t,2.34375,2.5),push=Math.sin(press*Math.PI)*7;rect(245,1284+push,590,105,32,claimed?C.deep:C.green);text(claimed?'Saved in Wallet':'Redeem · 100 pts',540,1312+push,34,900,C.surface);
 if(t>2.20&&t<2.7){const u=seg(t,2.2,2.65);circle(755,1360,27,C.gold);burst(t,2.34375,755,1360,C.green);}
 if(claimed){circle(795,696,51,C.green);check(795,696,46);particles(t,2.8125,795,696);}
 ctx.restore();
 if(t>.7&&t<2.3){const u=seg(t,.7,2.3);coin(lerp(880,760,u),lerp(595,1260,u)-150*Math.sin(u*Math.PI),50,t*4);}
 });
 pill(claimed?'133 − 100 = 33 pts':'100 points unlock this example',180,1570,720,72,C.sage,C.deep,30);text('Illustrative offer · Partner terms apply',540,1694,27,700,C.muted);
}
function sceneWallet(t){background(C.sage);brand(540,110,52);heading(t<1.6?'Wallet mein.\nReady to use.':'Store par\ndikhao.',t,C.deep,90);
 const focus=ease(seg(t,1.4,2.05)),settle=spring(t-.12,14,.85);objectCam(540,lerp(1120,1040,focus),1+.38*focus,()=>{
 card(170,1110,740,440,50,C.green);rect(205,1070,275,110,28,C.green);text('Wallet',300,1452,42,900,C.surface);
 const yy=lerp(330,630,clamp(settle));ctx.save();ctx.translate(540,yy+350);ctx.scale(Math.max(.08,Math.abs(Math.cos(Math.PI*(1-ease(seg(t,0,.45)))))),1);ctx.translate(-540,-yy-350);card(245,yy,590,730,32);circle(245,yy+465,25,C.sage);circle(835,yy+465,25,C.sage);pill('Ready to use',355,yy+36,370,56,C.sage,C.deep,27);text('20% off',540,yy+115,70,900);qr(370,yy+230,340);text('Sample café · Demo voucher',540,yy+625,25,800,C.muted);ctx.restore();
 const scan=seg(t,1.75,2.55);if(scan>0&&scan<1){ctx.save();ctx.globalAlpha=Math.sin(scan*Math.PI)*.7;line(350,860+scan*355,730,860+scan*355,C.green,5);ctx.restore();}
 if(t>2.65){circle(802,1250,54,C.green);check(802,1250,48);particles(t,2.65,802,1250);}
 });
 text('Your voucher, at the partner store.',540,1694,29,700,C.muted);
}
function sceneClose(t){background();const merge=ease(seg(t,.6,1.5));
 ctx.save();ctx.globalAlpha=1-merge;const xs=[230,540,850];for(let i=0;i<3;i++){const p=clamp(spring(t-i*.12));ctx.save();ctx.translate(lerp(xs[i],540,merge),lerp(930,690,merge));ctx.scale(p*(1-.7*merge),p*(1-.7*merge));circle(0,0,98,C.green);if(i===0)footprint(0,0,110,-.2,C.surface);else if(i===1)coin(0,0,67,t);else ticketIcon(0,0,105);text(['Walk','Points','Discounts'][i],0,150,38,900,C.deep);ctx.restore();if(i<2)line(xs[i]+110,930,xs[i+1]-110,930,'#A9B997',6);}ctx.restore();
 const p=out(seg(t,.85,1.5));ctx.save();ctx.globalAlpha=p;ctx.translate(0,30*(1-p));brand(540,360,115);text('Qadam aapke.\nFaida bhi aapka.',540,640,88,900);atlas('wave',clamp((t-1)/2.5)*59,330,870,420);pill('Coming soon on Android',130,1450,820,112,C.green,C.surface,39);text('Walk. Collect points. Enjoy partner discounts.',540,1604,30,800,C.deep);text('Tracking permissions, earning rules\nand partner terms apply.',540,1710,26,600,C.muted);text('BY HANOVA DEVS',540,1820,24,900,C.muted);ctx.restore();
 const random=rng(89);for(let i=0;i<13;i++){const a=random()*Math.PI*2,rr=360+random()*170;ctx.save();ctx.globalAlpha=.3*p;circle(540+Math.cos(a+t*.05)*rr,1000+Math.sin(a+t*.05)*rr,5+(i%3)*3,i%2?C.gold:C.green);ctx.restore();}
}
const scenes=[sceneOpen,sceneTracking,scenePoints,sceneReward,sceneWallet,sceneClose];
window.seek=function(t){if(!window.READY)return;t=clamp(t,0,VIDEO.duration);ctx.reset();let i=starts.findLastIndex(a=>t>=a);const local=t-starts[i],wipe=.30;if(i>0&&local<wipe){scenes[i-1](starts[i]-starts[i-1]);ctx.save();const k=out(local/wipe),x=i%2?845:235,y=1020;ctx.beginPath();ctx.arc(x,y,Math.max(1,k*2200),0,Math.PI*2);ctx.clip();scenes[i](local);ctx.restore();if(k<.95){circle(x,y,Math.max(1,k*2200),null,C.gold,12*(1-k));}}else scenes[i](local);ctx.setTransform(1,0,0,1,0,0);};
function loadImage(url){return new Promise((resolve,reject)=>{const im=new Image();im.onload=()=>resolve(im);im.onerror=()=>reject(new Error('Image load failed'));im.src=url;});}
window.readyPromise=(async()=>{await document.fonts.load('900 100px Nunito');await document.fonts.ready;await Promise.all(Object.entries(ASSETS).map(async([k,v])=>{imgs[k]=Array.isArray(v)?await Promise.all(v.map(loadImage)):await loadImage(v);}));window.READY=true;window.seek(0);})();

// Original groove, stronger downbeats, swept air and foley-like contacts. No external recording.
window.buildAudio=async function(ac){const master=ac.createGain(),music=ac.createGain(),fx=ac.createGain();master.gain.value=.65;music.gain.value=.55;fx.gain.value=.7;music.connect(master);fx.connect(master);master.connect(ac.destination);const random=rng(291),noise=ac.createBuffer(1,48000,48000);for(let i=0;i<noise.length;i++)noise.getChannelData(0)[i]=random()*2-1;
 function tone(midi,at,dur,level,type='triangle',dest=music){const o=ac.createOscillator(),g=ac.createGain();o.type=type;o.frequency.value=440*2**((midi-69)/12);g.gain.setValueAtTime(.0001,at);g.gain.exponentialRampToValueAtTime(level,at+.008);g.gain.exponentialRampToValueAtTime(.0001,at+dur);o.connect(g);g.connect(dest);o.start(at);o.stop(at+dur+.02);}
 function air(at,dur=.3,level=.1,from=500,to=5000,dest=fx){at=Math.max(0,at);const s=ac.createBufferSource(),f=ac.createBiquadFilter(),g=ac.createGain();s.buffer=noise;f.type='bandpass';f.Q.value=.65;f.frequency.setValueAtTime(from,at);f.frequency.exponentialRampToValueAtTime(to,at+dur);g.gain.setValueAtTime(.0001,at);g.gain.exponentialRampToValueAtTime(level,at+dur*.42);g.gain.exponentialRampToValueAtTime(.0001,at+dur);s.connect(f);f.connect(g);g.connect(dest);s.start(at);s.stop(at+dur);}
 function kick(at,level=.27){const o=ac.createOscillator(),g=ac.createGain();o.frequency.setValueAtTime(150,at);o.frequency.exponentialRampToValueAtTime(43,at+.16);g.gain.setValueAtTime(level,at);g.gain.exponentialRampToValueAtTime(.0001,at+.24);o.connect(g);g.connect(music);o.start(at);o.stop(at+.26);}
 air(0,B/2,.17,180,4500);const roots=[50,55,52,57],melody=[74,78,81,78,76,74,69,73];for(let b=0;b<44;b++){const at=b*B,root=roots[Math.floor(b/4)%4];kick(at,b%4===0?.32:.21);tone(root-12,at,.29,.14,'sine');if(b%4===0)for(const m of[root,root+7,root+12])tone(m,at,1.35,.035,'sine');if(b%2===1)air(at,.10,.055,1700,4000,music);air(at+B/2,.045,.022,6500,8000,music);if(b>1&&b<37)tone(melody[b%8],at+B/2,.18,.065);}
 for(const cue of window.CUES){const at=cue.t;if(cue.type==='scene_cut'||cue.type==='movement'){air(at-.12,.31,.16,320,6000);music.gain.setValueAtTime(.55,Math.max(0,at-.1));music.gain.linearRampToValueAtTime(.32,at+.05);music.gain.linearRampToValueAtTime(.55,at+.30);}else if(cue.type==='reveal'){kick(at,.35);air(at,.22,.11,1200,180);tone(38,at,.5,.22,'sine',fx);}else if(cue.type==='click'){air(at,.025,.09,2500,850);tone(76,at,.08,.1,'triangle',fx);}else{tone(cue.type==='success'?81:76,at,.35,.11,'sine',fx);air(at,.045,.04,800,2200);}}
 for(let i=0;i<9;i++)tone(69+i%5,6.2+i*.15,.13,.07,'triangle',fx);for(const[i,m]of[74,78,81].entries())tone(m,36*B+i*.12,.7,.12,'sine',fx);master.gain.setValueAtTime(.65,VIDEO.duration-1);master.gain.linearRampToValueAtTime(.0001,VIDEO.duration);
};
if(!render){const play=document.getElementById('play'),scrub=document.getElementById('scrub'),outEl=document.getElementById('time');scrub.max=VIDEO.duration;let ac,buffer,src,playing=false,offset=0,start=0;const now=()=>playing?Math.min(VIDEO.duration,offset+ac.currentTime-start):offset;function pause(){if(playing){offset=now();src.stop();playing=false;play.textContent='Play';}}
 play.onclick=async()=>{await window.readyPromise;if(playing)return pause();ac??=new AudioContext();await ac.resume();if(!buffer){const off=new OfflineAudioContext(2,Math.ceil(48000*VIDEO.duration),48000);await window.buildAudio(off);buffer=await off.startRendering();}if(offset>=VIDEO.duration)offset=0;src=ac.createBufferSource();src.buffer=buffer;src.connect(ac.destination);src.start(0,offset);start=ac.currentTime;playing=true;play.textContent='Pause';};scrub.oninput=()=>{pause();offset=+scrub.value;window.seek(offset);};(function loop(){if(window.READY){const t=now();window.seek(t);scrub.value=t;outEl.value=`0:${String(Math.floor(t)).padStart(2,'0')}`;if(t>=VIDEO.duration&&playing)pause();}requestAnimationFrame(loop);})();
}
