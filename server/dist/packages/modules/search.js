import { ProxyRequestUtil as r } from "../utils/request.js";
export const search = function (o) {
    const { request = r, keyword } = o ?? {};
    if (!keyword) {
        throw new Error("搜索关键词不能为空！");
    }
    return request("get", "https://monster-siren.hypergryph.com/api/search", {
        params: { keyword }
    });
};
export const search_album = function (o) {
    const { request = r, keyword, lastCid } = o ?? {};
    if (!keyword) {
        throw new Error("搜索关键词不能为空！");
    }
    return request("get", "https://monster-siren.hypergryph.com/api/search/album", {
        params: { keyword, lastCid }
    });
};
export const search_news = function (o) {
    const { request = r, keyword, lastCid } = o ?? {};
    if (!keyword) {
        throw new Error("搜索关键词不能为空！");
    }
    return request("get", "https://monster-siren.hypergryph.com/api/search/news", {
        params: { keyword, lastCid }
    });
};
