export function variant(key:string,uid:string){ let h=0; for(const c of (uid+key)) h=(h*31+c.charCodeAt(0))>>>0; return h%2; }
