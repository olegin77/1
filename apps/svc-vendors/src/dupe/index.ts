export const isDupe=(a:any,b:any)=> (a.phone && a.phone===b.phone) || (a.title===b.title && a.city===b.city);
