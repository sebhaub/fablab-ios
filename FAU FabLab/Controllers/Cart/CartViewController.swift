import UIKit
import AVFoundation
import RSBarcodes
import CoreActionSheetPicker
import MessageUI

class CartViewController : UIViewController, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate{
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet var labelTotalPrice: UILabel!
    
    private var checkoutButton : UIBarButtonItem {
        return self.navigationItem.rightBarButtonItem!
    }
    private var cartModel = CartModel.sharedInstance
    private var cartEntryCellIdentifier = "ProductCustomCell"
    private let noLocationSetIdentifier = "unknown location"
    private let modelOutOfStock = MalfunctionInfoModel.sharedInstance
    private var productSearchModel = ProductsearchModel()
    
    private var selectedIndexPath: NSIndexPath?
    private var selectedProduct: CartProduct?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "checkoutCodeScanned:", name: "CheckoutScannerNotification", object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "checkoutStatusChanged:", name: "CheckoutStatusChangedNotification", object: nil)
    }
    
    func setCart(cart: Cart) {
        if cart.status == CartStatus.SHOPPING.rawValue {
            cartModel = CartModel.sharedInstance
            return
        }
        cartModel = CartModel(cart: cart)
        if (cartModel.getStatus() == CartStatus.PAID) {
            self.title = "Bezahlt".localized
            let actionBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Action, target: self, action: "actionBarButtonItemClicked")
            self.navigationItem.rightBarButtonItem = actionBarButtonItem
        }
    }
    
    func actionBarButtonItemClicked() {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        
        let replaceAction = UIAlertAction(title: "Warenkorb ersetzen".localized, style: UIAlertActionStyle.Default, handler: {
            (alert: UIAlertAction) -> Void in
            self.cartModel.replace()
        })
        
        let addAction = UIAlertAction(title: "Zum Warenkorb hinzufügen".localized, style: UIAlertActionStyle.Default, handler: {
            (alert: UIAlertAction) -> Void in
            self.cartModel.add()
        })
        
        let cancelAction = UIAlertAction(title: "Abbrechen".localized, style: .Cancel, handler: {
            (alert: UIAlertAction) -> Void in
        })
        
        optionMenu.addAction(replaceAction)
        optionMenu.addAction(addAction)
        optionMenu.addAction(cancelAction)
        
        self.presentViewController(optionMenu, animated: true, completion: nil)
    }
    
    @IBAction func buttonChangeAmountPressed(sender: AnyObject) {
        let cartEntry = self.cartModel.getProductInCart(selectedIndexPath!.row)
        showChangeAmountPicker(cartEntry, initialValue: cartEntry.amount)
    }
    
    func showChangeAmountPicker(cartEntry: CartEntry, initialValue: Double) {
        ChangeAmountPickerHelper.showChangeAmountPicker(cartEntry, initialValue: initialValue, delegateSucceedAction: { (currentAmount: Double) -> Void in
                CartModel.sharedInstance.updateProductInCart(self.selectedIndexPath!.row, amount: Double(currentAmount))
                self.tableView.reloadData();
                self.tableView.setEditing(false, animated: true)
                self.showTotalPrice()
            }, delegateCancelAction: { (Void) -> Void in
                self.tableView.setEditing(false, animated: true)
            }, alertChangeAmountAction: { (currentAmount: Double) -> Void in
                ChangeAmountPickerHelper.alertChangeAmount(viewController: self, cartEntry: cartEntry, currentAmount: currentAmount, pickerCancelActionHandler: { (Void) -> Void in
                        self.showChangeAmountPicker(cartEntry, initialValue: currentAmount)
                    }, pickerDoneActionHandlerFinished: { (amount: Double) -> Void in
                        CartModel.sharedInstance.updateProductInCart(self.selectedIndexPath!.row, amount: amount)
                        self.tableView.reloadData();
                        self.tableView.setEditing(false, animated: true)
                        self.showTotalPrice()
                
                })
        })
    }
    
    @IBAction func buttonReportOutOfStockPressed(sender: AnyObject) {
        modelOutOfStock.fetchFablabMailAddress { () -> Void in
            self.presentViewController(MailComposeHelper.showOutOfStockMailComposeView(delegate: self, recipients: [self.modelOutOfStock.fablabMail!], productId: self.selectedProduct!.id, productName: self.selectedProduct!.name), animated: true, completion: nil)
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        Debug.instance.log(segue.identifier)
        if segue.identifier == "ProductLocationSegueCart" {
            let destination = segue.destinationViewController as? ProductLocationViewController
            
            let locationId = selectedProduct!.locationStringForMap
            let productName = selectedProduct!.name
            
            destination!.configure(id: locationId, name: productName)
        }
    }
    
    private func showTotalPrice(){
        labelTotalPrice.text = String(format: "%.2f€", cartModel.getTotalPrice());
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        showTotalPrice()
    }
    
    override func viewWillAppear(animated: Bool) {
        tableView.reloadData()
        refreshCheckoutButton()
        showTotalPrice()
    }
   
    // we have to unregister all observers!
    override func viewWillDisappear(animated: Bool) {
        for cell in tableView.visibleCells {
            (cell as! ProductCustomCell).ignoreFrameChanges()
        }
    }
    
    func refreshCheckoutButton() {
        if (cartModel.getNumberOfProductsInCart() > 0) {
            checkoutButton.enabled = true
        } else {
            checkoutButton.enabled = false
        }
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return cartModel.getNumberOfProductsInCart()
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCellWithIdentifier(cartEntryCellIdentifier) as? ProductCustomCell
        let cartEntry = cartModel.getProductInCart(indexPath.row)
        let amountValue = (cartEntry.product.rounding % 1 == 0) ? "\(Int(cartEntry.amount))" : "\(cartEntry.amount)"
        cell!.configure(cartEntry.product.name, unit: "\(amountValue) \(cartEntry.product.unit)", price: cartEntry.product.price * cartEntry.amount)
        cell!.selectionStyle = UITableViewCellSelectionStyle.None
        
        if(cartEntry.product.locationStringForMap == noLocationSetIdentifier){
            cell?.disableProductLocationButton()
        }else{
            cell?.enableProductLocationButton()
        }
        
        return cell!;
    }
    
    func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        if (cartModel.getStatus() == CartStatus.SHOPPING) {
            return true
        }
        return false
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if (editingStyle == UITableViewCellEditingStyle.Delete) {
            CartModel.sharedInstance.removeProductFromCart(indexPath.row)
            tableView.reloadData()
            showTotalPrice()
            refreshCheckoutButton()
        }
    }
    
    func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if (tableView == self.tableView) {
            (cell as! ProductCustomCell).watchFrameChanges()
        }
    }
    
    func tableView(tableView: UITableView, didEndDisplayingCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if (tableView == self.tableView) {
            (cell as! ProductCustomCell).ignoreFrameChanges()
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if (cartModel.getStatus() == CartStatus.SHOPPING) {
            let previousIndexPath = selectedIndexPath
            if indexPath == selectedIndexPath {
                selectedIndexPath = nil
            } else {
                selectedIndexPath = indexPath
            }
            var indexPaths : Array<NSIndexPath> = []
            if let previous = previousIndexPath{
                indexPaths += [previous]
            }
            if let current = selectedIndexPath {
                indexPaths += [current]
            }
            if indexPaths.count > 0 {
                tableView.reloadRowsAtIndexPaths(indexPaths, withRowAnimation: UITableViewRowAnimation.Automatic)
            }
            tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Top, animated: true)
            selectedProduct = cartModel.getProductInCart(indexPath.row).product
        }
    }
    
    func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        if (cartModel.getStatus() == CartStatus.SHOPPING && indexPath == selectedIndexPath){
            return ProductCustomCell.expandedHeight
        } else{
            return ProductCustomCell.defaultHeight
        }
    }
    
    /*                      Checkout process            */
    //Observer -> Scanner
    func checkoutCodeScanned(notification:NSNotification) {
        if cartModel.getNumberOfProductsInCart() > 0 {
            cartModel.sendCartToServer(notification.object as! String)
        }else{
            let alert = UIAlertController(title: "Fehler".localized, message: "Keine Produkte im Warenkorb".localized, preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK".localized, style: UIAlertActionStyle.Default, handler: nil))
            self.presentViewController(alert, animated: true, completion: nil)

        }
    }
    
    //Observer -> Status changed
    func checkoutStatusChanged(notification:NSNotification) {
        if let newStatus = CartStatus(rawValue: notification.object as! String) {
            switch(newStatus){
                case CartStatus.SHOPPING:
                    //cart is still @shopping -> error happend -> Code was wrong
                    let alertView = UIAlertView(title: "Fehler".localized, message: "Der gescannte Code wurde nicht akzeptiert. Bitte den Code vom Kassenterminal scannen.".localized, delegate: nil, cancelButtonTitle: "OK".localized)
                    alertView.show()
                
                case CartStatus.PENDING:
                    let payOrCancelViewController = self.storyboard?.instantiateViewControllerWithIdentifier("PayOrCancelView") as! PayOrCancelViewController
                    payOrCancelViewController.setCartModel(cartModel)
                    self.presentViewController(payOrCancelViewController, animated: true, completion: nil)
              
                case CartStatus.PAID:
                    let alertView = UIAlertView(title: "Bezahlt".localized, message: "Ihr Warenkorb wurde erfolgreich bezahlt".localized, delegate: nil, cancelButtonTitle: "OK".localized)
                    alertView.show()
                
                case CartStatus.CANCELLED:
                    let alertView = UIAlertView(title: "Abgebrochen".localized, message: "Bezahlvorgang wurde abgebrochen".localized, delegate: nil, cancelButtonTitle: "OK".localized)
                    alertView.show()
                
                case CartStatus.FAILED:
                    let alertView = UIAlertView(title: "Fehlgeschlagen".localized, message: "Bezahlvorgang ist Fehlgeschlagen".localized, delegate: nil, cancelButtonTitle: "OK".localized)
                    alertView.show()
                
            }
        }
    }
    

    //Gets sure that app has permissions to access the camera.
    
    @IBAction func startCheckout(sender: AnyObject) {
        self.cameraAction()
    }
    
    func cameraAction() {
        
        #if (arch(i386) || arch(x86_64)) && os(iOS)
            //App runs inside a simulator, so no camera functionality
            showTextInputForSimulator()
        #else
            //App runs on real device
            let authStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
            switch authStatus {
                case AVAuthorizationStatus.Authorized:
                    let popoverContent = self.storyboard?.instantiateViewControllerWithIdentifier("CheckoutCodeScanner")
                    let nav = UINavigationController(rootViewController: popoverContent!)
                    nav.modalPresentationStyle = UIModalPresentationStyle.Popover
                  
                    self.presentViewController(nav, animated: true, completion: nil)
            
                case AVAuthorizationStatus.Denied:
                    alertToEncourageCameraAccessInitially()
                case AVAuthorizationStatus.NotDetermined:
                    alertPromptToAllowCameraAccessViaSetting()
                default:
                    alertToEncourageCameraAccessInitially()
            }
        #endif
    }
    
    func alertToEncourageCameraAccessInitially(){
        let alert = UIAlertController(title: "Achtung".localized, message: "Es wird ein Zugriff auf die Kamera benötigt".localized, preferredStyle: UIAlertControllerStyle.Alert)
        
        alert.addAction(UIAlertAction(title: "Abbrechen".localized, style: .Default, handler: { (alert) -> Void in
            dispatch_async(dispatch_get_main_queue()) {
                self.dismissViewControllerAnimated(true, completion:nil)
            }
        }))
        
        alert.addAction(UIAlertAction(title: "Erlauben".localized, style: .Cancel, handler: { (alert) -> Void in
            UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
        }))
        
        self.presentViewController(alert, animated: true, completion: nil)
    }
    
    func alertPromptToAllowCameraAccessViaSetting() {
        let alert = UIAlertController(title: "Achtung".localized, message: "Es wird ein Zugriff auf die Kamera benötigt".localized, preferredStyle: UIAlertControllerStyle.Alert)
        
        alert.addAction(UIAlertAction(title: "Abbrechen".localized, style: .Cancel) { alert in
            if AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo).count > 0 {
                AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo) { granted in
                    dispatch_async(dispatch_get_main_queue()) {
                        self.cameraAction()
                    }
                }
            }
        })
    }
    
}

extension CartViewController : MFMailComposeViewControllerDelegate{
    
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
        dismissViewControllerAnimated(true, completion: nil)
        switch result.rawValue{
        case MFMailComposeResultCancelled.rawValue:
            self.presentViewController(MailComposeHelper.getCancelAlertController(), animated: true, completion: nil)
            
        case MFMailComposeResultSent.rawValue:
            self.presentViewController(MailComposeHelper.getSentAlertController(), animated: true, completion: nil)
            
        default:
            //TODO
            Debug.instance.log("Default")
        }
    }
}

// MARK: Simulator Debug View
extension CartViewController {
    
    func showTextInputForSimulator(){
        var inputTextField : UITextField?
        
        let doneAction: UIAlertAction = UIAlertAction(title: "Okay", style: .Default,
            handler: { (Void) -> Void in
                self.tabBarController?.selectedIndex = 2
                NSNotificationCenter.defaultCenter().postNotificationName("CheckoutScannerNotification", object: inputTextField?.text)
        })
        
        let alertController: UIAlertController = UIAlertController(title: "Warenkorb ID eingeben".localized, message: "Simulator", preferredStyle: .Alert)
        alertController.addTextFieldWithConfigurationHandler({ textField -> Void in
            inputTextField = textField
        })
        alertController.addAction(doneAction)
        presentViewController(alertController, animated: true, completion: nil)
    }
}