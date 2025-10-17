import {writeFileSync} from 'fs';
export function dump(name:string, rows:any[]){ writeFileSync(`infra/feast/snapshots/${name}.json`, JSON.stringify(rows,null,2)); }
