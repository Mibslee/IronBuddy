//
//  DatabasePath.swift
//  IronBuddy
//

import Foundation

enum AppGroupConfig {
    /// 与 `IronBuddy.entitlements` 中 App Group 一致；未配置或未开通时回退到 Application Support。
    static let identifier = "group.ShaneStudio.IronBuddy"
}

enum DatabasePath {
    static func getSharedContainerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: AppGroupConfig.identifier)
    }

    /// 作业书：优先 App Group 容器下的 `IronBuddy.sqlite`，否则使用 Application Support。
    static func sqliteFileURL() throws -> URL {
        if let container = getSharedContainerURL() {
            return container.appendingPathComponent("IronBuddy.sqlite")
        }
        return try FileManager.default
            .url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            .appendingPathComponent("IronBuddy.sqlite")
    }
}
