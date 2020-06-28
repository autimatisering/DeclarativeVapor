import DeclarativeAPI
import FluentMongoDriver

let app = try Application(.detect())
try app.databases.use(.mongo(connectionString: "mongodb://localhost/decl"), as: .mongo)

app.register(CreateUser())
app.register(ListAll<User>())

try app.run()
