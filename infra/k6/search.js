import http from 'k6/http'; export let options={vus:10,duration:'30s'}; export default()=>http.get('http://localhost:3000/health');
