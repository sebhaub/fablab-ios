
import Foundation
import UIKit
import MarkdownTextView

class CreateProjectsViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    @IBOutlet var titleText: UITextField!
    @IBOutlet var descText: UITextField!
    @IBOutlet var viewInScrollView: UIView!
    
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    
    var textView : MarkdownTextView?
    var projectId : Int?
    var markdownText : String?
    
    let projectsModel = ProjectsModel.sharedInstance
    
    func configure(projectId projectId: Int) {
        self.projectId = projectId
        self.markdownText = "_Enter Markdown-Text_"
    }
    
    func configure(projectId projectId: Int, cart: Cart) {
        configure(projectId: projectId)
        self.markdownText = getCartAsMDString(cart)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        let attributes = MarkdownAttributes()
        let textStorage = MarkdownTextStorage(attributes: attributes)
        var error: NSError?
        do {
            let linkHighlighter = try LinkHighlighter()
            textStorage.addHighlighter(linkHighlighter)
        } catch let error1 as NSError {
            error = error1
            assertionFailure("Error initializing LinkHighlighter: \(error)")
        }
        textStorage.addHighlighter(MarkdownStrikethroughHighlighter())
        textStorage.addHighlighter(MarkdownSuperscriptHighlighter())
        if let codeBlockAttributes = attributes.codeBlockAttributes {
            textStorage.addHighlighter(MarkdownFencedCodeHighlighter(attributes: codeBlockAttributes))
        }
        
        textView = MarkdownTextView(frame: CGRectZero, textStorage: textStorage)
        // hide autocorrection
        textView!.autocorrectionType = UITextAutocorrectionType.No
        textView!.translatesAutoresizingMaskIntoConstraints = false
        
        if self.projectId >= 0 {
            self.title = "Projekt bearbeiten".localized
            
            let selectedProject = projectsModel.getProject(self.projectId!)
            titleText.text = selectedProject.filename
            descText.text = selectedProject.descr
            textView!.text = selectedProject.content
        } else {
            self.title = "Projekt hinzufügen".localized
            textView!.text = self.markdownText
        }
        
        viewInScrollView.addSubview(textView!)
        
        let views = ["textView": textView!]
        var constraints = NSLayoutConstraint.constraintsWithVisualFormat("V:|-10-[textView]-10-|", options: [], metrics: nil, views: views)
        constraints += NSLayoutConstraint.constraintsWithVisualFormat("H:|-10-[textView]-10-|", options: [], metrics: nil, views: views)
        NSLayoutConstraint.activateConstraints(constraints)
        
        // Keyboard-Customization
        let toolBar = UIToolbar(frame: CGRect(x: 0.0, y: 0.0, width: 100.0, height: 44.0))
        toolBar.items = [
            UIBarButtonItem(title: "H1", style: UIBarButtonItemStyle.Plain, target: self, action: "addText:"),
            UIBarButtonItem(title: "H2", style: UIBarButtonItemStyle.Plain, target: self, action: "addText:"),
            UIBarButtonItem(title: "H3", style: UIBarButtonItemStyle.Plain, target: self, action: "addText:"),
            UIBarButtonItem(title: "B", style: UIBarButtonItemStyle.Plain, target: self, action: "addText:"),
            UIBarButtonItem(title: "I", style: UIBarButtonItemStyle.Plain, target: self, action: "addText:"),
            UIBarButtonItem(title: "Url", style: UIBarButtonItemStyle.Plain, target: self, action: "addText:"),
            UIBarButtonItem(title: "Img", style: UIBarButtonItemStyle.Plain, target: self, action: "addImage"),
            UIBarButtonItem(title: "*", style: UIBarButtonItemStyle.Plain, target: self, action: "addText:"),
            UIBarButtonItem(title: ">", style: UIBarButtonItemStyle.Plain, target: self, action: "addText:"),
            UIBarButtonItem(title: "^", style: UIBarButtonItemStyle.Plain, target: self, action: "addText:"),
            UIBarButtonItem(title: "~", style: UIBarButtonItemStyle.Plain, target: self, action: "addText:"),
            UIBarButtonItem(title: "`", style: UIBarButtonItemStyle.Plain, target: self, action: "addText:"),
            UIBarButtonItem(title: "Code", style: UIBarButtonItemStyle.Plain, target: self, action: "addText:"),
        ]
        
        textView!.inputAccessoryView = toolBar
    }
    
    func addText(sender: UIBarButtonItem) {
        if sender.title == "H1" {
            self.textView!.insertText("#")
        } else if sender.title == "H2" {
            self.textView!.insertText("##")
        } else if sender.title == "H3" {
            self.textView!.insertText("###")
        } else if sender.title == "B" {
            self.textView!.insertText("**")
        } else if sender.title == "I" {
            self.textView!.insertText("_")
        } else if sender.title == "Code" {
            self.textView!.insertText("```")
        } else if sender.title == "URL" {
            self.textView!.insertText("[title](http://)")
        } else {
            self.textView!.insertText(sender.title!)
        }
    }
    
    func addImage() {
        
        if self.projectId < 0 {
            // if the project has no (gist-)id yet, then save it CoreData first and then ask to upload the project
            self.saveProjectToCoreData();
            self.confirmUploadToGitHub(message: "Bitte laden Sie zuerst das Project auf GitHub hoch und versuchen dann erneut den Bild-Upload".localized);
        } else {
            self.showChoosePickerSourceAlert()
        }
    }
    
    func showChoosePickerSourceAlert() {
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Abbrechen".localized, style: .Cancel, handler: { (Void) -> Void in })
        
        let cameraAction: UIAlertAction = UIAlertAction(title: "Kamera".localized, style: .Default, handler: { (Void) -> Void in self.presentImagePickerController(sourceType: UIImagePickerControllerSourceType.Camera)})
        
        let galleryAction: UIAlertAction = UIAlertAction(title: "Galerie".localized, style: .Default, handler: { (Void) -> Void in self.presentImagePickerController(sourceType: UIImagePickerControllerSourceType.PhotoLibrary)})
        
        let alertController: UIAlertController = UIAlertController(title: "Bild auswählen".localized, message: "", preferredStyle: .Alert)
        alertController.addAction(cancelAction)
        alertController.addAction(cameraAction)
        alertController.addAction(galleryAction)
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func presentImagePickerController(sourceType sourceType: UIImagePickerControllerSourceType) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.allowsEditing = false
        imagePicker.sourceType = sourceType
        
        self.presentViewController(imagePicker, animated: true, completion: nil)
    }
    
    // MARK: - UIImagePickerControllerDelegate
    func imagePickerController(picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : AnyObject]) {
        if let pickedImage = info[UIImagePickerControllerOriginalImage] as? UIImage {

            self.dismissViewControllerAnimated(true, completion: { () -> Void in self.confirmImageUploadToGitHub(pickedImage)})
        }
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(picker: UIImagePickerController) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
    
    func navigationController(navigationController: UINavigationController, willShowViewController viewController: UIViewController, animated: Bool) {
        // needed to change the status-bar color in the picker view to white
        UIApplication.sharedApplication().setStatusBarStyle(UIStatusBarStyle.LightContent, animated: false)
    }
    
    @IBAction func showActionSheet(sender: AnyObject) {
        let optionMenu = UIAlertController(title: nil, message: nil, preferredStyle: .ActionSheet)
        
        let saveAction = UIAlertAction(title: "Projekt-Snippet speichern".localized, style: .Default, handler: {
            (alert: UIAlertAction) -> Void in
            self.saveProjectToCoreData()
        })
        
        let uploadAction = UIAlertAction(title: "Upload zu GitHub".localized, style: .Default, handler: {
            (alert: UIAlertAction) -> Void in
            self.saveProjectToCoreData()
            self.confirmUploadToGitHub(message: "Um Ihr Projekt auf Github hochzuladen, müssen Sie der CC0-Lizenz für sämtliche Inhalte zustimmen".localized)
        })
        
        let cancelAction = UIAlertAction(title: "Abbrechen".localized, style: .Cancel, handler: {
            (alert: UIAlertAction) -> Void in
        })
        
        optionMenu.addAction(saveAction)
        optionMenu.addAction(uploadAction)
        optionMenu.addAction(cancelAction)
        
        self.presentViewController(optionMenu, animated: true, completion: nil)
    }
    
    func saveProjectToCoreData() {
        if self.projectId >= 0 {
            self.projectsModel.updateProject(id: self.projectId!, description: self.descText.text!, filename: self.titleText.text!, content: self.textView!.text)
        } else {
            let proj = self.projectsModel.addProject(description: self.descText.text!, filename: self.titleText.text!, content: self.textView!.text, gistId: "")
            self.projectId = self.projectsModel.getIdForProject(proj)
        }
    }
    
    func confirmUploadToGitHub(message message: String) {
        let cancelAction: UIAlertAction = UIAlertAction(title: "Ablehnen".localized, style: .Cancel, handler: { (Void) -> Void in })
        
        let licenseAction = UIAlertAction(title: "Lizenz ansehen".localized, style: .Default, handler: {
            (alert: UIAlertAction) -> Void in
            if let url = NSURL(string: "https://creativecommons.org/publicdomain/zero/1.0/") {
                UIApplication.sharedApplication().openURL(url)
            }
        })
        
        let doneAction: UIAlertAction = UIAlertAction(title: "Zustimmen und hochladen".localized, style: .Default, handler: { (Void) -> Void in self.uploadProjectActionHandler()})
        
        let alertController: UIAlertController = UIAlertController(title: "Upload zu GitHub".localized, message: message, preferredStyle: .Alert)
        alertController.addAction(cancelAction)
        alertController.addAction(licenseAction)
        alertController.addAction(doneAction)
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func confirmImageUploadToGitHub(image: UIImage) {
        
        var inputTextField: UITextField?
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Ablehnen".localized, style: .Cancel, handler: { (Void) -> Void in })
        
        let licenseAction = UIAlertAction(title: "Lizenz ansehen".localized, style: .Default, handler: {
            (alert: UIAlertAction) -> Void in
            if let url = NSURL(string: "https://creativecommons.org/publicdomain/zero/1.0/") {
                UIApplication.sharedApplication().openURL(url)
            }
        })
        
        let doneAction: UIAlertAction = UIAlertAction(title: "Zustimmen und hochladen".localized, style: .Default, handler: { (Void) -> Void in self.uploadImageActionHandler(name: inputTextField!.text!, image: image)})
        
        let alertController: UIAlertController = UIAlertController(title: "Upload zu GitHub".localized, message: "Wollen Sie das Bild wirklich unter der CC0-Lizenz hochladen?".localized + "\n" + "Bitte geben Sie einen Namen für das Bild ein".localized + ":", preferredStyle: .Alert)
        alertController.addAction(cancelAction)
        alertController.addAction(licenseAction)
        alertController.addAction(doneAction)
        
        alertController.addTextFieldWithConfigurationHandler({ textField -> Void in
            inputTextField = textField
        })
        
        self.presentViewController(alertController, animated: true, completion: nil)
    }
    
    func uploadProjectActionHandler() {
        let api = ProjectsApi()
        
        let project = ProjectFile()
        project.setFilename(self.titleText.text! + ".md")
        project.setDescription(self.descText.text ?? "")
        project.setContent(self.textView!.text)
        
        let currGistId = self.projectsModel.getGistId(self.projectId!)
        
        if currGistId == "" {
            api.create(project, onCompletion: {
                gistId, err in
                
                // the project has a gist-id now -> save it!
                self.projectsModel.updateGistId(id: self.projectId!, gistId: gistId!)
                
                self.showUploadAlertController(gistId!, err: err)
            })
        } else {
            api.update(currGistId, project: project, onCompletion: {
                gistId, err in
                self.showUploadAlertController(gistId!, err: err)
            })
        }
    }
    
    func uploadImageActionHandler(name name: String, image: UIImage) {
        let api = ProjectsApi()
        
        if self.projectId >= 0 {
            let currGistId = self.projectsModel.getGistId(self.projectId!)
        
            let imageUpload = ProjectImageUpload()
            imageUpload.setFilename(name+".png")
            imageUpload.setData(UIImagePNGRepresentation(image)!.base64EncodedStringWithOptions([]))
            imageUpload.setRepoId(currGistId)
        
            self.activityIndicator.color = UIColor.fabLabGreen()
            self.activityIndicator.startAnimating()
        
            api.uploadImage(imageUpload, onCompletion: {
                imageLink, err in
            
                self.activityIndicator.stopAnimating()
            
                self.pasteImageLink(imageLink!, err: err)
            })
        }
    }
    
    func showUploadAlertController(gistId: String, err: NSError?) {
        if (err != nil) {
            AlertView.showErrorView("Projekt-Snippet konnte nicht hochgeladen werden".localized)
        } else {
            
            let url = "https://gist.github.com/" + gistId
            
            let doneAction: UIAlertAction = UIAlertAction(title: "OK".localized, style: .Default, handler: { (Void) -> Void in })
            
            let browserAction: UIAlertAction = UIAlertAction(title: "Gist anzeigen".localized, style: .Default, handler: { (Void) -> Void in
                if let nsurl = NSURL(string: url) {
                    UIApplication.sharedApplication().openURL(nsurl)
                }
            })
            
            let alertController: UIAlertController = UIAlertController(title: "Projekt-Snippet wurde erfolgreich hochgeladen".localized, message: "Link".localized + ": " + url, preferredStyle: .Alert)
            alertController.addAction(doneAction)
            alertController.addAction(browserAction)
            
            self.presentViewController(alertController, animated: true, completion: nil)
        }
    }
    
    func pasteImageLink(imageLink: String, err: NSError?) {
        if (err != nil) {
            AlertView.showErrorView("Bild konnte nicht hochgeladen werden".localized)
        } else {
            //insert image to md-view
            self.textView!.insertText("![title](\(imageLink))")
        }
    }
    
    func getCartAsMDString(cart: Cart) -> String {
        var text : String = ""
        text += "#" + "Einkaufliste".localized + "\n"
        for entry in cart.getEntries() {
            text += "* "
            text += String(format: "%." + String(entry.product.rounding.digitsAfterComma) + "f", entry.amount)
            text += " " + entry.product.unit + " " + entry.product.name
            text += "\n"
        }
        text += "\n"
        text += "#" + "Anleitung".localized + "\n"
        return text
    }
}