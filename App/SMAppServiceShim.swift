import ServiceManagement

enum SMAppServiceShim {
    static func registerLoginItem() throws {
        #if !DEBUG
        try SMAppService.mainApp.register()
        #endif
    }
}
