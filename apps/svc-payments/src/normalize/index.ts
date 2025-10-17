export const norm=(p:any)=>({ id:p.invoice_id||p.bill_id||p.id, amount:+(p.amount||p.total), status:p.status||'ok' });
