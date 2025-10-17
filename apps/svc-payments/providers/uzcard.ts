export function initUzcard({merchantId,secret}:{merchantId:string,secret:string}){ return {pay:(o:any)=>({ok:true,provider:'uzcard',o})}; }
