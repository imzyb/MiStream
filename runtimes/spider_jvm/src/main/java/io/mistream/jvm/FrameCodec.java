package io.mistream.jvm;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;

/**
 * LSP 风格分帧编解码器（docs/08 §1）。
 *
 * 与宿主侧 spider_js 的 SyncFrameCodec 逐字节对齐：header 读到 {@code \r\n\r\n}，
 * 按 Content-Length 精确读 body。整个运行时是单线程同步主循环，与
 * runtime_child.dart 的同步模型一致。
 */
public final class FrameCodec {
    /** header 上限（docs/08：单条消息上限 32MB）。 */
    static final int MAX_HEADER_BYTES = 16 * 1024;

    /** 单条消息体上限（docs/08 §1）。 */
    static final int MAX_MESSAGE_BYTES = 32 * 1024 * 1024;

    private final InputStream in;
    private final OutputStream out;

    FrameCodec() {
        this(System.in, System.out);
    }

    FrameCodec(InputStream in, OutputStream out) {
        this.in = in;
        this.out = out;
    }

    /**
     * 阻塞读出下一条消息的 JSON 文本。
     *
     * 流正常结束返回 null；输入非法抛 {@link FrameFormatException}。
     */
    String readFrame() throws IOException {
        String header = readHeader();
        if (header == null) return null;

        Integer length = parseContentLength(header);
        if (length == null) {
            throw new FrameFormatException("畸形 Content-Length");
        }
        if (length > MAX_MESSAGE_BYTES) {
            throw new FrameFormatException(
                "消息体 " + length + " 字节，超过上限 " + MAX_MESSAGE_BYTES);
        }

        byte[] body = new byte[length];
        int read = 0;
        while (read < length) {
            int n = in.read(body, read, length - read);
            if (n < 0) {
                throw new FrameFormatException(
                    "body 读到一半流就断了（" + read + "/" + length + " 字节）");
            }
            read += n;
        }
        return new String(body, StandardCharsets.UTF_8);
    }

    /** 写出一条消息。立即 flush，禁止行缓冲死锁（docs/08 §1）。 */
    void writeFrame(String json) throws IOException {
        byte[] body = json.getBytes(StandardCharsets.UTF_8);
        out.write(("Content-Length: " + body.length + "\r\n\r\n")
            .getBytes(StandardCharsets.UTF_8));
        out.write(body);
        out.flush();
    }

    private String readHeader() throws IOException {
        java.io.ByteArrayOutputStream buf = new java.io.ByteArrayOutputStream();
        int prev3 = -1;
        int prev2 = -1;
        int prev1 = -1;
        for (;;) {
            int b = in.read();
            if (b < 0) {
                if (buf.size() == 0) return null;
                throw new FrameFormatException(
                    "header 读到一半流就断了（" + buf.size() + " 字节）");
            }
            buf.write(b);
            // 检测结尾 \r\n\r\n
            if (prev3 == 13 && prev2 == 10 && prev1 == 13 && b == 10) {
                byte[] raw = buf.toByteArray();
                return new String(
                    raw, 0, raw.length - 4, StandardCharsets.UTF_8);
            }
            prev3 = prev2;
            prev2 = prev1;
            prev1 = b;
            if (buf.size() > MAX_HEADER_BYTES) {
                throw new FrameFormatException(
                    "header 超过上限 " + MAX_HEADER_BYTES + " 字节");
            }
        }
    }

    private static Integer parseContentLength(String header) {
        for (String rawLine : header.split("\r\n")) {
            String line = rawLine.trim();
            if (line.isEmpty()) continue;
            int colon = line.indexOf(':');
            if (colon <= 0) return null;
            if (!line.substring(0, colon).trim()
                .equalsIgnoreCase("content-length")) continue;
            try {
                int parsed = Integer.parseInt(line.substring(colon + 1).trim());
                if (parsed >= 0) return parsed;
            } catch (NumberFormatException ignored) {
                return null;
            }
        }
        return null;
    }
}