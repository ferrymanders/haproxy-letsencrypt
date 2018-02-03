#!/bin/bash

config=/config/config

configtmp=$(mktemp config.XXXXXXXX)
frontendtmp=$(mktemp frontendtmp.XXXXXXXX)
backendtmp=$(mktemp backendtmp.XXXXXXXX)
certtmp=$(mktemp certtmp.XXXXXXX)

STATS_ADMIN=${STATS_ADMIN:=admin}
STATS_PASS=${STATS_PASS:=admin}

echo "$(grep -Ev "^#" $config)" > $configtmp

while IFS=';' read domain provider backend port protocol;
do
  name=$(echo $domain | sed 's/\./_/g')
  
  case $protocol in
    https)
      echo -n " crt /config/dehydrated/certs/$domain/haproxy.pem" >> $certtmp
      echo "  acl acl_$name hdr(host) -i $domain" >> $frontendtmp
      echo "  redirect scheme https code 301 if { hdr(Host) -i $domain } !{ ssl_fc }" >> $frontendtmp
      echo "  use_backend bk_ssl_$name if acl_$name" >> $frontendtmp
      echo "" >> $frontendtmp
      
      echo "# Backend config for : $domain $backend:$port $protocol" >> $backendtmp
      echo "backend bk_ssl_$name" >> $backendtmp
      echo "  mode http" >> $backendtmp
      echo "  server ${name}_1 ${backend}:${port} check" >> $backendtmp
      echo "" >> $backendtmp
      ;;
    http$)
      echo "  acl acl_$name hdr(host) -i $domain" >> $frontendtmp
      echo "  use_backend bk_$name if acl_$name" >> $frontendtmp
      echo "" >> $frontendtmp
      
      echo "# Backend config for : $domain $backend:$port $protocol" >> $backendtmp
      echo "backend bk_$name" >> $backendtmp
      echo "  mode http" >> $backendtmp
      echo "  server ${name}_1 ${backend}:${port} check" >> $backendtmp
      echo "" >> $backendtmp 
      ;;
  esac
done < $configtmp

ssldirs=$(cat $certtmp)

echo '
global
  log 127.0.0.1:1514 local0 debug

# Adjust the timeout to your needs
defaults
  option  httplog
  option  dontlognull
  option  forwardfor
  option  contstats
  option  http-server-close
  option log-health-checks
  retries 3
  log global
  log-format {"type":"haproxy","timestamp":%Ts,"http_status":%ST,"http_request":"%r","remote_addr":"%ci","bytes_read":%B,"upstream_addr":"%si","backend_name":"%b","retries":%rc,"bytes_uploaded":%U,"upstream_response_time":"%Tr","upstream_connect_time":"%Tc","session_duration":"%Tt","termination_state":"%ts"}
  timeout client 30s
  timeout server 30s
  timeout connect 5s
' > /config/haproxy.cfg

echo "
listen stats
  bind :8080
  mode http
  stats enable  
  stats hide-version  
  stats realm Haproxy\ Statistics  
  stats uri /haproxy_stats  
  stats auth ${STATS_ADMIN}:${STATS_PASS}
" >> /config/haproxy.cfg

echo "
# Single VIP with sni content switching
frontend ft_ssl_vip
  bind *:443 ssl $ssldirs
  bind *:80
  mode http
  
  tcp-request inspect-delay 5s
  tcp-request content accept if { req_ssl_hello_type 1 }  
" >> /config/haproxy.cfg


cat $frontendtmp >> /config/haproxy.cfg

echo "
  default_backend bk_ssl_default
" >> /config/haproxy.cfg

cat $backendtmp >> /config/haproxy.cfg

echo "
backend bk_ssl_default
  mode http
  errorfile 503 /usr/local/etc/haproxy/errors/default-page.http
" >> /config/haproxy.cfg


rm $configtmp
rm $frontendtmp
rm $backendtmp
rm $certtmp