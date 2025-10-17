/** Простейшая линейная модель под оффлайн-скоры (заменяется на ML позднее). */
export function score(v:{conv:number;rating:number;profile:number;calendar:number;price?:number}) {
  const s = 0.55*v.conv + 0.2*v.rating + 0.2*v.profile + 0.05*v.calendar;
  return Math.max(0, Math.min(1, s));
}
