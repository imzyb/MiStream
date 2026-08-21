package com.github.catvod.crawler;

import android.content.Context;

import com.google.gson.JsonArray;

/**
 * TVBox csp 蜘蛛的 API 句柄（android 侧同名类的最小兼容实现）。
 *
 * TVBox 宿主创建 SpiderApi 并经 {@code Spider.initApi(SpiderApi)} 注入蜘蛛，
 * 蜘蛛用它做本机代理请求（getPort/getAddress）、webParse 网页解析、multiReq
 * 并发请求与日志。PC 客户端暂不提供这些服务，统一给安全默认值：
 * - 日志打到 stderr（stdout 是 RPC 信道，不能污染）
 * - 本机代理地址/端口给空值
 * - webParse/multiReq 原样返回输入或空 JSON
 */
public class SpiderApi {

    private Context context;

    /** 构造（宿主使用）。 */
    public SpiderApi() {
    }

    /** 初始化（部分蜘蛛会自行调用）。 */
    public void init(Context context) {
        this.context = context;
    }

    /** 当前上下文。 */
    public Context getContext() {
        return context;
    }

    /** 打一条日志。 */
    public void log(String msg) {
        System.err.println("[SpiderApi] " + msg);
    }

    /** 本机代理端口（PC 端暂无，给空字符串）。 */
    public String getPort() {
        return "";
    }

    /** 本机代理地址（PC 端暂无，给回环地址）。 */
    public String getAddress(boolean local) {
        return "127.0.0.1";
    }

    /** 网页解析（PC 端未集成 JS 解析引擎，原样返回 url）。 */
    public String webParse(String url, String js) {
        return url;
    }

    /** 并发请求（PC 端暂无，返回空数组 JSON）。 */
    public String multiReq(JsonArray urls) {
        return "[]";
    }
}