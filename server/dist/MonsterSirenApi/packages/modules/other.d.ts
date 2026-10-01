import { RequestFunction as RF } from "../declare/modules.js";
import { BasicResponse } from "../declare/modules.js";
export interface SingleFontInfo {
    tt: string;
    eot: string;
    svg: string;
    woff: string;
}
export interface FontsetResponse extends BasicResponse {
    data: Record<string, SingleFontInfo>;
}
export declare const fontset: RF<object, FontsetResponse>;
