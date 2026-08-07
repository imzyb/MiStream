/// type=0 内置通用脚本 —— XPath/CSP 网页解析器。
///
/// 对 type=0 的源，用内置脚本通过 `req` + `pdfh`/`pdfa` 从 HTML 页面中提取
/// 数据，无需外部 JS 脚本。
///
/// 这个脚本由 `init` 时注入的源配置驱动，配置中的 `ext` 字段定义了各页面的
/// 提取规则（XPath 伪选择器）。
library;

/// 内置通用脚本的 JS 源码。
///
/// 每个 type=0 源在 `init` 时获得此脚本，源配置 `ext` 字段包含：
/// ```json
/// {
///   "homeUrl": "https://example.com",
///   "homeRule": "body&&.list&&a&&href",
///   "homeTitle": "body&&.list&&a&&Text",
///   "categoryUrl": "https://example.com/list/{tid}-{page}.html",
///   "categoryRule": "body&&.list&&a&&href",
///   "detailRule": {
///     "vodName": "h1&&Text",
///     "vodPic": "img&&src",
///     "vodPlayFrom": ".playlist&&h3&&Text",
///     "vodPlayUrl": ".playlist&&a&&href"
///   },
///   "searchUrl": "https://example.com/search?wd={wd}",
///   "searchRule": "body&&.list&&a&&href"
/// }
/// ```
const String type0Script = r'''
// type=0 内置通用脚本 — XPath/CSP 网页解析器
// 由源配置 'ext' 字段驱动，通过 req + pdfh/pdfa 提取页面数据

async function init(extend, config) {
  try {
    this.ext = typeof extend === 'string' ? JSON.parse(extend) : extend;
  } catch (e) {
    this.ext = {};
  }
  return { ok: true, capabilities: ['home', 'category', 'detail', 'search'] };
}

function getExt(key, fallback) {
  const val = this.ext ? this.ext[key] : null;
  return val !== null && val !== undefined ? val : fallback;
}

function fetchPage(url) {
  return req(url, { method: 'GET', timeoutMs: 10000 });
}

function extractList(html, rule) {
  const urls = pdfa(html, rule);
  const titles = pdfa(html, getExt('listTitleRule', 'a&&Text'));
  const imgs = pdfa(html, getExt('listPicRule', 'img&&src'));
  return urls.map((url, i) => ({
    vodId: url,
    vodName: titles[i] || '',
    vodPic: imgs[i] || '',
    vodRemarks: ''
  }));
}

async function homeContent(filter) {
  const url = getExt('homeUrl', '');
  if (!url) return { classes: [], list: [] };
  const html = await fetchPage(url);
  const rule = getExt('homeRule', 'a&&href');
  const list = extractList(html, rule);
  return { classes: [], list: list };
}

async function categoryContent(tid, page, filter, extend) {
  const urlTpl = getExt('categoryUrl', '');
  if (!urlTpl) return { list: [] };
  const url = urlTpl.replace('{tid}', tid).replace('{page}', String(page));
  const html = await fetchPage(url);
  const rule = getExt('categoryRule', 'a&&href');
  const list = extractList(html, rule);
  return { list: list, page: page };
}

async function detailContent(ids) {
  const url = ids.length > 0 ? ids[0] : '';
  if (!url) return { list: [] };
  const html = await fetchPage(url);
  const detailRule = getExt('detailRule', {});
  const vodName = pdfh(html, detailRule.vodName || 'h1&&Text');
  const vodPic = pdfh(html, detailRule.vodPic || 'img&&src');
  return {
    list: [{
      vodId: url,
      vodName: vodName,
      vodPic: vodPic,
      vodPlayFrom: [pdfh(html, detailRule.vodPlayFrom || 'h3&&Text')],
      vodPlayUrl: [[{ name: '播放', url: url }]]
    }]
  };
}

async function searchContent(key, quick, page) {
  const urlTpl = getExt('searchUrl', '');
  if (!urlTpl) return { list: [] };
  const url = urlTpl.replace('{wd}', encodeURIComponent(key));
  const html = await fetchPage(url);
  const rule = getExt('searchRule', 'a&&href');
  const list = extractList(html, rule);
  return { list: list };
}

async function playerContent(flag, id, vipFlags) {
  return { parse: 0, url: id, header: {} };
}
''';
