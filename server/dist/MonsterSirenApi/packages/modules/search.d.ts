import { BasicResponse, RequestFunction as RF } from "../declare/modules.js";
interface Keyword {
    /** 必选，搜索关键词 */
    keyword: string;
}
interface LastCid {
    /** 上次请求中的最后子项 */
    lastCid?: string | number;
}
export interface SingleAlbumSearchResultItem {
    cid: string;
    name: string;
    belong: string;
    coverUrl: string;
    artistes: string[];
}
export interface SingleNewsSearchResultItem {
    cid: string;
    title: string;
    cate: number;
    date: string;
}
export interface SearchAlbumResponse {
    list: SingleAlbumSearchResultItem[];
    /** 结束标记 */
    end: boolean;
}
export interface SearchNewsResponse {
    list: SingleNewsSearchResultItem[];
    /** 结束标记 */
    end: boolean;
}
export interface SearchResponse extends BasicResponse {
    data: {
        albums: SearchAlbumResponse;
        news: SearchNewsResponse;
    };
}
export declare const search: RF<Keyword, SearchResponse>;
export declare const search_album: RF<Keyword & LastCid, BasicResponse & {
    data: SearchAlbumResponse;
}>;
export declare const search_news: RF<Keyword & LastCid, BasicResponse & {
    data: SearchNewsResponse;
}>;
export {};
