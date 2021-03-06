For advanced configuration use the following files:

* `ejabberd.cfg` for pure MongooseIM settings,

* `vm.args` to affect the Erlang VM behaviour (performance tuning, node name),

* `app.config` to change low-level logging parameters and settings of other Erlang applications.

Since you've gotten this far, we assume you're already familiar with Erlang syntax.

# ejabberd.cfg

This file consists of multiple erlang tuples terminated with a period.
In order to configure it, go to `[MongooseIM repo root]/rel/files/` (if you're building from source) or `[MongooseIM install root]/etc/` if you're using a pre-built version.

The tuple order is important, unless no `host_config` option is set.
Retaining the default layout is recommended so that the experienced MongooseIM users can smoothly traverse the file.

`ejabberd.cfg` is full of useful comments and in most cases they should be sufficient help in changing the configuration.

## Options

* All options except `hosts`, `host`, `host_config`, `pool` and the ODBC options can be used in the `host_config` tuple.

* There are two kinds of local options - those that are kept separately for each domain in the config file (defined inside `host_config`) and the options local for a node in the cluster.

* "global" options are shared by all cluster nodes and all domains.

* Options labeled as "multi" (in this page) can be declared multiple times in a row, e.g. one per domain.

* Section names below correspond with the ones in the file.

### Override stored options

* **override_global, override_local, override_acls** - optional
    * **Description:** Will cause MongooseIM to erase all global/local/acl options in database respectively. This ensures that ALL settings of a specific type will be reloaded on startup.

### Debugging

* **loglevel** (local)
    * **Description:** Log level configured with an integer: 0 (disabled), 1 (critical), 2 (error), 3 (warning), 4 (info), 5 (debug). Recommended values for production systems are 2 or 3 (5 is for development).


### Served hostnames

* **hosts** (global)
    * **Description:** List of domains supported by this cluster.
    * **Warning:** Extension modules and database backends will be started separately for every domain. When increasing the number of domains please make sure you have enough resources available (e.g. connection limit set in DBMS).
    * **Example:** `["localhost", "domain2"]`

* **route_subdomain** (local)
    * **Description:** If a stanza is addressed to a subdomain of the served domain and this option is set to `s2s`, such a stanza will be transmitted over s2s. Without it, MongooseIM will try to route the stanza to one of the internal services.
    * **Note:** `s2s` is the only valid value. Any other will simply disable the feature.

### Listening ports

* **listen** (local)
    * **Description:** List of modules handling the incoming connections. By default, 3 are enabled: `ejabberd_cowboy`, `ejabberd_c2s` and `ejabberd_s2s_in`. They accept XMPP, BOSH, Websocket and S2S connections (plus queries to metrics API).
    * **Syntax:** List of tuples: `{Port, Module, ModuleSpecificOptions}`
    * **See also:** [Listener modules](advanced-configuration/Listener-modules.md)

* **s2s_use_starttls** (global)
    * **Description:** Controls StartTLS feature for S2S connections.
    * **Values:**
        * `false`
        * `optional`
        * `required`
        * `required_trusted` - uses OpenSSL's function [SSL_get_verify_result](http://www.openssl.org/docs/ssl/SSL_get_verify_result.html)

* **s2s_certfile** (global)
    * **Description:** Path to X509 PEM file with a certificate and a private key inside (not protected by any password). Required if `s2s_use_starttls` is enabled.

* **s2s_ciphers** (global)
    * **Description:** Defines a list of accepted SSL ciphers in **outgoing** S2S connection. Please refer to the [OpenSSL documentation](http://www.openssl.org/docs/apps/ciphers.html) for the cipher string format.
    * **Default:** As of OpenSSL 1.0.0 it's `ALL:!aNULL:!eNULL` ([source](https://www.openssl.org/docs/apps/ciphers.html#CIPHER_STRINGS))

* **domain_certfile** (multi, global)
    * **Description:** Overrides common certificates with new ones specific for chosen XMPP domains.
                       Applies to S2S and C2S connections.
    * **Syntax:** `{domain_certfile, "example.com", "/path/to/example.com.pem"}.`

* **s2s_default_policy** (local)
    * **Description:** Default policy for a new S2S (server-to-server) **both incoming and outgoing** connection to/from an unknown remote server.

* **s2s_host** (multi, local)
    * **Description:** Allows black/whitelisting S2S destinations.
    * **Syntax:** `{ {s2s_host, "somehost.com"}, allow|deny }.`

* **outgoing_s2s_port** (local)
    * **Description:** Defines a port to be used for outgoing S2S connections. Cannot be random.
    * **Default:** 5269

* **s2s_addr** (multi, global)
    * **Description:** Override DNS lookup for a specific non-local XMPP domain and use a predefined server IP and port for S2S connection.
    * **Syntax:** `"{ {s2s_addr, \"some-domain\"}, { {10,20,30,40}, 7890 } }."`

* **outgoing_s2s_options** (global)
    * **Description:** Specifies the order of address families to try when establishing S2S connection and the connection timeout (in milliseconds or atom `infinity`).
    * **Default:** `{outgoing_s2s_options, [ipv4, ipv6], 10000}.`
    * **Family values:** `inet4`/`ipv4`, `inet6`/`ipv6`

* **s2s_shared** (global)
    * **Description:** S2S shared secret used in [Server Dialback](https://xmpp.org/extensions/xep-0220.html) extension.
    * **Syntax:** `{s2s_shared, <<"shared secret">>}`.
    * **Default:** 10 strong random bytes, hex-encoded.

* **s2s_dns_options** (local)
    * **Description:** Parameters used in DNS lookups for outgoing S2S connections.
    * **Syntax:** `{s2s_dns_options, [{Opt, Val}, ...]}.`
    * **Supported options**
        * `timeout` (integer, seconds, default: 10) - A timeout for DNS lookup.
        * `retries` (integer, default: 2) - How many DNS lookups will be attempted.
    * **Example:** `{s2s_dns_options, [{timeout, 30}, {retries, 1}]}.`

* **s2s_max_retry_delay** (local)
    * **Description:** How many seconds MIM node should wait until next attempt to connect to remote XMPP cluster.
    * **Syntax:** `{s2s_max_retry_delay, Delay}.`
    * **Default:** 300
    * **Example:** `{s2s_max_retry_delay, 30}.`

### Session backend

* **sm_backend** (global)
    * **Description:** Backend for storing user session data. Currently all nodes in a cluster must have access to a complete session database. Valid backends are `mnesia` and `redis`. Mnesia is sufficient in most cases, use Redis only in large deployments.
    * **Mnesia:** `{sm_backend, {mnesia, []}}`
    * **Redis:** `{redis, [{pool_size, Size}, {worker_config, [{host, "Host"}, {port, Port}]}]}}`

### LDAP Connection
* **ldap_servers**
    * **Description:** List of IP addresses or DNS names of your LDAP servers.
    * **Values:** `[Servers, ...]`
    * **Default:**  no default value. This option is required when setting up an LDAP connection.

* **ldap_encrypt**
    * **Description:** Enable connection encryption with your LDAP server.
        The value tls enables encryption by using LDAP over SSL. Note that STARTTLS encryption is not supported.
    * **Values:** `none`, `tls`
    * **Default:** `none`

* **ldap_tls_verify** This option specifies whether to verify LDAP server certificate or not when TLS is enabled.
    When `hard` is enabled mongooseim doesn’t proceed if a certificate is invalid.
    When `soft` is enabled mongooseim proceeds even if the check fails.
    `False` means no checks are performed.
    * **Values:** `soft`, `hard`, `false`
    * **Default:** `false`

* **ldap_tls_cacertfile**
    * **Description:** Path to a file containing PEM encoded CA certificates.
    * **Values:** Path
    * **Default:** This option is needed (and required) when TLS verification is enabled.

* **ldap_tls_depth**
    * **Description:**  Specifies the maximum verification depth when TLS verification is enabled.
         i.e. how far in a chain of certificates the verification process can proceed before the verification is considered to fail.
         Peer certificate = 0, CA certificate = 1, higher level CA certificate = 2, etc. The value 2 means that a chain can at most contain peer cert, CA cert, next CA cert, and an additional CA cert.
    * **Values:** Integer
    * **Default:** 1

* **ldap_port**
    * **Description:** Port to connect to your LDAP server.
    * **Values:** Integer
    * **Default:** 389 if encryption is disabled. 636 if encryption is enabled.

* **ldap_rootdn**
    * **Description:** Bind DN
    * **Values:** String
    * **Default:** empty string which is `anonymous connection`

* **ldap_password**
    * **Description:** Bind password
    * **Values:** String
    * **Default:** empty string

* **ldap_deref**
    * **Description:** Whether or not to dereference aliases
    * **Values:** `never`, `always`, `finding`, `searching`
    * **Default:** `never`

### Authentication

* **auth_method** (local)
    * **Description:** Chooses an authentication module or a list of modules. Modules from a list are queried one after another until one of them replies positively.
    * **Valid values:** `internal` (Mnesia), `odbc`, `external`, `anonymous`, `ldap`, `jwt`, `riak`, `http`
    * **Warning:** `external`, `jwt` and `ldap` work only with `PLAIN` SASL mechanism.
    * **Examples:** `odbc`, `[internal, anonymous]`

* **auth_opts** (local)
    * **Description:** Provides different parameters that will be applied to a choosen authentication method.
                       `auth_password_format` and `auth_scram_iterations` are common to `http`, `odbc`, `internal` and `riak`.

        * **auth_password_format**
             * **Description:** Decide whether user passwords will be kept plain or hashed in the database. Currently the popular XMPP clients support the SCRAM method, so it is strongly recommended to use the hashed version. The older ones can still use `PLAIN` mechiansm. `DIGEST-MD5` is not available with `scram`.
             * **Values:** `plain`, `scram`
             * **Default:** `plain` (for compatibility reasons, might change soon)

        * **auth_scram_iterations**
             * **Description:** Hash function round count. The higher the value, the more difficult breaking the hashes is. We advise against setting it too low.
             * **Default:** 4096

        * [`external` backend options](authentication-backends/External-authentication-module.md#configuration-options)

        * [`http` backend options](authentication-backends/HTTP-authentication-module.md#configuration-options)

        * [`jwt` backend options](authentication-backends/JWT-authentication-module.md#configuration-options)

* `ldap` backend options are not yet a part of `auth_opt` tuple, so [these parameters](authentication-backends/LDAP-authentication-module.md#configuration-options) are top-level keys in `ejabberd.cfg` file.

* **sasl_mechanisms** (local)
    * **Description:** Specifies a list of allowed SASL mechanisms. It affects the methods announced during stream negotiation and is enforced eventually (user can't pick mechanism not listed here but available in the source code).
    * **Warning:** This list is still filtered by auth backends capabilities, e.g. LDAP authentication requires a password provided via SASL PLAIN.
    * **Valid values:** `cyrsasl_plain, cyrsasl_digest, cyrsasl_scram, cyrsasl_anonymous, cyrsasl_oauth`
    * **Default:** `[cyrsasl_plain, cyrsasl_digest, cyrsasl_scram, cyrsasl_anonymous, cyrsasl_oauth]`
    * **Examples:** `[cyrsasl_plain]`, `[cyrsasl_anonymous, cyrsasl_scram]`

* **extauth_instances** (local)
    * **Description:** Specifies a number of workers serving external authentication requests.
    * **Syntax:** `{extauth_instances, Count}.`
    * **Default:** 1

### RDMBS connection setup

The following options can be used to configure RDMBS connection pools.
To set the options for all connection pools, put them on the top level of the configuration file.
To set them for an individual pool, put them inside the `Options` list in a pool specification.
Setting `odbc_server` is mandatory if connection details are not provided in pool tuples directly.

*Note*: `odbc` prefixes may be misleading. The options apply to all kinds of RDBMS connections, not only pure ODBC.

Please remember that SQL databases require creating a schema.
See [Database backends configuration](./advanced-configuration/database-backends-configuration.md) for more information.

* **pool** (multi, local)
    * **Description:** Declares a named pool of connections to the database.
    At least one pool is required to connect to an SQL database.
    * **Syntax:** `{pool, odbc, PoolName}.` or `{pool, odbc, PoolName, Options}.`
    * **Examples:** `{pool, odbc, default}.`

* **odbc_pool** (local)
    * **Description:** Name of the default connection pool used to connect to the database.
    * **Syntax:** `{odbc_pool, PoolName}`
    * **Default:** `default`

* **odbc_pool_size** (local)
    * **Description:** How many DB client workers should be started per each domain.
    * **Syntax:** `{odbc_pool_size, Size}`.
    * **Default:** 10

* **odbc_server** (local)
    * **Description:** SQL DB connection configuration. Currently supported DB types are `mysql` and `pgsql`.
    * **Syntax:** `{odbc_server, {Type, Host, Port, DBName, Username, Password}}.` **or** `{odbc_server, "<ODBC connection string>"}`
    * **Default:** `undefined`

* **pgsql_users_number_estimate** (local)
    * **Description:** PostgreSQL's internal structure can make the row counting slow.
    Enabling this option uses alternative query to `SELECT COUNT`, that might be not as accurate but is always fast.
    * **Syntax:** `{pgsql_users_number_estimate, false | true}`
    * **Default:** `false`

* **odbc_keepalive_interval** (local)
    * **Description:** When enabled, will send `SELECT 1` query through every DB connection at given interval to keep them open.
    This option should be used to ensure that database connections are restarted after they became broken (e.g. due to a database restart or a load balancer dropping connections).
    Currently, not every network related error returned from a database driver to a regular query will imply a connection restart.
    * **Syntax:** `{odbc_keepalive_interval, IntervalSeconds}.`
    * **Example:** `{odbc_keepalive_interval, 30}.`
    * **Default:** `undefined`

* **odbc_server_type** (local)
    * **Description:** Specifies RDBMS type. Some modules may optimise queries for certain DBs (e.g. `mod_mam_odbc_user` uses different query for `mssql`).
    * **Syntax:** `{odbc_server_type, Type}`
    * **Supported values:** `mssql`, `pgsql` or `undefined`
    * **Default:** `undefined`

### MySQL and PostgreSQL SSL connection setup

In order to establish a secure connection with a database additional options must be passed in aforementioned `odbc_server` tuple.
Here is the proper syntax:

`{odbc_server, {Type, Host, Port, DBName, Username, Password, SSL}}.`

#### MySQL

SSL configuration options for MySQL:

* **SSL**
    * **Description:** Specifies SSL connection options.
    * **Syntax:** `[Opt]`
    * **Supported values:** The options are just a **list** of Erlang `ssl:ssl_option()`. More details can be found in [official Erlang ssl documentation](http://erlang.org/doc/man/ssl.html).

##### Example configuration

An example configuration can look as follows:

`{odbc_server, {mysql, "localhost", "username", "database", "pass",
               [{verify, verify_peer}, {cacertfile, "path/to/cacert.pem"}]}}`

#### PostgreSQL

SSL configuration options for PGSQL:

* **SSL**
    * **Description:** Specifies general options for SSL connection.
    * **Syntax:** `[SSLMode, SSLOpts]`

* **SSLMode**
    * **Description:** Specifies a mode of SSL connection. Mode expresses how much the PostgreSQL driver carries about security of the connections.
    For more information click [here](https://github.com/epgsql/epgsql).
    * **Syntax:** `{ssl, Mode}`
    * **Supported values:** `false`, `true`, `required`

* **SSLOpts**
    * **Description:** Specifies SSL connection options.
    * **Syntax:** `{ssl_opts, [Opt]}`
    * **Supported values:** The options are just a **list** of Erlang `ssl:ssl_option()`. More details can be found in [official Erlang ssl documentation](http://erlang.org/doc/man/ssl.html).

##### Example configuration

An example configuration can look as follows:

`{odbc_server, {pgsql, "localhost", "username", "database", "pass",
               [{ssl, required}, {ssl_opts, [{verify, verify_peer}, {cacertfile, "path/to/cacert.pem"}]}]}}.`

### ODBC SSL connection setup

If you've configured MongooseIM to use an ODBC driver, i.e. you've provided an ODBC connection string to `odbc_server` option, e.g.

```erlang
{odbc_server, "DSN=mydb"}.
```

then the SSL options, along other connection options, should be present in the `~/.odbc.ini` file.

To enable SSL connection the `sslmode` option needs to be set to `verify-full`.
Additionally, you can provide the path to the CA certificate using the `sslrootcert` option.

#### Example ~/.odbc.ini configuration

```
[mydb]
Driver      = ...
ServerName  = ...
Port        = ...
...
sslmode     = verify-full
sslrootcert = /path/to/ca/cert
```

### Riak connection setup

Only one Riak connection pool can exist per each supported XMPP host.
It is configured with single tuple.

* **riak_server** (local)
    * **Description:** Declares a Riak connection pool with provided options.
    Autmatic reconnect and keepalive features are always enabled in the driver.
    * **Syntax:** `{riak_server, OptionList}.`
    * **Options:**
        * **pool_size** - A positive integer.
        * **address** - A string with IP or hostname.
        * **port** - A positive integer.
    * **Example:** `{riak_server, [{pool_size, 20}, {address, "127.0.0.1"}, {port, 8087}]}.`

#### Riak SSL connection setup

Using SSL for Riak connection requires passing extra options to the
aforementioned `riak_server` tuple.

Here is the proper syntax:

`{riak_server, [{pool_size, 20}, {address, "127.0.0.1"}, {port, 8087}, Credentials, CACert]}.`

* **Credentials**
    * **Description:** Specifies credentials to use to connect to the database.
    * **Syntax:** `{credentials, User, Password}`
    * **Supported values** `User` and `Password` are strings with a database username and password respectively.

* **CACert**
    * **Description:** Specifies a path to the CA certificate that was used to sign the database certificates.
    * **Syntax:** `{cacertfile, Path}`
    * **Supported values** `Path` is a string with a path to the CA certificate file.

##### Example configuration

An example configuration can look as follows:

`{riak_server, [{pool_size, 20}, {address, "127.0.0.1"}, {port, 8087},
               {credentials, "username", "pass"}, {cacertfile, "path/to/cacert.pem"}]}.`

### Cassandra connection setup

Cassandra connection pools are defined in a manner similar to RDBMS ones, but with a slightly different syntax.
All pools are grouped in `cassandra_servers` tuple and per-pool connection parameters can be provided.
If they are not present - defaults are used (connection to `localhost:9042` with 1 worker).

* **cassandra_servers** (local)
    * **Description:** Declares Cassandra connection pool(s) with provided options.
    * **Syntax:** `{cassandra_servers, [ PoolDefinition1, PoolDefinition2, ... ]}`

#### Pool definition

* **Syntax:** `{PoolName, WorkerCount, ConnectionParamsList}`
* **Elements:**
    * **PoolName** (atom) - A unique identifier used by modules that make requests to Cassandra.
    * **WorkerCount** (positive integer) - How many connections should be open to every node in Cassandra cluster.
    Cassandra database layer creates `4 * WorkerCount` workers as a intermediary between the caller and DB driver.
    * **ConnectionParamsList**

#### Connection parameters

* **servers** - A list of servers in Cassandra cluster in `{HostnameOrIP, Port}` format.
* **keyspace** - A name of keyspace to use in queries executed in this pool.
* You can find a full list in `cqerl` [documentation](https://github.com/matehat/cqerl#all-modes).

#### Example

```
{cassandra_servers,
 [
  {default, 100,
   [
    {servers, [{"cassandra_server1.example.com", 9042}, {"cassandra_server2.example.com", 9042}] },
    {keyspace, "big_mongooseim"}
   ]}
 ]}.
```

#### SSL connection setup

In order to establish a secure connection to Cassandra you must make some changes in the MongooseIM and Cassandra configuration files.

##### Create server keystore
Follow [this](https://docs.datastax.com/en/cassandra/3.0/cassandra/configuration/secureSSLCertWithCA.html) guide if you need to create certificate files.

##### Change the Cassandra configuration file
Find `client_encryption_options` in `cassandra.yaml` and make these changes:
```
client_encryption_options:
    enabled: true
    keystore: /your_certificate_directory/server.keystore
    keystore_password: your_password
```
Save the changes and restart Cassandra.

##### Enable MongooseIM to connect with SSL
An SSL connection can be established with both self-signed and CA-signed certificates.

###### Self-signed certificate

Find `cassandra_servers` in `ejabberd.cfg` and add the following line:
```
{cassandra_servers, [{default, [{ssl, [{verify, verify_none}]}]}]}.
```
Save the changes and restart MongooseIM.

###### CA-signed certificate

Find `cassandra_servers` in `ejabberd.cfg` and add the following line:
```
{cassandra_servers, [{default, [{ssl, [{cacertfile,
                                        "/path/to/rootCA.pem"},
                                        {verify, verify_peer}]}]}]}.
```
Save the changes and restart MongooseIM.

##### Testing the connection

Make sure Cassandra is running and then run MongooseIM in live mode:
 ```
 $ ./mongooseim live
 $ (mongooseim@localhost)1> cqerl:get_client(default).
 {ok,{<0.474.0>,#Ref<0.160699839.1270874114.234457>}}
 $ (mongooseim@localhost)2> sys:get_state(pid(0,474,0)).
 {live,{client_state,cqerl_auth_plain_handler,undefined,
                    undefined,
                    {"localhost",9042},
                    ssl,
                    {sslsocket,{gen_tcp,#Port<0.8458>,tls_connection,undefined},
                               <0.475.0>},
                    undefined,mongooseim,infinity,<<>>,undefined,
                    [...],
                    {[],[]},
                    [0,1,2,3,4,5,6,7,8,9,10,11|...],
                    [],hash,
                    {{"localhost",9042},
                     [...]}}}
 ```
If no errors occurred and your output is similar to the one above then your MongooseIM and Cassandra nodes can communicate over SSL.

### ElasticSearch connection setup

Currently MongooseIM allows to create only a single pool of connections to a single ElasticSearch node.
To enable a pool you need to add `elasticsearch_server` option in `ejabberd.cfg`:

```
{elasticsearch_server, [Option1, Option2]}.
```

Options include:
* `host` (default: `"localhost"`) - hostname or IP address of ElasticSearch node
* `port` (default: `9200`) - port the ElasticSearch node's HTTP API is listening on

You can verify that MongooseIM has established the connection by running the following function in the MongooseIM shell:

```
1> mongoose_elasticsearch:health().
{ok,#{<<"active_primary_shards">> => 15,<<"active_shards">> => 15,
       <<"active_shards_percent_as_number">> => 50.0,
       <<"cluster_name">> => <<"docker-cluster">>,
       <<"delayed_unassigned_shards">> => 0,
       <<"initializing_shards">> => 0,
       <<"number_of_data_nodes">> => 1,
       <<"number_of_in_flight_fetch">> => 0,
       <<"number_of_nodes">> => 1,
       <<"number_of_pending_tasks">> => 0,
       <<"relocating_shards">> => 0,
       <<"status">> => <<"yellow">>,
       <<"task_max_waiting_in_queue_millis">> => 0,
       <<"timed_out">> => false,
       <<"unassigned_shards">> => 15}}
```

Note that the output might differ based on your ElasticSearch cluster configuration.

### Outgoing HTTP connections

The `http_connections` option configures a list of named pools of outgoing HTTP connections that may be used by various modules. Each of the pools has a name (atom) and a list of options:

* **Syntax:** `{http_connections, [{PoolName1, PoolOptions1}, {PoolName2, PoolOptions2}, ...]}.`

Following pool options are recognized - all of them are optional.

* `{server, HostName}` - string, default: `"http://localhost"` - the URL of the destination HTTP server (including a port number if needed).
* `{pool_size, Number}` - positive integer, default: `20` - number of workers in the connection pool.
* `{max_overflow, Number}` - non-negative integer, default: `5` - maximum number of extra workers that can be allocated when the whole pool is busy.
* `{path_prefix, Prefix}` - string, default: `"/"` - the part of the destination URL that is appended to the host name (`host` option).
* `{pool_timeout, TimeoutValue}` - non-negative integer, default: `200` - maximum number of milliseconds to wait for an available worker from the pool.
* `{request_timeout, TimeoutValue}` - non-negative integer, default: `2000` - maximum number of milliseconds to wait for the HTTP response.

**Example:**
```
{http_connections, [{conn1, [{server, "http://my.server:8080"},
                             {pool_size, 50},
                             {path_prefix, "/my/path/"}]}
                   ]}.
```

### Traffic shapers

* **shaper** (mutli, global)
    * **Description:** Define a class of a shaper which is a mechanism for limiting traffic to prevent DoS attack or calming down too noisy clients.
    * **Syntax:** `{shaper, AtomName, {maxrate, BytesPerSecond}}`

* **max_fsm_queue** (local)
    * **Description:** When enabled, will terminate certain processes (e.g. client handlers) that exceed message limit, to prevent resource exhaustion.
                       This option is set for C2S, outgoing S2S and component connections and can be overridden for particular `ejabberd_s2s` or `ejabberd_service` listeners in their configurations.
                       **Use with caution!**
    * **Syntax:** `{max_fsm_queue, MaxFsmQueueLength}`

### Access control lists

* **acl** (multi)
    * **Description:** Define access control list class.
    * **Syntax:** `{acl, AtomName, Definition}`
    * **Regexp format:** Syntax for `_regexp` can be found in [Erlang documentation](http://www.erlang.org/doc/man/re.html) - it's based on AWK syntax. For `_glob` use `sh` regexp syntax.
    * **Valid definitions:**
        * `all`
        * `{user, U}` - check if the username equals `U` and the domain either equals the one specified by the module executing the check or (if the module does a `global` check) is on the served domains list (`hosts` option)
        * `{user, U, S}` - check if the username equals `U` and the domain equals `S`
        * `{server, S}` - check if the domain equals `S`
        * `{resource, R}` - check if the resource equals `R`
        * `{user_regexp, UR}` - perform a regular expression `UR` check on the username and check the server name like in `user`
        * `{user_regexp, UR, S}` - perform a regular expression `UR` check on the username and check if the domain equals `S`
        * `{server_regexp, SR}` - perform a regular expression `SR` check on a domain
        * `{resource_regexp, RR}` - perform a regular expression `SR` check on a resource
        * `{node_regexp, UR, SR}` - username must match `UR` and domain must match `SR`
        * `{user_glob, UR}` - like `_regexp` variant but with `sh` syntax
        * `{server_glob, UR}` - like `_regexp` variant but with `sh` syntax
        * `{resource_glob, UR}` - like `_regexp` variant but with `sh` syntax
        * `{node_glob, UR}` - like `_regexp` variant but with `sh` syntax

### Access rules

* **access** (multi, global)
    * **Description:** Define an access rule for internal checks. The configuration file contains all built-in ones with proper comments.
    * **Syntax:** `{access, AtomName, [{Value, AclName}]}`

* **registration_timeout** (local)
    * **Description:** Limits the registration frequency from a single IP. Valid values are `infinity` or a number of seconds.

* **mongooseimctl_access_commands** (local)
    * **Description:** Defines access rules to chosen `mongooseimctl` commands.
    * **Syntax:** `{mongooseimctl_access_commands, [Rule1, Rule2, ...]}.`
    * **Rule syntax:** `{AccessRule, Commands, ArgumentRestrictions}`
        * `AccessRule` - A name of a rule defined with `acl` config key.
        * `Commands` - A list of command names (e.g. `["restart", "stop"]`) or `all`.
        * `ArgumentRestrictions` - A list of permitted argument values (e.g. `[{domain, "localhost"}]`).
    * **Example:** `{mongooseimctl_access_commands, [{local, ["join_cluster"], [{node, "mongooseim@prime"}]}]}.`

### Default language

* **language** (global)
    * **Description:** Default language for messages sent by the server to users. You can get a full list of supported codes by executing `cd [MongooseIM root] ; ls priv/*.msg | awk '{split($0,a,"/"); split(a[4],b,"."); print b[1]}'` (`en` is not listed there)
    * **Default:** `en`

### Miscellaneous

* **all_metrics_are_global** (local)
    * **Description:** When enabled, all per-host metrics are merged into global equivalents. It means it is no longer possible to view individual host1, host2, host3, ... metrics, only sums are available. This option significantly reduces CPU and (especially) memory footprint in setups with exceptionally many domains (thousands, tens of thousands).
    * **Default:** `false`

* **routing_modules** (local)
    * **Description:** Provides an ordered list of modules used for routing messages. If one of the modules accepts packet for processing, the remaining ones are not called.
    * **Syntax:** `{routing_modules, ModulesList}.`
    * **Valid modules:**
        * `mongoose_router_global` - Calls `filter_packet` hook.
        * `mongoose_router_localdomain` - Routes packets addressed to a domain supported by the local cluster.
        * `mongoose_router_external_localnode` - Delivers packet to an XMPP component connected to the node, which processes the request.
        * `mongoose_router_external` - Delivers packet to an XMPP component connected to the local cluster.
        * `ejabberd_s2s` - Forwards a packet to another XMPP cluster over XMPP Federation.
    * **Default:** `[mongoose_router_global, mongoose_router_localdomain, mongoose_router_external_localnode, mongoose_router_external, ejabberd_s2s]`
    * **Example:** `{routing_modules, [mongoose_router_global, mongoose_router_localdomain]}.`

### Modules

For a specific configuration, please refer to [Modules](advanced-configuration/Modules.md) page.

* **modules** (local)
    * **Description:** List of enabled modules with their options.

### Services

For a specific configuration, please refer to [Services](advanced-configuration/Services.md) page.

* **services** (local)
    * **Description:** List of enabled services with their options.

### Per-domain configuration

The `host_config` allows configuring most options separately for specific domains served by the cluster. It is best to put `host_config` tuple right after the global section it overrides/complements or even at the end of `ejabberd.cfg`.

* **host_config** (multi, local)
    * **Syntax:** `{host_config, Domain, [ {{add, modules}, [{mod_some, Opts}]}, {access, c2s, [{deny, local}]}, ... ]}.`

# vm.args

This file contains parameters passed directly to the Erlang VM. To configure it, go to `[MongooseIM root]/rel/files/`.

Let's explore the default options.

## Options

* `-sname` - Erlang node name. Can be changed to `name`, if necessary
* `-setcookie` - Erlang cookie. All nodes in a cluster must use the same cookie value.
* `+K` - Enables kernel polling. It improves the stability when a large number of sockets is opened, but some systems might benefit from disabling it. Might be a subject of individual load testing.
* `+A 5` - Sets the asynchronous threads number. Async threads improve I/O operations efficiency by relieving scheduler threads of IO waits.
* `+P 10000000` - Process count limit. This is a maximum allowed number of processes running per node. In general, it should exceed the tripled estimated online user count.
* `-env ERL_MAX_PORTS 250000` - Open port count. This is a maximum allowed number of ports opened per node. In general, it should exceed the tripled estimated online user count. Keep in mind that increasing this number also increases the memory usage by a constant amount, so finding the right balance for it is important for every project.
* `-env ERL_FULLSWEEP_AFTER 2` - affects garbage collection. Reduces memory consumption (forces often full g.c.) at the expense of CPU usage.
* `-sasl sasl_error_logger false` - MongooseIM's solution for logging is Lager, so SASL error logger is disabled.

# app.config

A file with Erlang application configuration. To configure it, go to `[MongooseIM root]/rel/files/`.
By default only the following applications can be found there:

* `lager` - check [Lager's documentation](https://github.com/basho/lager) for more information. Here you can change the logs location and the file names (`file`), as well as the rotation strategy (`size` and `count`) and date formatting (`date`). Ignore the log level parameters - by defaultthey are overridden with the value in `ejabberd.cfg`.
* `ejabberd`
    * `keep_lager_intact` (default: `false`) - set it to `true` when you want to keep `lager` log level parameters from `app.config`. `false` means overriding the log levels with the value in `ejabberd.cfg`.
    * `config` (default: `"etc/ejabberd.cfg"`) - path to MongooseIM config file.
* `ssl`
    * `session_lifetime` (default specified in the file: `600` seconds) - This parameter says for how long should the ssl session remain in the cache for further re-use, should `ssl session resumption` happen.

# Configuring TLS: Certificates & Keys

TLS is configured in one of two ways: some modules need a private key and certificate (chain) in __separate__ files, while others need both in a __single__ file. This is because recent additions use OTP's `ssl` library, while older modules use `p1_tls`, respectively.

* Client-to-server connections need both in the __same__ `.pem` file
* Server-to-server connections need both in the __same__ `.pem` file
* BOSH, WebSockets and REST APIs need them in __separate__ files

In order to create private key & certificate bundle, you may simply concatenate them.

More information about configuring TLS for these endpoints is available in [Listener modules](advanced-configuration/Listener-modules.md) page.
