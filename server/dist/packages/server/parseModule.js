import * as AllModules from "../modules/AllModules.js";
import isValidKey from "../utils/isValidKey.js";
export default function (modules) {
    const res = [], FinalModules = modules ?? AllModules;
    for (const i in FinalModules) {
        if (isValidKey(i, FinalModules)) {
            const route = "/" + i
                .replaceAll(/\$/g, ":")
                .replaceAll(/_/g, "/");
            const mark = i;
            res.push({
                route,
                mark,
                handler: FinalModules[i]
            });
        }
    }
    return res;
}
