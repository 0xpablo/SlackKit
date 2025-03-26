public struct FileUploadURL {
    public let uploadURL: String
    public let fileID: String
    
    public init?(dictionary: [String: Any]) {
        guard let uploadURL = dictionary["upload_url"] as? String,
              let fileID = dictionary["file_id"] as? String else {
            return nil
        }
        self.uploadURL = uploadURL
        self.fileID = fileID
    }
}
