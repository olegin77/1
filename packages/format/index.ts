export const fmt=(n,c)=>new Intl.NumberFormat('ru-RU',{style:'currency',currency:c}).format(n);
