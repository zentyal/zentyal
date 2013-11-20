/*
 * Upgrade a mailbox from Exchange to Openchange
 *
 * OpenChange Project
 *
 * Copyright (C) Zentyal SL 2013
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "migrate.h"

static amqp_connection_state_t get_amqp_connection(void)
{
    int         status;
    amqp_connection_state_t conn;
    amqp_rpc_reply_t    reply;
    amqp_socket_t       *socket = NULL;

    conn = amqp_new_connection();
    if (!conn) {
        fprintf(stderr, "[!] Error getting ampq connection\n");
        return NULL;
    }

    socket = amqp_tcp_socket_new(conn);
    if (!socket) {
        amqp_destroy_connection(conn);
        fprintf(stderr, "[!] Error creating the TCP socket!\n");
        return NULL;
    }

    status = amqp_socket_open(socket, "localhost", 5672);
    if (status) {
        amqp_connection_close(conn, AMQP_REPLY_SUCCESS);
        amqp_destroy_connection(conn);
        fprintf(stderr, "[!] Error opening the TCP socket!\n");
        return NULL;
    }

    reply = amqp_login(conn, "/", 0, 131072, 0, AMQP_SASL_METHOD_PLAIN,
               "guest", "guest");
    if (reply.reply_type != AMQP_RESPONSE_NORMAL) {
        amqp_connection_close(conn, AMQP_REPLY_SUCCESS);
        amqp_destroy_connection(conn);
        fprintf(stderr, "[!] Error loggging into server\n");
        return NULL;
    }

    if (!amqp_channel_open(conn, 1)) {
        amqp_channel_close(conn, 1, AMQP_REPLY_SUCCESS);
        amqp_connection_close(conn, AMQP_REPLY_SUCCESS);
        fprintf(stderr, "[!] Error opening channel 1\n");
        return NULL;
    }

    return conn;
}


bool rpc_open(struct status *status)
{
    bool retval = false;
    int ret = 0;

    DEBUG(2, ("[*] Opening RPC\n"));

    /* Adquire lock */
    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        fprintf(stderr, "[!] pthread_spin_lock: %s\n", strerror(ret));
        return false;
    }

    /* Open connection */
    status->conn = get_amqp_connection();
    if (!status->conn) {
        retval = false;
        goto unlock;
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
        fprintf(stderr, "[!] Error declaring queue\n");
        retval = false;
        goto unlock;
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
        fprintf(stderr, "[!] Error starting consumer\n");
        retval = false;
        goto unlock;
    }

    retval = true;

unlock:
    /* Release lock */
    pthread_spin_unlock(&status->lock);

    return retval;
}


void rpc_close(struct status *status)
{
    int ret = 0;

    DEBUG(2, ("[*] Closing RPC\n"));

    /* Adquire lock */
    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        fprintf(stderr, "[!] pthread_spin_lock: %s\n", strerror(ret));
        return;
    }

    if (status->conn) {
        if (amqp_channel_close(status->conn, 1, AMQP_REPLY_SUCCESS).reply_type != AMQP_RESPONSE_NORMAL) {
            fprintf(stderr, "[!] Error closing AMQP channel\n");
        }
        if (amqp_connection_close(status->conn, AMQP_REPLY_SUCCESS).reply_type != AMQP_RESPONSE_NORMAL) {
            fprintf(stderr, "[!] Error closing AMQP connection\n");
        }
        if (amqp_destroy_connection(status->conn) < 0) {
            fprintf(stderr, "[!] Error destroying AMQP connection\n");
        }
    }
    status->conn = NULL;

    /* Release lock */
    pthread_spin_unlock(&status->lock);
}

bool rpc_check_run_flag(struct status *status)
{
    bool retval = false;
    int ret = 0;

    ret = pthread_spin_lock(&status->lock);
    if (ret) {
        fprintf(stderr, "[!] pthread_spin_lock: %s\n", strerror(ret));
        return false;
    }

    retval = status->rpc_run;

    /* Release lock */
    pthread_spin_unlock(&status->lock);
    return retval;
}


void rpc_run(struct status *status)
{
    int ret;

    DEBUG(2, ("[*] Running RPC command\n"));

    /* Init command control */
    if (!control_init(status)) {
        return;
    }

    /* Enter control loop */
    while (rpc_check_run_flag(status)) {
        amqp_rpc_reply_t    result;
        amqp_envelope_t     envelope;
        amqp_basic_properties_t response_header;
        amqp_bytes_t        response_body;

        response_header._flags = 0;
        amqp_maybe_release_buffers(status->conn);
        result = amqp_consume_message(status->conn, &envelope, NULL, 0);
        if (result.reply_type != AMQP_RESPONSE_NORMAL) {
            if (AMQP_RESPONSE_LIBRARY_EXCEPTION == result.reply_type &&
                AMQP_STATUS_UNEXPECTED_STATE == result.library_error)
            {
                amqp_frame_t    frame;

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
                        amqp_message_t  message;

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

        DEBUG(2, ("Delivery %u, exchange %.*s routingkey %.*s\n",
              (unsigned) envelope.delivery_tag,
              (int) envelope.exchange.len, (char *) envelope.exchange.bytes,
              (int) envelope.routing_key.len, (char *) envelope.routing_key.bytes));

        if (envelope.message.properties._flags & AMQP_BASIC_CONTENT_TYPE_FLAG) {
            DEBUG(2, ("Content-type: %.*s\n",
                  (int) envelope.message.properties.content_type.len,
                  (char *) envelope.message.properties.content_type.bytes));
        }
        if (envelope.message.properties._flags & AMQP_BASIC_REPLY_TO_FLAG) {
            response_header._flags |= AMQP_BASIC_REPLY_TO_FLAG;
            response_header.reply_to = amqp_bytes_malloc_dup(envelope.message.properties.reply_to);
            DEBUG(2, ("Reply-to: %.*s\n",
                  (int) envelope.message.properties.reply_to.len,
                  (char *) envelope.message.properties.reply_to.bytes));
        }
        if (envelope.message.properties._flags & AMQP_BASIC_CORRELATION_ID_FLAG) {
            response_header._flags |= AMQP_BASIC_CORRELATION_ID_FLAG;
            response_header.correlation_id = amqp_bytes_malloc_dup(envelope.message.properties.correlation_id);
            DEBUG(2, ("Correlation-id: %.*s\n",
                  (int) envelope.message.properties.correlation_id.len,
                  (char *) envelope.message.properties.correlation_id.bytes));
        }

        /* Handle the request */
        response_body = control_handle(status, envelope.message.body);
        DEBUG(2, ("[*] Sending response '%s'\n", (char*)response_body.bytes));

        /* Send the response */
        response_header._flags |= AMQP_BASIC_CONTENT_TYPE_FLAG;
        response_header.content_type = amqp_cstring_bytes("text/plain");

        response_header._flags |= AMQP_BASIC_DELIVERY_MODE_FLAG;
        response_header.delivery_mode = 1;
        ret = amqp_basic_publish(status->conn, 1,
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
