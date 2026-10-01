import { ProxyRequestUtil as r } from "../utils/request.js";
export const albums = function (o) {
    const { request = r } = o ?? {};
    return request("get", "https://monster-siren.hypergryph.com/api/albums");
};
export const album_$id_detail = function (o) {
    const { request = r, id } = o ?? {};
    if (!id) {
        throw new Error("专辑 id 不能为空！");
    }
    return request("GET", `https://monster-siren.hypergryph.com/api/album/${id}/detail`);
};
export const album_$id_data = function (o) {
    const { request = r, id } = o ?? {};
    if (!id) {
        throw new Error("专辑 id 不能为空！");
    }
    return request("GET", `https://monster-siren.hypergryph.com/api/album/${id}/data`);
};
