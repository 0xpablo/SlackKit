//
// WebAPI.swift
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

//swiftlint:disable file_length
import Foundation
#if !COCOAPODS
@_exported import SKCore
#endif

public final class WebAPI {

    public enum InfoType: String {
        case purpose, topic
    }

    public enum ParseMode: String {
        case full, none
    }

    public enum Presence: String {
        case auto, away
    }

    fileprivate enum ChannelType: String {
        case channel, group, im
    }

    public enum ConversationType: String {
        case public_channel, private_channel, mpim, im
    }

    fileprivate let networkInterface: NetworkInterface
    fileprivate let token: String

    public init(token: String) {
        self.networkInterface = NetworkInterface()
        self.token = token
    }
}

// MARK: - RTM
extension WebAPI {
    public static func rtmConnect(
        token: String,
        batchPresenceAware: Bool = false,
        presenceSub: Bool = false
    ) async throws -> [String: Any] {
        let parameters: [String: Any?] = [
            "batch_presence_aware": batchPresenceAware,
            "presence_sub": presenceSub
        ]
        return try await NetworkInterface().request(.rtmConnect, accessToken: token, parameters: parameters)
    }
}

// MARK: - Auth
extension WebAPI {
    public func authenticationTest() async throws -> (user: String?, team: String?) {
        let response = try await networkInterface.request(.authTest, accessToken: token, parameters: [:])
        return (
            user: response["user_id"] as? String,
            team: response["team_id"] as? String
        )
    }

    public static func oauthAccess(
        clientID: String,
        clientSecret: String,
        code: String,
        redirectURI: String? = nil
    ) async throws -> [String: Any] {
        let parameters: [String: Any?] = [
            "client_id": clientID,
            "client_secret": clientSecret,
            "code": code,
            "redirect_uri": redirectURI
        ]
        return try await NetworkInterface().request(.oauthAccess, accessToken: nil, parameters: parameters)
    }

    public static func oauthRevoke(
        token: String,
        test: Bool? = nil
    ) async throws {
        let parameters: [String: Any?] = ["test": test]
        _ = try await NetworkInterface().request(.authRevoke, accessToken: token, parameters: parameters)
    }
}

// MARK: - Channels
extension WebAPI {
    public func channelHistory(
        id: String,
        latest: String = "\(Date().timeIntervalSince1970)",
        oldest: String = "0",
        inclusive: Bool = false,
        count: Int = 100,
        unreads: Bool = false
    ) async throws -> History {
        return try await history(
            .channelsHistory,
            id: id,
            latest: latest,
            oldest: oldest,
            inclusive: inclusive,
            count: count,
            unreads: unreads
        )
    }
    
    public func channelsLeave(_ channel: String) async throws {
        try await leave(.channelsLeave, channel: channel)
    }
    
    public func channelsUnarchive(_ channel: String) async throws {
        try await unarchive(.channelsUnarchive, channel: channel)
    }
    
    public func channelsRename(_ channel: String, name: String, validate: Bool) async throws -> Channel {
        return try await rename(.channelsRename, channel: channel, name: name, validate: validate)
    }
    
    public func channelsKick(_ channel: String, user: String) async throws {
        try await kick(.channelsKick, channel: channel, user: user)
    }

    public func setChannelPurpose(channel: String, purpose: String) async throws {
        try await setInfo(.channelsSetPurpose, type: .purpose, channel: channel, text: purpose)
    }

    public func setChannelTopic(channel: String, topic: String) async throws {
        try await setInfo(.channelsSetTopic, type: .topic, channel: channel, text: topic)
    }
}

// MARK: - Messaging
extension WebAPI {
    public func deleteMessage(channel: String, ts: String) async throws {
        let parameters: [String: Any] = ["channel": channel, "ts": ts]
        _ = try await networkInterface.jsonRequest(.chatDelete, accessToken: token, parameters: parameters)
    }

    /// Sends a message to a Slack channel
    /// - Parameters:
    ///   - channel: Channel ID to send message to
    ///   - text: Message text
    ///   - username: Optional username override
    ///   - asUser: Whether to send as user
    /// - Returns: Tuple containing timestamp and channel ID of sent message
    /// - Throws: SlackError if request fails
    public func sendMessage(
        channel: String,
        text: String,
        username: String? = nil,
        asUser: Bool? = nil,
        parse: ParseMode? = nil,
        linkNames: Bool? = nil,
        attachments: [Attachment?]? = nil,
        blocks: [Block]? = nil,
        unfurlLinks: Bool? = nil,
        unfurlMedia: Bool? = nil,
        iconURL: String? = nil,
        iconEmoji: String? = nil
    ) async throws -> (ts: String?, channel: String?) {
        var parameters: [String: Any] = [
            "channel": channel,
            "text": text
        ]
        
        if let asUser = asUser { parameters["as_user"] = asUser }
        if let parse = parse { parameters["parse"] = parse.rawValue }
        if let linkNames = linkNames { parameters["link_names"] = linkNames }
        if let unfurlLinks = unfurlLinks { parameters["unfurl_links"] = unfurlLinks }
        if let unfurlMedia = unfurlMedia { parameters["unfurl_media"] = unfurlMedia }
        if let username = username { parameters["username"] = username }
        if let iconURL = iconURL { parameters["icon_url"] = iconURL }
        if let iconEmoji = iconEmoji { parameters["icon_emoji"] = iconEmoji }
        if let attachments = attachments?.compactMap({ $0 }) {
            parameters["attachments"] = attachments.map { $0.dictionary }
        }
        if let blocks = blocks {
            parameters["blocks"] = blocks.map { $0.dictionary }
        }

        let response = try await networkInterface.jsonRequest(.chatPostMessage, accessToken: token, parameters: parameters)
        return (ts: response["ts"] as? String, channel: response["channel"] as? String)
    }

    public func sendThreadedMessage(
        channel: String,
        thread: String,
        text: String,
        broadcastReply: Bool = false,
        username: String? = nil,
        asUser: Bool? = nil,
        parse: ParseMode? = nil,
        linkNames: Bool? = nil,
        attachments: [Attachment?]? = nil,
        unfurlLinks: Bool? = nil,
        unfurlMedia: Bool? = nil,
        iconURL: String? = nil,
        iconEmoji: String? = nil
    ) async throws -> (ts: String?, channel: String?) {
        var parameters: [String: Any] = [
            "channel": channel,
            "thread_ts": thread,
            "text": text,
            "reply_broadcast": broadcastReply
        ]
        
        if let asUser = asUser { parameters["as_user"] = asUser }
        if let parse = parse { parameters["parse"] = parse.rawValue }
        if let linkNames = linkNames { parameters["link_names"] = linkNames }
        if let unfurlLinks = unfurlLinks { parameters["unfurl_links"] = unfurlLinks }
        if let unfurlMedia = unfurlMedia { parameters["unfurl_media"] = unfurlMedia }
        if let username = username { parameters["username"] = username }
        if let iconURL = iconURL { parameters["icon_url"] = iconURL }
        if let iconEmoji = iconEmoji { parameters["icon_emoji"] = iconEmoji }
        if let attachments = attachments?.compactMap({ $0 }) {
            parameters["attachments"] = attachments.map { $0.dictionary }
        }

        let response = try await networkInterface.jsonRequest(.chatPostMessage, accessToken: token, parameters: parameters)
        return (ts: response["ts"] as? String, response["channel"] as? String)
    }

    public func sendEphemeral(
        channel: String,
        text: String,
        user: String,
        thread: String? = nil,
        asUser: Bool? = nil,
        attachments: [Attachment?]? = nil,
        blocks: [Block]? = nil,
        linkNames: Bool? = nil,
        parse: ParseMode? = nil
    ) async throws -> (ts: String?, channel: String?) {
        let parameters: [String: Any?] = [
            "channel": channel,
            "text": text,
            "user": user,
            "thread_ts": thread,
            "as_user": asUser,
            "attachments": encodeAttachments(attachments),
            "blocks": encodeBlocks(blocks),
            "link_names": linkNames,
            "parse": parse?.rawValue,
        ]
        let response = try await networkInterface.request(.chatPostEphemeral, accessToken: token, parameters: parameters)
        return (ts: response["message_ts"] as? String, response["channel"] as? String)
    }

    public func sendMeMessage(
        channel: String,
        text: String
    ) async throws -> (ts: String?, channel: String?) {
        let parameters: [String: Any?] = ["channel": channel, "text": text]
        let response = try await networkInterface.request(.chatMeMessage, accessToken: token, parameters: parameters)
        return (ts: response["ts"] as? String, channel: response["channel"] as? String)
    }

    public func updateMessage(
        channel: String,
        ts: String,
        message: String,
        attachments: [Attachment?]? = nil,
        parse: ParseMode = .none,
        linkNames: Bool = false
    ) async throws {
        var parameters: [String: Any] = [
            "channel": channel,
            "ts": ts,
            "text": message,
            "parse": parse.rawValue,
            "link_names": linkNames
        ]
        
        if let attachments = attachments?.compactMap({ $0 }) {
            parameters["attachments"] = attachments.map { $0.dictionary }
        }

        _ = try await networkInterface.jsonRequest(.chatUpdate, accessToken: token, parameters: parameters)
    }

    public func sendMessage(
        toWebHook webhookURL: String,
        text: String,
        blocks: [Block]? = nil,
        attachments: [Attachment?]? = nil,
        responseType: MessageResponseType? = nil
    ) async throws {
        var payload: [String: Any] = ["text": text]

        if let blocks = blocks {
            payload["blocks"] = encodeBlocks(blocks)
        }

        if let attachments = attachments {
            payload["attachments"] = encodeAttachments(attachments)
        }

        if let responseType {
            payload["response_type"] = responseType.rawValue
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            throw SlackError.invalidFormData
        }

        _ = try await networkInterface.customRequest(
            webhookURL,
            token: "", // No token required for webhooks
            data: jsonData
        )
    }
}

// MARK: - Do Not Disturb
extension WebAPI {
    public func dndInfo(user: String? = nil) async throws -> DoNotDisturbStatus {
        let parameters: [String: Any?] = ["user": user]
        let response = try await networkInterface.request(.dndInfo, accessToken: token, parameters: parameters)
        return DoNotDisturbStatus(status: response)
    }

    public func dndTeamInfo(users: [String]? = nil) async throws -> [String: DoNotDisturbStatus] {
        let parameters: [String: Any?] = ["users": users?.joined(separator: ",")]
        let response = try await networkInterface.request(.dndTeamInfo, accessToken: token, parameters: parameters)
        guard let usersDictionary = response["users"] as? [String: Any] else {
            return [:]
        }
        return self.enumerateDNDStatuses(usersDictionary)
    }
}

// MARK: - Emoji
extension WebAPI {
    public func emojiList() async throws -> [String: Any]? {
        let response = try await networkInterface.request(.emojiList, accessToken: token, parameters: [:])
        return response["emoji"] as? [String: Any]
    }
}

// MARK: - Files
extension WebAPI {
    public func deleteFile(fileID: String) async throws {
        let parameters = ["file": fileID]
        _ = try await networkInterface.request(.filesDelete, accessToken: token, parameters: parameters)
    }

    public func fileInfo(
        fileID: String,
        count: Int = 100,
        page: Int = 1
    ) async throws -> File {
        let parameters: [String: Any] = ["file": fileID, "count": count, "page": page]
        let response = try await networkInterface.request(.filesInfo, accessToken: token, parameters: parameters)
        var file = File(file: response["file"] as? [String: Any])
        (response["comments"] as? [[String: Any]])?.forEach { comment in
            let comment = Comment(comment: comment)
            if let id = comment.id {
                file.comments[id] = comment
            }
        }
        return file
    }

    public func uploadFile(
        data: Data,
        filename: String,
        title: String? = nil,
        altText: String? = nil,
        snippetType: String? = nil,
        initialComment: String? = nil,
        channelID: String? = nil,
        channels: [String]? = nil,
        threadTs: String? = nil
    ) async throws -> File {
        let parameters: [String: Any?] = [
            "filename": filename,
            "length": data.count,
            "alt_txt": altText,
            "snippet_type": snippetType
        ]
        
        let response = try await networkInterface.request(
            .filesGetUploadURLExternal,
            accessToken: token,
            parameters: parameters
        )
        
        guard let uploadURL = FileUploadURL(dictionary: response) else {
            throw SlackError.clientJSONError
        }
        
        try await networkInterface.uploadToURL(
            uploadURL.uploadURL,
            data: data,
            filename: filename
        )
        
        var completeParameters: [String: Any] = [
            "files": [["id": uploadURL.fileID, "title": title].compactMapValues { $0 }]
        ]

        if let channelID {
            completeParameters["channels"] = channelID
        }

        if let channels {
            completeParameters["channels"] = channels.joined(separator: ",")
        }
        if let initialComment {
            completeParameters["initial_comment"] = initialComment
        }
        if let threadTs {
            completeParameters["thread_ts"] = threadTs
        }
        
        let completeResponse = try await networkInterface.jsonRequest(
            .filesCompleteUploadExternal,
            accessToken: token,
            parameters: completeParameters
        )
        
        guard let files = completeResponse["files"] as? [[String: Any]],
              let firstFile = files.first else {
            throw SlackError.clientJSONError
        }
        
        return File(file: firstFile)
    }
}

// MARK: - File Comments
extension WebAPI {
    public func addFileComment(fileID: String, comment: String) async throws -> Comment {
        let parameters: [String: Any] = ["file": fileID, "comment": comment]
        let response = try await networkInterface.request(.filesCommentsAdd, accessToken: token, parameters: parameters)
        return Comment(comment: response["comment"] as? [String: Any])
    }

    public func editFileComment(fileID: String, commentID: String, comment: String) async throws -> Comment {
        let parameters: [String: Any] = ["file": fileID, "id": commentID, "comment": comment]
        let response = try await networkInterface.request(.filesCommentsEdit, accessToken: token, parameters: parameters)
        return Comment(comment: response["comment"] as? [String: Any])
    }

    public func deleteFileComment(fileID: String, commentID: String) async throws {
        let parameters: [String: Any] = ["file": fileID, "id": commentID]
        _ = try await networkInterface.request(.filesCommentsDelete, accessToken: token, parameters: parameters)
    }
}

// MARK: - Groups
extension WebAPI {
    public func closeGroup(groupID: String) async throws {
        try await close(.groupsClose, channelID: groupID)
    }

    public func groupHistory(
        id: String,
        latest: String = "\(Date().timeIntervalSince1970)",
        oldest: String = "0",
        inclusive: Bool = false,
        count: Int = 100,
        unreads: Bool = false
    ) async throws -> History {
        return try await history(
            .groupsHistory,
            id: id,
            latest: latest,
            oldest: oldest,
            inclusive: inclusive,
            count: count,
            unreads: unreads
        )
    }

    public func groupInfo(id: String) async throws -> Channel {
        return try await info(.groupsInfo, type: .group, id: id)
    }

    public func groupsList(
        excludeArchived: Bool = false,
        excludeMembers: Bool = false
    ) async throws -> [[String: Any]]? {
        return try await list(.groupsList, type: .group, excludeArchived: excludeArchived, excludeMembers: excludeMembers)
    }

    public func markGroup(channel: String, timestamp: String) async throws -> String {
        return try await mark(.groupsMark, channel: channel, timestamp: timestamp)
    }

    public func openGroup(channel: String) async throws {
        let parameters = ["channel": channel]
        _ = try await networkInterface.request(.groupsOpen, accessToken: token, parameters: parameters)
    }

    public func setGroupPurpose(channel: String, purpose: String) async throws {
        try await setInfo(.groupsSetPurpose, type: .purpose, channel: channel, text: purpose)
    }

    public func setGroupTopic(channel: String, topic: String) async throws {
        try await setInfo(.groupsSetTopic, type: .topic, channel: channel, text: topic)
    }
}

// MARK: - IM
extension WebAPI {
    public func closeIM(channel: String) async throws {
        try await close(.imClose, channelID: channel)
    }

    public func imHistory(
        id: String,
        latest: String = "\(Date().timeIntervalSince1970)",
        oldest: String = "0",
        inclusive: Bool = false,
        count: Int = 100,
        unreads: Bool = false
    ) async throws -> History {
        return try await history(
            .imHistory,
            id: id,
            latest: latest,
            oldest: oldest,
            inclusive: inclusive,
            count: count,
            unreads: unreads
        )
    }

    public func imsList(
        excludeArchived: Bool = false,
        excludeMembers: Bool = false
    ) async throws -> [[String: Any]]? {
        return try await list(.imList, type: .im, excludeArchived: excludeArchived, excludeMembers: excludeMembers)
    }

    public func markIM(channel: String, timestamp: String) async throws -> String {
        return try await mark(.imMark, channel: channel, timestamp: timestamp)
    }
}

// MARK: - MPIM
extension WebAPI {
    public func closeMPIM(channel: String) async throws {
        try await close(.mpimClose, channelID: channel)
    }

    public func mpimHistory(
        id: String,
        latest: String = "\(Date().timeIntervalSince1970)",
        oldest: String = "0",
        inclusive: Bool = false,
        count: Int = 100,
        unreads: Bool = false
    ) async throws -> History {
        return try await history(
            .mpimHistory,
            id: id,
            latest: latest,
            oldest: oldest,
            inclusive: inclusive,
            count: count,
            unreads: unreads
        )
    }

    public func mpimsList(
        excludeArchived: Bool = false,
        excludeMembers: Bool = false
    ) async throws -> [[String: Any]]? {
        return try await list(.mpimList, type: .group, excludeArchived: excludeArchived, excludeMembers: excludeMembers)
    }

    public func markMPIM(channel: String, timestamp: String) async throws -> String {
        return try await mark(.mpimMark, channel: channel, timestamp: timestamp)
    }

    public func openMPIM(userIDs: [String]) async throws -> String? {
        let parameters = ["users": userIDs.joined(separator: ",")]
        let response = try await networkInterface.request(.mpimOpen, accessToken: token, parameters: parameters)
        let group = response["group"] as? [String: Any]
        return group?["id"] as? String
    }
}

// MARK: - Pins
extension WebAPI {
    public func pinsList(channel: String) async throws -> [Item]? {
        let parameters: [String: Any?] = [
            "channel": channel
        ]
        let response = try await networkInterface.request(.pinsList, accessToken: token, parameters: parameters)
        let items = response["items"] as? [[String: Any]]
        return items?.map { Item(item: $0) }
    }

    public func pinItem(
        channel: String,
        file: String? = nil,
        fileComment: String? = nil,
        timestamp: String? = nil
    ) async throws {
        try await pin(.pinsAdd, channel: channel, file: file, fileComment: fileComment, timestamp: timestamp)
    }

    public func unpinItem(
        channel: String,
        file: String? = nil,
        fileComment: String? = nil,
        timestamp: String? = nil
    ) async throws {
        try await pin(.pinsRemove, channel: channel, file: file, fileComment: fileComment, timestamp: timestamp)
    }

    private func pin(
        _ endpoint: Endpoint,
        channel: String,
        file: String? = nil,
        fileComment: String? = nil,
        timestamp: String? = nil
    ) async throws {
        let parameters: [String: Any?] = [
            "channel": channel,
            "file": file,
            "file_comment": fileComment,
            "timestamp": timestamp
        ]
        _ = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
    }
}

// MARK: - Reactions
extension WebAPI {
    public func addReactionToMessage(name: String, channel: String, timestamp: String) async throws {
        try await addReaction(name: name, channel: channel, timestamp: timestamp)
    }

    public func addReactionToFile(name: String, file: String) async throws {
        try await addReaction(name: name, file: file)
    }

    public func addReactionToFileComment(name: String, fileComment: String) async throws {
        try await addReaction(name: name, fileComment: fileComment)
    }

    private func addReaction(
        name: String,
        file: String? = nil,
        fileComment: String? = nil,
        channel: String? = nil,
        timestamp: String? = nil
    ) async throws {
        try await react(.reactionsAdd, name: name, file: file, fileComment: fileComment, channel: channel, timestamp: timestamp)
    }

    public func removeReactionFromMessage(name: String, channel: String, timestamp: String) async throws {
        try await removeReaction(name: name, channel: channel, timestamp: timestamp)
    }

    public func removeReactionFromFile(name: String, file: String) async throws {
        try await removeReaction(name: name, file: file)
    }

    public func removeReactionFromFileComment(name: String, fileComment: String) async throws {
        try await removeReaction(name: name, fileComment: fileComment)
    }

    private func removeReaction(
        name: String,
        file: String? = nil,
        fileComment: String? = nil,
        channel: String? = nil,
        timestamp: String? = nil
    ) async throws {
        try await react(.reactionsRemove, name: name, file: file, fileComment: fileComment, channel: channel, timestamp: timestamp)
    }

    private func react(
        _ endpoint: Endpoint,
        name: String,
        file: String? = nil,
        fileComment: String? = nil,
        channel: String? = nil,
        timestamp: String? = nil
    ) async throws {
        let parameters: [String: Any?] = [
            "name": name,
            "file": file,
            "file_comment": fileComment,
            "channel": channel,
            "timestamp": timestamp
        ]
        _ = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
    }

    private enum ReactionItemType: String {
        case file, comment, message
    }

    public func getReactionsForFile(_ file: String, full: Bool = true) async throws -> [Reaction] {
        return try await getReactionsForItem(file, full: full, type: .file)
    }

    public func getReactionsForComment(_ comment: String, full: Bool = true) async throws -> [Reaction] {
        return try await getReactionsForItem(comment: comment, full: full, type: .comment)
    }

    public func getReactionsForMessage(_ channel: String, timestamp: String, full: Bool = true) async throws -> [Reaction] {
        return try await getReactionsForItem(channel: channel, timestamp: timestamp, full: full, type: .message)
    }

    private func getReactionsForItem(
        _ file: String? = nil,
        comment: String? = nil,
        channel: String? = nil,
        timestamp: String? = nil,
        full: Bool,
        type: ReactionItemType
    ) async throws -> [Reaction] {
        let parameters: [String: Any?] = [
            "file": file,
            "file_comment": comment,
            "channel": channel,
            "timestamp": timestamp,
            "full": full
        ]
        let response = try await networkInterface.request(.reactionsGet, accessToken: token, parameters: parameters)
        guard let item = response[type.rawValue] as? [String: Any] else {
            return []
        }
        switch type {
        case .message:
            let message = Message(dictionary: item)
            return message.reactions
        case .file:
            let file = File(file: item)
            return file.reactions
        case .comment:
            let comment = Comment(comment: item)
            return comment.reactions
        }
    }

    public func reactionsListForUser(
        _ user: String? = nil,
        full: Bool = true,
        count: Int = 100,
        page: Int = 1
    ) async throws -> [Item]? {
        let parameters: [String: Any?] = [
            "user": user,
            "full": full,
            "count": count,
            "page": page
        ]
        let response = try await networkInterface.request(.reactionsList, accessToken: token, parameters: parameters)
        let items = response["items"] as? [[String: Any]]
        return items?.map { Item(item: $0) }
    }
}

// MARK: - Stars
extension WebAPI {
    public func addStarToChannel(channel: String) async throws {
        try await addStar(channel: channel)
    }

    public func addStarToMessage(channel: String, timestamp: String) async throws {
        try await addStar(channel: channel, timestamp: timestamp)
    }

    public func addStarToFile(file: String) async throws {
        try await addStar(file: file)
    }

    public func addStarToFileComment(fileComment: String) async throws {
        try await addStar(fileComment: fileComment)
    }

    private func addStar(
        file: String? = nil,
        fileComment: String? = nil,
        channel: String? = nil,
        timestamp: String? = nil
    ) async throws {
        try await star(.starsAdd, file: file, fileComment: fileComment, channel: channel, timestamp: timestamp)
    }

    public func removeStarFromChannel(channel: String) async throws {
        try await removeStar(channel: channel)
    }

    public func removeStarFromMessage(channel: String, timestamp: String) async throws {
        try await removeStar(channel: channel, timestamp: timestamp)
    }

    public func removeStarFromFile(file: String) async throws {
        try await removeStar(file: file)
    }

    public func removeStarFromFilecomment(fileComment: String) async throws {
        try await removeStar(fileComment: fileComment)
    }

    private func removeStar(
        file: String? = nil,
        fileComment: String? = nil,
        channel: String? = nil,
        timestamp: String? = nil
    ) async throws {
        try await star(.starsRemove, file: file, fileComment: fileComment, channel: channel, timestamp: timestamp)
    }

    private func star(
        _ endpoint: Endpoint,
        file: String?,
        fileComment: String?,
        channel: String?,
        timestamp: String?
    ) async throws {
        let parameters: [String: Any?] = [
            "file": file,
            "file_comment": fileComment,
            "channel": channel,
            "timestamp": timestamp
        ]
        _ = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
    }
}

// MARK: - Team
extension WebAPI {
    public func teamInfo() async throws -> [String: Any]? {
        let response = try await networkInterface.request(.teamInfo, accessToken: token, parameters: [:])
        return response["team"] as? [String: Any]
    }
}

// MARK: - Users
extension WebAPI {
    public func userConversations(
        cursor: String? = nil,
        excludeArchived: Bool? = nil,
        limit: Int? = nil,
        types: [ConversationType]? = nil,
        userID: String? = nil
    ) async throws -> (channels: [Channel], nextCursor: String?) {
        let parameters: [String: Any?] = [
            "cursor": cursor,
            "exclude_archived": excludeArchived,
            "limit": limit,
            "types": types?.map({ $0.rawValue }).joined(separator: ","),
            "user": userID
        ]
        let response = try await networkInterface.request(.usersConversations, accessToken: token, parameters: parameters)
        let channels: [Channel] = (response["channels"] as? [[String: Any]])?.map{Channel(channel: $0)} ?? []
        return (
            channels: channels,
            nextCursor: (response["response_metadata"] as? [String: Any])?["next_cursor"] as? String
        )
    }

    public func userPresence(user: String) async throws -> String? {
        let parameters: [String: Any] = ["user": user]
        let response = try await networkInterface.request(.usersGetPresence, accessToken: token, parameters: parameters)
        return response["presence"] as? String
    }

    public func userInfo(id: String) async throws -> User {
        let parameters: [String: Any] = ["user": id]
        let response = try await networkInterface.request(.usersInfo, accessToken: token, parameters: parameters)
        return User(user: response["user"] as? [String: Any])
    }

    public func usersList(
        cursor: String? = nil,
        limit: Int? = nil,
        includePresence: Bool = false
    ) async throws -> (userList: [[String: Any]]?, nextCursor: String?) {
        var parameters: [String: Any] = ["presence": includePresence]
        if let cursor = cursor {
            parameters["cursor"] = cursor
        }
        if let limit = limit {
            parameters["limit"] = limit
        }
        
        let response = try await networkInterface.request(.usersList, accessToken: token, parameters: parameters)
        return (
            userList: response["members"] as? [[String: Any]],
            nextCursor: (response["response_metadata"] as? [String: Any])?["next_cursor"] as? String
        )
    }
    
    public func usersLookupByEmail(_ email: String) async throws -> User {
        let parameters: [String: Any] = ["email": email]
        let response = try await networkInterface.request(.usersLookupByEmail, accessToken: token, parameters: parameters)
        return User(user: response["user"] as? [String: Any])
    }

    public func usersProfileSet(profile: User.Profile) async throws {
        let profileValues = ([
            "first_name": profile.firstName,
            "last_name": profile.lastName,
            "real_name": profile.realName,
            "email": profile.email,
            "phone": profile.phone,
            "status_text": profile.statusText,
            "status_emoji": profile.statusEmoji,
            "status_expiration": profile.statusExpiration
        ] as [String: Any?])
        .filter { $0.value != nil }
        .mapValues { $0! }

        let data = try JSONSerialization.data(withJSONObject: ["profile": profileValues])
        let urlComponents = URLComponents(string: "https://slack.com/api/users.profile.set")
        guard let requestString = urlComponents?.url?.absoluteString else {
            throw SlackError.clientNetworkError
        }
        _ = try await networkInterface.customRequest(requestString, token: token, data: data)
    }

    public func setUserActive() async throws {
        _ = try await networkInterface.request(.usersSetActive, accessToken: token, parameters: [:])
    }

    public func setUserPresence(presence: Presence) async throws {
        let parameters: [String: Any] = ["presence": presence.rawValue]
        _ = try await networkInterface.request(.usersSetPresence, accessToken: token, parameters: parameters)
    }
}

// MARK: - Conversations
extension WebAPI {
    public func conversationsArchive(channel: String) async throws {
        let parameters = ["channel": channel]
        _ = try await networkInterface.request(.conversationsArchive, accessToken: token, parameters: parameters)
    }

    public func conversationsCreate(
        name: String,
        isPrivate: Bool = false
    ) async throws -> (id: String?, name: String?, creator: String?) {
        let parameters = [
            "name": name,
            "is_private": isPrivate
        ] as [String : Any]
        let response = try await networkInterface.request(.conversationsOpen, accessToken: token, parameters: parameters)
        let group = response["channel"] as? [String: Any]
        return (
            id: group?["id"] as? String,
            name: group?["name"] as? String,
            creator: group?["creator"] as? String
        )
    }

    public func conversationsList(
        excludeArchived: Bool = false,
        cursor: String? = nil,
        limit: Int? = nil,
        types: [ConversationType]? = nil
    ) async throws -> (channels: [[String: Any]]?, nextCursor: String?) {
        var parameters: [String: Any] = ["exclude_archived": excludeArchived]
        if let cursor = cursor {
            parameters["cursor"] = cursor
        }
        if let limit = limit {
            parameters["limit"] = limit
        }
        if let types = types {
            parameters["types"] = types.map({ $0.rawValue }).joined(separator: ",")
        }
        let response = try await networkInterface.request(.conversationsList, accessToken: token, parameters: parameters)
        return (
            channels: response["channels"] as? [[String: Any]],
            nextCursor: (response["response_metadata"] as? [String: Any])?["next_cursor"] as? String
        )
    }
    
    public func conversationsReplies(
        id: String,
        ts: String,
        cursor: String? = nil,
        inclusive: Bool = false,
        latest: String = "\(Date().timeIntervalSince1970)",
        limit: Int = 10,
        oldest: String = "0"
    ) async throws -> (messages: [[String: Any]]?, nextCursor: String?) {
        var parameters: [String: Any] = [
            "channel": id,
            "ts": ts,
            "inclusive": inclusive,
            "limit": limit,
            "latest": latest,
            "oldest": oldest,
        ]
        if let cursor = cursor {
            parameters["cursor"] = cursor
        }
        let response = try await networkInterface.request(.conversationsReplies, accessToken: token, parameters: parameters)
        return (
            messages: response["messages"] as? [[String: Any]],
            nextCursor: (response["response_metadata"] as? [String: Any])?["next_cursor"] as? String
        )
    }

    public func conversationsMembers(
        id: String,
        cursor: String? = nil,
        limit: Int? = nil
    ) async throws -> (members: [String]?, nextCursor: String?) {
        var parameters: [String: Any] = [
            "channel": id
        ]
        if let cursor = cursor {
            parameters["cursor"] = cursor
        }
        if let limit = limit {
            parameters["limit"] = limit
        }
        let response = try await networkInterface.request(.conversationsMembers, accessToken: token, parameters: parameters)
        return (
            members: response["members"] as? [String],
            nextCursor: (response["response_metadata"] as? [String: Any])?["next_cursor"] as? String
        )
    }

    public func conversationsHistory(
        id: String,
        cursor: String? = nil,
        inclusive: Bool = false,
        latest: String = "\(Date().timeIntervalSince1970)",
        limit: Int = 10,
        oldest: String = "0"
    ) async throws -> (messages: [[String: Any]]?, nextCursor: String?) {
        var parameters: [String: Any] = [
            "channel": id,
            "inclusive": inclusive,
            "limit": limit,
            "latest": latest,
            "oldest": oldest,
        ]
        if let cursor = cursor {
            parameters["cursor"] = cursor
        }
        let response = try await networkInterface.request(.conversationsHistory, accessToken: token, parameters: parameters)
        return (
            messages: response["messages"] as? [[String: Any]],
            nextCursor: (response["response_metadata"] as? [String: Any])?["next_cursor"] as? String
        )
    }

    public func conversationsOpen(
        userIDs: [String]
    ) async throws -> String? {
        let parameters = [
            "users": userIDs.joined(separator: ",")
        ]
        let response = try await networkInterface.request(.conversationsOpen, accessToken: token, parameters: parameters)
        let group = response["channel"] as? [String: Any]
        return group?["id"] as? String
    }
}

// MARK: - Search
extension WebAPI {
    public enum SearchSort: String {
        case score
        case timestamp
    }
    public enum SearchSortDirection: String {
        case asc
        case desc
    }
    
    public func search(
        query: String,
        count: Int = 20,
        highlight: Bool = false,
        page: Int = 1,
        sort: SearchSort = .score,
        sortDir: SearchSortDirection = .desc
    ) async throws -> (files: [[String: Any]]?, messages: [[String: Any]]?) {
        let parameters: [String: Any] = [
            "query": query,
            "count": count,
            "highlight": highlight,
            "page": page,
            "sort": sort.rawValue,
            "sort_dir": sortDir.rawValue,
        ]
        let response = try await networkInterface.request(.searchAll, accessToken: token, parameters: parameters)
        return (
            files: (response["files"] as? [String: Any])?["matches"] as? [[String: Any]],
            messages: (response["messages"] as? [String: Any])?["matches"] as? [[String: Any]]
            )
    }
    
    public func searchFiles(
        query: String,
        count: Int = 20,
        highlight: Bool = false,
        page: Int = 1,
        sort: SearchSort = .score,
        sortDir: SearchSortDirection = .desc
    ) async throws -> [[String: Any]]? {
        let parameters: [String: Any] = [
            "query": query,
            "count": count,
            "highlight": highlight,
            "page": page,
            "sort": sort.rawValue,
            "sort_dir": sortDir.rawValue,
        ]
        let response = try await networkInterface.request(.searchFiles, accessToken: token, parameters: parameters)
        return (response["files"] as? [String: Any])?["matches"] as? [[String: Any]]
    }
    
    public func searchMessages(
        query: String,
        count: Int = 20,
        highlight: Bool = false,
        page: Int = 1,
        sort: SearchSort = .score,
        sortDir: SearchSortDirection = .desc
    ) async throws -> [[String: Any]]? {
        let parameters: [String: Any] = [
            "query": query,
            "count": count,
            "highlight": highlight,
            "page": page,
            "sort": sort.rawValue,
            "sort_dir": sortDir.rawValue,
        ]
        let response = try await networkInterface.request(.searchMessages, accessToken: token, parameters: parameters)
        return (response["messages"] as? [String: Any])?["matches"] as? [[String: Any]]
    }
}

// MARK: - Helper Methods
extension WebAPI {
    fileprivate func encodeAttachments(_ attachments: [Attachment?]?) -> String? {
        if let attachments = attachments {
            var attachmentArray: [[String: Any]] = []
            for attachment in attachments {
                if let attachment = attachment {
                    attachmentArray.append(attachment.dictionary)
                }
            }
            do {
                let data = try JSONSerialization.data(withJSONObject: attachmentArray, options: [])
                return String(data: data, encoding: String.Encoding.utf8)
            } catch let error {
                print(error)
            }
        }
        return nil
    }

    fileprivate func encodeBlocks(_ blocks: [Block?]?) -> String? {
        if let blocks = blocks {
            let blocksArray: [[String: Any]] = blocks.map { $0?.dictionary ?? [:] }
            do {
                let data = try JSONSerialization.data(withJSONObject: blocksArray, options: [])
                return String(data: data, encoding: String.Encoding.utf8)
            } catch let error {
                print(error)
            }
        }
        return nil
    }

    fileprivate func enumerateDNDStatuses(_ statuses: [String: Any]) -> [String: DoNotDisturbStatus] {
        var retVal = [String: DoNotDisturbStatus]()
        for key in statuses.keys {
            retVal[key] = DoNotDisturbStatus(status: statuses[key] as? [String: Any])
        }
        return retVal
    }

    fileprivate func close(_ endpoint: Endpoint, channelID: String) async throws {
        let parameters: [String: Any] = ["channel": channelID]
        _ = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
    }

    fileprivate func history(
        _ endpoint: Endpoint,
        id: String,
        latest: String = "\(Date().timeIntervalSince1970)",
        oldest: String = "0",
        inclusive: Bool = false,
        count: Int = 100,
        unreads: Bool = false
    ) async throws -> History {
        let parameters: [String: Any] = [
            "channel": id,
            "latest": latest,
            "oldest": oldest,
            "inclusive": inclusive,
            "count": count,
            "unreads": unreads
        ]
        let response = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
        return History(history: response)
    }

    fileprivate func info(
        _ endpoint: Endpoint,
        type: ChannelType,
        id: String
    ) async throws -> Channel {
        let parameters: [String: Any] = ["channel": id]
        let response = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
        return Channel(channel: response[type.rawValue] as? [String: Any])
    }

    fileprivate func list(
        _ endpoint: Endpoint,
        type: ChannelType,
        excludeArchived: Bool = false,
        excludeMembers: Bool = false
    ) async throws -> [[String: Any]]? {
        let parameters: [String: Any] = ["exclude_archived": excludeArchived, "exclude_members": excludeMembers]
        let response = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
        return response[type.rawValue+"s"] as? [[String: Any]]
    }

    fileprivate func mark(
        _ endpoint: Endpoint,
        channel: String,
        timestamp: String
    ) async throws -> String {
        let parameters: [String: Any] = ["channel": channel, "ts": timestamp]
        let response = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
        return response["ts"] as? String ?? timestamp
    }

    fileprivate func setInfo(_ endpoint: Endpoint, type: InfoType, channel: String, text: String) async throws {
        let parameters: [String: Any] = ["channel": channel, type.rawValue: text]
        _ = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
    }

    fileprivate func create(_ endpoint: Endpoint, name: String) async throws -> Channel {
        let parameters: [String: Any] = ["name": name]
        let response = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
        return Channel(channel: response["channel"] as? [String: Any])
    }

    fileprivate func invite(_ endpoint: Endpoint, channel: String, user: String) async throws {
        let parameters: [String: Any] = ["channel": channel, "user": user]
        _ = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
    }
    
    fileprivate func join(_ endpoint: Endpoint, name: String, validate: Bool) async throws -> Channel {
        let parameters: [String: Any] = ["name": name, "validate": validate]
        let response = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
        return Channel(channel: response["channel"] as? [String: Any])
    }
    
    fileprivate func leave(_ endpoint: Endpoint, channel: String) async throws {
        let parameters: [String: Any] = ["channel": channel]
        _ = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
    }
    
    fileprivate func archive(_ endpoint: Endpoint, channel: String) async throws {
        let parameters: [String: Any] = ["channel": channel]
        _ = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
    }
    
    fileprivate func unarchive(_ endpoint: Endpoint, channel: String) async throws {
        let parameters: [String: Any] = ["channel": channel]
        _ = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
    }
    
    fileprivate func rename(
        _ endpoint: Endpoint,
        channel: String,
        name: String,
        validate: Bool
    ) async throws -> Channel {
        let parameters: [String: Any] = ["channel": channel, "name": name, "validate": validate]
        let response = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
        return Channel(channel: response["channel"] as? [String: Any])
    }
    
    fileprivate func kick(
        _ endpoint: Endpoint,
        channel: String,
        user: String
    ) async throws {
        let parameters: [String: Any] = ["channel": channel, "user": user]
        _ = try await networkInterface.request(endpoint, accessToken: token, parameters: parameters)
    }
}

// MARK: - Deprecated
extension WebAPI {
    // MARK: channels.*
    @available(*, deprecated, message: "Use conversationsArchive instead.")
    public func channelsArchive(_ channel: String) async throws {
        try await archive(.channelsArchive, channel: channel)
    }

    @available(*, deprecated, message: "Use conversationsCreate instead.")
    public func createChannel(channel: String) async throws -> Channel {
        return try await create(.channelsCreate, name: channel)
    }

    @available(*, deprecated)
    public func channelInfo(id: String) async throws -> Channel {
        return try await info(.channelsInfo, type: .channel, id: id)
    }

    @available(*, deprecated)
    public func inviteToChannel(_ channel: String, user: String) async throws {
        try await invite(.channelsInvite, channel: channel, user: user)
    }

    @available(*, deprecated)
    public func channelsJoin(_ name: String, validate: Bool) async throws -> Channel {
        return try await join(.channelsJoin, name: name, validate: validate)
    }

    @available(*, deprecated)
    public func channelsList(
        excludeArchived: Bool = false,
        excludeMembers: Bool = false
    ) async throws -> [[String: Any]]? {
        return try await list(.channelsList, type: .channel, excludeArchived: excludeArchived, excludeMembers: excludeMembers)
    }

    @available(*, deprecated)
    public func markChannel(channel: String, timestamp: String) async throws -> String {
        return try await mark(.channelsMark, channel: channel, timestamp: timestamp)
    }

    // MARK: im.*
    @available(*, deprecated, message: "Use conversationsOpen instead.")
    public func openIM(userID: String) async throws -> String? {
        let parameters = ["user": userID]
        let response = try await networkInterface.request(.imOpen, accessToken: token, parameters: parameters)
        let group = response["channel"] as? [String: Any]
        return group?["id"] as? String
    }
}
