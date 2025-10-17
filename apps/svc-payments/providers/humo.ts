export function initHumo({merchantId,secret}:{merchantId:string,secret:string}){ return {pay:(o:any)=>({ok:true,provider:'humo',o})}; }
