//
// NetworkInterface.swift
//
// Copyright © 2017 Peter Zignego. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#if os(Linux)
import Dispatch
#endif
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Foundation

#if !COCOAPODS
import SKCore
#endif


public struct NetworkInterface {

    private let apiUrl = "https://slack.com/api/"
    #if canImport(FoundationNetworking)
    private let session = FoundationNetworking.URLSession(configuration: .default)
    #else
    private let session = URLSession(configuration: .default)
    #endif

    internal init() {}

    internal func request(
        _ endpoint: Endpoint,
        accessToken: String? = nil,
        parameters: [String: Any?]
    ) async throws -> [String: Any] {
        if let accessToken, accessToken.isEmpty {
            throw SlackError.invalidAuth
        }

        guard let url = requestURL(for: endpoint, parameters: parameters) else {
            throw SlackError.clientNetworkError
        }

        var request = URLRequest(url: url)
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        let (data, response) = try await session.data(for: request)

        return try NetworkInterface.handleResponse(data, response: response, publicError: nil)
    }

    internal func customRequest(
        _ url: String,
        token: String,
        data: Data
    ) async throws -> Bool {
        guard let string = url.removingPercentEncoding, let url =  URL(string: string) else {
            throw SlackError.clientNetworkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let contentType = "application/json; charset: utf-8"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = data

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SlackError.clientNetworkError
        }
        return true
    }

    internal func uploadToURL(
        _ url: String,
        data: Data,
        filename: String
    ) async throws {
        guard let url = URL(string: url) else {
            throw SlackError.clientNetworkError
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = randomBoundary()
        request.setValue("multipart/form-data; boundary=\(boundary); charset=utf-8", forHTTPHeaderField: "Content-Type")

        // Build the body
        var bodyData = Data()
        if let boundaryData = "--\(boundary)\r\n".data(using: .utf8),
           let dispositionData = "Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8),
           let contentTypeData = "Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8),
           let closingBoundaryData = "\r\n--\(boundary)--\r\n".data(using: .utf8) {

            bodyData.append(boundaryData)
            bodyData.append(dispositionData)
            bodyData.append(contentTypeData)
            bodyData.append(data)
            bodyData.append(closingBoundaryData)
        } else {
            throw SlackError.clientNetworkError
        }
        request.httpBody = bodyData

        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SlackError.clientNetworkError
        }
    }

    internal func jsonRequest(
        _ endpoint: Endpoint,
        accessToken: String,
        parameters: [String: Any]
    ) async throws -> [String: Any] {
        guard let url = URL(string: "\(apiUrl)\(endpoint.rawValue)") else {
            throw SlackError.clientNetworkError
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        request.httpBody = try JSONSerialization.data(withJSONObject: parameters, options: [])

        let (data, response) = try await session.data(for: request)
        return try NetworkInterface.handleResponse(data, response: response, publicError: nil)
    }

    internal static func handleResponse(_ data: Data?, response: URLResponse?, publicError: Error?) throws -> [String: Any] {
        guard let data = data, let response = response as? HTTPURLResponse else {
            throw SlackError.clientNetworkError
        }
        do {
            guard let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                throw SlackError.clientJSONError
            }

            switch response.statusCode {
            case 200:
                if json["ok"] as? Bool == true {
                    return json
                } else {
                    if let errorString = json["error"] as? String {
                        throw SlackError(rawValue: errorString) ?? .unknownError
                    } else {
                        throw SlackError.unknownError
                    }
                }
            case 429:
                throw SlackError.tooManyRequests
            default:
                throw SlackError.clientNetworkError
            }
        } catch let error {
            if let slackError = error as? SlackError {
                throw slackError
            } else {
                throw SlackError.unknownError
            }
        }
    }

    private func requestURL(for endpoint: Endpoint, parameters: [String: Any?]) -> URL? {
        var components = URLComponents(string: "\(apiUrl)\(endpoint.rawValue)")
        if parameters.count > 0 {
            components?.queryItems = parameters.compactMapValues({$0}).map { URLQueryItem(name: $0.0, value: "\($0.1)") }
        }

        // As discussed http://www.openradar.me/24076063 and https://stackoverflow.com/a/37314144/407523, Apple considers
        // a + and ? as valid characters in a URL query string, but Slack has recently started enforcing that they be
        // encoded when included in a query string. As a result, we need to manually apply the encoding after Apple's
        // default encoding is applied.
        var encodedQuery = components?.percentEncodedQuery
        encodedQuery = encodedQuery?.replacingOccurrences(of: ">", with: "%3E")
        encodedQuery = encodedQuery?.replacingOccurrences(of: "<", with: "%3C")
        encodedQuery = encodedQuery?.replacingOccurrences(of: "@", with: "%40")

        encodedQuery = encodedQuery?.replacingOccurrences(of: "?", with: "%3F")
        encodedQuery = encodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        components?.percentEncodedQuery = encodedQuery

        return components?.url
    }

    private func randomBoundary() -> String {
        let uuid = UUID().uuidString
        return "Slack-\(uuid)"
    }
}
