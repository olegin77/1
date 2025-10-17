export function extract(vendor:any){
  return { conv: vendor.conv||0, rating: vendor.rating||0, profile: vendor.profileScore||0, calendar: vendor.calendar||0 };
}
