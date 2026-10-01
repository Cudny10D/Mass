import { ProxyRequestUtil as r } from "../utils/request.js";
export const fontset = function (o) {
    const { request = r } = o ?? {};
    return request("get", "https://monster-siren.hypergryph.com/api/fontset");
};
