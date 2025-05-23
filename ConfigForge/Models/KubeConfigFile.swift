import Foundation

enum KubeConfigFileStatus: Equatable {
    case valid
    case invalid(String)
    case unknown
}

enum KubeConfigFileType: Equatable {
    case active
    case backup
    case stored
}

struct KubeConfigFile: Identifiable, Equatable {
    var id: String { filePath.path }
    let fileName: String
    var displayName: String {
        fileName.components(separatedBy: ".").first ?? fileName
    }
    let filePath: URL
    private(set) var yamlContent: String?
    let fileType: KubeConfigFileType
    var status: KubeConfigFileStatus = .unknown
    let creationDate: Date?
    var modificationDate: Date?
    var isActive: Bool = false
    init(fileName: String, filePath: URL, fileType: KubeConfigFileType, yamlContent: String? = nil, 
         creationDate: Date? = nil, modificationDate: Date? = nil, isActive: Bool = false) {
        self.fileName = fileName
        self.filePath = filePath
        self.fileType = fileType
        self.yamlContent = yamlContent
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.isActive = isActive
    }

    static func from(url: URL, fileType: KubeConfigFileType, fileManager: FileManager = .default, isActive: Bool = false) -> KubeConfigFile? {
        var creationDate: Date? = nil
        var modificationDate: Date? = nil
        var yamlContent: String? = nil

        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            creationDate = attributes[.creationDate] as? Date
            modificationDate = attributes[.modificationDate] as? Date
        } catch {
            print("Warning: Could not read file attributes for \(url.path): \(error.localizedDescription)")
        }

        do {
             yamlContent = try String(contentsOf: url, encoding: .utf8)
        } catch {
            print("Warning: Could not read file content for \(url.path): \(error.localizedDescription)")
        }
        
        return KubeConfigFile(
            fileName: url.lastPathComponent,
            filePath: url,
            fileType: fileType,
            yamlContent: yamlContent,
            creationDate: creationDate,
            modificationDate: modificationDate,
            isActive: isActive
        )
    }

    mutating func updateYamlContent(_ newContent: String) {
        self.yamlContent = newContent
        self.status = .unknown 
        self.modificationDate = Date() 
    }

    mutating func markAsInvalid(_ reason: String) {
        self.status = .invalid(reason)
    }
    
    static func == (lhs: KubeConfigFile, rhs: KubeConfigFile) -> Bool {
        return lhs.filePath == rhs.filePath &&
               lhs.fileType == rhs.fileType
    }
} 