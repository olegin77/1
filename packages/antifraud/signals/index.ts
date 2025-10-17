export const signals={ manyEnquiriesShortTime:(u:any)=>u.eqLastHour>5, ipMismatch:(u:any)=>u.regIpCountry && u.txIpCountry && (u.regIpCountry!==u.txIpCountry) };
