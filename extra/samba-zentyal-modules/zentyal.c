/*
   ldb database zentyal module

   Copyright (C) 2012 eBox Technologies S.L.

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License, version 2, as
    published by the Free Software Foundation.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

/*
 *  Name: zentyal
 *
 *  Component: ldb zentyal module
 *
 *  Description: Intercept LDB operations and forward them to the synchronizer
 *               perl script
 *
 *  Author: eBox Technologies S.L. <info@zentyal.com>
 */

#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <math.h>
#include <sys/socket.h>
#include <sys/un.h>
#include <ldb_module.h>
#include <jansson.h>

static char socket_path[] = "/var/run/ldb";

static char encoding_table[] = {'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H',
                                'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
                                'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X',
                                'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
                                'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n',
                                'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
                                'w', 'x', 'y', 'z', '0', '1', '2', '3',
                                '4', '5', '6', '7', '8', '9', '+', '/'};
static int mod_table[] = {0, 2, 1};

struct private_data
{
    int socket;
};

static char *base64_encode(uint8_t *data, size_t input_length,
                           size_t *output_length)
{
    int i, j;

    *output_length = (size_t) (4.0 * ceil((double) input_length / 3.0));

    char *encoded_data = malloc(*output_length);
    if (encoded_data == NULL)
        return NULL;

    for (i = 0, j = 0; i < input_length;) {
        uint32_t octet_a = i < input_length ? data[i++] : 0;
        uint32_t octet_b = i < input_length ? data[i++] : 0;
        uint32_t octet_c = i < input_length ? data[i++] : 0;

        uint32_t triple = (octet_a << 0x10) + (octet_b << 0x08) + octet_c;

        encoded_data[j++] = encoding_table[(triple >> 3 * 6) & 0x3F];
        encoded_data[j++] = encoding_table[(triple >> 2 * 6) & 0x3F];
        encoded_data[j++] = encoding_table[(triple >> 1 * 6) & 0x3F];
        encoded_data[j++] = encoding_table[(triple >> 0 * 6) & 0x3F];
    }

    for (i = 0; i < mod_table[input_length % 3]; i++)
        encoded_data[*output_length - 1 - i] = '=';

    return encoded_data;
}

static int dn_to_json(struct ldb_dn *ldn, json_t **dn)
{
    json_t *aux = json_string(ldb_dn_get_linearized(ldn));
    *dn = aux;
    return (aux == NULL ? -1 : 0);
}

/**
 *  Convert a ldb_message to a JSON encoded perl hash of the following format:
 *  hash ref =  {
 *                  element1 => {
 *                                  flags  => 'element flags (integer)'
 *                                  values => [ 'value1', 'value2', ]
 *                              }
 *                  element2 => {
 *                                  flags  => 'element flags (integer)'
 *                                  values => [ 'value1', 'value2', ]
 *                              }
 *              }
 *  The values are base64 encoded.
 *
 **/
static int msg_to_json(const struct ldb_message *lmsg, json_t **msg)
{
    int i, j, ret;

    json_t *hs = json_object();
    if (hs == NULL)
        return -1;

    for (i = 0; i < lmsg->num_elements; i++) {
        const struct ldb_message_element *elem = &lmsg->elements[i];
        json_t *elem_hash = json_object();
        if (elem_hash == NULL)
            return -1;

        json_t *values_array = json_array();
        if (values_array == NULL)
            return -1;

        json_t *flags = json_integer(elem->flags);
        if (flags == NULL)
            return -1;

        ret = json_object_set_new(elem_hash, "flags", flags);
        if (ret)
            return -1;

        for (j = 0; j < elem->num_values; j++) {
            struct ldb_val *value = &elem->values[j];

            // Encode the value in base64
            size_t b64_len;
            char *b64_value = base64_encode(value->data, value->length, &b64_len);

            // Copy the string to append the '\0', required by json_string
            char *b64_value2 = malloc(b64_len + 1);
            strncpy(b64_value2, b64_value, b64_len);
            b64_value2[b64_len] = '\0';

            // Create the JSON string
            json_t *val = json_string(b64_value2);
            if (val == NULL)
                return -1;

            // Append the value to the values array of the attribute
            ret = json_array_append(values_array, val);
            if (ret)
                return -1;

            // Free allocated memory
            free(b64_value);
            free(b64_value2);
        }
        ret = json_object_set_new(elem_hash, "values", values_array);
        if (ret)
            return -1;

        ret = json_object_set_new(hs, elem->name, elem_hash);
        if (ret)
            return -1;
    }
    *msg = hs;

    return 0;
}

static char *json(const char *lop, struct ldb_dn *ldn,
                  const struct ldb_message *lmods,
                  const struct ldb_message *lobject)
{
    json_t *root, *op, *dn, *mods, *object;
    int ret;

    root = json_object();
    if (root == NULL)
        return NULL;

    op = json_string(lop);
    if (op == NULL)
        return NULL;

    ret = json_object_set_new(root, "operation", op);
    if (ret)
        return NULL;

    ret = dn_to_json(ldn, &dn);
    if (ret)
        return NULL;

    ret = json_object_set_new(root, "dn", dn);
    if (ret)
        return NULL;

    if (lmods != NULL) {
        ret = msg_to_json(lmods, &mods);
        if (ret)
            return NULL;

        ret = json_object_set_new(root, "mods", mods);
        if (ret)
            return NULL;
    }

    if (lobject != NULL) {
        ret = msg_to_json(lobject, &object);
        if (ret)
            return NULL;

        ret = json_object_set_new(root, "object", object);
        if (ret)
            return NULL;
    }

    // Dump JSON string
    char *json = json_dumps(root, 0);
    return json;
}

static int open_socket(struct ldb_module *module)
{
    struct ldb_context *ldb;
    struct private_data *data;
    struct sockaddr_un remote;
    int len;

    ldb = ldb_module_get_ctx(module);
	data = talloc_get_type(ldb_module_get_private(module), struct private_data);

    if ((data->socket = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
        ldb_debug(ldb, LDB_DEBUG_ERROR, "zentyal: %s", strerror(errno));
        return -1;
    }

    remote.sun_family = AF_UNIX;
    strcpy(remote.sun_path, socket_path);
    len = strlen(remote.sun_path) + sizeof(remote.sun_family);
    if (connect(data->socket, (struct sockaddr *)&remote, len) == -1) {
        ldb_debug(ldb, LDB_DEBUG_ERROR, "zentyal: %s", strerror(errno));
        return -1;
    }

    return 0;
}

static int close_socket(struct ldb_module *module)
{
    struct private_data *data;

	data = talloc_get_type(ldb_module_get_private(module), struct private_data);

    close(data->socket);
    data->socket = -1;

    return 0;
}

static int socket_send(struct ldb_module *module, const char *json_str)
{
    struct ldb_context *ldb;
    struct private_data *data;
    int ret;

    ldb = ldb_module_get_ctx(module);
	data = talloc_get_type(ldb_module_get_private(module), struct private_data);

    ret = open_socket(module);
    if (ret) {
        ldb_debug(ldb, LDB_DEBUG_ERROR, "zentyal: %s", strerror(errno));
        return -1;
    }

    if (send(data->socket, json_str, strlen(json_str), 0) == -1) {
        ldb_debug(ldb, LDB_DEBUG_ERROR, "zentyal: %s", strerror(errno));
        return -1;
    }
    if (send(data->socket, "\n", 1, 0) == -1) {
        ldb_debug(ldb, LDB_DEBUG_ERROR, "zentyal: %s", strerror(errno));
        return -1;
    }

    // Wait for response
    int nbytes;
    char response[1024];
    if ((nbytes = recv(data->socket, &response, 1024, 0)) > 0) {
        response[nbytes] = '\0';
        ldb_debug(ldb, LDB_DEBUG_TRACE, "zentyal: Response from synchronizer: %s", response);
    } else {
        if (nbytes < 0)
            ldb_debug(ldb, LDB_DEBUG_ERROR, "zentyal: %s", strerror(errno));
        else
            ldb_debug(ldb, LDB_DEBUG_ERROR, "zentyal: %s", strerror(errno));
        return -1;
    }

    // Close socket
    close_socket(module);

    // Check return code from synchronizer
    ret = strcmp(response, "OK");

    return ret;
}

static int search_entry(struct ldb_context *ldb, struct ldb_dn *dn, struct ldb_result **result)
{
    int ret;

    ret = ldb_search(ldb, ldb, result, dn, LDB_SCOPE_BASE, NULL, NULL);
    if (ret != LDB_SUCCESS) {
        return ret;
    }

    if ((*result)->count == 0) {
        ldb_debug(ldb, LDB_DEBUG_ERROR, "zentyal: No results!");
        return LDB_ERR_CONSTRAINT_VIOLATION;
    }

    if ((*result)->count > 1) {
        ldb_debug(ldb, LDB_DEBUG_ERROR, "zentyal: Too many results!");
        return LDB_ERR_CONSTRAINT_VIOLATION;
    }

    return ret;
}

static int zentyal_add(struct ldb_module *module, struct ldb_request *req)
{
    struct ldb_context *ldb = NULL;

    ldb = ldb_module_get_ctx(module);

    if (req->operation == LDB_ADD) {
        // Convert the message to JSON format
        char *json_str = NULL;
        json_str = json("LDB_ADD", req->op.add.message->dn, req->op.add.message, NULL);
        if (json_str == NULL) {
            ldb_debug(ldb, LDB_DEBUG_ERROR, "zentyal: Can't create JSON string");
            return LDB_ERR_OPERATIONS_ERROR;
        }

        int ret;
        ret = socket_send(module, json_str);
        free(json_str);
        if (ret)
            return LDB_ERR_OPERATIONS_ERROR;
    }

    return ldb_next_request(module, req);
}

static int zentyal_modify(struct ldb_module *module, struct ldb_request *req)
{
    struct ldb_context *ldb = NULL;
    struct ldb_result *result;

    ldb = ldb_module_get_ctx(module);

    if (req->operation == LDB_MODIFY) {
        struct ldb_dn *dn;
        struct ldb_message *object;
        int ret;

        dn = req->op.mod.message->dn;

        // Get the current attributes of the DN
        ret = search_entry(ldb, dn, &result);
        if (ret != LDB_SUCCESS) {
            return ret;
        }
        object = result->msgs[0];

        // Convert the message to JSON format
        char *json_str = NULL;
        json_str = json("LDB_MODIFY", dn, req->op.mod.message, object);
        if (json_str == NULL) {
            ldb_debug(ldb, LDB_DEBUG_ERROR, "zentyal: Can't create JSON string");
            return LDB_ERR_OPERATIONS_ERROR;
        }

        // Free the search results
        talloc_free(result);

        ret = socket_send(module, json_str);
        free(json_str);
        if (ret)
            return LDB_ERR_OPERATIONS_ERROR;
    }

    return ldb_next_request(module, req);
}

static int zentyal_delete(struct ldb_module *module, struct ldb_request *req)
{
    struct ldb_context *ldb;
    struct ldb_result *result;

    ldb = ldb_module_get_ctx(module);

    if (req->operation == LDB_DELETE) {
        struct ldb_dn *dn;
        struct ldb_message *object;
        int ret;

        dn = req->op.del.dn;

        // Get the sAMAccountName of the DN
        ret = search_entry(ldb, dn, &result);
        if (ret != LDB_SUCCESS) {
            return ret;
        }
        object = result->msgs[0];

        // Convert the message to JSON format
        char *json_str = NULL;
        json_str = json("LDB_DELETE", dn, NULL, object);
        if (json_str == NULL) {
            ldb_debug(ldb, LDB_DEBUG_ERROR, "zentyal: Can't create JSON string");
            return LDB_ERR_OPERATIONS_ERROR;
        }

        // Free the search results
        talloc_free(result);

        ret = socket_send(module, json_str);
        free(json_str);
        if (ret)
            return LDB_ERR_OPERATIONS_ERROR;
    }

	return ldb_next_request(module, req);
}

//static int zentyal_rename(struct ldb_module *module, struct ldb_request *req)
//{
//    int ret;
//    struct ldb_context *ldb;
//        ldb = ldb_module_get_ctx(module);
//    ldb_debug(ldb, LDB_DEBUG_TRACE, "RENAME");
//
//    if (req->operation == LDB_RENAME)
//        ret = perl_call_rename("renameInLdap", req->op.rename.olddn, req->op.rename.newdn);
//
//	return ldb_next_request(module, req);
//}

//static int zentyal_start_trans(struct ldb_module *module)
//{
//    // TODO Implement transactions
//	return ldb_next_start_trans(module);
//}
//
//static int zentyal_end_trans(struct ldb_module *module)
//{
//    // TODO Implement transactions
//	return ldb_next_end_trans(module);
//}
//
//static int zentyal_del_trans(struct ldb_module *module)
//{
//    // TODO Implement transactions
//	return ldb_next_del_trans(module);
//}
//
//static int zentyal_prepare_commit(struct ldb_module *module)
//{
//    // TODO Implement transactions
//    return ldb_next_prepare_commit(module);
//}
//
//static int zentyal_request(struct ldb_module *module, struct ldb_request *req)
//{
//    struct ldb_context *ldb;
//        ldb = ldb_module_get_ctx(module);
//    ldb_debug(ldb, LDB_DEBUG_TRACE, "REQUEST");
//	return ldb_next_request(module, req);
//
//}

static int zentyal_destructor(struct ldb_module *module)
{
    struct private_data *data;

    data = talloc_get_type(ldb_module_get_private(module), struct private_data);

    // Free private data
    talloc_free(data);

    return LDB_SUCCESS;
}

static int zentyal_init(struct ldb_module *module)
{
    struct ldb_context *ldb;
    struct private_data *data;

    ldb = ldb_module_get_ctx(module);

    // Init private data
    data = talloc(module, struct private_data);
    if (data == NULL) {
        ldb_oom(ldb);
        return LDB_ERR_OPERATIONS_ERROR;
    }
    data->socket = -1;
    ldb_module_set_private(module, data);

    talloc_set_destructor(module, zentyal_destructor);

    return ldb_next_init(module);
}

static const struct ldb_module_ops ldb_zentyal_module_ops = {
	.name		       = "zentyal",
	.init_context	   = zentyal_init,
	.add               = zentyal_add,
	.modify            = zentyal_modify,
	.del               = zentyal_delete,
//	.rename            = zentyal_rename,
//	.request      	   = zentyal_request,
//	.start_transaction = zentyal_start_trans,
//	.end_transaction   = zentyal_end_trans,
//	.del_transaction   = zentyal_del_trans,
//  .prepare_commit    = zentyal_prepare_commit,
};

int ldb_init_module(const char *version)
{
	LDB_MODULE_CHECK_VERSION(version);
    return ldb_register_module(&ldb_zentyal_module_ops);
}
