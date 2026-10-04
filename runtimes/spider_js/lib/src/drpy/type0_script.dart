/// type=0 内置通用脚本 —— XPath/CSP 网页解析器。
///
/// 对 type=0 的源，用内置脚本通过 `req` + `pdfh`/`pdfa` 从 HTML 页面中提取
/// 数据，无需外部 JS 脚本。
///
/// 这个脚本由 `init` 时注入的源配置驱动，配置中的 `ext` 字段定义了各页面的
/// 提取规则（XPath 伪选择器）。
///
/// ## 入口与字段约定（写错不会报错，只会安静地渲染出空白）
///
/// - **函数名**：`home` / `category` / `detail` / `search` / `play`（TVBox 约定）。
///   宿主按这些名字取函数，见 `runtime_child.dart` 的 `_spiderCallExpr`。
/// - **字段名**：snake_case —— `vod_id` / `vod_name` / `vod_pic` / `vod_remarks` /
///   `type_id` / `type_name` / `vod_play_from` / `vod_play_url`。解析方在
///   `packages/search_engine` 的 `home_use_case.dart` 与 `apps/mistream` 的
///   `detail_use_case.dart`，两边都按这些键取值。
/// - **线路**：`vod_play_from` 与 `vod_play_url` 均以 `$$$` 分隔线路；
///   `vod_play_url` 内以 `#` 分隔剧集、`$` 分隔「名称$地址」（只给地址也行，
///   宿主会补默认集名）。
library;

/// 内置通用脚本的 JS 源码。
///
/// 每个 type=0 源在 `init` 时获得此脚本，源配置 `ext` 字段包含：
/// ```json
/// {
///   "homeUrl": "https://example.com",
///   "homeRule": "body&&.list&&a&&href",
///   "listTitleRule": ".list&&a&&Text",
///   "listPicRule": ".list&&img&&src",
///   "listRemarksRule": ".list&&span&&Text",
///   "classes": [{"type_id": "1", "type_name": "电影"}],
///   "categoryUrl": "https://example.com/list/{tid}-{pg}.html",
///   "categoryRule": "body&&.list&&a&&href",
///   "nextPageRule": ".pager&&a&&href",
///   "detailRule": {
///     "vodName": "h1&&Text",
///     "vodPic": "img&&src",
///     "vodContent": ".desc&&Text",
///     "vodPlayFrom": ".playlist&&h3&&Text",
///     "vodPlayUrl": ".playlist&&a&&href",
///     "vodPlayUrlName": ".playlist&&a&&Text"
///   },
///   "searchUrl": "https://example.com/search?wd={wd}",
///   "searchRule": "body&&.list&&a&&href"
/// }
/// ```
/// `classes` 也接受 drpy 的字符串写法 `名称$值#名称$值`。
const String type0Script = r'''
// type=0 内置通用脚本 — XPath/CSP 网页解析器
// 由源配置 'ext' 字段驱动，通过 req + pdfh/pdfa 提取页面数据。
//
// 刻意不定义 homeVod()：宿主的 spider.home 会把 home() 与 homeVod() 的结果
// 合并且**后者覆盖前者**，两个都定义会让首页抓两次、列表还被后一次覆盖。
// home() 一次返回 {class, list} 就够了。

var __ext = {};

function init(extend, config) {
  if (typeof extend === 'string') {
    try {
      __ext = JSON.parse(extend) || {};
    } catch (e) {
      __ext = {};
    }
  } else if (extend && typeof extend === 'object') {
    __ext = extend;
  } else {
    __ext = {};
  }
  return { ok: true, capabilities: ['home', 'category', 'detail', 'search'] };
}

function cfg(key, fallback) {
  var v = __ext[key];
  return v === undefined || v === null || v === '' ? fallback : v;
}

function fetchPage(url) {
  return req(url, { method: 'GET', timeoutMs: 10000 });
}

// 统一取「页面正文 + 最终地址」。
//
// req 返回的是 `{content, headers, code, url}`，**不是裸字符串**。把整个对象
// 喂给 pdfh/pdfa，跨到宿主那边会被 `.toString()` 成 Dart Map 的 `{content: …}`，
// 页面一条都抽不出来，而且不报错。
async function load(url) {
  var resp = await fetchPage(url);
  if (resp === null || resp === undefined) return { url: url, content: '' };
  if (typeof resp === 'string') return { url: url, content: resp };
  return {
    url: resp.url === undefined || resp.url === null ? url : String(resp.url),
    content: resp.content === undefined || resp.content === null
      ? ''
      : String(resp.content)
  };
}

// 页面里的链接基本都是相对地址，而 vod_id 要能直接拿去请求详情页。
function absUrl(base, u) {
  if (!u) return '';
  return joinUrl(base, u);
}

// 把 URL 模板里的 {tid} / {pg} 之类占位符替换掉。同一语义给多个别名，
// 不同配置里见到的写法不一样（cateId/catePg 是 XBPQ 系的叫法）。
function fill(tpl, vars) {
  var out = String(tpl);
  for (var k in vars) {
    if (!Object.prototype.hasOwnProperty.call(vars, k)) continue;
    out = out.split('{' + k + '}').join(String(vars[k]));
  }
  return out;
}

function toInt(v, fallback) {
  var n = parseInt(v, 10);
  return isNaN(n) ? fallback : n;
}

// 取详情页地址。宿主按**字符串**传 `ids`（TVBox 约定，多 id 逗号分隔），
// 也有宿主传数组——所以不能直接 `ids[0]`，字符串那样取到的是首字符。
function firstId(ids) {
  if (ids === null || ids === undefined) return '';
  if (typeof ids !== 'string') {
    return ids.length ? String(ids[0]) : '';
  }
  // vod_id 也可能是完整 URL，URL 里的逗号属于地址本身，不能当分隔符截断。
  if (ids.indexOf('://') >= 0) return ids;
  var i = ids.indexOf(',');
  return i >= 0 ? ids.substring(0, i) : ids;
}

// 按 listRule 抽链接，标题/封面/备注各用一条可选规则，按**下标对齐**。
// 三条规则命中数不一致时缺的补空串，宁可少个名字也不要错位。
function extractList(page, rule) {
  var html = page.content;
  var urls = pdfa(html, rule);
  var titles = pdfa(html, cfg('listTitleRule', 'a&&Text'));
  var pics = pdfa(html, cfg('listPicRule', 'img&&src'));
  var remarks = pdfa(html, cfg('listRemarksRule', 'span&&Text'));
  var out = [];
  for (var i = 0; i < urls.length; i++) {
    out.push({
      vod_id: absUrl(page.url, urls[i]),
      vod_name: titles[i] || '',
      vod_pic: absUrl(page.url, pics[i]),
      vod_remarks: remarks[i] || ''
    });
  }
  return out;
}

// 分类列表。classes 支持两种写法：对象数组，或 drpy 的 '名称$值#名称$值'。
function readClasses() {
  var raw = cfg('classes', []);
  var out = [];
  if (typeof raw === 'string') {
    var items = raw.split('#');
    for (var i = 0; i < items.length; i++) {
      var parts = items[i].split('$');
      if (!parts[0]) continue;
      out.push({ type_id: parts[1] || parts[0], type_name: parts[0] });
    }
    return out;
  }
  if (raw && raw.length) {
    for (var j = 0; j < raw.length; j++) {
      var c = raw[j] || {};
      var id = c.type_id !== undefined ? c.type_id : c.typeId;
      var name = c.type_name !== undefined ? c.type_name : c.typeName;
      out.push({ type_id: String(id === undefined ? '' : id),
                 type_name: String(name === undefined ? '' : name) });
    }
  }
  return out;
}

async function home(filter) {
  var classes = readClasses();
  var url = cfg('homeUrl', '');
  if (!url) return { class: classes, list: [] };
  var page = await load(url);
  return {
    class: classes,
    list: extractList(page, cfg('homeRule', 'a&&href'))
  };
}

async function category(tid, pg, filter, extend) {
  var page = toInt(pg, 1);
  var tpl = cfg('categoryUrl', '');
  if (!tpl) return { list: [], page: page };
  var url = fill(tpl, {
    tid: tid, id: tid, cateId: tid,
    pg: page, page: page, catePg: page
  });
  var doc = await load(url);
  var list = extractList(doc, cfg('categoryRule', cfg('homeRule', 'a&&href')));
  var result = { list: list, page: page, limit: list.length, total: 0 };
  // 有「下一页」才认为还有一页。规则缺省时**不动 pagecount**——宿主把它缺省
  // 成 1，凭空造一个更大的值只会让界面翻出空白页。
  var nextRule = cfg('nextPageRule', '');
  if (nextRule && pdfh(doc.content, nextRule)) result.pagecount = page + 1;
  return result;
}

async function detail(ids) {
  var url = firstId(ids);
  if (!url) return { list: [] };
  var page = await load(url);
  var html = page.content;
  var d = cfg('detailRule', {});

  var lineName = d.vodPlayFrom ? pdfh(html, d.vodPlayFrom) : '';
  if (!lineName) lineName = '播放';

  // 播放地址抽成**一条线路**的剧集列表。多线路源需要源专属脚本，通用 XPath
  // 规则分不出「哪些链接属于哪条线路」，硬猜只会把剧集混在一起。
  var urls = d.vodPlayUrl ? pdfa(html, d.vodPlayUrl) : [];
  var names = d.vodPlayUrlName ? pdfa(html, d.vodPlayUrlName) : [];
  var episodes = [];
  for (var i = 0; i < urls.length; i++) {
    var ep = absUrl(page.url, urls[i]);
    episodes.push(names[i] ? names[i] + '$' + ep : ep);
  }

  return {
    list: [{
      vod_id: url,
      vod_name: pdfh(html, d.vodName || 'h1&&Text'),
      vod_pic: absUrl(page.url, pdfh(html, d.vodPic || 'img&&src')),
      vod_content: d.vodContent ? pdfh(html, d.vodContent) : '',
      vod_play_from: lineName,
      vod_play_url: episodes.join('#')
    }]
  };
}

async function search(wd, quick, pg) {
  var page = toInt(pg, 1);
  var tpl = cfg('searchUrl', '');
  if (!tpl) return { list: [] };
  var url = fill(tpl, {
    wd: encodeURIComponent(wd), key: encodeURIComponent(wd),
    pg: page, page: page
  });
  var doc = await load(url);
  return {
    list: extractList(doc, cfg('searchRule', cfg('homeRule', 'a&&href')))
  };
}

function play(flag, id, flags) {
  return { parse: 0, url: id, header: {} };
}
''';
