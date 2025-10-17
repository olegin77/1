import {initUzcard} from "../providers/uzcard"; import {initHumo} from "../providers/humo";
export function payments(env:any){ return { uzcard:initUzcard(env), humo:initHumo(env) }; }
