import http from "http"; const port=process.env.PORT||3000;
http.createServer((req,res)=>{ if(req.url==="/health"){res.writeHead(200,{"Content-Type":"application/json"});return res.end(JSON.stringify({status:"ok"}));}
res.writeHead(404);res.end(); }).listen(port,"0.0.0.0",()=>console.log("svc ok",port));
