import { BasicResponse, RequestFunction as RF } from "../declare/modules.js";
type SR = string | number;
export interface SingleRecommendItem {
    /** 动向标题 */
    title: string;
    /** 封面信息 */
    cover: {
        /** 作用未知 */
        private: boolean;
        /** 封面url路径，**注意：传入URL并非以http协议开头，需要进行处理** */
        path: string;
    };
    /** 动向底部描述 */
    description: string;
    /** 类型，作用未知 */
    type: number;
    /** 作用未知 */
    data: string;
}
export interface SingleNewsItem {
    cid: string;
    title: string;
    /** 作用未知 */
    cate: number;
    date: string;
}
export interface NewsIdItem {
    cid: string;
    title: string;
    /** 作用未知 */
    cate: number;
    author: string;
    /** 新闻内容，为 HTML 结构，可以直接插入页面内，但是可能需要处理样式 */
    content: string;
    date: string;
}
export interface RecommendsResponse extends BasicResponse {
    data: SingleRecommendItem[];
}
export interface NewsResponse extends BasicResponse {
    data: {
        list: SingleNewsItem[];
    };
}
export interface NewsIdResponse extends BasicResponse {
    data: NewsIdItem;
}
export declare const recommends: RF<object, RecommendsResponse>;
export declare const news: RF<{
    /** 上次请求中列表最后一项新闻的 id */
    lastCid?: SR | undefined;
}, NewsResponse>;
export declare const news_$id: RF<{
    /** 新闻 id */
    id: SR;
}, NewsIdResponse>;
export {};
