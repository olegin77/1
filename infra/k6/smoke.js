import http from 'k6/http';export default()=>http.get('http://localhost:3000/health');
