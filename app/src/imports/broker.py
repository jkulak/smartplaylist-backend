import pika


def create_channel(name):
    """Creates RabbitMQ channel
    "broker" is a RabbitMQ service name from stack.yml file"""
    connection = pika.BlockingConnection(pika.ConnectionParameters("broker"))
    channel = connection.channel()
    channel.queue_declare(queue=name)
    return connection, channel


def close_connection(connection):
    connection.close()
