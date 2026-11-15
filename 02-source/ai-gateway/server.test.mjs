import test from 'node:test';
import assert from 'node:assert/strict';
import {createGateway} from './server.mjs';
const token='eyJhbGciOiJIUzI1NiJ9.'+Buffer.from(JSON.stringify({exp:9999999999})).toString('base64url')+'.signature';
const payload={model:'openai/gpt-oss-120b',messages:[{role:'user',content:'Giải thích ngắn gọn vì sao hai vế bằng nhau.'}]};
async function fixture(fn,options={}) {
 const calls=[];
 const upstream=async(url,init)=>{
  calls.push({url,init});
  if(url.includes('/auth/v1/user'))return Response.json({id:'test-user'});
  return Response.json({id:'real-shape-test',choices:[{message:{content:'Hai vế cùng được thực hiện một phép biến đổi.'}}]});
 };
 const server=createGateway({env:{SUPABASE_URL:'https://example.supabase.co',SUPABASE_PUBLISHABLE_KEY:'public-key',GROQ_API_KEY:'server-only-secret'},upstream,...options});
 await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));const url=`http://127.0.0.1:${server.address().port}`;
 try{await fn({url,calls,post:(body=payload,headers={})=>fetch(url+'/chat/completions',{method:'POST',headers:{'Content-Type':'application/json',Authorization:'Bearer '+token,...headers},body:JSON.stringify(body)})});}
 finally{server.closeAllConnections();await new Promise(r=>server.close(r));}
}
test('unauthenticated calls never reach provider',()=>fixture(async({post,calls})=>{const r=await post(payload,{Authorization:''});assert.equal(r.status,401);assert.equal(calls.length,0);}));
test('server validates session, preserves Vietnamese, clamps token budget and never exposes secret',()=>fixture(async({post,calls})=>{const r=await post({...payload,max_completion_tokens:100000});assert.equal(r.status,200);const data=await r.text();assert(!data.includes('server-only-secret'));assert.equal(calls.length,2);assert.equal(calls[1].init.headers.Authorization,'Bearer server-only-secret');const sent=JSON.parse(calls[1].init.body);assert.equal(sent.messages[0].content,payload.messages[0].content);assert.equal(sent.max_completion_tokens,4096);}));
test('untrusted browser origins and models are rejected',()=>fixture(async({post,calls})=>{assert.equal((await post(payload,{Origin:'https://evil.invalid'})).status,403);assert.equal((await post({...payload,model:'unknown'})).status,400);assert.equal(calls.length,0);}));
test('user capacity is enforced before the twenty-first provider request',()=>fixture(async({post,calls})=>{for(let i=0;i<20;i++)assert.equal((await post()).status,200);assert.equal((await post()).status,429);assert.equal(calls.filter(x=>!x.url.includes('/auth/')).length,20);}));
test('upstream errors do not leak provider diagnostics',()=>fixture(async({post})=>{const r=await post();assert.equal(r.status,502);assert(!((await r.text()).includes('private-credential')));},{upstream:async(url)=>url.includes('/auth/')?Response.json({id:'test-user'}):new Response('private-credential',{status:500})}));
test('image URLs cannot make the gateway/provider fetch arbitrary user-controlled hosts',()=>fixture(async({post,calls})=>{const r=await post({...payload,messages:[{role:'user',content:[{type:'image_url',image_url:{url:'http://127.0.0.1/private'}}]}]});assert.equal(r.status,400);assert.equal(calls.length,0);}));
test('ALLOWED_ORIGINS enables an extra origin and echoes it, others stay blocked',()=>fixture(async({url,post})=>{
 const pre=await fetch(url+'/chat/completions',{method:'OPTIONS',headers:{Origin:'http://127.0.0.1:8600'}});
 assert.equal(pre.status,204);
 assert.equal(pre.headers.get('access-control-allow-origin'),'http://127.0.0.1:8600');
 const ok=await post(payload,{Origin:'http://127.0.0.1:8600'});
 assert.equal(ok.status,200);
 assert.equal(ok.headers.get('access-control-allow-origin'),'http://127.0.0.1:8600');
 assert.equal((await post(payload,{Origin:'https://evil.invalid'})).status,403);
},{env:{SUPABASE_URL:'https://example.supabase.co',SUPABASE_PUBLISHABLE_KEY:'public-key',GROQ_API_KEY:'server-only-secret',ALLOWED_ORIGINS:'https://bendocs.tailc1f51b.ts.net,http://127.0.0.1:8600'}}));
