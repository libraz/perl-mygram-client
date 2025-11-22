#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "ppport.h"

#include <mygramdb/mygramclient_c.h>

typedef MygramClient_C* MygramDB__Client;

MODULE = MygramDB::Client    PACKAGE = MygramDB::Client::XS

PROTOTYPES: DISABLE

MygramDB__Client
new(CLASS, host, port, timeout_ms=5000, recv_buffer_size=65536)
    const char* CLASS
    const char* host
    unsigned short port
    unsigned int timeout_ms
    unsigned int recv_buffer_size
  CODE:
    MygramClientConfig_C config = {
        .host = host,
        .port = port,
        .timeout_ms = timeout_ms,
        .recv_buffer_size = recv_buffer_size
    };

    RETVAL = mygramclient_create(&config);
    if (RETVAL == NULL) {
        croak("Failed to create MygramDB client");
    }
  OUTPUT:
    RETVAL

void
DESTROY(client)
    MygramDB__Client client
  CODE:
    if (client) {
        mygramclient_destroy(client);
    }

int
connect(client)
    MygramDB__Client client
  CODE:
    RETVAL = mygramclient_connect(client);
    if (RETVAL != 0) {
        const char* err = mygramclient_get_last_error(client);
        croak("Connection failed: %s", err);
    }
  OUTPUT:
    RETVAL

void
disconnect(client)
    MygramDB__Client client
  CODE:
    mygramclient_disconnect(client);

int
is_connected(client)
    MygramDB__Client client
  CODE:
    RETVAL = mygramclient_is_connected(client);
  OUTPUT:
    RETVAL

const char*
get_last_error(client)
    MygramDB__Client client
  CODE:
    RETVAL = mygramclient_get_last_error(client);
  OUTPUT:
    RETVAL

SV*
search(client, table, query, limit=1000, offset=0)
    MygramDB__Client client
    const char* table
    const char* query
    unsigned int limit
    unsigned int offset
  PREINIT:
    MygramSearchResult_C* result = NULL;
    HV* rh;
    AV* results_av;
    size_t i;
  CODE:
    if (mygramclient_search(client, table, query, limit, offset, &result) != 0) {
        const char* err = mygramclient_get_last_error(client);
        croak("Search failed: %s", err);
    }

    /* Create hash for return value */
    rh = newHV();

    /* Add total_count */
    hv_store(rh, "total_count", 11, newSVuv(result->total_count), 0);

    /* Add results array */
    results_av = newAV();
    for (i = 0; i < result->count; i++) {
        HV* doc_hv = newHV();
        hv_store(doc_hv, "primary_key", 11,
                 newSVpv(result->primary_keys[i], 0), 0);
        av_push(results_av, newRV_noinc((SV*)doc_hv));
    }
    hv_store(rh, "results", 7, newRV_noinc((SV*)results_av), 0);

    RETVAL = newRV_noinc((SV*)rh);

    /* Free C result */
    mygramclient_free_search_result(result);
  OUTPUT:
    RETVAL

SV*
search_advanced(client, table, query, limit, offset, and_terms_av, not_terms_av, filters_hv, sort_column, sort_desc)
    MygramDB__Client client
    const char* table
    const char* query
    unsigned int limit
    unsigned int offset
    SV* and_terms_av
    SV* not_terms_av
    SV* filters_hv
    const char* sort_column
    int sort_desc
  PREINIT:
    MygramSearchResult_C* result = NULL;
    const char** and_terms = NULL;
    size_t and_count = 0;
    const char** not_terms = NULL;
    size_t not_count = 0;
    const char** filter_keys = NULL;
    const char** filter_values = NULL;
    size_t filter_count = 0;
    AV* and_av = NULL;
    AV* not_av = NULL;
    HV* filter_hv = NULL;
    HV* rh;
    AV* results_av;
    size_t i;
  CODE:
    /* Process AND terms */
    if (SvOK(and_terms_av) && SvROK(and_terms_av) && SvTYPE(SvRV(and_terms_av)) == SVt_PVAV) {
        and_av = (AV*)SvRV(and_terms_av);
        and_count = av_len(and_av) + 1;
        if (and_count > 0) {
            Newx(and_terms, and_count, const char*);
            for (i = 0; i < and_count; i++) {
                SV** sv = av_fetch(and_av, i, 0);
                and_terms[i] = sv ? SvPV_nolen(*sv) : "";
            }
        }
    }

    /* Process NOT terms */
    if (SvOK(not_terms_av) && SvROK(not_terms_av) && SvTYPE(SvRV(not_terms_av)) == SVt_PVAV) {
        not_av = (AV*)SvRV(not_terms_av);
        not_count = av_len(not_av) + 1;
        if (not_count > 0) {
            Newx(not_terms, not_count, const char*);
            for (i = 0; i < not_count; i++) {
                SV** sv = av_fetch(not_av, i, 0);
                not_terms[i] = sv ? SvPV_nolen(*sv) : "";
            }
        }
    }

    /* Process filters */
    if (SvOK(filters_hv) && SvROK(filters_hv) && SvTYPE(SvRV(filters_hv)) == SVt_PVHV) {
        filter_hv = (HV*)SvRV(filters_hv);
        filter_count = hv_iterinit(filter_hv);
        if (filter_count > 0) {
            Newx(filter_keys, filter_count, const char*);
            Newx(filter_values, filter_count, const char*);

            HE* entry;
            i = 0;
            while ((entry = hv_iternext(filter_hv)) != NULL) {
                filter_keys[i] = HePV(entry, PL_na);
                SV* val = HeVAL(entry);
                filter_values[i] = SvPV_nolen(val);
                i++;
            }
        }
    }

    /* Call C API */
    if (mygramclient_search_advanced(
            client, table, query, limit, offset,
            and_terms, and_count,
            not_terms, not_count,
            filter_keys, filter_values, filter_count,
            sort_column, sort_desc,
            &result) != 0) {
        const char* err = mygramclient_get_last_error(client);

        /* Clean up allocated memory */
        if (and_terms) Safefree(and_terms);
        if (not_terms) Safefree(not_terms);
        if (filter_keys) Safefree(filter_keys);
        if (filter_values) Safefree(filter_values);

        croak("Search failed: %s", err);
    }

    /* Create hash for return value */
    rh = newHV();
    hv_store(rh, "total_count", 11, newSVuv(result->total_count), 0);

    /* Add results array */
    results_av = newAV();
    for (i = 0; i < result->count; i++) {
        HV* doc_hv = newHV();
        hv_store(doc_hv, "primary_key", 11,
                 newSVpv(result->primary_keys[i], 0), 0);
        av_push(results_av, newRV_noinc((SV*)doc_hv));
    }
    hv_store(rh, "results", 7, newRV_noinc((SV*)results_av), 0);

    RETVAL = newRV_noinc((SV*)rh);

    /* Free C result and allocated memory */
    mygramclient_free_search_result(result);
    if (and_terms) Safefree(and_terms);
    if (not_terms) Safefree(not_terms);
    if (filter_keys) Safefree(filter_keys);
    if (filter_values) Safefree(filter_values);
  OUTPUT:
    RETVAL

UV
count(client, table, query)
    MygramDB__Client client
    const char* table
    const char* query
  PREINIT:
    uint64_t count = 0;
  CODE:
    if (mygramclient_count(client, table, query, &count) != 0) {
        const char* err = mygramclient_get_last_error(client);
        croak("Count failed: %s", err);
    }
    RETVAL = count;
  OUTPUT:
    RETVAL

SV*
get(client, table, primary_key)
    MygramDB__Client client
    const char* table
    const char* primary_key
  PREINIT:
    MygramDocument_C* doc = NULL;
    HV* rh;
    HV* fields_hv;
    size_t i;
  CODE:
    if (mygramclient_get(client, table, primary_key, &doc) != 0) {
        const char* err = mygramclient_get_last_error(client);
        croak("Get failed: %s", err);
    }

    /* Create hash for return value */
    rh = newHV();
    hv_store(rh, "primary_key", 11, newSVpv(doc->primary_key, 0), 0);

    /* Add fields */
    fields_hv = newHV();
    for (i = 0; i < doc->field_count; i++) {
        hv_store(fields_hv, doc->field_keys[i], strlen(doc->field_keys[i]),
                 newSVpv(doc->field_values[i], 0), 0);
    }
    hv_store(rh, "fields", 6, newRV_noinc((SV*)fields_hv), 0);

    RETVAL = newRV_noinc((SV*)rh);

    /* Free C result */
    mygramclient_free_document(doc);
  OUTPUT:
    RETVAL

SV*
info(client)
    MygramDB__Client client
  PREINIT:
    MygramServerInfo_C* info = NULL;
    HV* rh;
    AV* tables_av;
    size_t i;
  CODE:
    if (mygramclient_info(client, &info) != 0) {
        const char* err = mygramclient_get_last_error(client);
        croak("Info failed: %s", err);
    }

    /* Create hash for return value */
    rh = newHV();
    hv_store(rh, "version", 7, newSVpv(info->version, 0), 0);
    hv_store(rh, "uptime_seconds", 14, newSVuv(info->uptime_seconds), 0);
    hv_store(rh, "total_requests", 14, newSVuv(info->total_requests), 0);
    hv_store(rh, "active_connections", 18, newSVuv(info->active_connections), 0);
    hv_store(rh, "index_size_bytes", 16, newSVuv(info->index_size_bytes), 0);
    hv_store(rh, "doc_count", 9, newSVuv(info->doc_count), 0);

    /* Add tables array */
    tables_av = newAV();
    for (i = 0; i < info->table_count; i++) {
        av_push(tables_av, newSVpv(info->tables[i], 0));
    }
    hv_store(rh, "tables", 6, newRV_noinc((SV*)tables_av), 0);

    RETVAL = newRV_noinc((SV*)rh);

    /* Free C result */
    mygramclient_free_server_info(info);
  OUTPUT:
    RETVAL

int
enable_debug(client)
    MygramDB__Client client
  CODE:
    RETVAL = mygramclient_debug_on(client);
    if (RETVAL != 0) {
        const char* err = mygramclient_get_last_error(client);
        croak("Enable debug failed: %s", err);
    }
  OUTPUT:
    RETVAL

int
disable_debug(client)
    MygramDB__Client client
  CODE:
    RETVAL = mygramclient_debug_off(client);
    if (RETVAL != 0) {
        const char* err = mygramclient_get_last_error(client);
        croak("Disable debug failed: %s", err);
    }
  OUTPUT:
    RETVAL

int
replication_stop(client)
    MygramDB__Client client
  CODE:
    RETVAL = mygramclient_replication_stop(client);
    if (RETVAL != 0) {
        const char* err = mygramclient_get_last_error(client);
        croak("Replication stop failed: %s", err);
    }
  OUTPUT:
    RETVAL

int
replication_start(client)
    MygramDB__Client client
  CODE:
    RETVAL = mygramclient_replication_start(client);
    if (RETVAL != 0) {
        const char* err = mygramclient_get_last_error(client);
        croak("Replication start failed: %s", err);
    }
  OUTPUT:
    RETVAL

SV*
parse_search_expression(expression)
    const char* expression
  PREINIT:
    MygramParsedExpression_C* parsed = NULL;
    HV* rh;
    AV* and_av;
    AV* not_av;
    AV* opt_av;
    size_t i;
  CODE:
    if (mygramclient_parse_search_expression(expression, &parsed) != 0) {
        croak("Failed to parse search expression");
    }

    /* Create hash for return value */
    rh = newHV();

    /* Add main_term */
    if (parsed->main_term) {
        hv_store(rh, "main_term", 9, newSVpv(parsed->main_term, 0), 0);
    }

    /* Add and_terms array */
    and_av = newAV();
    for (i = 0; i < parsed->and_count; i++) {
        av_push(and_av, newSVpv(parsed->and_terms[i], 0));
    }
    hv_store(rh, "and_terms", 9, newRV_noinc((SV*)and_av), 0);

    /* Add not_terms array */
    not_av = newAV();
    for (i = 0; i < parsed->not_count; i++) {
        av_push(not_av, newSVpv(parsed->not_terms[i], 0));
    }
    hv_store(rh, "not_terms", 9, newRV_noinc((SV*)not_av), 0);

    /* Add optional_terms array */
    opt_av = newAV();
    for (i = 0; i < parsed->optional_count; i++) {
        av_push(opt_av, newSVpv(parsed->optional_terms[i], 0));
    }
    hv_store(rh, "optional_terms", 14, newRV_noinc((SV*)opt_av), 0);

    RETVAL = newRV_noinc((SV*)rh);

    /* Free C result */
    mygramclient_free_parsed_expression(parsed);
  OUTPUT:
    RETVAL
