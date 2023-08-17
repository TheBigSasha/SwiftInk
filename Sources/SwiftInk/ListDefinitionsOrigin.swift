import Foundation

public class ListDefinitionsOrigin {
    public var lists: [ListDefinition] {
        var listOfLists: [ListDefinition] = []
        for namedList in _lists {
            listOfLists.append(namedList.value)
        }
        return listOfLists
    }
    
    public init(_ lists: [ListDefinition]) {
        _lists = [:]
        _allUnambiguousListValueCache = [:]
        
        for list in lists {
            _lists[list.name] = list
            
            for itemWithValue in list.items {
                var item = itemWithValue.key
                var val = itemWithValue.value
                var listValue = ListValue(item, val)
                
                // May be ambiguous, but compiler should've caught that,
                // so we may be doing some replacement here, but that's okay.
                if item.itemName != nil {
                    _allUnambiguousListValueCache[item.itemName!] = listValue
                }
                _allUnambiguousListValueCache[item.fullName] = listValue
            }
        }
    }
    
    public func TryListGetDefinition(_ name: String) -> ListDefinition? {
        _lists[name]
    }
    
    public func FindSingleItemListWithName(_ name: String) -> ListValue? {
        _allUnambiguousListValueCache[name]
    }
    
    var _lists: [String: ListDefinition] = [:]
    var _allUnambiguousListValueCache: [String: ListValue] = [:]
}
