#include <amqp_tcp_socket.h>
#include <amqp.h>
#include <amqp_framing.h>
#include <stdbool.h>

#include "migrate.h"
#include "control.h"

/*
 *
 */
static amqp_connection_state_t get_amqp_connection()
{
    int status;
    amqp_connection_state_t conn;
    amqp_rpc_reply_t reply;
    amqp_socket_t *socket = NULL;

    conn = amqp_new_connection();
    if (!conn) {
        DEBUG(0, ("[!] Error getting ampq connection"));
        return NULL;
    }

    socket = amqp_tcp_socket_new(conn);
    if (!socket) {
        amqp_destroy_connection(conn);
        DEBUG(0, ("[!] Error creating the TCP socket!\n"));
        return NULL;
    }

    status = amqp_socket_open(socket, "localhost", 5672);
    if (status) {
        amqp_connection_close(conn, AMQP_REPLY_SUCCESS);
        amqp_destroy_connection(conn);
        DEBUG(0, ("[!] Error opening the TCP socket!\n"));
        return NULL;
    }

    reply = amqp_login(conn, "/", 0, 131072, 0, AMQP_SASL_METHOD_PLAIN,
                       "guest", "guest");
    if (reply.reply_type != AMQP_RESPONSE_NORMAL) {
        amqp_connection_close(conn, AMQP_REPLY_SUCCESS);
        amqp_destroy_connection(conn);
        DEBUG(0, ("[!] Error loggging into server\n"));
        return NULL;
    }

    if (!amqp_channel_open(conn, 1)) {
        amqp_channel_close(conn, 1, AMQP_REPLY_SUCCESS);
        amqp_connection_close(conn, AMQP_REPLY_SUCCESS);
        DEBUG(0, ("[!] Error opening channel 1\n"));
        return NULL;
    }

    return conn;
}

bool rpc_open(struct status *status)
{
    /* Open connection */
    status->conn = get_amqp_connection();
    if (!status->conn) {
        return false;
    }

    /* Declare the control queue */
    amqp_queue_declare(status->conn,
        1, /* Channel */
        amqp_cstring_bytes("Zentyal.OpenChange.Migrate.Control"),
        0, /* Passive */
        0, /* Durable */
        1, /* Exclusive */
        1, /* Auto delete */
        amqp_empty_table);
    if (amqp_get_rpc_reply(status->conn).reply_type != AMQP_RESPONSE_NORMAL) {
        DEBUG(0, ("[!] Error declaring queue\n"));
        return false;
    }

    /* Start the consumer */
    amqp_basic_consume(status->conn, 1,
        amqp_cstring_bytes("Zentyal.OpenChange.Migrate.Control"), /* Queue */
        amqp_cstring_bytes("Zentyal.OpenChange.Migrate.Control"), /* Tag */
        0,  /* no local */
        1,  /* no ack */
        0,  /* exclusive */
        amqp_empty_table);
    if (amqp_get_rpc_reply(status->conn).reply_type != AMQP_RESPONSE_NORMAL) {
        DEBUG(0, ("[!] Error starting consumer\n"));
        return false;
    }

    return true;
}

void rpc_close(struct status *status)
{
    if (status->conn) {
        if (amqp_channel_close(status->conn, 1, AMQP_REPLY_SUCCESS).reply_type != AMQP_RESPONSE_NORMAL) {
            DEBUG(0, ("[!] Error closing AMQP channel\n"));
        }
        if (amqp_connection_close(status->conn, AMQP_REPLY_SUCCESS).reply_type != AMQP_RESPONSE_NORMAL) {
            DEBUG(0, ("[!] Error closing AMQP connection\n"));
        }
        if (amqp_destroy_connection(status->conn) < 0) {
            DEBUG(0, ("[!] Error destroying AMQP connection\n"));
        }
    }
    status->conn = NULL;
}

void rpc_run(struct status *status)
{
    DEBUG(2, ("[*] Init RPC loop\n"));

    /* Init command control */
    if (!control_init(status)) {
        return;
    }

    /* Enter control loop */
    while (status->rpc_run) {
        amqp_rpc_reply_t result;
        amqp_envelope_t envelope;

        amqp_basic_properties_t response_header;
        amqp_bytes_t response_body;

        amqp_maybe_release_buffers(status->conn);
        result = amqp_consume_message(status->conn, &envelope, NULL, 0);
        if (result.reply_type != AMQP_RESPONSE_NORMAL) {
            if (AMQP_RESPONSE_LIBRARY_EXCEPTION == result.reply_type &&
                AMQP_STATUS_UNEXPECTED_STATE == result.library_error)
            {
                amqp_frame_t frame;
                if (AMQP_STATUS_OK != amqp_simple_wait_frame(status->conn, &frame)) {
                    DEBUG(0, ("[!] Error consuming message\n"));
                    control_abort(status);
                    break;
                }
                if (AMQP_FRAME_METHOD == frame.frame_type) {
                    switch (frame.payload.method.id) {
                        case AMQP_BASIC_ACK_METHOD:
                            /* if we've turned publisher confirms on, and we've published a message
                             * here is a message being confirmed
                             */
                            break;
                        case AMQP_BASIC_RETURN_METHOD:
                            /* if a published message couldn't be routed and the mandatory flag was set
                             * this is what would be returned. The message then needs to be read.
                             */
                            {
                                amqp_message_t message;
                                result = amqp_read_message(status->conn, frame.channel, &message, 0);
                                if (AMQP_RESPONSE_NORMAL != result.reply_type) {
                                    control_abort(status);
                                    return;
                                }
                                amqp_destroy_message(&message);
                            }
                            break;
                        case AMQP_CHANNEL_CLOSE_METHOD:
                            /* a channel.close method happens when a channel exception occurs, this
                             * can happen by publishing to an exchange that doesn't exist for example
                             *
                             * In this case you would need to open another channel redeclare any queues
                             * that were declared auto-delete, and restart any consumers that were attached
                             * to the previous channel
                             */
                            return;

                        case AMQP_CONNECTION_CLOSE_METHOD:
                            /* a connection.close method happens when a connection exception occurs,
                             * this can happen by trying to use a channel that isn't open for example.
                             *
                             * In this case the whole connection must be restarted.
                             */
                            return;

                        default:
                            DEBUG(0, ("[!] An unexpected method was received %d\n", frame.payload.method.id));
                            return;
                    }
                    continue;
                }
                continue;
            }
            DEBUG(0, ("[!] Error consuming message\n"));
            control_abort(status);
            break;
        }

        DEBUG(0, ("Delivery %u, exchange %.*s routingkey %.*s\n",
             (unsigned) envelope.delivery_tag,
             (int) envelope.exchange.len, (char *) envelope.exchange.bytes,
             (int) envelope.routing_key.len, (char *) envelope.routing_key.bytes));
        if (envelope.message.properties._flags & AMQP_BASIC_CONTENT_TYPE_FLAG) {
            DEBUG(0, ("Content-type: %.*s\n",
                (int) envelope.message.properties.content_type.len,
                (char *) envelope.message.properties.content_type.bytes));
        }
        if (envelope.message.properties._flags & AMQP_BASIC_REPLY_TO_FLAG) {
            response_header._flags |= AMQP_BASIC_REPLY_TO_FLAG;
            response_header.reply_to = amqp_bytes_malloc_dup(envelope.message.properties.reply_to);
            DEBUG(0, ("Reply-to: %.*s\n",
                (int) envelope.message.properties.reply_to.len,
                (char *) envelope.message.properties.reply_to.bytes));
        }
        if (envelope.message.properties._flags & AMQP_BASIC_CORRELATION_ID_FLAG) {
            response_header._flags |= AMQP_BASIC_CORRELATION_ID_FLAG;
            response_header.correlation_id = amqp_bytes_malloc_dup(envelope.message.properties.correlation_id);
            DEBUG(0, ("Correlation-id: %.*s\n",
                (int) envelope.message.properties.correlation_id.len,
                (char *) envelope.message.properties.correlation_id.bytes));
        }

        /* Handle the request */
        response_body = control_handle(status, envelope.message.body);
        DEBUG(0, ("[*] Sending response '%s'\n", (char*)response_body.bytes));

        ///* Send the response */
        response_header._flags |= AMQP_BASIC_CONTENT_TYPE_FLAG;
        response_header.content_type = amqp_cstring_bytes("text/plain");

        response_header._flags |= AMQP_BASIC_DELIVERY_MODE_FLAG;
        response_header.delivery_mode = 1;
        int ret = amqp_basic_publish(status->conn,
            1,
            amqp_empty_bytes,
            amqp_bytes_malloc_dup(envelope.message.properties.reply_to),
            0, /* Mandatory */
            0, /* Inmediate */
            &response_header,
            response_body);
        if (ret != AMQP_STATUS_OK) {
            DEBUG(0, ("[!] Error publishing command response: %s\n", amqp_error_string2(ret)));
        }

        //* Free memory */
        amqp_destroy_envelope(&envelope);
    }

    /* Clean up control */
    control_free(status);
}
