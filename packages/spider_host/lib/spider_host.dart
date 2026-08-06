/// Spider 子进程的宿主侧实现。
///
/// 见 `docs/08-RPC协议.md` 与 `docs/05-Spider引擎.md`。
library;

export 'src/rpc/frame_parser.dart'
    show
        FrameComplete,
        FrameError,
        FrameNeedMore,
        FrameResult,
        LspFrameParser,
        kMaxHeaderBytes,
        kMaxMessageBytes;
export 'src/rpc/rpc_message.dart'
    show
        RpcMessage,
        RpcNotification,
        RpcRequest,
        RpcResponse,
        encodeFramed,
        jsonRpcInternalError,
        jsonRpcInvalidRequest,
        jsonRpcMethodNotFound,
        jsonRpcParseError,
        kJsonRpcVersion;
