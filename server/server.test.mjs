import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {spawn} from 'node:child_process';
import assert from 'node:assert/strict';
import {fileURLToPath} from 'node:url';
const serverPath = fileURLToPath(new URL('./server.mjs', import.meta.url));
const root=await fs.mkdtemp(path.join(os.tmpdir(),'spellbook-server-test-'));
const project=path.join(root,'project'); await fs.mkdir(project);
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
const children=[];
async function start(extra=[]){
 const child=spawn(process.execPath,[serverPath,'--project',project,'--no-open',...extra],{env:{...process.env,HOME:root},stdio:['ignore','pipe','pipe']});children.push(child);
 let output='',error='';child.stdout.on('data',d=>output+=d);child.stderr.on('data',d=>error+=d);
 for(let n=0;n<200;n++){if(output.includes('http://'))return {child,url:output.trim().split('\n')[0]};if(child.exitCode!==null)throw Error(error);await sleep(50)}throw Error('startup timed out '+error);
}
try{
 const first=await start(); const health=await (await fetch(first.url+'api/health')).json(); assert.equal(health.clients,0);assert.equal(health.waiters,0);
 const collision=await start();assert.equal(Number(new URL(collision.url).port),Number(new URL(first.url).port)+1);collision.child.kill();await new Promise(r=>collision.child.once('exit',r));
 const controller=new AbortController();const response=await fetch(first.url+'api/events',{signal:controller.signal});let events='';const consume=(async()=>{try{for await(const data of response.body)events+=Buffer.from(data).toString()}catch{}})();
 assert.equal((await (await fetch(first.url+'api/health')).json()).clients,1);
 const skill=path.join(project,'.claude','skills','demo');await fs.mkdir(skill,{recursive:true});await sleep(700);await fs.writeFile(path.join(skill,'SKILL.md'),'---\nname: demo\ndescription: Temporary watcher check\n---\nOriginal text.\n');
 let survey;for(let n=0;n<80;n++){survey=await (await fetch(first.url+'api/survey')).json();if(survey.installs.some(i=>i.skills.some(s=>s.id==='demo')))break;await sleep(100)}
 assert(survey.installs.some(i=>i.skills.some(s=>s.id==='demo')),'new skill discovered');assert(events.includes('event: survey'));
 const waiter=fetch(first.url+'api/briefs/next?wait=1');await sleep(100);assert.equal((await (await fetch(first.url+'api/health')).json()).waiters,1);
 await fetch(first.url+'api/briefs',{method:'POST',headers:{'content-type':'application/json'},body:JSON.stringify({text:'Verify test reload'})});assert.equal((await (await waiter).json()).text,'Verify test reload');
 await fs.writeFile(path.join(skill,'SKILL.md'),'---\nname: demo\ndescription: Temporary watcher check\n---\nEdited text.\n');await sleep(500);assert(events.includes('event: changed'));
 controller.abort();await consume;first.child.kill();await new Promise(r=>first.child.once('exit',r));
 const restart=await start(['--idle','0.02']);assert.equal(restart.url,first.url);await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('idle exit failed')),5000);restart.child.once('exit',()=>{clearTimeout(timer);resolve()})});
 console.log('PASS health, port collision, stable restart, missing root discovery, delayed SKILL.md, SSE, Brief delivery/reload, idle exit');
}finally{for(const child of children)if(child.exitCode===null)child.kill();await fs.rm(root,{recursive:true,force:true})}
