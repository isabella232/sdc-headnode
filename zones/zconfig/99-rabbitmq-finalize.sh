echo "99 finalizing rabbitmq pkg"

# Setup erlang
svccfg import /opt/local/share/smf/manifest/erlang.xml
svcadm enable epmd
