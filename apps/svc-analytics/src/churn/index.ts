export function churnScore(u:{daysInactive:number,enquiries:number}){ return Math.min(1, (u.daysInactive/30) - 0.1*u.enquiries); }
