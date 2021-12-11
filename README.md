# CoreNetworkStack

### RemoteSession api:
    //Creating a RemoteSession:
    + (instancetype) defaultSession;
    - (instancetype)initWithBackgroundSessionIdentifier:(NSString*)identifier;
    - (instancetype)initWithBackgroundSessionIdentifier:(NSString*)identifier andSessionDelegate:(SessionHandler*)handler;
    
    //
    - (NSURLSession*) createBackgroundSessionWithIdentifier:(NSString*)identifier andSessionDelegate:(SessionHandler*)handler;
    - (RemoteDataTask*) sendMessage:(HttpWebRequest*)capsul onCompletion:(CompletionHandler)completion;
    - (RemoteDataTask*) sendMessage:(HttpWebRequest*)capsul onDispatchQueue:(dispatch_queue_t)queue onCompletion:(CompletionHandler)completion;
    //
    - (RemoteUploadTask*) uploadContent:(HttpFileRequest*)capsul progressDelegate:(id<ContentDelegate>)delegate onCompletion:(CompletionHandler)completion;
    - (RemoteUploadTask*) uploadContent:(HttpFileRequest*)capsul progressDelegate:(id<ContentDelegate>)delegate onDispatchQueue:(dispatch_queue_t)queue onCompletion:(CompletionHandler)completion;
    //
    - (RemoteDownloadTask*) downloadContent:(HttpWebRequest*)capsul progressDelegate:(id<ContentDelegate>)delegate onCompletion:(DownloadCompletionHandler)completion;
    
    
### How to make remote call:
    let req = HttpWebRequest(baseUrl: "http://mydomain.com/api/v1/users"
                            , method: POST
                            , contentType: Application_JSON)
    //attach @RequestBody
    req?.payLoad = ["name":"etc", "age":"32"] as? NGObjectProtocol
    
    //Make Remote call:
    RemoteSession.default()?.sendMessage(req!, onCompletion: { (data, response, error) in
        //...
    })
    
### NetworkActivity api
    //First activate network reachability from application delegate:
    //..
    func applicationWillEnterForeground(_ application: UIApplication) {
        badgeCounter.clearBadgeNumber(application: application)
        NetworkActivity.sharedInstance().activateReachabilityObserver(withHostAddress: "www.google.com")
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        NetworkActivity.sharedInstance().deactivateReachabilityObserver()
    }
    //..
    
    //Then anywhere in the app-code check network reachability like this:
    //
    let isWifiReachable = NetworkActivity.sharedInstance()?.isWifiReachable()
    
    //OR
    let isNetReachable = NetworkActivity.sharedInstance()?.isInternetReachable()
    
    //..etc