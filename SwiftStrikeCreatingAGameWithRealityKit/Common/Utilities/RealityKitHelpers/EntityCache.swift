/*
See LICENSE folder for this sample’s licensing information.

Abstract:
EntityCache
*/

import os.log
import RealityKit

typealias EntityCachePredicate = (Entity) -> Bool

typealias EntityCacheId = UInt64
private var enityCacheUniqueId: EntityCacheId = 1
private func nextEntityCacheUniqueId() -> EntityCacheId {
    let id = enityCacheUniqueId
    enityCacheUniqueId += 1
    return id
}

/// EnityCacheUniquePredicate
/// This predicate is used as a closure to filter the returned Entity
/// list by arbitrary logic in the caller.
/// Each predicate is required to have a unique id in order for the cache
/// to properly cache and return values from that predicate.
struct EntityCacheUniquePredicate<T> where T: Entity {
    let id: EntityCacheId = nextEntityCacheUniqueId()
    fileprivate let closure: EntityCachePredicate
    init(_ closure: @escaping EntityCachePredicate) {
        self.closure = closure
    }
}

extension GameLog {
    static let entityCache = OSLog(subsystem: subsystem, category: "entitycache")
}

extension Entity {

    func processHierarchy(_ task: (Entity) -> Void) {
        task(self)
        for child in children {
            child.processHierarchy(task)
        }
    }

}

///
/// WeakReference
/// useful generic wrapper for any type to be stored as a weak reference (mostly used in array storage)
struct WeakReference<T> where T: AnyObject {
    private(set) weak var value: T?
    init(_ value: T?) {
        self.value = value
    }
}

///
/// EntityCache
/// The purpose of this class is to provide an optimization to Entity lookups in the Scene by Enitty type, Component type,
/// and/or predicate method (which can include any logic to filter the Entities).
/// The cache creates "cache lines" based on the caller parameter set such that all entityList calls with only
/// an Entity type will return the same set of Entities when called from anywhere in the app give the same Entity type.
/// Likewise for Component type or predicate.  This includes the combinations of those three, such that each search
/// for Entities is uniquely identified and the results cached.  Any search may set the forceRefresh to clear the cache
/// for that search and force a fresh search of the Scene.  Of course the use of this flag for every search would
/// nullify the optimization made availablie by the cache.
/// Since this system only holds weak references, it can reduce its cache by removing Entities that have been
/// removed from the Scene.
class EntityCache {

    ///
    /// CacheKey
    /// made from two strings:  one based on the Entity sub-class one as the predicate string to help differentiate different lists of the same
    /// Entity sub-class that may have been created using different match criteria
    struct CacheKey: Hashable {
        private let typeName: String
        private let key: String
        init(typeName: String, key: String) {
            self.typeName = typeName
            self.key = key
        }
    }

    class EntityListStorage {
        private var cacheKey: CacheKey
        fileprivate var list: [WeakReference<Entity>]
        fileprivate var timesCompacted: Int

        init(_ cacheKey: CacheKey) {
            self.cacheKey = cacheKey
            list = [WeakReference<Entity>]()
            timesCompacted = 0
        }

        func reset() {
            list = [WeakReference<Entity>]()
            timesCompacted = 0
        }

        func add(_ entity: Entity) {
            list.append(WeakReference(entity))
        }

        func compact() {
            os_log(.default, log: GameLog.entityCache, "cache %s - Compacting...", "\(cacheKey)")
            list = list.compactMap { weakReference in
                return weakReference.value != nil ? weakReference : nil
            }
            timesCompacted += 1
            if list.isEmpty {
                os_log(.default, log: GameLog.entityCache, "cache %s is empty.", "\(cacheKey)")
            }
        }

        func dump() {
            os_log(.default, log: GameLog.entityCache, "    key=%s, count=%s, compacted=%s", "\(cacheKey)", "\(list.count)", "\(timesCompacted)")
        }
    }

    //
    // instance vars
    //
    private weak var scene: Scene?
    private var cache: [CacheKey: EntityListStorage] = [:]

    private var misses: Int
    private var hits: Int

    init(_ scene: Scene) {
        self.scene = scene
        self.cache = [:]
        self.misses = 0
        self.hits = 0
        reset()
    }

    func reset() {
        cache = [:]
        misses = 0
        hits = 0
    }

    func forEachEntity(where predicate: (Entity) -> Void) {
        guard let scene = scene else {
            assertionFailure("EntityCache scene has not been created or has been destroyed")
            return
        }

        scene.anchors.forEach {
            $0.processHierarchy { predicate($0) }
        }
    }

    /// entityList() - only a predicate required
    func entityList(forceRefresh: Bool = false,
                    where predicate: EntityCacheUniquePredicate<Entity>
    ) -> [Entity] {
        return cachedEntityList(forceRefresh: forceRefresh, where: predicate)
    }

    /// entityList() - only an Entity type required, predicate optional
    func entityList<EntityType: Entity>(entityType: EntityType.Type,
                                        forceRefresh: Bool = false,
                                        where predicate: EntityCacheUniquePredicate<EntityType>? = nil
    ) -> [EntityType] {
        return cachedEntityList(entityType: entityType, forceRefresh: forceRefresh, where: predicate)
    }

    /// entityList() - only a Component type required, predicate optional
    func entityList(componentType: Component.Type,
                    forceRefresh: Bool = false,
                    where predicate: EntityCacheUniquePredicate<Entity>? = nil
    ) -> [Entity] {
        return cachedEntityList(componentType: componentType, forceRefresh: forceRefresh, where: predicate)
    }

    /// entityList() - Entity type and Component type required, predicate optional
    func entityList<EntityType: Entity>(entityType: EntityType.Type,
                                        componentType: Component.Type,
                                        forceRefresh: Bool = false,
                                        where predicate: EntityCacheUniquePredicate<EntityType>? = nil
    ) -> [EntityType] {
        return cachedEntityList(entityType: entityType, componentType: componentType, forceRefresh: forceRefresh, where: predicate)
    }

    private func cachedEntityList<EntityType: Entity>(entityType: EntityType.Type? = nil,
                                                      componentType: Component.Type? = nil,
                                                      forceRefresh: Bool = false,
                                                      where predicate: EntityCacheUniquePredicate<EntityType>? = nil
    ) -> [EntityType] {
        guard let scene = self.scene else {
            assertionFailure("EntityCache scene has not been created or has been destroyed")
            return []
        }
        guard entityType != nil || componentType != nil || predicate != nil else {
            assertionFailure("EntityCache requires one of Entity type, Component type, or unique predicate wrapper to create a cache key")
            return []
        }

        let typeString = entityType.map { "\($0)" } ?? componentType.map { "\($0)" } ?? "<notype>"
        let keyString = predicate.map { "\($0.id)" } ?? ""
        let cacheKey = CacheKey(typeName: typeString, key: keyString)
        var listStorage = cache[cacheKey]
        if listStorage == nil {
            listStorage = EntityListStorage(cacheKey)
            cache[cacheKey] = listStorage
        }
        guard let storage = listStorage else {
            assertionFailure(String(format: "allocation failed for EntityCache list storage for %s", "\(cacheKey)"))
            return []
        }

        if forceRefresh {
            storage.reset()
        }

        if storage.list.isEmpty {
            misses += 1
            scene.anchors.forEach {
                $0.processHierarchy {
                    guard let entity = $0 as? EntityType,
                    (componentType == nil || entity.components[componentType!] != nil),
                    (predicate == nil || predicate!.closure(entity)) else { return }

                    storage.add(entity)
                }
            }
        } else {
            hits += 1
        }

        // setup compacted array of EntityType entities
        let entities: [EntityType] = storage.list.compactMap {
            return $0.value as? EntityType
        }

        // When we receive a compacted map that's smaller in size than the
        // cached list, that means some entities have been destroyed, so
        // compacting the map is necessary.
        if entities.count != storage.list.count {
            storage.compact()
        }
        return entities
    }

    func dump() {
        os_log(.default, log: GameLog.entityCache, "EntityCache Stats: cache lines: %s, cache misses: %s, cache hits: %s",
               "\(cache.count)", "\(misses)", "\(hits)")
        cache.forEach { (_, storage) in
            storage.dump()
        }
    }

}
