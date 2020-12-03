import Foundation
import Fluent

/// Encapsulates the state maintained by clients of FluentKit.
public final class FluentKitContext {
    public let threadPool: NIOThreadPool
    public let eventLoopGroup: EventLoopGroup
    public let logger: Logger
    public let databases: Databases
    public let migrations: Migrations

    public init(eventLoopGroup: EventLoopGroup, logger: Logger = .init(label: "Fluent")) {
        self.threadPool = .init(numberOfThreads: 1)
        self.eventLoopGroup = eventLoopGroup
        self.logger = logger
        self.databases = .init(threadPool: threadPool, on: eventLoopGroup)
        self.migrations = .init()
    }
    deinit {
        self.databases.shutdown()
        try! self.threadPool.syncShutdownGracefully()
    }
    public func use(database factory: DatabaseConfigurationFactory, as id: DatabaseID, isDefault: Bool? = nil) {
        self.databases.use(factory, as: id, isDefault: isDefault)
    }
    public func use(database driver: DatabaseConfiguration, as id: DatabaseID, isDefault: Bool? = nil) { /* snip */ }
    public func add(migration: Migration, to id: DatabaseID? = nil) { self.migrations.add(migration, to: id) }
    public func migrate() -> EventLoopFuture<Void> {
        let migrator = Migrator(databases: self.databases, migrations: self.migrations, logger: self.logger, on: self.eventLoopGroup.next())
        return migrator.setupIfNeeded().flatMap { migrator.prepareBatch() }
    }
    public func revert() -> EventLoopFuture<Void> {
        let migrator = Migrator(databases: self.databases, migrations: self.migrations, logger: self.logger, on: self.eventLoopGroup.next())
        return migrator.revertLastBatch()
    }
}

