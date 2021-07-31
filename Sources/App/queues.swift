import Vapor
import Queues

func queues(_ app: Application) throws {
    // MARK: Queues Configuration
    if app.environment != .testing {
        try app.queues.use(
            .redis(url: Environment.get("REDIS_URL") ?? "redis://127.0.0.1:6379")            
        )
        app.logger.info("connected to redis.", metadata: nil)

    }
    
    // MARK: Jobs
    app.queues.add(EmailJob())
}
