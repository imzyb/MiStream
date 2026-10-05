package android.content.res;

/**
 * android.content.res.XmlResourceParser 的最小兼容 shim。
 *
 * <p>真实 Android 里它继承 {@code XmlPullParser} 并实现 {@code AttributeSet}，
 * 用于解析编译后的二进制 XML 资源。无头运行时里没有资源表，所以这里退化成
 * 一个**空标记接口** —— 它只作为 {@code PackageItemInfo.loadXmlMetaData} 的
 * 返回类型出现在方法描述符里，只要类存在即可。
 *
 * <p>刻意不引入 {@code org.xmlpull.v1.XmlPullParser}：那会把一个解析器依赖
 * 拖进运行时，而实际没有任何源会真的去解析资源 XML（源要读 manifest 里的
 * meta-data 时，宿主会走别的路）。
 */
public interface XmlResourceParser {
}
