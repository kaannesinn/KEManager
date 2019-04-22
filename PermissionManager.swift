//
//  PermissionManager.swift
//  BaseiOS
//
//  Created by Kaan Esin on 26.02.2019.
//  Copyright © 2019 Kaan Esin. All rights reserved.
//

import UIKit
import AVFoundation
import CNPPopupController
import Photos
import MobileCoreServices
import UserNotifications
import Speech
import Contacts
import ContactsUI

class PermissionManager: NSObject, SFSpeechRecognizerDelegate, AVSpeechSynthesizerDelegate {
    static let shared = PermissionManager()

    let Settings_Frame = (Constants().IS_IPAD || Constants().IS_DEVICE_MODEL_IPAD) ? CGRect(x: 0, y:0, width: UIScreen.main.bounds.size.width * 367/414.0, height: UIScreen.main.bounds.size.height * 550/736.0) : CGRect(x: 0, y: 0, width: UIScreen.main.bounds.size.width * 367/414.0, height: UIScreen.main.bounds.size.height * 419/736.0)

    var captureSession:AVCaptureSession? = nil
    var videoPreviewLayer:AVCaptureVideoPreviewLayer? = nil
    var videoDevice:AVCaptureDevice? = nil
    var videoDeviceInput:AVCaptureDeviceInput? = nil
    var videoDeviceOutput:AVCapturePhotoOutput? = nil
    var videoConnection:AVCaptureConnection? = nil
    var videoSettings:AVCapturePhotoSettings? = nil
    var customPopup : CNPPopupController?
    var cameravc: CameraVC? = nil
    
    var audioEngine: AVAudioEngine?
    var speechRecognizer: SFSpeechRecognizer?
    var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    var recognitionTask: SFSpeechRecognitionTask?
    var btnMic: UIButton?
    var senderVC: UIViewController?
    
    var speechSynthesizer: AVSpeechSynthesizer?
    var totalUtterances: Int = 0
    var currentUtterance: Int = 0
    var totalTextLength: Int = 0
    var spokenTextLengths: Int = 0
    var btnVoiceForSource: UIButton?
    var btnVoiceForTarget: UIButton?
    var targetKey: String? = ""
    var micvc: MicrophoneVC? = nil

    var contactvc: ContactsVC? = nil

    var locationvc: LocationVC? = nil

    //MARK: - camera
    
    func statusForCameraPermission() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    func getCameraPermission(vc: CameraVC?) {
        cameravc = vc
        
        var isRestricted:Bool = false
        
        let authStatus:AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch authStatus {
        case .authorized:
            isRestricted = false
            break
        case .denied:
            isRestricted = true
            break
        case .restricted:
            isRestricted = true
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { (granted: Bool) in
                DispatchQueue.main.async {
                    if granted {
                        isRestricted = false
                        self.startCamera()
                    }
                    else {
                        isRestricted = true
                        self.showSettingsForCameraPermission()
                    }
                }
            }
            break
        default:
            isRestricted = true
            break
        }
        
        if isRestricted {
            self.showSettingsForCameraPermission()
        }
        else {
            startCamera()
        }
    }
    
    func startCamera() {
        cameravc?.closeFlash()
                
        cameravc?.btnCameraFlash.isHidden = (Constants().IS_IPAD || Constants().IS_DEVICE_MODEL_IPAD) ? true : false
        if videoDevice != nil {
            cameravc?.btnCameraFlash.isHidden = (!(videoDevice?.hasFlash ?? true) || !(videoDevice?.hasTorch ?? true)) ? true : false
        }
        
        if videoDevice == nil {
            do {
                videoDevice = AVCaptureDevice.default(for: .video)
                if videoDevice != nil {
                    try videoDeviceInput = AVCaptureDeviceInput.init(device: videoDevice!)
                    captureSession = AVCaptureSession()
                    videoPreviewLayer = AVCaptureVideoPreviewLayer.init(session: captureSession!)
                    videoDeviceOutput = AVCapturePhotoOutput()
                    
                    if Constants().SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v: "11.4.0") {
                        captureSession = AVCaptureSession()
                    }
                    captureSession?.sessionPreset = AVCaptureSession.Preset.high
                    
                    if  Constants().SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v: "11.4.0") {
                        videoPreviewLayer = AVCaptureVideoPreviewLayer.init(session: captureSession!)
                    }
                    videoPreviewLayer?.videoGravity = .resizeAspectFill
                    videoPreviewLayer?.frame = cameravc?.imgPhoto.layer.bounds ?? CGRect.zero
                    
                    if cameravc?.pinchRecognizer == nil {
                        cameravc?.pinchRecognizer = UIPinchGestureRecognizer(target: cameravc, action: #selector(cameravc?.handlePinchToZoomRecognizer(pinchRecognizer:)))
                        cameravc?.imgPhoto.removeGestureRecognizer((cameravc?.pinchRecognizer)!)
                        cameravc?.imgPhoto.addGestureRecognizer((cameravc?.pinchRecognizer)!)
                    }

                    if cameravc?.tapRecognizer == nil {
                        cameravc?.tapRecognizer = UITapGestureRecognizer(target: cameravc, action: #selector(cameravc?.handleTapRecognizer(tapRecognizer:)))
                        cameravc?.imgPhoto.removeGestureRecognizer((cameravc?.tapRecognizer)!)
                        cameravc?.imgPhoto.addGestureRecognizer((cameravc?.tapRecognizer)!)
                    }
                    
                    cameravc?.imgPhoto.contentMode = .scaleAspectFill
                    cameravc?.imgPhoto.isUserInteractionEnabled = true

                    if cameravc?.focusImageView != nil {
                        cameravc?.focusImageView?.removeFromSuperview()
                    }

                    cameravc?.imgPhoto.layer.addSublayer(videoPreviewLayer!)

                    cameravc?.showCropperOnScreen()
                    
                    if captureSession?.canAddInput(videoDeviceInput!) ?? false {
                        captureSession?.beginConfiguration()
                        captureSession?.addInput(videoDeviceInput!)
                        captureSession?.commitConfiguration()
                        captureSession?.startRunning()
                        
                        if !(videoDevice?.hasFlash ?? true) || !(videoDevice?.hasTorch ?? true) {
                            cameravc?.btnCameraFlash.isHidden = true
                        }
                        
                        if captureSession?.canAddOutput(videoDeviceOutput!) ?? false{
                            captureSession?.beginConfiguration()
                            captureSession?.addOutput(videoDeviceOutput!)
                            captureSession?.commitConfiguration()
                            captureSession?.startRunning()
                            
                            videoConnection = nil;
                            for connection in videoDeviceOutput?.connections ?? [] {
                                for port in connection.inputPorts {
                                    if port.mediaType == .video {
                                        videoConnection = connection
                                        break
                                    }
                                }
                                if videoConnection != nil {
                                    if !(captureSession?.isRunning ?? true) {
                                        captureSession?.startRunning()
                                    }
                                    break
                                }
                            }
                        }
                        else {
                            AppUtils.shared.NSLogDebug(msg: "cant add outpur")
                        }
                    }
                    else {
                        AppUtils.shared.NSLogDebug(msg: "cant add input")
                    }
                }
            }
            catch {
                print(error)
                return
            }
        }
        
        cameravc?.btnCameraFlash.isHidden = cameravc?.btnSwapCamera.isSelected ?? false
        
        self.videoPreviewLayer?.isHidden = false
    }
    
    func stopCamera() {
        cameravc?.closeFlash()
        
        captureSession?.stopRunning()
        videoPreviewLayer?.removeFromSuperlayer()
        //        videoPreviewLayer = nil
        //        videoSettings = nil
        //        videoConnection = nil
        //        videoDeviceInput = nil
        //        videoDeviceOutput = nil
        videoDevice = nil
        
        cameravc?.imgPhoto.image = nil
        
        if let arr = cameravc?.imgPhoto.layer.sublayers {
            var layers:[CALayer] = arr
            for layer in arr {
                if layer.isKind(of: AVCaptureVideoPreviewLayer.self) {
                    if let index = layers.firstIndex(of: layer) {
                        layers.remove(at: index)
                    }
                }
            }
            cameravc?.imgPhoto.layer.sublayers = layers
        }
    }
    
    //MARK: - gallery
    func statusForGalleryPermission() -> PHAuthorizationStatus {
        return PHPhotoLibrary.authorizationStatus()
    }
    
    func getGalleryPermission() {
        let status:PHAuthorizationStatus = PHPhotoLibrary.authorizationStatus()
        if status == .authorized {
            showGallery()
        }
        else if status != .notDetermined {
            showSettingsForGalleryPermission()
        }
        else {
            PHPhotoLibrary.requestAuthorization { (status: PHAuthorizationStatus) in
                DispatchQueue.main.async {
                    switch status {
                    case .authorized:
                        self.showGallery()
                        break
                    case .denied:
                        self.showSettingsForGalleryPermission()
                        break
                    case .restricted:
                        self.showSettingsForGalleryPermission()
                        break
                    default:
                        break
                    }
                }
            }
        }
    }
    
    func showGallery() {
        AppUtils.shared.showCustomLoading()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            OperationQueue.main.addOperation({
                DispatchQueue.main.async {
                    if UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) {
                        let imagePickerController:UIImagePickerController = UIImagePickerController()
                        imagePickerController.delegate = self.cameravc
                        imagePickerController.sourceType = .savedPhotosAlbum
                        imagePickerController.allowsEditing = false
                        imagePickerController.mediaTypes = [kUTTypeImage as String]
                        self.cameravc?.navigationController?.present(imagePickerController, animated: true, completion: {
                            DispatchQueue.main.async {
                                AppUtils.shared.hideCustomLoading()
                            }
                        })
                    }
                }
            })
        }
    }
    
    //MARK:- push notification
    func getPushPermission() {
        UNUserNotificationCenter.current().delegate = AppUtils.shared.App_Delegate
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { (granted, error) in
            if error == nil && granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func showPushNotificationPermissionPopupView() {
        if AppUtils.shared.App_Delegate?.window?.rootViewController?.presentedViewController is LandingVC  {
            return
        }
        
        UNUserNotificationCenter.current().delegate = AppUtils.shared.App_Delegate
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { (granted, error) in
            if error == nil && granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            else {
                DispatchQueue.main.async {
                    let userDefGranted = AppUtils.shared.userDefsPlistGetObjectForKey(forKey: Constants().ud_UserNotificationIsPermitted)
                    if userDefGranted as? Int == Constants().Tag_NotificationUndetermined {
                        AppUtils.shared.userDefsPlistSetObject(object: Constants().Tag_NotificationDenied, forKey:  Constants().ud_UserNotificationIsPermitted)
                    }
                    else if userDefGranted as? Int == Constants().Tag_NotificationDenied || !granted {
                        AppUtils.shared.userDefsPlistSetObject(object: Constants().Tag_NotificationDenied, forKey:  Constants().ud_UserNotificationIsPermitted)
                        if AppUtils.shared.App_Delegate?.window?.rootViewController?.isKind(of: MainNavigationVC.self) ?? false {
                            self.showSettingsForPushNotificationPermission()
                        }
                    }
                    
                    let main = AppUtils.shared.App_Delegate?.window?.rootViewController as? MainNavigationVC
                    if main != nil {
                        guard let vcs = main?.viewControllers else { return }
                        for vc in vcs {
                            if vc.isKind(of: SettingsVC.self) {
                                let temp = vc as! SettingsVC
                                temp.settingsTable.reloadData()
                            }
                        }
                    }
                }
            }
            
            if error != nil {
                DispatchQueue.main.async {
                    APIManager.shared.requestForPermission(sender: nil, selector: nil, isProgressShowing: false, clientNotificationStatus: granted, clientCameraStatus: nil, clientLocationStatus: nil, clientGalleryStatus: nil, clientContactsStatus: nil, clientMicrophoneStatus: granted, clientSpeechToTextStatus: nil)
                }
            }
        }
    }
    
    func statusForNotifPermission() -> UNAuthorizationStatus {
        var authStatus: UNAuthorizationStatus?
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            UNUserNotificationCenter.current().getNotificationSettings { (settings) in
                authStatus = settings.authorizationStatus
                semaphore.signal()
            }
        }
        semaphore.wait()
        return authStatus ?? .notDetermined
    }
    
    func checkNotifPermission() {
        if AppUtils.shared.App_Delegate?.window?.rootViewController?.presentedViewController is LandingVC {
            return
        }
        
        UNUserNotificationCenter.current().delegate = AppUtils.shared.App_Delegate
        UNUserNotificationCenter.current().requestAuthorization(options: [.badge, .alert, .sound]) { (granted, error) in
            if !granted {
                DispatchQueue.main.async {
                    let userDefGranted = AppUtils.shared.userDefsPlistGetObjectForKey(forKey: Constants().ud_UserNotificationIsPermitted) as? Int
                    if userDefGranted == Constants().Tag_NotificationGranted {
                        APIManager.shared.requestForPermission(sender: nil, selector: nil, isProgressShowing: false, clientNotificationStatus: granted, clientCameraStatus: nil, clientLocationStatus: nil, clientGalleryStatus: nil, clientContactsStatus: nil, clientMicrophoneStatus: granted, clientSpeechToTextStatus: nil)
                    }
                }
            }
            if error != nil {
                DispatchQueue.main.async {
                    APIManager.shared.requestForPermission(sender: nil, selector: nil, isProgressShowing: false, clientNotificationStatus: granted, clientCameraStatus: nil, clientLocationStatus: nil, clientGalleryStatus: nil, clientContactsStatus: nil, clientMicrophoneStatus: granted, clientSpeechToTextStatus: nil)
                }
            }
        }
    }
    
    //MARK: - show settings
    func showSettingsForCameraPermission() {
        let settings:SettingsView = (Bundle.main.loadNibNamed(Constants().nib_SettingsView, owner: self, options: nil)?.first as? SettingsView)!
        settings.frame = Settings_Frame
        settings.prepareScreenForCamera()
        
        let theme:CNPPopupTheme = CNPPopupTheme.default()
        customPopup = CNPPopupController.init(contents: [settings])
        theme.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.75)
        theme.cornerRadius = 0.0
        theme.popupContentInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        theme.popupStyle = .centered
        theme.presentationStyle = .fadeIn
        theme.maskType = .dimmed
        theme.dismissesOppositeDirection = true
        theme.shouldDismissOnBackgroundTouch = false
        theme.movesAboveKeyboard = true
        theme.animationDuration = 0.25
        customPopup?.theme = theme
        customPopup?.present(animated: true)
    }
    
    func showSettingsForGalleryPermission() {
        let settings:SettingsView = (Bundle.main.loadNibNamed(Constants().nib_SettingsView, owner: self, options: nil)?.first as? SettingsView)!
        settings.frame = Settings_Frame
        settings.prepareScreenForGallery()
        
        let theme:CNPPopupTheme = CNPPopupTheme.default()
        customPopup = CNPPopupController.init(contents: [settings])
        theme.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.75)
        theme.cornerRadius = 0.0
        theme.popupContentInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        theme.popupStyle = .centered
        theme.presentationStyle = .fadeIn
        theme.maskType = .dimmed
        theme.dismissesOppositeDirection = true
        theme.shouldDismissOnBackgroundTouch = true
        theme.movesAboveKeyboard = true
        theme.animationDuration = 0.25
        customPopup?.theme = theme
        customPopup?.present(animated: true)
    }
    
    func showSettingsForPushNotificationPermission() {
        showSettingsForPushNotificationShowLanding(showLanding: true)
    }
    
    func showSettingsForPushNotificationShowLanding(showLanding: Bool, navc: UINavigationController = (AppUtils.shared.App_Delegate?.window?.rootViewController as! UINavigationController)) {
        let alert = UIAlertController(title: AppUtils.shared.App_Delegate?.localization?.popupNotificationTitle, message: AppUtils.shared.App_Delegate?.localization?.popupNotificationDescription, preferredStyle: .alert)
        let notNowAction = UIAlertAction(title: AppUtils.shared.App_Delegate?.localization?.btnPopupNotificationDismiss ?? "", style: .cancel, handler: { action in
            AppUtils.shared.userDefsPlistSetObject(object: Constants().Tag_NotificationDenied, forKey: Constants().ud_UserNotificationIsPermitted)
            APIManager.shared.requestForPermission(sender: nil, selector: nil, isProgressShowing: true, clientNotificationStatus: false, clientCameraStatus: nil, clientLocationStatus: nil, clientGalleryStatus: nil, clientContactsStatus: nil, clientMicrophoneStatus: nil, clientSpeechToTextStatus: nil)
        })
        let settingsAction = UIAlertAction(title: AppUtils.shared.App_Delegate?.localization?.btnPopupNotificationConfirm ?? "", style: .default, handler: { action in
            if let aString = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(aString, options: [:], completionHandler: nil)
            }            
            AppUtils.shared.userDefsPlistSetObject(object: Constants().Tag_NotificationDenied, forKey:  Constants().ud_UserNotificationIsPermitted)
            APIManager.shared.requestForPermission(sender: nil, selector: nil, isProgressShowing: true, clientNotificationStatus: false, clientCameraStatus: nil, clientLocationStatus: nil, clientGalleryStatus: nil, clientContactsStatus: nil, clientMicrophoneStatus: nil, clientSpeechToTextStatus: nil)
        })
        alert.addAction(settingsAction)
        alert.addAction(notNowAction)
        navc.present(alert, animated: true)
    }
    
    func showSettingsForMicrophonePermission(vc: UIViewController?) {
        let alert = UIAlertController(title: AppUtils.shared.App_Delegate?.localization?.popupMicrophoneTitle,
                                      message: AppUtils.shared.App_Delegate?.localization?.popupMicrophoneDescription,
                                      preferredStyle: .alert)
        let notNowAction = UIAlertAction(title: AppUtils.shared.App_Delegate?.localization?.btnPopupMicrophoneDismiss, style: .cancel, handler: { action in
        })
        
        let settingsAction = UIAlertAction(title: AppUtils.shared.App_Delegate?.localization?.btnPopupMicrophoneConfirm, style: .default, handler: { action in
            if let aString = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(aString, options: [:], completionHandler: nil)
            }
        })
        alert.addAction(settingsAction)
        alert.addAction(notNowAction)
        
        vc?.present(alert, animated: true)
    }
    
    func showSettingsForSpeechToTextPermission(vc: UIViewController?) {
        let alert = UIAlertController(title: AppUtils.shared.App_Delegate?.localization?.popupSpeechTitle,
                                      message: AppUtils.shared.App_Delegate?.localization?.popupSpeechDescription,
                                      preferredStyle: .alert)
        let notNowAction = UIAlertAction(title: AppUtils.shared.App_Delegate?.localization?.btnPopupSpeechDismiss, style: .cancel, handler: { action in
        })
        let settingsAction = UIAlertAction(title: AppUtils.shared.App_Delegate?.localization?.btnPopupSpeechConfirm, style: .default, handler: { action in
            if let aString = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(aString, options: [:], completionHandler: nil)
            }
        })
        alert.addAction(settingsAction)
        alert.addAction(notNowAction)
        
        vc?.present(alert, animated: true)
    }
    
    func showSettingsForSpeechRecognitionUnavailable(vc: UIViewController?) {
        let alert = UIAlertController(title: NSLocalizedString("Alert_Warning_Title", comment: ""), message: AppUtils.shared.App_Delegate?.localization?.txtSpeechRecognitionNotAvailable, preferredStyle: .alert)
        let notNowAction = UIAlertAction(title: NSLocalizedString("Alert_Action_OK", comment: ""), style: .default, handler: { action in
        })
        alert.addAction(notNowAction)
        vc?.present(alert, animated: true)
    }
    
    func showSettingsForContactsPermission() {
        let settings:SettingsView = (Bundle.main.loadNibNamed(Constants().nib_SettingsView, owner: self, options: nil)?.first as? SettingsView)!
        settings.frame = Settings_Frame
        settings.prepareScreenForContacts()
        
        let theme:CNPPopupTheme = CNPPopupTheme.default()
        customPopup = CNPPopupController.init(contents: [settings])
        theme.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.75)
        theme.cornerRadius = 0.0
        theme.popupContentInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        theme.popupStyle = .centered
        theme.presentationStyle = .fadeIn
        theme.maskType = .dimmed
        theme.dismissesOppositeDirection = true
        theme.shouldDismissOnBackgroundTouch = true
        theme.movesAboveKeyboard = true
        theme.animationDuration = 0.25
        customPopup?.theme = theme
        customPopup?.present(animated: true)
    }
    
    func showSettingsForLocationPermission() {
        let settings:SettingsView = (Bundle.main.loadNibNamed(Constants().nib_SettingsView, owner: self, options: nil)?.first as? SettingsView)!
        settings.frame = Settings_Frame
        settings.prepareScreenForLocation()
        
        let theme:CNPPopupTheme = CNPPopupTheme.default()
        customPopup = CNPPopupController.init(contents: [settings])
        theme.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.75)
        theme.cornerRadius = 0.0
        theme.popupContentInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
        theme.popupStyle = .centered
        theme.presentationStyle = .fadeIn
        theme.maskType = .dimmed
        theme.dismissesOppositeDirection = true
        theme.shouldDismissOnBackgroundTouch = true
        theme.movesAboveKeyboard = true
        theme.animationDuration = 0.25
        customPopup?.theme = theme
        customPopup?.present(animated: true)
    }
    
    // MARK:- speech to text
    func recordVoiceForSourceKey(source: String?, sender: AnyObject?, microphoneButton: UIButton?) {
        audioEngine = AVAudioEngine()
        speechRecognizer = SFSpeechRecognizer(locale: NSLocale(localeIdentifier: "\(source ?? "")") as Locale)
        speechRecognizer?.delegate = sender as? SFSpeechRecognizerDelegate
        btnMic = microphoneButton
        senderVC = sender as? UIViewController
    }
    
    func statusForMicrophonePermission() -> AVAudioSession.RecordPermission {
        return AVAudioSession.sharedInstance().recordPermission
    }
    
    func checkMicrophonePermission(vc: MicrophoneVC?) {
        micvc = vc
        
        let sessionRecordPermission: AVAudioSession.RecordPermission = AVAudioSession.sharedInstance().recordPermission
        switch sessionRecordPermission {
        case .undetermined:
            showMicrophonePermission()
        case .denied:
            if (AppUtils.shared.App_Delegate?.window?.rootViewController is MainNavigationVC) {
                showSettingsForMicrophonePermission(vc:AppUtils.shared.App_Delegate?.window?.rootViewController)
            }
            AppUtils.shared.userDefsPlistSetObject(object:Constants().Tag_MicrophoneDenied, forKey: Constants().ud_MicrophoneIsPermitted)
        case .granted:
            AppUtils.shared.userDefsPlistSetObject(object:Constants().Tag_MicrophoneGranted, forKey: Constants().ud_MicrophoneIsPermitted)
            checkSpeechToTextPermission(vc: micvc)
        default:
            break
        }
    }
    
    func showMicrophonePermission() {
        if AVAudioSession.sharedInstance().responds(to: #selector(AVAudioSession.requestRecordPermission(_:))) {
            AVAudioSession.sharedInstance().requestRecordPermission({ granted in
                if granted {
                    DispatchQueue.main.async(execute: {
                        self.checkSpeechToTextPermission(vc: self.micvc)
                        AppUtils.shared.userDefsPlistSetObject(object: Constants().Tag_MicrophoneGranted, forKey: Constants().ud_MicrophoneIsPermitted)
                    })
                } else {
                    DispatchQueue.main.async(execute: {
                        AppUtils.shared.userDefsPlistSetObject(object: Constants().Tag_MicrophoneDenied, forKey: Constants().ud_MicrophoneIsPermitted)
                    })
                }
                DispatchQueue.main.async(execute: {
                    APIManager.shared.requestForPermission(sender: nil, selector: nil, isProgressShowing: false, clientNotificationStatus: nil, clientCameraStatus: nil, clientLocationStatus: nil, clientGalleryStatus: nil, clientContactsStatus: nil, clientMicrophoneStatus: granted, clientSpeechToTextStatus: nil)
                })
            })
        }
    }
    
    func statusForSpeechToTextPermission() -> SFSpeechRecognizerAuthorizationStatus {
        return SFSpeechRecognizer.authorizationStatus()
    }
    
    func checkSpeechToTextPermission(vc: MicrophoneVC?) {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .notDetermined:
            showSpeechToTextPermission()
        case .authorized:
            if audioEngine?.isRunning ?? false || btnMic?.isSelected ?? false {
                if senderVC != nil && senderVC?.responds(to: #selector(stopRecordingVoice)) ?? false {
                    senderVC?.perform(#selector(self.stopRecordingVoice))
                }
            }
            else {
                if senderVC != nil && senderVC?.responds(to: #selector(startRecordingVoice)) ?? false {
                    senderVC?.perform(#selector(self.startRecordingVoice))
                }
            }
            AppUtils.shared.userDefsPlistSetObject(object: Constants().Tag_SpeechToTextGranted, forKey: Constants().ud_SpeechToTextIsPermitted)
        case .denied:
            if (AppUtils.shared.App_Delegate?.window?.rootViewController is MainNavigationVC) {
                showSettingsForSpeechToTextPermission(vc:AppUtils.shared.App_Delegate?.window?.rootViewController)
            }
            AppUtils.shared.userDefsPlistSetObject(object:Constants().Tag_SpeechToTextDenied, forKey: Constants().ud_SpeechToTextIsPermitted)
        case .restricted:
            if (AppUtils.shared.App_Delegate?.window?.rootViewController is MainNavigationVC) {
                showSettingsForSpeechToTextPermission(vc: AppUtils.shared.App_Delegate?.window?.rootViewController)
            }
            AppUtils.shared.userDefsPlistSetObject(object:Constants().Tag_SpeechToTextDenied, forKey: Constants().ud_SpeechToTextIsPermitted)
        default:
            break
        }
    }
    
    func showSpeechToTextPermission() {
        SFSpeechRecognizer.requestAuthorization({ status in
            switch status {
            case .authorized:
                DispatchQueue.main.async(execute: {
                    if self.audioEngine?.isRunning ?? false || self.btnMic?.isSelected ?? false {
                        if self.senderVC != nil && self.senderVC?.responds(to: #selector(self.stopRecordingVoice)) ?? false {
                            self.senderVC?.perform(#selector(self.stopRecordingVoice))
                        }
                    }
                    else {
                        if self.senderVC != nil && self.senderVC?.responds(to: #selector(self.startRecordingVoice)) ?? false {
                            self.senderVC?.perform(#selector(self.startRecordingVoice))
                        }
                    }
                    AppUtils.shared.userDefsPlistSetObject(object:Constants().Tag_SpeechToTextGranted, forKey: Constants().ud_SpeechToTextIsPermitted)
                    APIManager.shared.requestForPermission(sender: nil, selector: nil, isProgressShowing: false, clientNotificationStatus: nil, clientCameraStatus: nil, clientLocationStatus: nil, clientGalleryStatus: nil, clientContactsStatus: nil, clientMicrophoneStatus: nil, clientSpeechToTextStatus: true)
                })
            case .denied:
                DispatchQueue.main.async(execute: {
                    AppUtils.shared.userDefsPlistSetObject(object:Constants().Tag_SpeechToTextDenied, forKey: Constants().ud_SpeechToTextIsPermitted)
                    APIManager.shared.requestForPermission(sender: nil, selector: nil, isProgressShowing: false, clientNotificationStatus: nil, clientCameraStatus: nil, clientLocationStatus: nil, clientGalleryStatus: nil, clientContactsStatus: nil, clientMicrophoneStatus: nil, clientSpeechToTextStatus: false)
                })
            case .restricted:
                DispatchQueue.main.async(execute: {
                    AppUtils.shared.userDefsPlistSetObject(object:Constants().Tag_SpeechToTextDenied, forKey: Constants().ud_SpeechToTextIsPermitted)
                    APIManager.shared.requestForPermission(sender: nil, selector: nil, isProgressShowing: false, clientNotificationStatus: nil, clientCameraStatus: nil, clientLocationStatus: nil, clientGalleryStatus: nil, clientContactsStatus: nil, clientMicrophoneStatus: nil, clientSpeechToTextStatus: false)
                })
            default:
                break
            }
        })
    }
    
    @objc func startRecordingVoice() {
    }
    
    @objc func stopRecordingVoice() {
    }
    
    //MARK:- text to speech
    func playingTranslation(willBePlayedText: String?, senderForSource: UIButton?, senderForTarget: UIButton?, targetKey: String) {
        if (willBePlayedText?.count ?? 0) > 0 && (senderForSource != nil || senderForTarget != nil) && targetKey.count > 0 {
            self.speechSynthesizer = AVSpeechSynthesizer()
            self.speechSynthesizer?.delegate = self
            self.targetKey = targetKey
            btnVoiceForSource = senderForSource
            btnVoiceForTarget = senderForTarget
            speakText(speakableText: willBePlayedText)
        }
    }
    
    func speakText(speakableText: String?) {
        if !(self.speechSynthesizer?.isSpeaking ?? true) {
            let sentences = speakableText?.components(separatedBy: "\n")
            totalUtterances = sentences?.count ?? 0
            currentUtterance = 0
            totalTextLength = 0
            spokenTextLengths = 0
            
            if let sentence = speakableText {
                let speechUtterance = AVSpeechUtterance(string: sentence)
                speechUtterance.rate = AVSpeechUtteranceDefaultSpeechRate
                speechUtterance.pitchMultiplier = 1.0
                speechUtterance.volume = 1.0
                speechUtterance.postUtteranceDelay = 0.005
                speechUtterance.preUtteranceDelay = 0.005
                
                if targetKey != nil && targetKey?.count ?? 0 > 0 {
                    speechUtterance.voice = AVSpeechSynthesisVoice(language: targetKey)
                    
                    totalTextLength = totalTextLength + sentence.count
                    
                    //it is for playing sound if device is silent (sound button of the device is off)
                    let audioSession = AVAudioSession.sharedInstance()
                    do {
                        try audioSession.setCategory(AVAudioSession.Category.playback, mode: AVAudioSession.Mode.spokenAudio, options: AVAudioSession.CategoryOptions.defaultToSpeaker)
                    }
                    catch {
                        AppUtils.shared.NSLogDebug(msg:"\(#function) setCategoryError=\(error)")
                    }
                    self.speechSynthesizer?.speak(speechUtterance)
                }
                else {
                    self.speechSynthesizer?.stopSpeaking(at: .immediate)
                }
            }
        }
        else {
            self.speechSynthesizer?.stopSpeaking(at: .immediate)
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        currentUtterance = currentUtterance + 1
        
        btnVoiceForSource?.isSelected = false
        btnVoiceForTarget?.isSelected = false
        
        if btnVoiceForSource != nil  {
            btnVoiceForSource?.isSelected = true
        }
        if btnVoiceForTarget != nil {
            btnVoiceForTarget?.isSelected = true
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        AppUtils.shared.NSLogDebug(msg:"progress:\(Int((spokenTextLengths + characterRange.location)) * 100 / totalTextLength)")
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        spokenTextLengths = spokenTextLengths + utterance.speechString.count + 1
        let progress: Float = Float(spokenTextLengths * 100 / totalTextLength)
        AppUtils.shared.NSLogDebug(msg:"finish progress:\(progress)")
        btnVoiceForSource?.isSelected = false
        btnVoiceForTarget?.isSelected = false
    }
    
    func statusForContactsPermission() -> CNAuthorizationStatus {
        return CNContactStore.authorizationStatus(for: .contacts)
    }
    
    func checkContactsPermission(vc: ContactsVC?) {
        contactvc = vc
        
        let status = CNContactStore.authorizationStatus(for: .contacts)
        if status == .denied || status == .restricted {
            showSettingsForContactsPermission()
            return
        }
        
        let store = CNContactStore()
        store.requestAccess(for: .contacts) { (granted, error) in
            if !granted {
                DispatchQueue.main.async(execute: {
                    self.showSettingsForContactsPermission()
                })
                return
            }
        }
    }
    
    //MARK:- location
    func statusForLocationPermission() -> CLAuthorizationStatus {
        return CLLocationManager.authorizationStatus()
    }
    
    func checkLocationPermission(vc: LocationVC?) {
        locationvc = vc
        
        let status = CLLocationManager.authorizationStatus()
        if status == .denied || status == .restricted {
            showSettingsForLocationPermission()
            return
        }
        
        let locManager = CLLocationManager()
        locManager.delegate = vc
        if status == .notDetermined {
//            locManager.requestWhenInUseAuthorization()
            locManager.requestAlwaysAuthorization()
            locManager.startUpdatingLocation()
        }
        else if status == .authorizedAlways || status == .authorizedWhenInUse {
            locManager.startUpdatingLocation()
        }
        locationvc?.locManager = locManager
    }
}
