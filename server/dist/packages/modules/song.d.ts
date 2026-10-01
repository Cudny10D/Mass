import { BasicResponse, RequestFunction as RF } from "../declare/modules.js";
interface BasicSong {
    /** 歌曲id */
    cid: string;
    /** 歌曲名字 */
    name: string;
    /** 专辑id */
    albumCid: string;
    /** 作者列表 */
    artists: string[];
}
export interface SongIdResponse extends BasicResponse {
    data: BasicSong & {
        /** 音频链接 */
        sourceUrl: string;
        /** 歌词链接 */
        lyricUrl: string | null;
        /** mv链接 */
        mvUrl: string | null;
        /** mv封面链接 */
        mvCoverUrl: string | null;
    };
}
export interface SongsResponse extends BasicResponse {
    data: {
        list: BasicSong[];
    };
}
export declare const song_$id: RF<{
    /**
     * 歌曲 id
     * @see https://github.com/QingXia-Ela/MonsterSirenApi/blob/main/docs/dev/%E5%B7%B2%E6%9C%89%E6%AD%8C%E6%9B%B2ID%E4%B8%80%E8%A7%88.md
     */
    id: string | number;
}, SongIdResponse>;
export declare const songs: RF<object, SongsResponse>;
export {};
