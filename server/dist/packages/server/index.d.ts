import express from "express";
export interface ServerOptions {
    /** 服务器端口 */
    port?: number;
}
export default function (options?: ServerOptions): Promise<express.Express>;
