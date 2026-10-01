import { ProxyRequestUtil as r } from "../utils/request.js";
export const song_$id = function (o) {
    const { request = r, id } = o ?? {};
    if (!id)
        throw new Error("歌曲id不能为空！");
    return request("get", `https://monster-siren.hypergryph.com/api/song/${id}`);
};
export const songs = function (o) {
    const { request = r } = o ?? {};
    return request("get", "https://monster-siren.hypergryph.com/api/songs");
};
