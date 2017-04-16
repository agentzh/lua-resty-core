# vim:set ft= ts=4 sw=4 et fdm=marker:
use lib 'lib';
use Test::Nginx::Socket::Lua;
use Cwd qw(cwd);

#worker_connections(1014);
master_process_enabled(1);
#log_level('error');

repeat_each(2);

plan tests => repeat_each() * (blocks() * 5);

my $pwd = cwd();

our $HttpConfig = <<_EOC_;
    lua_shared_dict dogs 1m;
    lua_package_path "$pwd/lib/?.lua;../lua-resty-lrucache/lib/?.lua;;";
    init_by_lua_block {
        local verbose = false
        if verbose then
            local dump = require "jit.dump"
            dump.on("b", "$Test::Nginx::Util::ErrLogFile")
        else
            local v = require "jit.v"
            v.on("$Test::Nginx::Util::ErrLogFile")
        end

        require "resty.core"
        -- jit.off()
    }

    init_worker_by_lua_block {
        local v
        local typ = ngx.process.type
        for i = 1, 400 do
            v = typ()
        end
        ngx.log(ngx.WARN, "process type: ", v)
    }
_EOC_

#no_diff();
#no_long_string();
check_accum_error_log();
run_tests();

__DATA__

=== TEST 1: sanity
--- http_config eval: $::HttpConfig
--- config
    location = /t {
        content_by_lua_block {
            local v
            local typ = ngx.process.type
            for i = 1, 400 do
                v = typ()
            end
            ngx.say("type: ", v)
        }
    }
--- request
GET /t
--- response_body
type: 3
--- grep_error_log eval
qr/\[TRACE   \d+ init_worker_by_lua:4 loop\]|\[TRACE   \d+ content_by_lua\(nginx\.conf:\d+\):4 loop\]|init_worker_by_lua:7: process type: \d/
--- grep_error_log_out eval
[
"[TRACE   1 init_worker_by_lua:4 loop]
[TRACE   1 content_by_lua(nginx.conf:71):4 loop]
init_worker_by_lua:7: process type: 3
",
"[TRACE   1 init_worker_by_lua:4 loop]
[TRACE   1 content_by_lua(nginx.conf:71):4 loop]
init_worker_by_lua:7: process type: 3
"
]
--- no_error_log
[error]
 -- NYI:
--- skip_nginx: 5: < 1.11.2
