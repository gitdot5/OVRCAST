import Foundation

/// Display hardware families without exposing a user's computer name in privacy mode.
enum MachineLabels {
    static func family(_ name: String) -> String? {
        let key = name.lowercased().filter { $0.isLetter || $0.isNumber }
        for (needle, label) in [("macbookpro", "MacBook Pro"), ("macbookair", "MacBook Air"),
                                ("macbook", "MacBook"), ("macmini", "Mac mini"),
                                ("macstudio", "Mac Studio"), ("imac", "iMac"), ("macpro", "Mac Pro")] {
            if key.contains(needle) { return label }
        }
        return ["mini": "Mac mini", "studio": "Mac Studio"][key]
    }
    static func hardwareFamily(_ data: Data) -> String? {
        guard let report = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let rows = report["SPHardwareDataType"] as? [[String: Any]],
              let model = rows.first?["machine_name"] as? String else { return nil }
        return family(model)
    }
    static let localFamily: String? = {
        guard let output = try? CommandRunner.run("/usr/sbin/system_profiler", ["SPHardwareDataType", "-json"], timeout: 5), output.code == 0 else { return nil }
        // Keep only the model family; no serial number, hostname or other hardware field is saved.
        return hardwareFamily(output.data)
    }()
    static func label(_ machine: String, machines: [String], privacy: Bool, localMachine: String? = nil, localFamily: String? = nil) -> String {
        func model(_ name: String) -> String? { name == localMachine ? localFamily ?? family(name) : family(name) }
        let type = model(machine)
        if !privacy {
            let standard = ["thismac", "macbook", "mini", "studio"].contains(machine.lowercased().filter { !$0.isWhitespace })
            return standard ? type ?? machine : machine
        }
        let base = type ?? "Mac"
        let peers = Array(Set(machines + [machine])).filter { (model($0) ?? "Mac") == base }.sorted()
        return peers.count > 1 ? "\(base) \((peers.firstIndex(of: machine) ?? 0) + 1)" : base
    }
    static func symbol(_ type: String) -> String {
        switch family(type) {
        case "MacBook", "MacBook Air", "MacBook Pro": return "laptopcomputer"
        case "Mac mini": return "macmini"
        case "Mac Studio": return "macstudio"
        case "Mac Pro": return "macpro.gen3"
        default: return "desktopcomputer"
        }
    }
}
