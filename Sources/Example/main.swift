import DeclarativeAPI

let app = try Application(.detect())
try app.connectMongoDB(to: "mongodb://localhost/decl")

app.register(CreateUser())
app.register(ListAll<User>())

try app.run()
