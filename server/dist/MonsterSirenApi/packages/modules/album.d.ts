import { RequestFunction as RF } from "../declare/modules.js";
import { BasicResponse } from "../declare/modules.js";
interface AlbumId {
    /**
     * 专辑 id
     * @see https://github.com/QingXia-Ela/MonsterSirenApi/blob/main/docs/dev/%E5%B7%B2%E6%9C%89%E4%B8%93%E8%BE%91ID%E4%B8%80%E8%A7%88.md
     */
    id: string | number;
}
export interface SingleAlbumItem {
    /** 专辑 id */
    cid: string;
    /** 专辑名字 */
    name: string;
    /** 专辑图片 */
    coverUrl: string;
    /** 作者 */
    artistes: string[];
}
export interface SingleAlbumDetailItem extends Omit<SingleAlbumItem, "artistes"> {
    /** 专辑介绍 */
    intro: string;
    /** 未知，猜测为版权所属 */
    belong: string;
    /** 第二封图，类似 B 站视频封面 */
    coverDeUrl: string;
    /** 专辑包含歌曲 */
    songs: Omit<SingleAlbumItem, "coverUrl">;
}
export interface AlbumsResponse extends BasicResponse {
    data: SingleAlbumItem[];
}
export interface AlbumsDetailResponse extends BasicResponse {
    data: SingleAlbumDetailItem;
}
export interface AlbumsDataResponse extends BasicResponse {
    data: Omit<SingleAlbumDetailItem, "songs"> & SingleAlbumItem;
}
export declare const albums: RF<object, AlbumsResponse>;
export declare const album_$id_detail: RF<AlbumId, AlbumsDetailResponse>;
export declare const album_$id_data: RF<AlbumId, AlbumsDataResponse>;
export {};
