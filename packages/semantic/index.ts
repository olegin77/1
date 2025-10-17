const idx=new Map<string,number[]>();
export const embed=(t:string)=>Array.from({length:16},(_,i)=>((t.charCodeAt(i%t.length)||0)%17)/17);
export function insert(id:string, text:string){ idx.set(id, embed(text)); }
export function search(q:string, k=5){
  const qe=embed(q); const sc=(a:number[],b:number[])=>a.reduce((s,v,i)=>s+v*(b[i]||0),0);
  return [...idx.entries()].map(([id,v])=>({id,score:sc(qe,v)})).sort((a,b)=>b.score-a.score).slice(0,k);
}
