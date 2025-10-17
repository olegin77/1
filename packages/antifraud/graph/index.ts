import {edges,link} from "../../graph"; export {link};
export const suspiciousCluster=(id:string)=> (edges.get(id)||[]).length>10;
