import Testing

let enableSystemTests = false

extension Tag {
    // this test requires running RabbitMQ service to function (will use default config), to run those, change enableSystemTests to `true`
    @Tag static var requiresRMQServer: Self
}
