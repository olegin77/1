export const edges = new Map<string,string[]>(); export const link=(a:string,b:string)=>{ const x=edges.get(a)||[]; if(!x.includes(b)) x.push(b); edges.set(a,x); };
