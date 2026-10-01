import express from "express";
import parseModule from "./parseModule.js";
import request from "../utils/request.js";
import chalk from "chalk";
import getCurrentTime from "../utils/getCurrentTime.js";
import judgeCorrectPath from "../utils/judgeCorrectPath.js";
const CacheMap = new Map();
function regRoute(app) {
    const modules = parseModule();
    for (const { route, handler } of modules) {
        app.use(route, async ({ query, params, body, originalUrl }, res, next) => {
            if (!judgeCorrectPath(route, originalUrl)) {
                next();
                return;
            }
            try {
                const hasCache = CacheMap.has(originalUrl);
                const response = hasCache ? CacheMap.get(originalUrl) : await handler({
                    ...query,
                    ...params,
                    ...body,
                    request: (method, url, config = {}) => {
                        return request({
                            method,
                            url,
                            ...config
                        });
                    }
                });
                console.log(`${chalk.green(`[200 OK${hasCache ? " Cache Used" : ""}] [${getCurrentTime()}]`)} ${decodeURI(originalUrl)}`);
                if (!hasCache) {
                    // @ts-expect-error: ignore axios response
                    CacheMap.set(originalUrl, response);
                    setTimeout(() => {
                        CacheMap.delete(originalUrl);
                    }, 60000);
                }
                res.send(response);
                return;
            }
            catch (e) {
                console.log(`${chalk.red(`[${e.code ?? "400"} ERROR] [${getCurrentTime()}]`)} ${decodeURI(originalUrl)}`);
                res.statusCode = 400;
                res.send(e.toString());
            }
        });
    }
}
function createServer() {
    const app = express();
    const CORS_ALLOW_ORIGIN = false;
    /**
     * CORS & Preflight request
    */
    app.use((req, res, next) => {
        if (req.path !== "/" && !req.path.includes(".")) {
            res.set({
                "Access-Control-Allow-Credentials": true,
                "Access-Control-Allow-Origin": CORS_ALLOW_ORIGIN || req.headers.origin || "*",
                "Access-Control-Allow-Headers": "X-Requested-With,Content-Type,User-Agent",
                "Access-Control-Allow-Methods": "PUT,POST,GET,DELETE,OPTIONS",
                "Content-Type": "application/json; charset=utf-8",
            });
        }
        req.method === "OPTIONS" ? res.status(204).end() : next();
    });
    /**
     * reg module
     */
    regRoute(app);
    return app;
}
export default function (options = {}) {
    return new Promise((res, rej) => {
        try {
            const port = Number(options.port || process.env.PORT || "3000");
            const server = createServer();
            server.listen(port, () => {
                console.log(`server running @ http://localhost:${port}`);
                res(server);
            });
        }
        catch (e) {
            rej(e);
        }
    });
}
