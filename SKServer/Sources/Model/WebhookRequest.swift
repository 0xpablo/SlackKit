//
// WebhookRequest.swift
//
// Copyright © 2025 Pablo Carcelén. All rights reserved.
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

public struct WebhookRequest: Codable {
    public let token: String?
    public let teamID: String?
    public let teamDomain: String?
    public let channelID: String?
    public let channelName: String?
    public let ts: String?
    public let userID: String?
    public let userName: String?
    public let command: String?
    public let text: String?
    public let triggerWord: String?
    public let responseURL: String?

    // Mapping keys for custom decoding if necessary
    private enum CodingKeys: String, CodingKey {
        case token
        case teamID = "team_id"
        case teamDomain = "team_domain"
        case channelID = "channel_id"
        case channelName = "channel_name"
        case ts = "timestamp"
        case userID = "user_id"
        case userName = "user_name"
        case command
        case text
        case triggerWord = "trigger_word"
        case responseURL = "response_url"
    }
}
