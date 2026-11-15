import http from 'node:http';
import {createHash} from 'node:crypto';
import {pathToFileURL} from 'node:url';

export function createGateway({env=process.env, upstream=fetch, now=()=>Date.now()}={}) {
  const verified=new Map(), usage=new Map(), attempts=new Map();
  const models=new Set(['openai/gpt-oss-120b','openai/gpt-oss-20b','qwen/qwen3.8-27b']);
  let concurrent=0, globalDay='', globalCount=0;
  // Comma-separated allow-list. Default stays the production origin; add other
  // origins (for example a local preview) explicitly via ALLOWED_ORIGINS.
  const allowedOrigins=String(env.ALLOWED_ORIGINS||'https://bendocs.tailc1f51b.ts.net').split(',').map(v=>v.trim()).filter(Boolean);
  if(!allowedOrigins.length)allowedOrigins.push('https://bendocs.tailc1f51b.ts.net');
  return http.createServer(async(req,res)=>{
    const respond=(status,value)=>{if(!res.headersSent)res.writeHead(status,{'Content-Type':'application/json; charset=utf-8','Cache-Control':'no-store'});res.end(JSON.stringify(value));};
    const requestOrigin=req.headers.origin;
    if(requestOrigin && !allowedOrigins.includes(requestOrigin)) return respond(403,{error:{code:'origin_denied'}});
    res.setHeader('Access-Control-Allow-Origin',requestOrigin || allowedOrigins[0]);
    res.setHeader('Vary','Origin');
    res.setHeader('Access-Control-Allow-Headers','Authorization, Content-Type');
    res.setHeader('Access-Control-Allow-Methods','POST, OPTIONS, GET');
    res.setHeader('X-Content-Type-Options','nosniff');
    if(req.method==='OPTIONS'){res.writeHead(204);return res.end();}
    const path=new URL(req.url,'http://localhost').pathname.replace(/^\/mochi-ai/,'');
    if(path==='/health' && req.method==='GET')return respond(200,{status:'ready',version:1});
    if(req.method!=='POST'||path!=='/chat/completions')return respond(404,{error:{code:'not_found'}});
    const ip=req.socket.remoteAddress || 'unknown';
    const minute=Math.floor(now()/60000), burst=attempts.get(ip);
    if(!burst||burst.minute!==minute)attempts.set(ip,{minute,count:1});
    else if(++burst.count>90)return respond(429,{error:{code:'request_rate_limited'}});
    const token=/^Bearer (\S+)$/.exec(req.headers.authorization || '')?.[1];
    if(!token)return respond(401,{error:{code:'authentication_required'}});
    let size=0; const chunks=[];
    try {
      for await(const chunk of req){size+=chunk.length;chunks.push(chunk);if(size>8*1024*1024)return respond(413,{error:{code:'input_too_large'}});}
      const body=JSON.parse(Buffer.concat(chunks).toString('utf8'));
      if(!models.has(body.model)||!Array.isArray(body.messages)||!body.messages.length||body.messages.length>60)return respond(400,{error:{code:'invalid_request'}});
      for(const msg of body.messages){
        if(!['system','user','assistant','tool'].includes(msg.role))return respond(400,{error:{code:'invalid_role'}});
        if(Array.isArray(msg.content))for(const item of msg.content){
          if(item.type==='image_url'){
            const raw = item.image_url?.url || '';
            if(!/^data:image\/(png|jpeg|jpg|webp);base64,[A-Za-z0-9+/=\s]+$/.test(raw)) return respond(400,{error:{code:'image_requires_upload'}});
            const idx = raw.indexOf('base64,');
            item.image_url.url = raw.slice(0, idx + 7) + raw.slice(idx + 7).replace(/\s+/g, '');
          }
        }
      }
      const hash=createHash('sha256').update(token).digest('hex');
      let user=verified.get(hash);
      if(!user||user.until<now()){
        const auth=await upstream(env.SUPABASE_URL+'/auth/v1/user',{headers:{apikey:env.SUPABASE_PUBLISHABLE_KEY,Authorization:'Bearer '+token},signal:AbortSignal.timeout(10000)});
        if(!auth.ok)return respond(401,{error:{code:'session_expired'}});
        const data=await auth.json();if(!data.id)return respond(401,{error:{code:'invalid_session'}});
        const exp=JSON.parse(Buffer.from(token.split('.')[1]||'', 'base64url').toString()||'{}').exp;
        user={id:data.id,until:Math.min(now()+60000,exp?exp*1000:now()+60000)};verified.set(hash,user);
      }
      const day=new Date(now()).toISOString().slice(0,10);
      if(globalDay!==day){globalDay=day;globalCount=0;usage.clear();}
      const used=usage.get(user.id)||{dayCount:0,minute,count:0};
      if(used.minute!==minute){used.minute=minute;used.count=0;}
      if(used.dayCount>=200||used.count>=20||globalCount>=1000||concurrent>=6)return respond(429,{error:{code:'ai_capacity_reached',message:'AI đang đạt hạn mức. Hãy thử lại sau.'}});
      used.dayCount++;used.count++;usage.set(user.id,used);globalCount++;concurrent++;
      try {
        if(!env.GROQ_API_KEY)return respond(503,{error:{code:'ai_unconfigured'}});
        const key=body.max_completion_tokens!==undefined?'max_completion_tokens':'max_tokens';
        body[key]=Math.min(4096,Math.max(1,Number(body[key])||2200));
        const response=await upstream('https://api.groq.com/openai/v1/chat/completions',{
          method:'POST',headers:{Authorization:'Bearer '+env.GROQ_API_KEY,'Content-Type':'application/json'},body:JSON.stringify(body),signal:AbortSignal.timeout(45000),
        });
        if(!response.ok){
          // Do not forward provider diagnostics/credentials into product UI.
          await response.arrayBuffer();
          return respond(response.status===429?429:502,{error:{code:response.status===429?'ai_capacity_reached':'ai_request_failed'}});
        }
        res.writeHead(200,{'Content-Type':body.stream?'text/event-stream':'application/json; charset=utf-8','Cache-Control':'no-store'});
        for await(const part of response.body){if(res.destroyed)break;res.write(part);}
        res.end();
      } finally {concurrent--;}
    } catch(e){return respond(e instanceof SyntaxError?400:503,{error:{code:e instanceof SyntaxError?'invalid_json':'temporarily_unavailable'}});}
    // Expired entries contain only hashed tokens/IDs, never prompts or answers.
    finally{if(verified.size>2000)for(const [k,v]of verified)if(v.until<now())verified.delete(k);if(attempts.size>2000)for(const[k,v]of attempts)if(v.minute<minute)attempts.delete(k);}
  });
}
if(process.argv[1] && import.meta.url===pathToFileURL(process.argv[1]).href){
  createGateway().listen(Number(process.env.PORT)||8897,'127.0.0.1',()=>process.stdout.write('MOCHI AI gateway listening\n'));
}
