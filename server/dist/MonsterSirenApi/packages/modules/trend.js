import { ProxyRequestUtil as r } from "../utils/request.js";
export const recommends = function (o) {
    const { request = r } = o ?? {};
    return request("get", "https://monster-siren.hypergryph.com/api/recommends");
};
export const news = function (o) {
    const { request = r, lastCid } = o ?? {};
    return request("get", "https://monster-siren.hypergryph.com/api/news", {
        params: { lastCid }
    });
};
export const news_$id = function (o) {
    const { request = r, id } = o ?? {};
    if (!id)
        throw new Error("新闻id不能为空！");
    return request("get", `https://monster-siren.hypergryph.com/api/news/${id}`);
};
