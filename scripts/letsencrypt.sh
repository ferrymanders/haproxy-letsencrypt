#!/bin/bash

config=/config/config

echo "$(grep -Ev "^#" $config)" | while IFS=';' read domain provider backend port protocol;
do
  doHydrate=true
  case $provider in
    route53)
      #[ -d /root/.aws ] || { echo "aws config and credentials not found"; exit 0; }
      hook="/usr/bin/route53_hook.sh"
      ;;
    transip)
      export PROVIDER=transip
      hook="/usr/local/bin/lexicon_hook.sh"
      ;;
    *)
      doHydrate=false
      ;;
  esac
  
  #echo "-> $domain $provider $backend $port $protocol"
  if $doHydrate;
  then
    /usr/bin/dehydrated --cron --hook $hook --challenge dns-01 -d $domain
  else
    echo "################### Something went wrong !!! #################"
  fi
  
  cat /config/dehydrated/certs/$domain/fullchain.pem /config/dehydrated/certs/$domain/privkey.pem > /config/dehydrated/certs/$domain/haproxy.pem
  
done
