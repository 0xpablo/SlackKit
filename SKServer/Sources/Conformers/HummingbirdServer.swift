import Foundation
import Hummingbird
import HummingbirdCore

class HummingbirdServer: SlackKitServer {
    let server: HBApplication
    let port: in_port_t
    let forceIPV4: Bool

    init(port: in_port_t = 8080, forceIPV4: Bool = false, responder: SlackKitResponder) {
        self.port = port
        self.forceIPV4 = forceIPV4
        server = HBApplication(configuration: .init(address: .hostname("127.0.0.1", port: Int(port))))

        for route in responder.routes {
            server.router.get(route.path) { r -> HBResponse in
                let skRequest = try await Request(r)
                let skResponse = route.middleware.respond(to: (skRequest, Response())).1
                return .init(skResponse)
            }
        }
    }

    public func start() {
        do {
            try server.start()
        } catch let error {
            print("Server failed to start with error: \(error)")
        }
    }

    deinit {
        server.stop()
    }
}

private extension Request {
    init(_ r: HBRequest) async throws{
        let body = try await r.body.consumeBody(maxSize: 5 * 1024 * 1024)
        let data = body.map { Data(buffer: $0) } ?? Data()

        let queryPairs = r.uri.queryParameters.map { (String($0.key), String($0.value)) }

        self.init(method: HTTPMethod.custom(named: r.method.rawValue),
                  path: r.endpointPath!,
                  queryPairs: queryPairs,
                  body: data,
                  headers: .init(headers: r.headers.map { $0 })
                  )
    }
}

private extension HBResponse {
    init(_ r: ResponseType) {
        self.init(status: .init(statusCode: r.code),
                  headers: .init(r.headers.headers),
                  body: .byteBuffer(.init(data: r.body)))

    }
}
