import Fluent
import FluentPostgresDriver
import Vapor
import JWT
import Mailgun
import QueuesRedisDriver

public func configure(_ app: Application) throws {
    
    // MARK: JWT
    if app.environment != .testing {
        let jwksFilePath = app.directory.workingDirectory + (Environment.get("JWKS_KEYPAIR_FILE") ?? "keypair.jwks")
         guard
             let jwks = FileManager.default.contents(atPath: jwksFilePath),
             let jwksString = String(data: jwks, encoding: .utf8)
             else {
                 fatalError("Failed to load JWKS Keypair file at: \(jwksFilePath)")
         }
         try app.jwt.signers.use(jwksJSON: jwksString)
        app.logger.info("Found JWKS.", metadata: nil)
    }
    
    // MARK: Database
    // Configure PostgreSQL database
    
    app.databases.use(.postgres(
        hostname: Environment.get("POSTGRES_HOSTNAME") ?? "localhost",
        username: Environment.get("POSTGRES_USERNAME") ?? "vapor",
        password: Environment.get("POSTGRES_PASSWORD") ?? "password",
        database: Environment.get("POSTGRES_DATABASE") ?? "vapor"
    ), as: .psql)
    app.logger.info("DB configured per env settings", metadata: nil)

    // MARK: Middleware
    app.middleware = .init()
    
    app.middleware.use(ErrorMiddleware.custom(environment: app.environment))
    let corsConfiguration = CORSMiddleware.Configuration(
        allowedOrigin: .all,
        allowedMethods: [.GET, .POST, .PUT, .OPTIONS, .DELETE, .PATCH],
        allowedHeaders: [.accept, .authorization, .contentType, .origin, .xRequestedWith, .userAgent, .accessControlAllowOrigin]
    )
    app.logger.info("CORS configured: \(corsConfiguration)", metadata: nil)
    
    let cors = CORSMiddleware(configuration: corsConfiguration)
    // cors middleware should come before default error middleware using `at: .beginning`
    app.middleware.use(cors, at: .beginning)

    // MARK: Model Middleware
    
    // MARK: Mailgun
    app.mailgun.configuration = .environment
    app.mailgun.defaultDomain = .sandbox
    app.logger.info("Mailgun \(String(describing: app.mailgun.configuration)), \(String(describing: app.mailgun.defaultDomain))", metadata: nil)
    
    // MARK: App Config
    app.config = .environment
    app.http.server.configuration.port = 8081
    
    try routes(app)
    try migrations(app)
    try queues(app)
    try services(app)
    
    if app.environment == .development {
        try app.autoMigrate().wait()
        app.logger.info("Automigration done.")
        try app.queues.startInProcessJobs()
        app.logger.info("In process jobs started.")
    }
}
