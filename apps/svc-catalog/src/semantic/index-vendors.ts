import {insert} from "@wt/semantic"; export function reindex(vendors:any[]){ vendors.forEach(v=>insert(v.id, `${v.title} ${v.city} ${v.type}`)); }
