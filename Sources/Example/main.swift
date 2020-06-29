import DeclarativeAPI
import FluentMongoDriver

let app = try Application(.detect())
try app.databases.use(.mongo(connectionString: "mongodb://localhost/decl"), as: .mongo)

app.buildRoutes {
    CreateUser()
    GetProfile()
    SneakyPromoteAdmin()
    
    Grouped(PermissionsCheck(type: .admin)) {
        ListAll<User>()
    }
}

try app.run()
