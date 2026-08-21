package io.mistream.jvm;

import java.io.IOException;

/**
 * 分帧层输入非法：畸形 header、超长、非法 UTF-8。
 *
 * 与「流正常结束」区分开——后者是 {@link FrameCodec#readFrame()} 返回 null。
 */
public final class FrameFormatException extends IOException {

    FrameFormatException(String reason) {
        super(reason);
    }
}