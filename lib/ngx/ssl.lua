-- Copyright (C) Yichun Zhang (agentzh)


local ffi = require "ffi"
local base = require "resty.core.base"
local bit = require "bit"


local C = ffi.C
local ffi_str = ffi.string
local ffi_gc = ffi.gc
local getfenv = getfenv
local error = error
local tonumber = tonumber
local errmsg = base.get_errmsg_ptr()
local get_string_buf = base.get_string_buf
local get_string_buf_size = base.get_string_buf_size
local get_size_ptr = base.get_size_ptr
local FFI_DECLINED = base.FFI_DECLINED
local FFI_OK = base.FFI_OK
local bor = bit.bor
local ERR_BUF_SIZE = 256


ffi.cdef[[

struct ngx_ssl_conn_s;
typedef struct ngx_ssl_conn_s  ngx_ssl_conn_t;

int ngx_http_lua_ffi_ssl_set_der_certificate(ngx_http_request_t *r,
    const char *data, size_t len, char **err);

int ngx_http_lua_ffi_ssl_clear_certs(ngx_http_request_t *r, char **err);

int ngx_http_lua_ffi_ssl_set_der_private_key(ngx_http_request_t *r,
    const char *data, size_t len, char **err);

int ngx_http_lua_ffi_ssl_raw_server_addr(ngx_http_request_t *r, char **addr,
    size_t *addrlen, int *addrtype, char **err);

int ngx_http_lua_ffi_ssl_server_name(ngx_http_request_t *r, char **name,
    size_t *namelen, char **err);

int ngx_http_lua_ffi_cert_pem_to_der(const unsigned char *pem, size_t pem_len,
    unsigned char *der, char **err);

int ngx_http_lua_ffi_priv_key_pem_to_der(const unsigned char *pem,
    size_t pem_len, unsigned char *der, char **err);

int ngx_http_lua_ffi_ssl_get_tls1_version(ngx_http_request_t *r, char **err);

void *ngx_http_lua_ffi_parse_pem_cert(const unsigned char *pem,
    size_t pem_len, char **err);

void *ngx_http_lua_ffi_parse_pem_priv_key(const unsigned char *pem,
    size_t pem_len, char **err);

int ngx_http_lua_ffi_set_cert(void *r, void *cdata, char **err);

int ngx_http_lua_ffi_set_priv_key(void *r, void *cdata, char **err);

void ngx_http_lua_ffi_free_cert(void *cdata);

void ngx_http_lua_ffi_free_priv_key(void *cdata);

void *ngx_http_lua_ffi_ssl_ctx_init(unsigned int protocols, char **err);

void ngx_http_lua_ffi_ssl_ctx_free(void *cdata);

int ngx_http_lua_ffi_ssl_ctx_set_priv_key(void *cdata_ctx, void *cdata_key,
    unsigned char *ssl_err_buf, size_t *ssl_err_buf_len);

int ngx_http_lua_ffi_ssl_ctx_set_cert(void *cdata_ctx, void *cdata_cert,
    unsigned char *ssl_err_buf, size_t *ssl_err_buf_len);

]]


local _M = { version = base.version }


local charpp = ffi.new("char*[1]")
local intp = ffi.new("int[1]")
local err_buf = ffi.new("unsigned char *[1]")


function _M.clear_certs()
    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    local rc = C.ngx_http_lua_ffi_ssl_clear_certs(r, errmsg)
    if rc == FFI_OK then
        return true
    end

    return nil, ffi_str(errmsg[0])
end


function _M.set_der_cert(data)
    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    local rc = C.ngx_http_lua_ffi_ssl_set_der_certificate(r, data, #data,
                                                          errmsg)
    if rc == FFI_OK then
        return true
    end

    return nil, ffi_str(errmsg[0])
end


function _M.set_der_priv_key(data)
    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    local rc = C.ngx_http_lua_ffi_ssl_set_der_private_key(r, data, #data,
                                                          errmsg)
    if rc == FFI_OK then
        return true
    end

    return nil, ffi_str(errmsg[0])
end


local addr_types = {
    [0] = "unix",
    [1] = "inet",
    [2] = "inet6",
}


function _M.raw_server_addr()
    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    local sizep = get_size_ptr()

    local rc = C.ngx_http_lua_ffi_ssl_raw_server_addr(r, charpp, sizep,
                                                      intp, errmsg)
    if rc == FFI_OK then
        local typ = addr_types[intp[0]]
        if not typ then
            return nil, nil, "unknown address type: " .. intp[0]
        end
        return ffi_str(charpp[0], sizep[0]), typ
    end

    return nil, nil, ffi_str(errmsg[0])
end


function _M.server_name()
    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    local sizep = get_size_ptr()

    local rc = C.ngx_http_lua_ffi_ssl_server_name(r, charpp, sizep, errmsg)
    if rc == FFI_OK then
        return ffi_str(charpp[0], sizep[0])
    end

    if rc == FFI_DECLINED then
        return nil
    end

    return nil, ffi_str(errmsg[0])
end


function _M.cert_pem_to_der(pem)
    local outbuf = get_string_buf(#pem)

    local sz = C.ngx_http_lua_ffi_cert_pem_to_der(pem, #pem, outbuf, errmsg)
    if sz > 0 then
        return ffi_str(outbuf, sz)
    end

    return nil, ffi_str(errmsg[0])
end


function _M.priv_key_pem_to_der(pem)
    local outbuf = get_string_buf(#pem)

    local sz = C.ngx_http_lua_ffi_priv_key_pem_to_der(pem, #pem, outbuf, errmsg)
    if sz > 0 then
        return ffi_str(outbuf, sz)
    end

    return nil, ffi_str(errmsg[0])
end


local function get_tls1_version()

    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    local ver = C.ngx_http_lua_ffi_ssl_get_tls1_version(r, errmsg)

    ver = tonumber(ver)

    if ver >= 0 then
        return ver
    end

    -- rc == FFI_ERROR

    return nil, ffi_str(errmsg[0])
end
_M.get_tls1_version = get_tls1_version


function _M.parse_pem_cert(pem)
    local cert = C.ngx_http_lua_ffi_parse_pem_cert(pem, #pem, errmsg)
    if cert ~= nil then
        return ffi_gc(cert, C.ngx_http_lua_ffi_free_cert)
    end

    return nil, ffi_str(errmsg[0])
end


function _M.parse_pem_priv_key(pem)
    local pkey = C.ngx_http_lua_ffi_parse_pem_priv_key(pem, #pem, errmsg)
    if pkey ~= nil then
        return ffi_gc(pkey, C.ngx_http_lua_ffi_free_priv_key)
    end

    return nil, ffi_str(errmsg[0])
end


function _M.set_cert(cert)
    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    local rc = C.ngx_http_lua_ffi_set_cert(r, cert, errmsg)
    if rc == FFI_OK then
        return true
    end

    return nil, ffi_str(errmsg[0])
end


function _M.set_priv_key(priv_key)
    local r = getfenv(0).__ngx_req
    if not r then
        return error("no request found")
    end

    local rc = C.ngx_http_lua_ffi_set_priv_key(r, priv_key, errmsg)
    if rc == FFI_OK then
        return true
    end

    return nil, ffi_str(errmsg[0])
end


_M.PROTOCOL_SSLv2 = 0x0002
_M.PROTOCOL_SSLv3 = 0x0004
_M.PROTOCOL_TLSv1 = 0x0008
_M.PROTOCOL_TLSv1_1 = 0x0010
_M.PROTOCOL_TLSv1_2 = 0x0020
local default_protocols = bor(_M.PROTOCOL_SSLv3, _M.PROTOCOL_TLSv1,
                              _M.PROTOCOL_TLSv1_1, _M.PROTOCOL_TLSv1_2)


function _M.create_ctx(options)
    if type(options) ~= 'table' then
        return nil, "no options found"
    end

    local protocols = options.protocols or default_protocols

    local ctx = C.ngx_http_lua_ffi_ssl_ctx_init(protocols, errmsg)
    if ctx == nil then
        return nil, ffi_str(errmsg[0])
    end

    ctx = ffi_gc(ctx, C.ngx_http_lua_ffi_ssl_ctx_free)

    local err_buf = get_string_buf(ERR_BUF_SIZE)
    local err_buf_len = get_size_ptr()
    err_buf_len[0] = ERR_BUF_SIZE

    if options.cert ~= nil then
        local rc = C.ngx_http_lua_ffi_ssl_ctx_set_cert(ctx, options.cert,
                                                       err_buf,
                                                       err_buf_len)
        if rc ~= FFI_OK then
            return nil, ffi_str(err_buf, err_buf_len[0])
        end
    end

    if options.priv_key ~= nil then
        local rc = C.ngx_http_lua_ffi_ssl_ctx_set_priv_key(ctx,
                                                           options.priv_key,
                                                           err_buf,
                                                           err_buf_len)
        if rc ~= FFI_OK then
            return nil, ffi_str(err_buf, err_buf_len[0])
        end
    end

    return ctx
end


do
    _M.SSL3_VERSION = 0x0300
    _M.TLS1_VERSION = 0x0301
    _M.TLS1_1_VERSION = 0x0302
    _M.TLS1_2_VERSION = 0x0303

    local map = {
        [_M.SSL3_VERSION] = "SSLv3",
        [_M.TLS1_VERSION] = "TLSv1",
        [_M.TLS1_1_VERSION] = "TLSv1.1",
        [_M.TLS1_2_VERSION] = "TLSv1.2",
    }

    function _M.get_tls1_version_str()
        local ver, err = get_tls1_version()
        if not ver then
            return nil, err
        end
        return map[ver]
    end
end


return _M
