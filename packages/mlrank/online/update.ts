let w={conv:0.55,rating:0.2,profile:0.2,calendar:0.05};
export function update(event:{type:'click'|'book',delta:number}){ if(event.type==='book') w.conv+=0.001*event.delta; }
export function weights(){ return w; }
