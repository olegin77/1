const buckets=new Map<string,{tokens:number,ts:number}>();
export function allow(key:string, limit=60, windowMs=60000){
  const now=Date.now(); const b=buckets.get(key)||{tokens:limit,ts:now};
  const refill=Math.floor((now-b.ts)/windowMs)*limit; b.tokens=Math.min(limit,b.tokens+Math.max(0,refill)); b.ts=now;
  if(b.tokens<=0){ buckets.set(key,b); return false; } b.tokens--; buckets.set(key,b); return true;
}
