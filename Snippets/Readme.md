# Snippets

Most likely all of those require AMQP server running. The fastest and easiest way is to
use docker:

```sh
# latest RabbitMQ 4.0.x
docker run -it --rm --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:4.0-management
```

The admin console is accessible at http://localhost:15672 behind the default RabbitMQ credentials.
