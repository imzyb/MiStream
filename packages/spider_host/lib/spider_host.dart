/// Spider 子进程的宿主侧实现。
///
/// 见 `docs/08-RPC协议.md` 与 `docs/05-Spider引擎.md`。
library;

export 'src/host/host_api.dart'
    show FetchResult, HostApi, HostFetchConfig, HostStorage;
export 'src/host/spider_host.dart'
    show
        HandshakeResult,
        ProcessLauncher,
        SpiderHost,
        defaultProcessLauncher,
        kGracefulShutdownMs,
        kHandshakeTimeout,
        kHeartbeatInterval,
        kHeartbeatMissLimit,
        kMaxRestartAttempts;
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
export 'src/rpc/rpc_recorder.dart'
    show RecordingRpcChannel, RpcRecordEvent, RpcRecorder, RpcReplayer;
export 'src/rpc/stdio_rpc_channel.dart'
    show StdioRpcChannel, kDefaultRequestTimeout, kWriteQueueMax;
export 'src/runtime/http_runtime.dart'
    show HttpRequestParams, HttpResponseData, HttpRuntime;
export 'src/runtime/spider_runtime_factory.dart'
    show
        HttpRuntimeAdapter,
        JsRuntimeAdapter,
        SpiderRuntime,
        SpiderRuntimeFactory,
        SpiderRuntimeType;
