import Foundation

class UserDataHelper {
    
    static func parseDictionaryToJSONString(_ dictionary: [String: String]?) -> String {
        guard let dictionary = dictionary else {
            return "null"
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: dictionary, options: [])
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                return jsonString
            }
        } catch {
            print("Error converting dictionary to JSON: \(error)")
        }
        
        return "null" // Return "null" in case of an error
    }
}
