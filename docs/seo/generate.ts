import {clusters} from './clusters'; import {writeFileSync, mkdirSync, existsSync} from 'fs';
for(const c of clusters){ const dir=`docs/seo/${c.topic}`; if(!existsSync(dir)) mkdirSync(dir,{recursive:true});
  for(const s of c.subs){ writeFileSync(`${dir}/${s}.mdx`, `# ${c.topic} — ${s}\nОписание.\n`); } }
