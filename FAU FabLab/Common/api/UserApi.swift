struct UserApi {
    
    private let api = RestManager.sharedInstance
    private let resource = "/user"

    func getUserInfo(user: User, onCompletion: (User?, NSError?) -> Void){
        api.makeJSONRequestWithBasicAuth(.GET, encoding: .URL, resource: resource,
            username: user.username!,
            password: user.password!,
            params: nil,
            onCompletion: { json, error in
                ApiResult.get(json, error: error, completionHandler: onCompletion)
        })
    }
}
