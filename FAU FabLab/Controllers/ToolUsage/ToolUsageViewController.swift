import Foundation
import CoreActionSheetPicker

class ToolUsageViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet var tableView: UITableView!
    
    private let toolModel = ToolModel.sharedInstance
    private let toolUsageModel = ToolUsageModel.sharedInstance
    private let buttonCustomCellIdentifier = "ButtonCustomCell"
    private let toolUsageCustomCellIdentifier = "ToolUsageCustomCell"
    private let addToolUsageViewControllerIndentifier = "AddToolUsageViewController"
    private var activityIndicator: UIActivityIndicatorView!
    private var toolId: Int64 = 0
    
    @IBAction func addToolUsage(sender: AnyObject) {
        let addToolUsageViewController = storyboard?.instantiateViewControllerWithIdentifier(addToolUsageViewControllerIndentifier) as! AddToolUsageViewController
        addToolUsageViewController.configure(toolId)
        navigationController?.pushViewController(addToolUsageViewController, animated: true)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        activityIndicator = UIActivityIndicatorView(activityIndicatorStyle: UIActivityIndicatorViewStyle.Gray)
        activityIndicator.center = self.view.center
        activityIndicator.hidesWhenStopped = true
        activityIndicator.autoresizingMask = [UIViewAutoresizing.FlexibleLeftMargin, UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleRightMargin, UIViewAutoresizing.FlexibleTopMargin, UIViewAutoresizing.FlexibleHeight, UIViewAutoresizing.FlexibleBottomMargin]
        view.addSubview(activityIndicator)
        
        startLoading()
        toolModel.fetchTools({
            (error) -> Void in
            if error != nil {
                Debug.instance.log(error)
                return
            }
            self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: UITableViewRowAnimation.None)
            self.stopLoading()
            self.setTool(self.toolId)
        })
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        setTool(self.toolId)
    }

    private func startLoading() {
        tableView.userInteractionEnabled = false
        activityIndicator.startAnimating()
    }
    
    private func stopLoading() {
        tableView.userInteractionEnabled = true
        activityIndicator.stopAnimating()
    }
    
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if section == 0 {
            return "Maschine".localized
        } else {
            if toolUsageModel.getCount() > 0 {
                return "Reservierung".localized
            }
            return ""
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return 1
        }
        return toolUsageModel.getCount()
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.section == 0 {
            let cell = tableView.dequeueReusableCellWithIdentifier(buttonCustomCellIdentifier) as! ButtonCustomCell
            cell.configure(toolModel.getToolName(Int(toolId)), buttonClickedAction: toolButtonClicked)
            return cell
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier(toolUsageCustomCellIdentifier) as! ToolUsageCustomCell
            cell.configure(toolUsageModel.getToolUsage(indexPath.row), startingTime: toolUsageModel.getStartingTimeOfToolUsage(indexPath.row))
            return cell
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath.section == 0 {
            toolButtonClicked()
        }
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if indexPath.section == 0 {
            return false
        }
        
        let toolUsage = toolUsageModel.getToolUsage(indexPath.row)
        if toolUsageModel.isOwnToolUsage(toolUsage.id!) {
            return true
        }
        
        return false
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == UITableViewCellEditingStyle.Delete {
            startLoading()
            toolUsageModel.removeToolUsage(toolUsageModel.getToolUsage(indexPath.row), user: nil, token: UIDevice.currentDevice().identifierForVendor!.UUIDString,
                onCompletion: {
                    (error) -> Void in
                    self.stopLoading()
                    if error != nil {
                        Debug.instance.log(error)
                    }
                    self.tableView.reloadRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.None)
                    self.setTool(self.toolId)
                    
            })
        }
    }
    
    func toolButtonClicked() {
        startLoading()
        toolModel.fetchTools({
            (error) -> Void in
            self.stopLoading()
            if error != nil {
                Debug.instance.log(error)
                return
            }
            self.showToolPicker()
        })
    }
    
    private func showToolPicker() {
        let picker = ActionSheetStringPicker(title: "Maschine wählen".localized, rows: toolModel.getToolNames(), initialSelection: 0,
            doneBlock: {
                picker, index, value in
                Debug.instance.log(index)
                self.toolId = Int64(index)
                self.tableView.reloadRowsAtIndexPaths([NSIndexPath(forRow: 0, inSection: 0)], withRowAnimation: UITableViewRowAnimation.None)
                self.setTool(self.toolId)
                return
            },
            cancelBlock: nil, origin: nil)
        
        let doneButton: UIBarButtonItem = UIBarButtonItem()
        doneButton.title = "Auswählen".localized
        doneButton.tintColor = UIColor.fabLabGreen()
        let cancelButton: UIBarButtonItem = UIBarButtonItem()
        cancelButton.title = "Abbrechen".localized
        cancelButton.tintColor = UIColor.fabLabGreen()
        
        picker.setDoneButton(doneButton)
        picker.setCancelButton(cancelButton)
        picker.tapDismissAction = TapAction.Cancel
        picker.showActionSheetPicker()
    }
    
    private func setTool(toolId: Int64) {
        self.startLoading()
        self.toolUsageModel.fetchToolUsagesForTool(toolId, onCompletion: {
            (error) -> Void in
            self.stopLoading()
            if error != nil {
                Debug.instance.log(error)
                return
            }
            self.tableView.reloadData()
        })
    }
    
}