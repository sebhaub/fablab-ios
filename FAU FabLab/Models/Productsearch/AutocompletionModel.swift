import Foundation
import CoreData

class AutocompletionModel: NSObject {
    
    private let api = ProductApi()
    private let managedObjectContext : NSManagedObjectContext
    private let coreData = CoreDataHelper(sqliteDocumentName: "CoreDataModel.db", schemaName:"")
    //24 hours, in seconds
    private let refreshInterval : Double = 24*60*60
    
    private var isLoading = false
    
    private var entries : [AutocompleteEntry] {
        get {
            let request = NSFetchRequest(entityName: AutocompleteEntry.EntityName)
            return (try! managedObjectContext.executeFetchRequest(request)) as! [AutocompleteEntry]
        }
    }
    
    override init(){
        self.managedObjectContext = coreData.createManagedObjectContext()
        super.init()
    }
    
    private func saveCoreData() {
        var error : NSError?
        do {
            try self.managedObjectContext.save()
        } catch let error1 as NSError {
            error = error1
            Debug.instance.log("Error saving: \(error!)")
        }
    }
    
    func fetchEntries() {
        if(!isLoading && entries.isEmpty || Double(NSDate().timeIntervalSinceDate(entries[0].date)) >= refreshInterval) {
            self.isLoading = true
            api.getAutoCompletions({ autocompletions, err in
                if(err == nil){
                    if let completions = autocompletions{
                        self.addEntries(completions)
                    }
                }
                self.isLoading = false
            })
        }
    }
    
    private func addEntries(words: [String]) {
        removeEntries()
        for word in words {
            let entry = NSEntityDescription.insertNewObjectForEntityForName(AutocompleteEntry.EntityName,
                inManagedObjectContext: self.managedObjectContext) as! AutocompleteEntry
            entry.word = word
            entry.date = NSDate()
        }
        saveCoreData()
    }
    
    func removeEntries() {
        for entry in entries {
            managedObjectContext.deleteObject(entry)
        }
    }
    
    func getCount() -> Int {
        return entries.count
    }
    
    func getEntries() -> [String] {
        var words = [String]()
        for entry in entries {
            words.append(entry.word)
        }
        //sort suggestions alphabetically
        words.sortInPlace({$0 < $1})
        return words
    }
    
    func getEntriesWithSubstring(substring: String) -> [String] {
        var words = [String]()
        let options = NSStringCompareOptions.CaseInsensitiveSearch
        for entry in entries {
            let substringRange: NSRange! = (entry.word as NSString).rangeOfString(substring, options: options)
            if (substringRange.location != NSNotFound) {
                words.append(entry.word)
            }
        }
        //sort suggestions alphabetically
        words.sortInPlace({$0 < $1})
        return words
    }
    
}