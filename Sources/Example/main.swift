import DeclarativeAPI
import FluentMongoDriver

let app = try Application(.detect())
try app.databases.use(.mongo(connectionString: "mongodb://localhost/decl"), as: .mongo)

app.buildRoutes {
    CreateUser()
    ListAll<User>()
    
    Grouped(PermissionsCheck(type: .admin)) {
        GetProfile()
    }
}

try app.run()
