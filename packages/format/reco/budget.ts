export const recommend=(city:string, guests:number)=> Math.round((guests*30) * (city==='Tashkent'?1.3:1.0));
