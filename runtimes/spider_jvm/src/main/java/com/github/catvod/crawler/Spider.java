package com.github.catvod.crawler;

import android.content.Context;

import java.net.InetAddress;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;

import okhttp3.Dns;

/**
 * TVBox csp 蜘蛛的基类（android 侧同名类的最小兼容实现）。
 *
 * 真实 jar 里的 csp_ 类继承自 {@code com.github.catvod.crawler.Spider}，而这个
 * 类在 jar 里不存在，必须由运行时提供（B1 研究确认）。这里只实现与
 * TVBoxOSC 官方一致的方法签名与返回约定：
 *
 * - 各 content 方法返回 JSON 字符串（TvBox 标准 schema）
 * - 网络请求由运行时直连（用户决策），不经过 host.fetch
 */
public abstract class Spider {

    /** 应用上下文。jar 里的源常经 init(Context) 拿它取包名/偏好。 */
    protected Context context;

    /**
     * 容错 DNS。TVBox 宿主同名方法：解析失败**不抛异常**，返回空列表。
     *
     * 这个方法是**宿主提供**的（jar 里没有），部分蜘蛛（Hxq / App3Q / AppYQK 等）
     * 在建 OkHttpClient 时会调用它。缺了会抛
     * {@code NoSuchMethodError: 'okhttp3.Dns ...Spider.safeDns()'}，整条取数链直接
     * 失败 —— 2026-10-04 用 `ApiSurfaceScan` 扫 jar 的成员引用时才发现漏了。
     */
    public static Dns safeDns() {
        return host -> {
            try {
                List<InetAddress> list = Dns.SYSTEM.lookup(host);
                return list == null ? Collections.emptyList() : list;
            } catch (Exception e) {
                SpiderDebug.log(e);
                return Collections.emptyList();
            }
        };
    }

    /** 初始化（单参版本）。 */
    public void init(Context context) {
        this.context = context;
    }

    /** 初始化（带扩展参数版本，ext 常是配置/账号串）。 */
    public void init(Context context, String extend) {
        this.context = context;
    }

    /** 首页：分类 + 推荐列表。 */
    public String homeContent(boolean filter) throws Exception {
        return "";
    }

    /** 首页视频（部分源实现）。 */
    public String homeVideoContent() throws Exception {
        return "";
    }

    /** 分类列表页。 */
    public String categoryContent(
            String cid, String page, boolean filter,
            HashMap<String, String> extend) throws Exception {
        return "";
    }

    /** 详情。ids 为 vod id 列表。 */
    public String detailContent(List<String> ids) throws Exception {
        return "";
    }

    /** 搜索。 */
    public String searchContent(String key, boolean quick) throws Exception {
        return "";
    }

    /** 播放地址解析。 */
    public String playerContent(
            String flag, String id, List<String> vipFlags) throws Exception {
        return "";
    }

    /** 手动校验视频。 */
    public String manualVideoCheck() throws Exception {
        return "";
    }

    /** 自定义 action。 */
    public String action(String action) throws Exception {
        return "";
    }

    /** 播放前的检查（可选）。 */
    public String isVideoFormat(String url) throws Exception {
        return "";
    }

    /** 注入 SpiderApi 句柄（TVBox 宿主在 create 后调用）。 */
    public void initApi(SpiderApi api) {
    }
}