import Foundation
import Hummingbird
import HummingbirdCore

class HummingbirdServer: SlackKitServer {
    let server: Application<RouterResponder<BasicRequestContext>>
    let port: in_port_t
    let forceIPV4: Bool
    private var serverTask: Task<Void, any Error>?

    init(port: in_port_t = 8080, forceIPV4: Bool = false, responder: SlackKitResponder) {
        self.port = port
        self.forceIPV4 = forceIPV4

        let router = Router()

        for route in responder.routes {
            router.post(RouterPath(route.path)) { r, context -> HummingbirdCore.Response in
                let skRequest = try await Request(r)
                let skResponse = await route.middleware.respond(to: (skRequest, Response())).1
                return .init(skResponse)
            }
        }

        server = Application(
            router: router,
            configuration: .init(address: .hostname("127.0.0.1", port: Int(port)))
        )
    }

    public func start() {
        serverTask = Task {
            try await server.run()
        }
    }

    deinit {
        serverTask?.cancel()
    }
}

private extension Request {
    init(_ r: HummingbirdCore.Request) async throws{
        let body = try await r.body.collect(upTo: 5 * 1024 * 1024)
        let data = Data(buffer: body)

        let queryPairs = r.uri.queryParameters.map { (String($0.key), String($0.value)) }

        self.init(method: HTTPMethod.custom(named: r.method.rawValue),
                  path: r.uri.path,
                  queryPairs: queryPairs,
                  body: data,
                  headers: .init(headers: r.headers.map { header in (header.name.rawName, header.value) })
                  )
    }
}

private extension HummingbirdCore.Response {
    init(_ r: ResponseType) {
        self.init(status: .init(code: r.code),
                  headers: .init(r.headers.map { .init(name: .init($0.name)!, value: $0.value) }),
                  body: .init(byteBuffer: .init(data: r.body)))
    }
}
